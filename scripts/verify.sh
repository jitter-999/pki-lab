#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 05-verify.sh — Verify the certificate chain offline
#
# This simulates what a TLS client does: given a leaf cert and
# a trust store, can it build a valid chain?
# ============================================================

DOMAIN="test.pkilab.local"

echo "==> Test 1: Full chain verification (should PASS)"
echo ""
echo "    Command: openssl verify -CAfile root/root.crt \\"
echo "               -untrusted intermediate/intermediate.crt \\"
echo "               certs/${DOMAIN}.crt"
echo ""
echo "    -CAfile    = trust store (certs we consider root anchors)"
echo "    -untrusted = chain-building hints (NOT trusted as roots)"
echo ""
echo "    The verifier:"
echo "    1. Reads the leaf cert"
echo "    2. Finds its issuer (intermediate) in -untrusted"
echo "    3. Verifies the leaf's signature with the intermediate's public key"
echo "    4. Finds the intermediate's issuer (root) in -CAfile"
echo "    5. Verifies the intermediate's signature with the root's public key"
echo "    6. Root is in -CAfile → trusted anchor → chain complete"
echo ""

openssl verify -CAfile root/root.crt \
  -untrusted intermediate/intermediate.crt \
  "certs/${DOMAIN}.crt"

echo ""
echo "---"
echo ""
echo "==> Test 2: Verify WITHOUT the intermediate (should FAIL)"
echo ""
echo "    Without the intermediate, OpenSSL can't connect leaf → root."
echo ""

openssl verify -CAfile root/root.crt "certs/${DOMAIN}.crt" 2>&1 || true
# Expected: error 20 at 0 depth lookup: unable to get local issuer certificate

echo ""
echo "---"
echo ""
echo "==> Test 3: Verify with intermediate in -CAfile (WRONG but passes)"
echo ""
echo "    Putting the intermediate in -CAfile means 'trust it as a root.'"
echo "    This passes but is semantically wrong — it skips verifying the"
echo "    intermediate's own signature chain. Don't do this in production."
echo ""

openssl verify -CAfile intermediate/intermediate.crt "certs/${DOMAIN}.crt" 2>&1 || true

echo ""
echo "---"
echo ""
echo "==> Test 4: Inspect what the chain file contains"
echo ""
echo "    The chain file is just concatenated PEM certs. Here are the subjects:"
echo ""

# This uses a neat trick: openssl reads multiple PEMs from stdin and shows each
openssl crl2pkcs7 -nocrl -certfile "certs/${DOMAIN}.chain.pem" \
  | openssl pkcs7 -print_certs -noout 2>/dev/null || \
  echo "    (Listing subjects from chain file...)" && \
  grep -E "^subject=|^issuer=" <(openssl x509 -in "certs/${DOMAIN}.crt" -noout -subject -issuer) && \
  echo "    ---" && \
  grep -E "^subject=|^issuer=" <(openssl x509 -in intermediate/intermediate.crt -noout -subject -issuer)

echo ""
echo "==> Next: ./scripts/06-tls-test.sh"
