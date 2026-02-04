# EncryptionService Contract

**Type**: Internal Service Contract
**Version**: 1.0.0
**Language**: Swift 5.9+

## Overview

`EncryptionService` manages encryption and decryption of sensitive clipboard entries. Uses AES-256 encryption with keys stored in macOS Keychain.

## Public Interface

```swift
@MainActor
protocol EncryptionServiceProtocol {
    /// Encrypt clipboard entry content
    /// - Parameter content: Plaintext content to encrypt
    /// - Returns: Tuple of (encryptedData: Data, keyId: String)
    /// - Throws: EncryptionError
    func encrypt(_ content: Data) async throws -> (encryptedData: Data, keyId: String)

    /// Decrypt clipboard entry content
    /// - Parameters:
    ///   - encryptedData: Encrypted content
    ///   - keyId: Key identifier for Keychain lookup
    /// - Returns: Decrypted plaintext content
    /// - Throws: EncryptionError.keyNotFound, EncryptionError.decryptionFailed
    func decrypt(_ encryptedData: Data, keyId: String) async throws -> Data

    /// Check if an entry is encrypted
    /// - Parameter entry: Clipboard entry to check
    /// - Returns: True if entry.isEncrypted == true
    func isEncrypted(_ entry: ClipboardEntry) -> Bool

    /// Generate new encryption key
    /// - Returns: Tuple of (keyData: Data, keyId: String)
    /// - Throws: EncryptionError.keyGenerationFailed
    func generateKey() async throws -> (keyData: Data, keyId: String)

    /// Delete encryption key from Keychain
    /// - Parameter keyId: Key identifier to delete
    /// - Throws: EncryptionError.keyDeleteFailed
    func deleteKey(keyId: String) async throws
}
```

## Data Types

```swift
enum EncryptionError: LocalizedError {
    case keyGenerationFailed
    case keyNotFound(keyId: String)
    case encryptionFailed(underlying: Error)
    case decryptionFailed
    case keyStorageFailed(underlying: Error)
    case keyDeleteFailed(underlying: Error)
    case invalidKeyLength

    var errorDescription: String? {
        switch self {
        case .keyGenerationFailed: return "Failed to generate encryption key"
        case .keyNotFound(let id): return "Encryption key not found: \(id)"
        case .encryptionFailed(let err): return "Encryption failed: \(err.localizedDescription)"
        case .decryptionFailed: return "Decryption failed: incorrect key or corrupted data"
        case .keyStorageFailed(let err): return "Failed to store key in Keychain: \(err.localizedDescription)"
        case .keyDeleteFailed(let err): return "Failed to delete key from Keychain: \(err.localizedDescription)"
        case .invalidKeyLength: return "Invalid encryption key length"
        }
    }
}
```

## Implementation Requirements

### Encryption Algorithm
- **Algorithm**: AES-256-GCM (Galois/Counter Mode)
- **Key Length**: 256 bits (32 bytes)
- **Nonce**: 96 bits (12 bytes), randomly generated per encryption
- **Authentication Tag**: 128 bits (built into GCM)

```swift
import CryptoKit

struct AES256GCMEncryptor {
    static func encrypt(data: Data, key: SymmetricKey) throws -> (encrypted: Data, nonce: Data) {
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
        return (sealedBox.ciphertext + sealedBox.tag, Data(nonce))
    }

    static func decrypt(encryptedData: Data, nonce: Data, key: SymmetricKey) throws -> Data {
        let ciphertext = encryptedData[0..<(encryptedData.count - 16)]  // Strip tag
        let tag = encryptedData[(encryptedData.count - 16)...]
        let sealedBox = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: nonce),
                                              ciphertext: Data(ciphertext),
                                              tag: Data(tag))
        return try AES.GCM.open(sealedBox, using: key)
    }
}
```

### Key Storage (macOS Keychain)

```swift
import Security

struct KeychainManager {
    private let service = "com.pasty.clipboard.encryption"

    func storeKey(_ keyData: Data, keyId: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyId,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,  // Requires device unlock
            kSecAttrSynchronizable as String: false  // No iCloud sync (security)
        ]

        // Delete existing key if present
        SecItemDelete(query as CFDictionary)

        // Add new key
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionError.keyStorageFailed(underlying: NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
    }

    func loadKey(keyId: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyId,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let keyData = result as? Data else {
            throw EncryptionError.keyNotFound(keyId: keyId)
        }

        return keyData
    }

    func deleteKey(keyId: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: keyId
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw EncryptionError.keyDeleteFailed(underlying: NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
        }
    }
}
```

### Key Generation

```swift
func generateKey() async throws -> (keyData: Data, keyId: String) {
    // Generate 256-bit key
    var keyBytes = [UInt8](repeating: 0, count: 32)
    let status = SecRandomCopyBytes(kSecRandomDefault, 32, &keyBytes)

    guard status == errSecSuccess else {
        throw EncryptionError.keyGenerationFailed
    }

    let keyData = Data(keyBytes)
    let keyId = UUID().uuidString

    // Store in Keychain
    try KeychainManager().storeKey(keyData, keyId: keyId)

    return (keyData, keyId)
}
```

### Encryption Flow

```swift
func encrypt(_ content: Data) async throws -> (encryptedData: Data, keyId: String) {
    // 1. Generate new key
    let (keyData, keyId) = try await generateKey()

    // 2. Create SymmetricKey
    let key = SymmetricKey(data: keyData)

    // 3. Encrypt with AES-256-GCM
    let (encrypted, nonce) = try AES256GCMEncryptor.encrypt(data: content, key: key)

    // 4. Pack: nonce + encryptedData
    var packed = nonce
    packed.append(encrypted)

    return (packed, keyId)
}

func decrypt(_ encryptedData: Data, keyId: String) async throws -> Data {
    // 1. Load key from Keychain
    let keyData = try KeychainManager().loadKey(keyId: keyId)
    let key = SymmetricKey(data: keyData)

    // 2. Extract nonce (first 12 bytes)
    let nonce = encryptedData[0..<12]
    let ciphertext = encryptedData[12...]
    var combined = Data(nonce)
    combined.append(ciphertext)

    // 3. Decrypt
    return try AES256GCMEncryptor.decrypt(encryptedData: combined, nonce: Data(nonce), key: key)
}
```

## Security Requirements

### Key Storage
- Keys stored in macOS Keychain with `kSecAttrAccessibleWhenUnlocked`
- No iCloud sync (`kSecAttrSynchronizable = false`)
- Keys never logged or exposed in error messages
- Each entry uses unique encryption key (per-entry key isolation)

### Data Handling
- Nonce randomly generated per encryption (never reused)
- GCM provides authenticated encryption (detects tampering)
- Clear plaintext from memory after encryption (set to nil)
- Maximum encrypted content size: 10MB (to prevent DoS)

### Access Control
- Keychain item requires user to be logged in (unlock required)
- Optional: Require biometric auth (Touch ID) for key access (future enhancement)
- Keys deleted when clipboard entry deleted

## Testing Contract

### Unit Tests
```swift
final class EncryptionServiceTests: XCTestCase {
    func testEncryptDecrypt_RoundTrip_Success()
    func testEncrypt_GeneratesNewKeyId()
    func testDecrypt_InvalidKey_ThrowsError()
    func testDecrypt_WrongKey_ThrowsError()
    func testGenerateKey_CreatesValidKey()
    func testDeleteKey_RemovesFromKeychain()
    func testEncrypt_LargeContent_ThrowsError()
}
```

### Security Tests
```swift
func testEncryptedData_DifferentFromPlaintext() {
    let plaintext = Data("secret".utf8)
    let (encrypted, _) = try! encrypt(plaintext)
    XCTAssertNotEqual(plaintext, encrypted)
}

func testDecrypt_TamperedData_ThrowsError() {
    let plaintext = Data("secret".utf8)
    let (encrypted, keyId) = try! encrypt(plaintext)
    var tampered = encrypted
    tampered[0] ^= 0xFF  // Flip bit
    XCTAssertThrowsError(try decrypt(tampered, keyId: keyId))
}
```

### Performance Tests
```swift
func testEncryptPerformance_1MB() {
    let data = Data(repeating: 0xFF, count: 1_000_000)
    measure {
        _ = try? encrypt(data)
    }
    // Must complete within 500ms
}
```

## Dependencies

- **CryptoKit**: Apple's native crypto framework (iOS 13+, macOS 10.15+)
- **Security framework**: For Keychain access and random number generation
- **Foundation**: For Data and UUID types

## Integration Points

- **ClipboardService**: Calls `encrypt()` before saving sensitive entries to database
- **ClipboardService**: Calls `decrypt()` when loading encrypted entries for preview/copy
- **Database**: Stores `keyId` in `clipboard_entries` table (new column `encryption_key_id`)

## Error Handling

All errors are user-facing in UI:
- `.keyNotFound`: Show error "Encryption key missing. Entry cannot be decrypted."
- `.decryptionFailed`: Show error "Failed to decrypt entry. Data may be corrupted."
- `.encryptionFailed`: Show error "Failed to encrypt entry. Entry not saved."

## Open Questions

None - contract fully specified.
