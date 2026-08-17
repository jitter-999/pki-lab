#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 04-leaf-cert.sh — Issue a server (leaf) certificate for
#   test.pkilab.local, signed by the Intermediate CA.
# ============================================================

DOMAIN="test.pkilab.local"

echo "==> Generating server private key for ${DOMAIN}..."
echo "    No passphrase (-aes256 omitted) — servers need unattended startup."
echo "    In production, protect this with file permissions or an HSM."
echo ""

# 2048-bit is sufficient for a short-lived leaf cert.
# The performance savings over 4096-bit matter for TLS handshakes.
openssl genrsa -out "certs/${DOMAIN}.key" 2048
chmod 400 "certs/${DOMAIN}.key"

echo ""
echo "==> Generating CSR for ${DOMAIN}..."
echo ""

# -subj         — pass subject fields inline instead of reading from a config.
#                 Format: /KEY=VALUE/KEY=VALUE
#                 C = Country, O = Organization, CN = Common Name
# -new          — new CSR
# -key          — the server's private key
openssl req -new \
  -key "certs/${DOMAIN}.key" \
  -subj "/C=CH/O=PKI Lab/CN=${DOMAIN}" \
  -out "certs/${DOMAIN}.csr"

echo "==> Intermediate CA signing the leaf CSR..."
echo "    You'll need the INTERMEDIATE CA's passphrase."
echo ""

# -config       — intermediate's config (intermediate is the signer now)
# -extensions server_cert — applies leaf extensions:
#                 CA:FALSE, digitalSignature, keyEncipherment, serverAuth, SANs
openssl ca -config configs/intermediate.cnf \
  -extensions server_cert \
  -notext \
  -in "certs/${DOMAIN}.csr" \
  -out "certs/${DOMAIN}.crt"

echo ""
echo "==> Building chain file (leaf + intermediate)..."
echo "    The server sends this during TLS so the client can build the chain."
echo "    Root is NOT included — the client already has it in its trust store."
echo ""

# cat concatenates PEM files. Order: leaf first, then intermediate(s).
# PEM files are text with BEGIN/END delimiters, so concatenation is valid.
cat "certs/${DOMAIN}.crt" intermediate/intermediate.crt \
  > "certs/${DOMAIN}.chain.pem"

echo "==> Inspecting the leaf certificate..."
echo ""

openssl x509 -in "certs/${DOMAIN}.crt" -text -noout

echo ""
echo "==> Verify these in the output above:"
echo "    • Basic Constraints: CA:FALSE"
echo "    • Key Usage: Digital Signature, Key Encipherment"
echo "    • Extended Key Usage: TLS Web Server Authentication"
echo "    • Subject Alternative Name: DNS:test.pkilab.local, DNS:*.pkilab.local"
echo ""
echo "==> Next: ./scripts/05-verify.sh"
