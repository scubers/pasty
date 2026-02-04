import Foundation

extension String {
    /// Truncate string to max length, adding ellipsis if needed
    func truncated(to maxLength: Int, trailing: String = "...") -> String {
        if self.count <= maxLength {
            return self
        }
        return String(self.prefix(maxLength)) + trailing
    }

    /// Check if string contains another string (case-insensitive)
    func containsIgnoreCase(_ string: String) -> Bool {
        self.localizedCaseInsensitiveContains(string)
    }
}
