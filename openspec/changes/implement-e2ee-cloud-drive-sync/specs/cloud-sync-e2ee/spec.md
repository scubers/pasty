## ADDED Requirements

### Requirement: Master Key Derivation from Passphrase
The system SHALL derive a master encryption key from a user-provided passphrase using Argon2id.

#### Scenario: Successful key derivation
- **WHEN** user provides a passphrase and the system retrieves the salt from `meta/protocol-info.json`
- **THEN** system SHALL generate a 32-byte master key using `crypto_pwhash`

### Requirement: Encrypted Event Export
The system SHALL encrypt the sensitive fields of a clipboard event before exporting to the cloud log.

#### Scenario: Exporting encrypted text item
- **WHEN** system exports a `upsert_text` event and encryption is enabled
- **THEN** system SHALL generate a random nonce, encrypt the `text` content using `crypto_aead_xchacha20poly1305_ietf`, and store it in the `ciphertext` field
- **AND** system SHALL set `encryption` to `"e2ee"` and include the `nonce` and `key_id`

### Requirement: Decrypted Event Import
The system SHALL decrypt encrypted event payloads using the master key during import.

#### Scenario: Importing encrypted event
- **WHEN** system reads an event with `encryption: "e2ee"`
- **THEN** system SHALL use the master key and the event's `nonce` to decrypt the `ciphertext`
- **AND** system SHALL validate the authentication tag before processing the content

### Requirement: Encrypted Asset Export
The system SHALL encrypt binary assets (images) before writing them to the `assets/` directory.

#### Scenario: Exporting encrypted image
- **WHEN** system exports an image asset and encryption is enabled
- **THEN** system SHALL encrypt the raw image bytes using a unique nonce and the master key
- **AND** the encrypted bytes SHALL be stored in the `assets/` directory under the content hash name
