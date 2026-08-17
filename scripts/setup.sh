#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 01-setup.sh — Create the directory structure and bookkeeping
#               files that OpenSSL's CA commands expect.
# ============================================================

echo "==> Creating directory structure..."

mkdir -p root/newcerts
mkdir -p intermediate/newcerts
mkdir -p certs

# index.txt: OpenSSL's flat-file database.
# Each line records a certificate's status (V=valid, R=revoked, E=expired),
# expiry date, revocation date (if any), serial number, and subject DN.
# Starts empty — OpenSSL populates it as you sign certs.
touch root/index.txt
touch intermediate/index.txt

# serial: Contains the next serial number to assign, in hex.
# X.509 requires every cert issued by a CA to have a unique serial.
# OpenSSL reads this, uses it, and increments it after each signing.
echo 1000 > root/serial
echo 2000 > intermediate/serial

echo "==> Directory structure ready:"
echo ""
echo "    root/            — Root CA keys, certs, and database"
echo "    root/newcerts/   — Audit copies of certs signed by root"
echo "    intermediate/    — Intermediate CA keys, certs, and database"
echo "    intermediate/newcerts/ — Audit copies of certs signed by intermediate"
echo "    certs/           — Leaf certificates"
echo ""
echo "==> Next: ./scripts/02-root-ca.sh"
