#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 07-break-it.sh — Deliberate failure exercises
#
# These exercises intentionally break things so you can see
# what the errors look like. Run them one at a time, read the
# output, and understand WHY it fails.
#
# Usage: ./scripts/07-break-it.sh [a|b|c|d]
# ============================================================

DOMAIN="test.pkilab.local"

exercise_a() {
    echo "============================================================"
    echo " Exercise A — Missing CA:FALSE on a leaf cert"
    echo ""
    echo " We'll issue a self-signed cert WITHOUT basicConstraints"
    echo " and see if we can use it to sign another certificate."
    echo "============================================================"
    echo ""

    # Create a self-signed cert with NO extensions at all
    openssl req -new -x509 \
      -key "certs/${DOMAIN}.key" \
      -subj "/CN=Unrestricted Leaf" \
      -days 365 \
      -out certs/unrestricted.crt

    echo "==> Created certs/unrestricted.crt with no CA constraint."
    echo ""

    # Generate a new key and CSR for a "rogue" cert
    openssl genrsa -out certs/rogue.key 2048 2>/dev/null
    openssl req -new \
      -key certs/rogue.key \
      -subj "/CN=Rogue Certificate" \
      -out certs/rogue.csr

    # Use the unrestricted cert to sign the rogue CSR
    openssl x509 -req \
      -in certs/rogue.csr \
      -CA certs/unrestricted.crt \
      -CAkey "certs/${DOMAIN}.key" \
      -CAcreateserial \
      -out certs/rogue.crt \
      -days 365

    echo ""
    echo "==> Signed certs/rogue.crt using the unrestricted leaf as a CA."
    echo "    The RSA math doesn't care — any key can sign anything."
    echo ""
    echo "==> Now let's verify it:"
    echo ""

    openssl verify -CAfile certs/unrestricted.crt certs/rogue.crt 2>&1 || true

    echo ""
    echo "==> LESSON: Without CA:TRUE, a proper X.509 verifier rejects"
    echo "    the chain. Extensions are the POLICY layer on top of the math."
    echo "    The signature is valid, but the cert isn't authorized to sign."
    echo ""

    # Clean up
    rm -f certs/unrestricted.crt certs/rogue.key certs/rogue.csr certs/rogue.crt certs/unrestricted.srl
}

exercise_b() {
    echo "============================================================"
    echo " Exercise B — Expired certificate"
    echo ""
    echo " We'll issue a cert with dates in the past and try to use it."
    echo "============================================================"
    echo ""

    openssl req -new -x509 \
      -key "certs/${DOMAIN}.key" \
      -subj "/CN=Expired Cert" \
      -days 1 \
      -out certs/expired.crt

    echo "==> Created a cert valid for only 1 day."
    echo "    To see a real expiry failure, you'd need to wait or backdate."
    echo ""
    echo "==> Checking the validity dates:"
    openssl x509 -in certs/expired.crt -noout -dates
    echo ""
    echo "==> To simulate expiry, try changing your system clock forward"
    echo "    by 2 days (in a VM!) and running:"
    echo ""
    echo "    openssl verify -CAfile certs/expired.crt certs/expired.crt"
    echo "    # → certificate has expired"
    echo ""
    echo "==> Or use faketime:"
    echo "    faketime '+2 days' openssl verify certs/expired.crt"
    echo ""

    rm -f certs/expired.crt
}

exercise_c() {
    echo "============================================================"
    echo " Exercise C — SAN mismatch"
    echo ""
    echo " Our cert has SANs for test.pkilab.local and *.pkilab.local."
    echo " We'll test what happens with a non-matching hostname."
    echo "============================================================"
    echo ""

    echo "==> The leaf cert's SANs:"
    openssl x509 -in "certs/${DOMAIN}.crt" -noout -ext subjectAltName
    echo ""

    echo "==> Verifying against a matching hostname (should pass):"
    openssl x509 -in "certs/${DOMAIN}.crt" -noout \
      -checkhost test.pkilab.local
    echo ""

    echo "==> Verifying against a non-matching hostname (should fail):"
    openssl x509 -in "certs/${DOMAIN}.crt" -noout \
      -checkhost evil.example.com
    echo ""

    echo "==> Verifying a subdomain against the wildcard (should pass):"
    openssl x509 -in "certs/${DOMAIN}.crt" -noout \
      -checkhost anything.pkilab.local
    echo ""

    echo "==> Verifying a NESTED subdomain against the wildcard (should fail):"
    echo "    Wildcards match only one label: *.pkilab.local does NOT match"
    echo "    sub.anything.pkilab.local"
    openssl x509 -in "certs/${DOMAIN}.crt" -noout \
      -checkhost sub.anything.pkilab.local
    echo ""
}

exercise_d() {
    echo "============================================================"
    echo " Exercise D — Certificate revocation"
    echo ""
    echo " We'll revoke the leaf cert, generate a CRL, and verify."
    echo ""
    echo " WARNING: This revokes your leaf cert. You'll need to re-run"
    echo " 04-leaf-cert.sh to get a new one afterward."
    echo "============================================================"
    echo ""
    read -p "Proceed with revocation? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipped."
        return
    fi

    echo "==> Revoking the leaf certificate..."
    echo "    You'll need the INTERMEDIATE CA's passphrase."
    echo ""

    # ca -revoke    — mark a cert as revoked in index.txt
    openssl ca -config configs/intermediate.cnf \
      -revoke "certs/${DOMAIN}.crt"

    echo ""
    echo "==> Generating a Certificate Revocation List (CRL)..."
    echo ""

    # ca -gencrl    — generate a CRL file listing all revoked certs
    openssl ca -config configs/intermediate.cnf \
      -gencrl -out intermediate/intermediate.crl.pem

    echo "==> CRL contents:"
    openssl crl -in intermediate/intermediate.crl.pem -text -noout

    echo ""
    echo "==> Verifying the revoked cert with CRL checking..."
    echo ""

    # -crl_check    — enable CRL checking during verification
    # -CRLfile      — the CRL to check against
    openssl verify -CAfile root/root.crt \
      -untrusted intermediate/intermediate.crt \
      -crl_check -CRLfile intermediate/intermediate.crl.pem \
      "certs/${DOMAIN}.crt" 2>&1 || true

    echo ""
    echo "==> Expected: certificate revoked"
    echo "    The chain signature is still valid, but the CRL says"
    echo "    this serial number has been revoked. A proper client"
    echo "    checks OCSP or CRLs before accepting a cert."
    echo ""
    echo "==> To get a fresh leaf cert, re-run: ./scripts/04-leaf-cert.sh"
}

# ---- Main ----

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 [a|b|c|d]"
    echo ""
    echo "  a — Missing CA:FALSE (can a leaf sign other certs?)"
    echo "  b — Expired certificate"
    echo "  c — SAN / hostname mismatch"
    echo "  d — Certificate revocation and CRL"
    exit 0
fi

case "${1,,}" in
    a) exercise_a ;;
    b) exercise_b ;;
    c) exercise_c ;;
    d) exercise_d ;;
    *) echo "Unknown exercise: $1. Use a, b, c, or d." ;;
esac
