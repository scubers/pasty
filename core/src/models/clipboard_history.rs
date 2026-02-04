//! Clipboard history management
//!
//! Manages the collection of clipboard entries with retention policies.

use crate::models::ClipboardEntry;
use serde::{Deserialize, Serialize};

/// Manages clipboard history with retention policies
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClipboardHistory {
    /// Ordered list of clipboard entries (newest first)
    pub entries: Vec<ClipboardEntry>,

    /// Maximum number of entries to retain
    pub max_entries: usize,

    /// Retention duration in seconds (0 = unlimited)
    pub retention_seconds: i64,
}

impl ClipboardHistory {
    /// Create a new clipboard history
    ///
    /// # Arguments
    /// * `max_entries` - Maximum number of entries to retain (must be > 0)
    /// * `retention_seconds` - Retention duration in seconds (0 = unlimited)
    ///
    /// # Returns
    /// A new ClipboardHistory instance
    ///
    /// # Panics
    /// Panics if max_entries is 0
    pub fn new(max_entries: usize, retention_seconds: i64) -> Self {
        assert!(max_entries > 0, "max_entries must be greater than 0");
        assert!(retention_seconds >= 0, "retention_seconds must be non-negative");

        ClipboardHistory {
            entries: Vec::new(),
            max_entries,
            retention_seconds,
        }
    }

    /// Add a new entry to history
    ///
    /// Enforces max_entries limit by removing oldest entries if needed
    /// Removes expired entries before adding new entry
    ///
    /// # Arguments
    /// * `entry` - The entry to add
    pub fn add_entry(&mut self, entry: ClipboardEntry) {
        self.remove_expired();

        self.entries.insert(0, entry);

        // Enforce max_entries limit
        while self.entries.len() > self.max_entries {
            self.entries.pop();
        }
    }

    /// Remove an entry by ID
    ///
    /// # Arguments
    /// * `id` - The ID of the entry to remove
    ///
    /// # Returns
    /// - `Ok(())` if entry was removed
    /// - `Err(String)` if entry not found
    pub fn remove_entry(&mut self, id: &str) -> Result<(), String> {
        let original_len = self.entries.len();
        self.entries.retain(|entry| entry.id != id);

        if self.entries.len() == original_len {
            Err(format!("Entry with id '{}' not found", id))
        } else {
            Ok(())
        }
    }

    /// Get entry by ID
    ///
    /// # Arguments
    /// * `id` - The ID of the entry to get
    ///
    /// # Returns
    /// Reference to the entry if found, None otherwise
    pub fn get_entry(&self, id: &str) -> Option<&ClipboardEntry> {
        self.entries.iter().find(|entry| entry.id == id)
    }

    /// Get all entries (newest first)
    ///
    /// # Returns
    /// Vector of references to all entries in chronological order (newest first)
    pub fn get_all_entries(&self) -> Vec<&ClipboardEntry> {
        self.entries.iter().collect()
    }

    /// Clear all entries
    pub fn clear(&mut self) {
        self.entries.clear();
    }

    /// Remove expired entries based on retention policy
    pub fn remove_expired(&mut self) {
        if self.retention_seconds == 0 {
            return; // Unlimited retention
        }

        use std::time::{SystemTime, UNIX_EPOCH};
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;

        let cutoff = now - self.retention_seconds;

        self.entries.retain(|entry| entry.timestamp > cutoff);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{ContentType, ClipboardData};

    #[test]
    fn test_clipboard_history_creation() {
        let history = ClipboardHistory::new(100, 3600);

        assert_eq!(history.entries.len(), 0);
        assert_eq!(history.max_entries, 100);
        assert_eq!(history.retention_seconds, 3600);
    }

    #[test]
    fn test_add_entry() {
        let mut history = ClipboardHistory::new(10, 0);

        let entry = ClipboardEntry::new(
            ContentType::Text,
            ClipboardData::Text("Test".to_string()),
        );

        history.add_entry(entry);

        assert_eq!(history.entries.len(), 1);
    }

    #[test]
    fn test_max_entries_limit() {
        let mut history = ClipboardHistory::new(3, 0);

        for i in 0..5 {
            let entry = ClipboardEntry::new(
                ContentType::Text,
                ClipboardData::Text(format!("Entry {}", i)),
            );
            history.add_entry(entry);
        }

        assert_eq!(history.entries.len(), 3);
    }
}
