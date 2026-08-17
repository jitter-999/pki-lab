# PKI Concepts

Background for the hands-on lab. Read this if the README's walkthrough left you wanting more "why."

## What Problem Does PKI Solve?

You want to talk securely to a server. Encryption alone isn't enough — you need to know you're encrypting to the *right* server, not an attacker sitting in the middle. PKI solves this by creating a system where trusted third parties (Certificate Authorities) vouch for the identity of servers (and sometimes clients).

The model is: you trust a small set of root CAs (pre-installed in your OS or browser). Those root CAs sign intermediate CAs. Intermediate CAs sign leaf certificates for specific servers. When you connect to a server, it presents its leaf cert and the intermediates, and your client walks the chain back to a root it trusts.

## X.509 Certificates

An X.509 certificate is a signed data structure that binds a public key to an identity. The important fields:

- **Subject** — who the certificate identifies (CN, O, C, etc.)
- **Issuer** — who signed this certificate
- **Public Key** — the subject's public key
- **Validity Period** — Not Before / Not After dates
- **Serial Number** — unique within the issuing CA
- **Signature** — the issuer's RSA/ECDSA signature over all the above
- **Extensions** — the policy layer (see below)

The certificate is encoded in ASN.1 DER (a binary format), then usually wrapped in PEM (base64 with `-----BEGIN CERTIFICATE-----` headers) for storage and transmission.

## Extensions — The Policy Layer

The raw math of public-key cryptography doesn't care about authorization. Any private key can sign any data. Extensions add constraints that software enforces on top of the math:

**Basic Constraints** tells you whether a certificate is a CA or a leaf. `CA:TRUE` means it's allowed to sign other certificates. `CA:FALSE` means it's an end-entity. The `pathlen` constraint limits how deep the CA hierarchy can go below this point.

**Key Usage** restricts what operations the key can perform. A CA key should only have `keyCertSign` and `cRLSign`. A server key should have `digitalSignature` (for TLS handshake signing) and `keyEncipherment` (for RSA key exchange).

**Extended Key Usage** further narrows the purpose. `serverAuth` means TLS server authentication. `clientAuth` means TLS client authentication (for mTLS). `codeSigning` means code signing. A certificate with `serverAuth` cannot be used for code signing, even if the Key Usage bits would allow it.

**Subject Alternative Names (SANs)** list the hostnames (or IPs, or email addresses) the certificate is valid for. Modern TLS clients check SANs, not the CN field in the Subject. Wildcards (`*.example.com`) match one DNS label only.

The `critical` flag on an extension means: any software that encounters this certificate MUST understand and enforce this extension. If it doesn't recognize the extension, it must reject the certificate. Non-critical extensions are advisory — unrecognized ones can be ignored.

## Trust Stores

A trust store is a collection of root CA certificates that a system considers trustworthy. Your operating system ships with one (hundreds of root CAs from DigiCert, Let's Encrypt, GlobalSign, etc.). Browsers may use the OS store or maintain their own (Firefox has its own, Chrome uses the OS store on most platforms).

Adding a certificate to a trust store is a statement of unconditional trust: anything signed (directly or through intermediates) by this CA will be accepted. This is why root CA private keys are protected so aggressively — compromising one lets an attacker impersonate any website.

## Chain Verification

When a client verifies a certificate chain, it checks:

1. **Signature validity** — each cert's signature is valid under its issuer's public key
2. **Chain completeness** — the chain reaches a trusted root
3. **Validity period** — no cert is expired or not-yet-valid
4. **Basic Constraints** — intermediate certs have CA:TRUE
5. **Path length** — pathlen constraints aren't violated
6. **Key Usage** — issuers have keyCertSign
7. **Hostname match** — the leaf's SANs include the hostname being connected to
8. **Revocation status** — the cert hasn't been revoked (via CRL or OCSP)

## CSR vs Certificate

A Certificate Signing Request (CSR) is not a certificate. It's a request that says "here is my public key and my desired subject; please sign me a certificate." The CSR includes a proof-of-possession signature (the requester signs it with their own private key to prove they hold the corresponding private key).

Crucially, the CSR does NOT contain extensions. Extensions are applied by the signing CA according to its policy. You can't request `CA:TRUE` in a CSR and expect the CA to grant it — the CA decides what extensions to apply based on its own configuration and the type of certificate being issued.

## Revocation

Certificates can be revoked before they expire. Two mechanisms:

**CRL (Certificate Revocation List)** — the CA periodically publishes a signed list of revoked serial numbers. Clients download and cache it. Downsides: CRLs can be large, and there's a window between revocation and the next CRL publication where clients don't know about the revocation.

**OCSP (Online Certificate Status Protocol)** — the client asks the CA's OCSP responder "is this serial number revoked?" in real time. More timely than CRLs, but adds a network round-trip and a privacy concern (the CA sees which sites you're visiting). OCSP stapling mitigates this: the server itself fetches the OCSP response and includes it in the TLS handshake.

## Real-World PKI at Scale

At companies like SIX Group (Swiss financial infrastructure), certificate management involves thousands of certificates across internal services, external-facing APIs, interbank mTLS connections, and SWIFT messaging infrastructure. This is managed through:

- **Internal CAs** — private CA hierarchy for internal services, with root keys in HSMs
- **CLM platforms** — automated discovery, issuance, renewal, and revocation (Venafi, Keyfactor, etc.)
- **Short-lived certificates** — workload certificates valid for hours, automatically rotated
- **Key ceremonies** — formal, audited procedures for root CA operations, with M-of-N quorum controls
- **Certificate Transparency** — monitoring CT logs to detect unauthorized issuance

The principles are the same as in this lab — the difference is automation, scale, and the consequences of getting it wrong.
