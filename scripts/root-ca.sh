#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 02-root-ca.sh — Generate the Root CA key and self-signed cert
# ============================================================

echo "==> Generating Root CA private key (4096-bit RSA, AES-256 encrypted)..."
echo "    You'll be asked for a passphrase. This protects the root key at rest."
echo ""

# genrsa        — generate an RSA private key
# -aes256       — encrypt the PEM file with AES-256-CBC (passphrase-derived key)
# -out          — output file path
# 4096          — key size in bits (CA keys use 4096 for long-term security margin)
openssl genrsa -aes256 -out root/root.key 4096

# Lock down file permissions — only the owner can read the key
chmod 400 root/root.key

echo ""
echo "==> Generating self-signed Root CA certificate (valid 10 years)..."
echo ""

# req           — certificate request / self-signed cert generator
# -config       — read settings from this config file
# -key          — sign with this private key
# -new          — create a new request (combined with -x509: a new self-signed cert)
# -x509         — output a self-signed cert instead of a CSR
# -days 3650    — validity period (~10 years)
# -extensions   — apply extensions from this config section (adds CA:TRUE, keyCertSign)
# -out          — output certificate file
openssl req -config configs/root.cnf \
  -key root/root.key \
  -new -x509 -days 3650 \
  -extensions v3_ca \
  -out root/root.crt

echo ""
echo "==> Root CA certificate created. Inspecting..."
echo ""

# x509          — certificate display/manipulation tool
# -in           — input certificate
# -text         — print human-readable decoded form
# -noout        — don't also print the raw PEM base64
openssl x509 -in root/root.crt -text -noout

echo ""
echo "==> Verify these in the output above:"
echo "    • Issuer and Subject are identical (self-signed)"
echo "    • Basic Constraints: CA:TRUE"
echo "    • Key Usage: Certificate Sign, CRL Sign"
echo ""
echo "==> Next: ./scripts/03-intermediate-ca.sh"
