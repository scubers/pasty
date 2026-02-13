## 1. Build & Dependency Setup

- [ ] 1.1 Add `libsodium` dependency to `core/CMakeLists.txt`
- [ ] 1.2 Update `platform/macos/project.yml` to include `libsodium` library and headers in the Xcode project
- [ ] 1.3 Verify `libsodium` linkage by running a dummy test in Core
- [ ] 1.4 Update build scripts (`scripts/core-build.sh`) to ensure libsodium is available in the environment

## 2. Core Cryptography Wrapper

- [ ] 2.1 Implement `core/src/infrastructure/crypto/encryption_manager.h/cpp` using `libsodium`
- [ ] 2.2 Implement Argon2id key derivation in `EncryptionManager`
- [ ] 2.3 Implement XChaCha20-Poly1305 AEAD encryption/decryption for `std::string` and `std::vector<uint8_t>`
- [ ] 2.4 Add unit tests for `EncryptionManager` covering KDF and AEAD

## 3. Protocol & Metadata Management

- [ ] 3.1 Define `meta/protocol-info.json` structure and implement reader/writer in Core
- [ ] 3.2 Update `CloudDriveSyncState` to manage local encryption status (is_e2ee_enabled)
- [ ] 3.3 Implement salt generation and persistence during initial E2EE setup

## 4. Sync Engine Updates (Core)

- [ ] 4.1 Modify `CloudDriveSyncExporter` to encrypt event payloads when `encryption` is enabled
- [ ] 4.2 Modify `CloudDriveSyncExporter` to encrypt image assets before saving to `assets/`
- [ ] 4.3 Modify `CloudDriveSyncImporter` to decrypt events with `encryption: "e2ee"` during import
- [ ] 4.4 Modify `CloudDriveSyncImporter` to decrypt image assets after downloading from `assets/`
- [ ] 4.5 Ensure backward compatibility: plaintext events must still be readable if `encryption` is `"none"`

## 5. Core API & Runtime Integration

- [ ] 5.1 Add E2EE configuration methods to `pasty::runtime_json_api`
- [ ] 5.2 Update `CoreRuntime` to handle passphrase input and initialize `EncryptionManager`
- [ ] 5.3 Implement secure wiping of passphrase/keys from memory in Core

## 6. macOS Platform Integration

- [ ] 6.1 Implement `KeychainService` adapter in `platform/macos` for secure passphrase storage
- [ ] 6.2 Update `SettingsView` with a new "Encryption" section and toggle
- [ ] 6.3 Implement `PassphraseEntryDialog` and `PassphraseSetupDialog` in SwiftUI
- [ ] 6.4 Wire UI events to the Core `runtime_json_api`

## 7. Verification & Testing

- [ ] 7.1 Extend `core/tests/cloud_drive_sync_test.cpp` with E2EE test cases
- [ ] 7.2 Perform end-to-end sync test between two local instances with E2EE enabled
- [ ] 7.3 Verify that un-keyed clients gracefully ignore encrypted events
