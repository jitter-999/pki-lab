# OpenSSL Config File Reference

Line-by-line explanation of `configs/root.cnf` and `configs/intermediate.cnf`.

## File Format

OpenSSL configs use INI-style syntax: `[ section_name ]` headers followed by `key = value` pairs. Different OpenSSL subcommands read different sections:

| Command | Entry section | Purpose |
|---------|--------------|---------|
| `openssl ca` | `[ ca ]` → `[ CA_default ]` | Sign CSRs, manage cert database |
| `openssl req` | `[ req ]` | Generate keys, CSRs, or self-signed certs |

Variables (`$dir`) are supported — define once, reference anywhere in the same file.

## `[ ca ]` and `[ CA_default ]`

```ini
[ ca ]
default_ca = CA_default
```

The `[ ca ]` section is just an indirection — it names the section with the actual CA config. This lets you define multiple CA profiles in one file.

```ini
[ CA_default ]
dir               = ./root
```

| Key | What it does |
|-----|-------------|
| `dir` | Base path variable. Referenced as `$dir` in subsequent lines. |
| `new_certs_dir` | Directory where OpenSSL drops a copy of every signed cert, named by serial number (`1000.pem`, `1001.pem`). Your audit trail. |
| `database` | Path to `index.txt`, the flat-file cert database. |
| `serial` | Path to the file containing the next serial number in hex. |
| `private_key` | The CA's own private key (used to sign CSRs). |
| `certificate` | The CA's own certificate (included in the issued cert's chain metadata). |
| `default_md` | Hash algorithm for signatures. `sha256` → the certificate's signature algorithm will be `sha256WithRSAEncryption`. Never use `sha1` — broken for forgery since 2017. |
| `default_days` | Validity period if `-days` isn't specified on the command line. |
| `policy` | Names the section that defines subject-field requirements for CSRs. |
| `default_crl_days` | How long a generated CRL is valid before it needs to be regenerated. |

## Policy Sections

```ini
[ policy_strict ]
countryName             = match
organizationName        = match
commonName              = supplied
```

Controls which subject fields a CSR must have, and whether they must match the CA's own values:

| Value | Meaning |
|-------|---------|
| `match` | Field must exist AND be identical to the CA certificate's value |
| `supplied` | Field must exist but can be any value |
| `optional` | Field may be omitted entirely |

The root uses `policy_strict` (country and org must match) to prevent accidentally signing certs for a different organization. The intermediate uses `policy_loose` (everything optional except CN) because leaf certs may have varied subjects.

## `[ req ]` Section

```ini
[ req ]
default_bits       = 4096
default_md         = sha256
distinguished_name = req_distinguished_name
x509_extensions    = v3_ca
prompt             = no
```

| Key | What it does |
|-----|-------------|
| `default_bits` | RSA key size when generating with `openssl req -newkey rsa`. |
| `default_md` | Hash for the CSR's self-signature (proof of possession). |
| `distinguished_name` | Section containing subject field values (or prompts). |
| `x509_extensions` | Extensions section to use when `-x509` flag is present. Only relevant for self-signed certs. |
| `prompt = no` | Don't interactively ask for subject fields — take values from the config. Without this, OpenSSL prompts for each field one by one. |

## `[ req_distinguished_name ]`

```ini
C  = CH
O  = PKI Lab
CN = PKI Lab Root CA
```

The subject (identity) of the certificate. Fields map to X.500 distinguished name attributes:

| Field | X.500 OID | Meaning |
|-------|-----------|---------|
| `C` | 2.5.4.6 | Country (ISO 3166-1 alpha-2, e.g., `CH`, `US`, `DE`) |
| `ST` | 2.5.4.8 | State or province |
| `L` | 2.5.4.7 | Locality (city) |
| `O` | 2.5.4.10 | Organization |
| `OU` | 2.5.4.11 | Organizational unit |
| `CN` | 2.5.4.3 | Common Name |

For CAs, the CN is a human-readable identifier. For legacy server certs, the CN was checked against the hostname, but modern TLS uses SANs instead.

## Extension Sections

Extensions are where the real security semantics live.

### `[ v3_ca ]` — Root CA Extensions

```ini
basicConstraints       = critical, CA:TRUE
keyUsage               = critical, keyCertSign, cRLSign
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always, issuer
```

| Extension | Value | Meaning |
|-----------|-------|---------|
| `basicConstraints` | `critical, CA:TRUE` | This IS a CA certificate — can sign other certs. `critical` means software MUST enforce this; if it doesn't understand the extension, it must reject the cert. |
| `keyUsage` | `critical, keyCertSign, cRLSign` | Key can ONLY sign certificates and CRLs. Cannot do TLS, encryption, email signing, etc. Principle of least privilege. |
| `subjectKeyIdentifier` | `hash` | SHA-1 hash of this cert's public key. Used by child certs' `authorityKeyIdentifier` to link to their issuer, enabling chain building. |
| `authorityKeyIdentifier` | `keyid:always, issuer` | For a self-signed root, this points to itself. For issued certs, it links to the signing CA's `subjectKeyIdentifier`. |

### `[ v3_intermediate_ca ]` — Intermediate CA Extensions

```ini
basicConstraints       = critical, CA:TRUE, pathlen:0
```

Same as root, but with `pathlen:0`: this CA can sign leaf certificates, but those leaves cannot be CAs themselves (the chain cannot extend further). `pathlen:1` would allow one more CA level below; no `pathlen` means unlimited depth.

### `[ server_cert ]` — Leaf Certificate Extensions

```ini
basicConstraints       = critical, CA:FALSE
keyUsage               = critical, digitalSignature, keyEncipherment
extendedKeyUsage       = serverAuth
subjectAltName         = @alt_names
```

| Extension | Value | Meaning |
|-----------|-------|---------|
| `basicConstraints` | `CA:FALSE` | NOT a CA — cannot sign other certificates. If compromised, cannot be used to issue more certs. |
| `keyUsage` | `digitalSignature` | Can sign TLS handshake messages (used in ECDHE/DHE key exchange for CertificateVerify). |
| | `keyEncipherment` | Can encrypt the premaster secret (used in legacy RSA key exchange). |
| `extendedKeyUsage` | `serverAuth` | Restricted to TLS server authentication. Add `clientAuth` for mTLS, `codeSigning` for code signing, etc. |
| `subjectAltName` | `@alt_names` | Hostnames this cert is valid for. Points to a section listing DNS names. |

### `[ alt_names ]`

```ini
DNS.1 = test.pkilab.local
DNS.2 = *.pkilab.local
```

Subject Alternative Names. Modern TLS checks these (not CN) for hostname validation. Wildcards match one DNS label: `*.pkilab.local` matches `foo.pkilab.local` but NOT `sub.foo.pkilab.local`. You can also add IP addresses (`IP.1 = 192.168.1.10`) or email addresses (`email.1 = user@example.com`).
