import Foundation

/// Service for detecting sensitive content in clipboard entries
/// Uses regex-based pattern matching for common sensitive data types
struct SensitiveContentDetector {

    // MARK: - Sensitive Pattern Types

    /// Detected sensitive content type
    enum SensitiveType: String {
        case password = "password"
        case apiKey = "api_key"
        case token = "token"
        case creditCard = "credit_card"
        case awsKey = "aws_key"
        case privateKey = "private_key"
    }

    // MARK: - Patterns

    /// Pre-compiled regex patterns for sensitive content detection
    private static let patterns: [(SensitiveType, NSRegularExpression)] = {
        // Compile patterns lazily on first access
        var compiled: [(SensitiveType, NSRegularExpression)] = []

        // Password patterns
        if let passwordRegex = try? NSRegularExpression(
            pattern: #"(?i)password\s*[:=]\s*\S+"#,
            options: .caseInsensitive
        ) {
            compiled.append((.password, passwordRegex))
        }

        // API key patterns
        if let apiKeyRegex = try? NSRegularExpression(
            pattern: #"(?i)(api[_-]?key|apikey)\s*[:=]\s*[A-Za-z0-9_\-]{20,}"#,
            options: .caseInsensitive
        ) {
            compiled.append((.apiKey, apiKeyRegex))
        }

        // Token patterns
        if let tokenRegex = try? NSRegularExpression(
            pattern: #"(?i)(bearer\s+)?token\s*[:=]\s+[A-Za-z0-9_\-\.]{20,}"#,
            options: .caseInsensitive
        ) {
            compiled.append((.token, tokenRegex))
        }

        // Credit card patterns (simplified)
        if let creditCardRegex = try? NSRegularExpression(
            pattern: #"\b(?:\d[ -]*?){13,16}\b"#,
            options: []
        ) {
            compiled.append((.creditCard, creditCardRegex))
        }

        // AWS key patterns
        if let awsKeyRegex = try? NSRegularExpression(
            pattern: #"AKIA[0-9A-Z]{16}"#,
            options: []
        ) {
            compiled.append((.awsKey, awsKeyRegex))
        }

        // Private key patterns
        if let privateKeyRegex = try? NSRegularExpression(
            pattern: #"-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----"#,
            options: .caseInsensitive
        ) {
            compiled.append((.privateKey, privateKeyRegex))
        }

        return compiled
    }()

    // MARK: - Detection Methods

    /// Detect if text content contains sensitive information
    /// - Parameter text: The text content to analyze
    /// - Returns: The detected sensitive type, or nil if no sensitive content found
    static func detectSensitiveContent(in text: String) -> SensitiveType? {
        guard !text.isEmpty else { return nil }

        // Check each pattern
        for (type, regex) in patterns {
            let range = NSRange(location: 0, length: text.utf16.count)

            if regex.firstMatch(in: text, options: [], range: range) != nil {
                Logger.debug("Detected sensitive content of type: \(type.rawValue)")
                return type
            }
        }

        // No sensitive content detected
        return nil
    }

    /// Check if a clipboard entry contains sensitive content
    /// - Parameter entry: The clipboard entry to check
    /// - Returns: True if entry contains sensitive content, false otherwise
    static func isSensitive(_ entry: ClipboardEntry) -> Bool {
        // Only text content can be analyzed
        guard case .text(let text) = entry.content else {
            return false
        }

        return detectSensitiveContent(in: text) != nil
    }

    /// Get the sensitive type name for a clipboard entry
    /// - Parameter entry: The clipboard entry to check
    /// - Returns: The sensitive type name, or nil if not sensitive
    static func getSensitiveType(for entry: ClipboardEntry) -> String? {
        guard case .text(let text) = entry.content else {
            return nil
        }

        return detectSensitiveContent(in: text)?.rawValue
    }
}

// MARK: - ClipboardEntry Extension for Sensitivity Check

extension ClipboardEntry {
    /// Check if this entry contains sensitive content
    var isSensitiveContent: Bool {
        return SensitiveContentDetector.isSensitive(self)
    }

    /// Get the sensitive type for this entry (if any)
    var sensitiveContentType: String? {
        return SensitiveContentDetector.getSensitiveType(for: self)
    }
}
