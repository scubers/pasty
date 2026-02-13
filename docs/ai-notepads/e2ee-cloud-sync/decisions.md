## E2EE Cloud Sync Decisions

- **Passphrase Storage**: We store the passphrase in the macOS Keychain using the `KeychainService` keyed by the normalized root path of the sync directory. This ensures that changing the sync directory doesn't leak or use the wrong passphrase.
- **Initialization**: We attempt to initialize E2EE via `pasty_cloud_sync_e2ee_initialize` in `SettingsViewModel.refreshCloudSyncStatus` (on a background thread) before calling `pasty_cloud_sync_import_now`. This ensures that any encrypted data can be decrypted during import.
- **UI Interaction**: Added a dedicated `CloudSyncE2eePassphraseSheet` for passphrase entry, using `SecureField` for security. The main `CloudSyncSettingsView` shows the encryption status and key ID when enabled.
- **Thin Shell**: We avoided direct calls to Core from the View, routing everything through `SettingsViewModel`.
- **Explicit Key Clearing**: Added `pasty_cloud_sync_e2ee_clear` to the C API and wired it to the macOS "Remove Passphrase" action. This ensures that when a user removes their passphrase from the Keychain, the sensitive E2EE master key is also immediately wiped from the application's memory, preventing further decryption or import of E2EE events until a passphrase is re-entered.
