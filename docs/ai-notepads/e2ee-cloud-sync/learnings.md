## E2EE Cloud Sync Learnings

- Core C API `pasty_cloud_sync_e2ee_initialize` is required to enable decryption during sync.
- `CloudSyncSettingsView` uses `SettingsRow` and `PastyToggle` for consistent UI.
- Keychain access via `KeychainService` works well for secure storage.
- Using `refreshCloudSyncStatus` as the initialization point ensures correct state management during sync operations.
- UI should track local unlock state (passphrase presence) separately from Core protocol existence (e2eeEnabled) to correctly reflect "Locked/Not Encrypted" state when a passphrase is removed locally.
- E2EE init must occur outside Settings UI to keep exports encrypted after restart.
