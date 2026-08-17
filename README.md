# pki-lab

Build a three-tier certificate authority from scratch using OpenSSL. Root CA → Intermediate CA → leaf certificate, with scripts for each step.

I put this together while learning how PKI actually works — not the theory, but the actual OpenSSL commands, config directives, and what happens when things break. The scripts are heavily commented so you can read them as you go.

## Prerequisites

- OpenSSL 3.x (`openssl version`)
- Linux, macOS, or WSL
- A terminal

## What's in here

```
configs/
  root.cnf              # OpenSSL config for the root CA
  intermediate.cnf      # OpenSSL config for the intermediate CA
scripts/
  01-setup.sh           # Create directory structure
  02-root-ca.sh         # Generate the root CA
  03-intermediate-ca.sh # Generate and sign the intermediate CA
  04-leaf-cert.sh       # Issue a server certificate
  05-verify.sh          # Verify the chain offline
  06-tls-test.sh        # Live TLS server/client test
  07-break-it.sh        # Deliberately break things
docs/
  concepts.md           # Background on X.509, trust stores, extensions
  config-reference.md   # Line-by-line explanation of the config files
```

The `root/`, `intermediate/`, and `certs/` directories are created by the scripts and gitignored. They contain private keys.

## Usage

```bash
git clone https://github.com/<your-username>/pki-lab.git
cd pki-lab

chmod +x scripts/*.sh

./scripts/01-setup.sh
./scripts/02-root-ca.sh
./scripts/03-intermediate-ca.sh
./scripts/04-leaf-cert.sh
./scripts/05-verify.sh
./scripts/06-tls-test.sh
```

Read the scripts before running them — the comments explain every flag and config directive.

## Walkthrough

### 1. Setup (`01-setup.sh`)

Creates directories and initializes OpenSSL's bookkeeping files (`index.txt` for tracking issued certs, `serial` for the next serial number, `newcerts/` for audit copies).

```bash
mkdir -p root/newcerts intermediate/newcerts certs
touch root/index.txt intermediate/index.txt
echo 1000 > root/serial
echo 2000 > intermediate/serial
```

### 2. Root CA (`02-root-ca.sh`)

Generates the root CA's key (4096-bit RSA, passphrase-encrypted) and a self-signed certificate.

```bash
openssl genrsa -aes256 -out root/root.key 4096

openssl req -config configs/root.cnf \
  -key root/root.key \
  -new -x509 -days 3650 \
  -extensions v3_ca \
  -out root/root.crt
```

The `-x509` flag is what makes this self-signed — the cert signs itself instead of producing a CSR for someone else to sign. Check the output for `CA:TRUE` in Basic Constraints and `Certificate Sign, CRL Sign` in Key Usage.

### 3. Intermediate CA (`03-intermediate-ca.sh`)

Generates the intermediate's key, creates a CSR, and has the root sign it.

```bash
openssl genrsa -aes256 -out intermediate/intermediate.key 4096

openssl req -config configs/intermediate.cnf \
  -key intermediate/intermediate.key \
  -new \
  -out intermediate/intermediate.csr

openssl ca -config configs/root.cnf \
  -extensions v3_intermediate_ca \
  -extfile configs/intermediate.cnf \
  -days 1825 \
  -notext \
  -in intermediate/intermediate.csr \
  -out intermediate/intermediate.crt
```

No `-x509` this time, so `openssl req` produces a CSR instead of a cert. The root then signs it with `openssl ca`. Note that `-config` points to the *root's* config (the root is the signer) but `-extfile` points to the *intermediate's* config (that's where the `v3_intermediate_ca` extensions section lives).

The intermediate gets `CA:TRUE, pathlen:0` — it can sign leaf certs but not further CAs.

### 4. Leaf certificate (`04-leaf-cert.sh`)

Issues a server certificate for `test.pkilab.local`.

```bash
openssl genrsa -out certs/test.pkilab.local.key 2048

openssl req -new \
  -key certs/test.pkilab.local.key \
  -subj "/C=CH/O=PKI Lab/CN=test.pkilab.local" \
  -out certs/test.pkilab.local.csr

openssl ca -config configs/intermediate.cnf \
  -extensions server_cert \
  -notext \
  -in certs/test.pkilab.local.csr \
  -out certs/test.pkilab.local.crt

cat certs/test.pkilab.local.crt intermediate/intermediate.crt \
  > certs/test.pkilab.local.chain.pem
```

No passphrase on the server key (servers need unattended startup). 2048-bit is fine for a short-lived leaf. The chain file concatenates the leaf and intermediate — the server sends both during TLS so the client can build the chain back to the root.

### 5. Verification (`05-verify.sh`)

```bash
openssl verify -CAfile root/root.crt \
  -untrusted intermediate/intermediate.crt \
  certs/test.pkilab.local.crt
```

`-CAfile` is the trust store (what you consider a root). `-untrusted` provides the intermediate for chain building but doesn't treat it as a trust anchor. If you put the intermediate in `-CAfile` instead, verification would pass even if the intermediate's signature from the root was broken — that's the wrong thing to do.

### 6. Live TLS test (`06-tls-test.sh`)

Start a TLS server in one terminal:

```bash
openssl s_server -accept 4433 \
  -cert certs/test.pkilab.local.crt \
  -key certs/test.pkilab.local.key \
  -CAfile intermediate/intermediate.crt
```

Connect from another:

```bash
openssl s_client -connect localhost:4433 \
  -CAfile root/root.crt
```

You should see `Verify return code: 0 (ok)`. Try it without `-CAfile` to see what happens when the root isn't trusted (error 19). Try `-verify_hostname evil.example.com` to see a SAN mismatch (error 62).

### 7. Break things (`07-break-it.sh`)

Four exercises you run individually with `./scripts/07-break-it.sh [a|b|c|d]`:

- **a** — Issue a cert without `CA:FALSE` and use it to sign another cert. Shows why extensions matter.
- **b** — Expired certificates.
- **c** — SAN/hostname mismatches and wildcard behavior.
- **d** — Revoke a cert, generate a CRL, verify against it.

## More detail

- [docs/concepts.md](docs/concepts.md) — what X.509 certificates are, how trust stores and chain verification work, CSRs vs certs, revocation
- [docs/config-reference.md](docs/config-reference.md) — every directive in the config files explained

## What to do next

- **SoftHSM2 + PKCS#11** — redo this lab but store CA keys in a software HSM instead of files
- **step-ca** — replace the manual CA with an ACME-compatible automated one
- **mTLS** — set up two services that authenticate each other with client certificates
- **Post-quantum certs** — use OpenSSL 3.x with the oqs-provider to build a chain using ML-DSA signatures

## License

MIT
