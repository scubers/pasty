## Context

Pasty's Cloud Drive Sync allows users to synchronize clipboard history across devices using a shared directory on a cloud provider (e.g., iCloud Drive, Dropbox). Currently, this data is stored in plaintext JSONL files (`logs/`) and raw binary files (`assets/`). 

To protect user privacy, we are implementing End-to-End Encryption (E2EE) using `libsodium`.

## Goals / Non-Goals

**Goals:**
- **Zero-Knowledge**: The cloud provider must not be able to read clipboard content.
- **Strong Cryptography**: Use industry-standard AEAD and KDF primitives.
- **Passphrase-based**: Users should be able to set a sync passphrase that generates the encryption keys.
- **Portable**: The core encryption logic must be in the C++ Core and work across all platforms.
- **Key Storage**: Securely store keys on the local device (macOS Keychain).

**Non-Goals:**
- **Multi-user Support**: This design assumes a single user owning all devices in the sync pool.
- **Complex Key Rotation**: Automatic rotation is out of scope for v1.
- **Cloud Metadata Encryption**: Filenames in `logs/` and `assets/` (which are hashes) remain public.

## Decisions

### 1. Cryptographic Library: libsodium
- **Rationale**: `libsodium` is highly portable, easy to use correctly, and provides modern primitives like XChaCha20-Poly1305 and Argon2id. It is a proven choice for E2EE.

### 2. Encryption Primitive: XChaCha20-Poly1305 (AEAD)
- **Rationale**: Provides both confidentiality and authenticity. The "X" variant uses a 192-bit nonce, which is safe to generate randomly without risk of collision across millions of events.
- **Implementation**:
    - **Events**: The entire JSON object (excluding metadata like `event_id`, `encryption`, `key_id`, `nonce`) is encrypted and stored in the `ciphertext` field.
    - **Assets**: The raw file bytes are encrypted before being written to the `assets/` directory.

### 3. Key Derivation: Argon2id
- **Rationale**: Argon2id is the state-of-the-art for password hashing and key derivation. It is memory-hard, preventing efficient brute-force attacks via GPUs/ASICs.
- **Parameters**: 
    - `opslimit`: `crypto_pwhash_OPSLIMIT_INTERACTIVE`
    - `memlimit`: `crypto_pwhash_MEMLIMIT_INTERACTIVE`
- **Storage**: The 16-byte random salt and KDF parameters will be stored in `meta/protocol-info.json`.

### 4. Protocol Integration
- **Fields**:
    - `encryption`: Set to `"e2ee"`.
    - `key_id`: A hash of the public key or a random ID to identify which key was used (useful for future rotation).
    - `nonce`: Base64 encoded 24-byte nonce.
    - `ciphertext`: Base64 encoded encrypted payload.

### 5. Threat Model
- **Attacker**: Cloud provider or an attacker who gains access to the sync directory.
- **Guarantees**: Attacker cannot read `text` content or `image` bytes. Attacker cannot modify events without detection (AEAD tag validation will fail).
- **Leakage**: Attacker can see event frequency, timestamps, and approximate content sizes.

## Risks / Trade-offs

- **[Risk] Passphrase Loss** → **[Mitigation]** Data is unrecoverable. UI must warn users during setup and encourage secure storage of the passphrase.
- **[Risk] Performance Impact of Argon2** → **[Mitigation]** Use "interactive" limits. Key derivation only happens on app start or settings change, not on every sync.
- **[Risk] Sync Conflicts in meta/protocol-info.json** → **[Mitigation]** Use a first-writer-wins approach with atomic renames. If a conflict occurs, the user may need to re-enter the passphrase if the salt changes.
