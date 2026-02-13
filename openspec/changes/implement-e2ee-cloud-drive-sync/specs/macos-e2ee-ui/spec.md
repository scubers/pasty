## ADDED Requirements

### Requirement: Encryption Settings UI
The system SHALL provide a UI in the macOS Settings panel to enable/disable E2EE and manage the sync passphrase.

#### Scenario: Enabling E2EE
- **WHEN** user toggles "Enable End-to-End Encryption" in Settings
- **THEN** system SHALL prompt the user to enter a new sync passphrase
- **AND** system SHALL initialize the sync metadata with a new salt and the chosen KDF parameters

### Requirement: Passphrase Entry Dialog
The system SHALL display a secure passphrase entry dialog when the sync passphrase is required but not found in the Keychain.

#### Scenario: Prompting for missing passphrase
- **WHEN** app starts and E2EE is enabled in the sync directory but the key is missing from the local Keychain
- **THEN** system SHALL display a dialog requesting the sync passphrase from the user
- **AND** system SHALL provide an option to "Remember in Keychain"

### Requirement: Keychain Integration
The system SHALL securely store the sync passphrase in the macOS Keychain.

#### Scenario: Storing passphrase in Keychain
- **WHEN** user enters a passphrase and selects "Remember in Keychain"
- **THEN** system SHALL store the passphrase under the service name `com.github.pasty.sync-encryption`
- **AND** the passphrase SHALL be retrieved automatically on subsequent app launches
