#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 03-intermediate-ca.sh — Generate the Intermediate CA key,
#   create a CSR, and have the Root CA sign it.
# ============================================================

echo "==> Generating Intermediate CA private key..."
echo ""

openssl genrsa -aes256 -out intermediate/intermediate.key 4096
chmod 400 intermediate/intermediate.key

echo ""
echo "==> Generating Certificate Signing Request (CSR)..."
echo "    Note: no -x509 flag, so this produces a REQUEST, not a certificate."
echo "    The CSR contains the public key + subject, signed by the requester's"
echo "    private key (proof of possession). Extensions like CA:TRUE are NOT in"
echo "    the CSR — the signing CA applies them."
echo ""

# req -new      — generate a new CSR (no -x509 = not self-signed)
# -config       — config with the intermediate's subject fields
# -key          — the intermediate's private key (for the proof-of-possession signature)
# -out          — the CSR file
openssl req -config configs/intermediate.cnf \
  -key intermediate/intermediate.key \
  -new \
  -out intermediate/intermediate.csr

echo ""
echo "==> Root CA signing the intermediate's CSR..."
echo "    You'll need the ROOT CA's passphrase (not the intermediate's)."
echo ""

# ca            — the CA signing command (stateful: updates index.txt and serial)
# -config       — the ROOT's config (root is the signer, so we need root's key/cert/db)
# -extensions   — apply v3_intermediate_ca extensions to the resulting cert
# -extfile      — find those extensions in this file (intermediate's config)
# -days 1825    — 5-year validity (shorter than root, allows rotation)
# -notext       — don't embed human-readable text in the PEM
# -in           — the CSR to sign
# -out          — the resulting signed certificate
openssl ca -config configs/root.cnf \
  -extensions v3_intermediate_ca \
  -extfile configs/intermediate.cnf \
  -days 1825 \
  -notext \
  -in intermediate/intermediate.csr \
  -out intermediate/intermediate.crt

echo ""
echo "==> Verifying the intermediate chains back to the root..."
echo ""

# verify        — validate a certificate chain
# -CAfile       — trust store (the root we trust)
# last arg      — the cert to verify
openssl verify -CAfile root/root.crt intermediate/intermediate.crt

echo ""
echo "==> Inspecting the intermediate certificate..."
echo ""

openssl x509 -in intermediate/intermediate.crt -text -noout

echo ""
echo "==> Verify these in the output above:"
echo "    • Issuer is the Root CA, Subject is the Intermediate CA"
echo "    • Basic Constraints: CA:TRUE, pathlen:0"
echo "    • Key Usage: Certificate Sign, CRL Sign"
echo ""
echo "==> Next: ./scripts/04-leaf-cert.sh"
