## Why

The current Cloud Drive Sync protocol stores clipboard data in plaintext on third-party cloud storage (e.g., iCloud, Dropbox). This presents a privacy risk as sensitive clipboard content is accessible to cloud providers or anyone with access to the sync directory. Implementing End-to-End Encryption (E2EE) ensures that only authorized user devices holding the correct key can access the content, providing true privacy and security for synced data.

## What Changes

- **Cryptography Integration**: Add `libsodium` as a core dependency for robust, cross-platform cryptographic primitives.
- **Protocol Enhancement**: Implement the reserved encryption fields (`encryption`, `key_id`, `nonce`, `ciphertext`) in the Cloud Drive Sync protocol.
- **AEAD for Events & Assets**: Use XChaCha20-Poly1305 (AEAD) to encrypt both JSONL event payloads and binary assets (images).
- **Key Derivation (KDF)**: Implement Argon2id to derive the master sync key from a user-provided passphrase.
- **Metadata Management**: Store encryption parameters (salt, KDF limits, versioning) in the sync root's `meta/` directory.
- **Key Storage**: Securely store the sync passphrase/key in the system keychain (macOS Keychain).
- **Graceful Compatibility**: Maintain backward compatibility where encrypted events are ignored or displayed as "Encrypted" by older or unconfigured clients, rather than causing sync failures.

## Capabilities

### New Capabilities
- `cloud-sync-e2ee`: Core encryption/decryption logic, key derivation, and integration with the sync exporter/importer.
- `macos-e2ee-ui`: macOS-specific UI for managing encryption settings, passphrase entry, and Keychain integration.

### Modified Capabilities
- `cloud-drive-sync`: The base sync protocol and implementation will be updated to handle the transition from `"none"` to `"e2ee"` encryption modes.

## Impact

- **Core Layer**: 
    - `CloudDriveSyncExporter` & `CloudDriveSyncImporter`: Updated to handle encryption/decryption during I/O.
    - `CloudDriveSyncState`: Store local encryption status.
    - `runtime_json_api`: New endpoints for configuring sync encryption.
- **Platform Layer (macOS)**: 
    - Settings UI: New section for E2EE configuration.
    - Keychain Service: Adapter for storing/retrieving the master key.
- **Build System**: 
    - `core/CMakeLists.txt`: Add `libsodium` dependency.
    - `platform/macos/project.yml`: Add `libsodium` library and headers.
- **Security**: Significantly improved threat model against cloud provider compromise.
