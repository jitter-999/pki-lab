# PKI Concepts

Background for the lab. Read this if the walkthrough left you wanting more "why."

## What problem does PKI solve?

You want to talk securely to a server. Encryption alone isn't enough — you need to know you're encrypting to the *right* server, not an attacker in the middle. PKI creates a system where trusted third parties (Certificate Authorities) vouch for the identity of servers (and sometimes clients).

The model: you trust a small set of root CAs (pre-installed in your OS or browser). Those root CAs sign intermediate CAs. Intermediate CAs sign leaf certificates for specific servers. When you connect, the server presents its leaf cert and the intermediates, and your client walks the chain back to a root it trusts.

## X.509 certificates

An X.509 certificate is a signed data structure that binds a public key to an identity. The important fields:

- **Subject** — who the certificate identifies (CN, O, C, etc.)
- **Issuer** — who signed it
- **Public Key** — the subject's public key
- **Validity Period** — Not Before / Not After dates
- **Serial Number** — unique within the issuing CA
- **Signature** — the issuer's signature over all the above
- **Extensions** — the policy layer (see below)

Certificates are encoded in ASN.1 DER (binary), usually wrapped in PEM (base64 with `-----BEGIN CERTIFICATE-----` headers) for storage.

## Extensions

The math of public-key cryptography doesn't care about authorization — any private key can sign any data. Extensions add constraints that software enforces on top of the math.

**Basic Constraints** says whether a certificate is a CA or a leaf. `CA:TRUE` means it can sign other certificates. `CA:FALSE` means it can't. `pathlen` limits how deep the hierarchy can go below this point.

**Key Usage** restricts what operations the key can perform. A CA key should only have `keyCertSign` and `cRLSign`. A server key should have `digitalSignature` and `keyEncipherment`.

**Extended Key Usage** narrows the purpose further. `serverAuth` = TLS server authentication. `clientAuth` = TLS client auth (for mTLS). A cert with `serverAuth` can't be used for code signing even if the Key Usage bits would allow it.

**Subject Alternative Names (SANs)** list the hostnames the cert is valid for. Modern TLS checks SANs, not the CN. Wildcards (`*.example.com`) match one DNS label only.

The `critical` flag means software MUST enforce the extension. If it doesn't recognize a critical extension, it must reject the cert. Non-critical extensions can be ignored.

Exercise A in `07-break-it.sh` shows what happens when these constraints are missing — you can actually sign a cert with a leaf that has no `CA:TRUE`, and the RSA math works fine. The extension is the only thing stopping it.

## Trust stores

A trust store is a collection of root CA certificates your system considers trustworthy. Your OS ships with one (a few hundred roots). Browsers may use the OS store or maintain their own (Firefox has its own).

Adding a cert to a trust store means unconditional trust: anything signed by this CA (directly or through intermediates) will be accepted. That's why root CA keys are so heavily protected — compromising one lets you impersonate any site.

In the lab, `-CAfile root/root.crt` is our trust store. It only contains our custom root.

## Chain verification

When a client verifies a chain, it checks:

1. **Signatures** — each cert's signature is valid under its issuer's public key
2. **Chain completeness** — it reaches a trusted root
3. **Validity period** — nothing's expired
4. **Basic Constraints** — issuers have `CA:TRUE`
5. **Path length** — `pathlen` constraints hold
6. **Key Usage** — issuers have `keyCertSign`
7. **Hostname** — the leaf's SANs include the hostname being connected to
8. **Revocation** — the cert hasn't been revoked (via CRL or OCSP)

`05-verify.sh` runs through this offline. `06-tls-test.sh` runs through it in a live TLS handshake where you can see each depth being checked.

## CSRs vs certificates

A Certificate Signing Request is not a certificate. It's a request: "here is my public key and my desired subject, please sign me a certificate." The CSR includes a proof-of-possession signature (the requester signs it with their private key to prove they hold the matching key).

The CSR does NOT contain extensions. Extensions are applied by the signing CA according to its own policy. You can't request `CA:TRUE` in a CSR and expect the CA to grant it.

This is visible in the lab: in step 3, `openssl req` produces a CSR, and then `openssl ca` stamps the `v3_intermediate_ca` extensions onto the resulting certificate. The requester doesn't control what extensions they get.

## Revocation

Certificates can be revoked before they expire. Two mechanisms:

**CRL (Certificate Revocation List)** — the CA periodically publishes a signed list of revoked serial numbers. Clients download and cache it. Problem: there's a window between revocation and the next CRL publication where clients don't know yet.

**OCSP (Online Certificate Status Protocol)** — the client asks the CA in real time whether a serial number is revoked. More timely, but adds a round-trip and a privacy issue (the CA sees which sites you visit). OCSP stapling avoids this: the server fetches the OCSP response itself and includes it in the TLS handshake.

Exercise D in `07-break-it.sh` walks through revoking a cert and verifying against a CRL.

