#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 06-tls-test.sh — Test the certificate in a live TLS handshake
#
# This requires two terminals. The script starts the server
# and then tells you what to run in the second terminal.
# ============================================================

DOMAIN="test.pkilab.local"
PORT=4433

echo "============================================================"
echo " TLS Live Test"
echo "============================================================"
echo ""
echo " This script starts a TLS server. You'll need a SECOND"
echo " terminal to run the client commands below."
echo ""
echo " ── Client commands to try (copy-paste into terminal 2) ──"
echo ""
echo " TEST A — Successful verification:"
echo ""
echo "   openssl s_client -connect localhost:${PORT} \\"
echo "     -CAfile root/root.crt"
echo ""
echo "   Expected: Verify return code: 0 (ok)"
echo "   The client trusts our root, receives leaf+intermediate"
echo "   from the server, verifies the chain, all good."
echo ""
echo " TEST B — Hostname verification (should PASS):"
echo ""
echo "   openssl s_client -connect localhost:${PORT} \\"
echo "     -CAfile root/root.crt \\"
echo "     -verify_hostname ${DOMAIN}"
echo ""
echo "   Expected: Verify return code: 0 (ok)"
echo "   The SAN includes ${DOMAIN}, so hostname matches."
echo ""
echo " TEST C — Hostname mismatch (should FAIL):"
echo ""
echo "   openssl s_client -connect localhost:${PORT} \\"
echo "     -CAfile root/root.crt \\"
echo "     -verify_hostname evil.example.com"
echo ""
echo "   Expected: Verify return code: 62 (hostname mismatch)"
echo "   The chain is valid, but the cert isn't for that hostname."
echo "   This is the defense against stolen/misused certificates."
echo ""
echo " TEST D — No trust anchor (should FAIL):"
echo ""
echo "   openssl s_client -connect localhost:${PORT}"
echo ""
echo "   Expected: Verify return code: 19 (self-signed certificate in chain)"
echo "   Without -CAfile, the system trust store is used. Our custom"
echo "   root isn't in there, so the chain terminates at an untrusted"
echo "   self-signed cert. This is what browsers show as a warning."
echo ""
echo " TEST E — Inspect the full handshake:"
echo ""
echo "   openssl s_client -connect localhost:${PORT} \\"
echo "     -CAfile root/root.crt -state -debug"
echo ""
echo "   Shows every TLS handshake message: ClientHello, ServerHello,"
echo "   Certificate, CertificateVerify, Finished, etc."
echo ""
echo " Press Ctrl+C in THIS terminal to stop the server."
echo "============================================================"
echo ""
echo "==> Starting TLS server on port ${PORT}..."
echo ""

# s_server      — minimal TLS server (like netcat over TLS)
# -accept       — port to listen on
# -cert         — leaf certificate to present to clients
# -key          — private key for the TLS handshake
#                 In TLS 1.3: server signs the handshake transcript (CertificateVerify)
#                 In TLS 1.2 RSA: server decrypts the premaster secret
# -CAfile       — intermediate cert(s) to send in the Certificate message
#                 alongside the leaf, so the client can build the chain
# -www          — serve a simple status page if the client sends an HTTP GET
#                 (makes it testable from a browser too, though it'll warn about
#                 the untrusted root)
openssl s_server -accept "${PORT}" \
  -cert "certs/${DOMAIN}.crt" \
  -key "certs/${DOMAIN}.key" \
  -CAfile intermediate/intermediate.crt \
  -www
