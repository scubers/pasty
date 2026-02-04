# Clipboard History Manager - Usage Examples

**Feature**: 002-clipboard-history
**Last Updated**: 2026-02-04
**Target Audience**: Developers using the clipboard history manager

## Table of Contents

1. [Basic Usage](#basic-usage)
2. [Clipboard Monitoring](#clipboard-monitoring)
3. [Storing Content](#storing-content)
4. [Retrieving History](#retrieving-history)
5. [Error Handling](#error-handling)
6. [Advanced Usage](#advanced-usage)
7. [Best Practices](#best-practices)
8. [Complete Examples](#complete-examples)

---

## Basic Usage

### Initializing the Clipboard Store

The `ClipboardStore` is the main entry point for all clipboard operations.

```rust
use pasty_core::services::ClipboardStore;
use pasty_core::models::SourceApplication;
use std::path::Path;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize with database and storage paths
    let store = ClipboardStore::new(
        "./clipboard.db",
        "./images"
    )?;

    println!("Clipboard store initialized successfully");
    Ok(())
}
```

### Storing Text Content

```rust
use pasty_core::services::ClipboardStore;
use pasty_core::models::SourceApplication;

// Create source application info
let source = SourceApplication::new(
    "com.apple.Safari".to_string(),
    "Safari".to_string(),
    1234
);

// Store text content
let entry = store.store_text(
    "Hello, World!",
    source
)?;

println!("Stored entry with ID: {}", entry.id);
```

### Storing Image Content

```rust
use pasty_core::services::ClipboardStore;
use pasty_core::models::SourceApplication;

// Read image file
let image_data = std::fs::read("screenshot.png")?;

let source = SourceApplication::new(
    "com.apple.Preview".to_string(),
    "Preview".to_string(),
    5678
);

// Store image content
let entry = store.store_image(
    &image_data,
    "png",  // format
    source
)?;

println!("Stored image with ID: {}", entry.id);
println!("Image stored at: {}", entry.image_file_path().unwrap());
```

---

## Clipboard Monitoring

### Setting Up Automatic Monitoring (macOS/Swift)

Complete clipboard monitoring setup with automatic change detection:

```swift
import Cocoa
import Foundation

class ClipboardMonitor {
    private var monitor: Monitor?
    private let coordinator: ClipboardCoordinator

    init() {
        let detector = ContentTypeDetector()
        let ffiBridge = RustBridge()
        self.coordinator = ClipboardCoordinator(ffiBridge: ffiBridge)
        let monitor = Monitor(detector: detector, coordinator: coordinator)
        self.monitor = monitor
    }

    func start() {
        monitor?.startMonitoring()
        NSLog("[ClipboardMonitor] Monitoring started")
    }

    func stop() {
        monitor?.stopMonitoring()
        NSLog("[ClipboardMonitor] Monitoring stopped")
    }
}

// Usage
let app = ClipboardMonitor()
app.start()

// Run the main loop
NSRunLoop.main.run()
```

### Monitoring with Debouncing

The built-in debouncing prevents excessive processing:

```swift
// Monitor automatically debounces with 200ms delay
// Multiple rapid changes within 200ms are treated as a single event
```

---

## Storing Content

### Text with Source Application

```rust
use pasty_core::models::SourceApplication;

// Get current application (frontmost app)
let source = SourceApplication::current();

// Or create manually
let source = SourceApplication::new(
    "com.microsoft.Word".to_string(),
    "Microsoft Word".to_string(),
    9999
);

// Store with metadata
let entry = store.store_text(
    "Document content here...",
    source
)?;

println!("Stored text entry:");
println!("  ID: {}", entry.id);
println!("  Hash: {}", entry.content_hash);
println!("  Timestamp: {}", entry.timestamp);
```

### Image with Metadata

```rust
// Capture and store screenshot
let screenshot_data = capture_screenshot()?;

let source = SourceApplication::new(
    "com.apple.screencapture".to_string(),
    "Screen Capture".to_string(),
    1001
);

let entry = store.store_image(
    &screenshot_data,
    "png",
    source
)?;

println!("Stored image entry:");
println!("  Format: {:?}", entry.image_file_format());
println!("  Size: {} bytes", entry.image_file_size().unwrap());
```

---

## Retrieving History

### Get All Entries (with Pagination)

```rust
use pasty_core::services::ClipboardStore;

// Get first 20 entries (most recent first)
let page1 = store.get_history(20, 0)?;

println!("Found {} entries:", page1.len());
for entry in page1 {
    println!("  - {}: {}",
        entry.id,
        match entry.content {
            pasty_core::models::Content::Text(text) =>
                format!("Text: \"{}\"", text.chars().take(30).collect::<String>()),
            pasty_core::models::Content::Image(_) =>
                "[Image]",
        }
    );
}

// Get next page (skip first 20)
let page2 = store.get_history(20, 20)?;
```

### Filter by Content Type

```rust
use pasty_core::models::ContentType;

// Get only text entries
let text_entries = store.get_history_filtered(
    ContentType::Text,
    50,
    0
)?;

// Get only image entries
let image_entries = store.get_history_filtered(
    ContentType::Image,
    50,
    0
)?;

println!("Text entries: {}", text_entries.len());
println!("Image entries: {}", image_entries.len());
```

### Retrieve Specific Entry

```rust
use uuid::Uuid;

let entry_id = Uuid::parse_str("01234567-89ab-cdef-0123-456789abcdef")?;

if let Some(entry) = store.get_entry_by_id(entry_id)? {
    println!("Found entry:");
    println!("  Content Type: {:?}", entry.content_type);
    println!("  Timestamp: {}", entry.timestamp);
    println!("  Source: {}", entry.source.app_name);
} else {
    println!("Entry not found");
}
```

---

## Error Handling

### Basic Error Handling

```rust
use pasty_core::services::database::DatabaseError;

fn store_text_safely(text: &str, source: SourceApplication) {
    match store.store_text(text, source) {
        Ok(entry) => {
            println!("Successfully stored entry: {}", entry.id);
        }
        Err(DatabaseError::Sqlite(e)) => {
            eprintln!("Database error: {}", e);
            // Handle SQLite-specific errors
        }
        Err(DatabaseError::Io(e)) => {
            eprintln!("IO error: {}", e);
            // Handle file system errors
        }
        Err(e) => {
            eprintln!("Other error: {}", e);
        }
    }
}
```

### Retry with Exponential Backoff

```rust
use std::time::Duration;
use std::thread;

fn store_with_retry(store: &ClipboardStore, text: &str, source: SourceApplication) {
    let mut attempts = 0;
    let max_attempts = 5;
    let mut delay = Duration::from_millis(50);

    loop {
        match store.store_text(text, source.clone()) {
            Ok(entry) => {
                println!("Stored after {} attempts", attempts + 1);
                return Ok(entry);
            }
            Err(e) if e.is_retryable() && attempts < max_attempts - 1 => {
                println!("Retry {} in {:?}", attempts + 1, delay);
                thread::sleep(delay);
                attempts += 1;
                delay *= 2; // Exponential backoff
            }
            Err(e) => {
                eprintln!("Failed after {} attempts: {}", attempts + 1, e);
                return Err(e);
            }
        }
    }
}
```

### Structured Error Handling

```rust
use pasty_core::services::database::DatabaseError;

fn handle_database_error(err: DatabaseError) {
    match err {
        DatabaseError::SqliteWithOperation { operation, source } => {
            eprintln!("Operation '{}' failed: {}", operation, source);
        }
        DatabaseError::Connection { path, reason } => {
            eprintln!("Cannot connect to database at '{}': {}", path, reason);
        }
        DatabaseError::Migration { version, reason } => {
            eprintln!("Migration to version {} failed: {}", version, reason);
        }
        DatabaseError::DatabaseLocked { attempts } => {
            eprintln!("Database locked after {} attempts", attempts);
        }
        DatabaseError::EntryNotFound { id } => {
            eprintln!("Entry not found: {}", id);
        }
        DatabaseError::Io(e) => {
            eprintln!("File system error: {}", e);
        }
    }
}
```

---

## Advanced Usage

### Check for Duplicates Before Storing

```rust
use pasty_core::services::ClipboardStore;

// Check if content already exists
let hash = calculate_hash("duplicate text");

if store.entry_exists(&hash)? {
    println!("Entry already exists, skipping storage");
    // Optionally retrieve and return existing entry
    let existing = store.get_entry_by_hash(&hash)?.unwrap();
    return Ok(existing);
}

// Store new entry
let entry = store.store_text("new text", source)?;
```

### Batch Operations

```rust
use pasty_core::services::ClipboardStore;

// Store multiple entries efficiently
let texts = vec![
    "Entry 1",
    "Entry 2",
    "Entry 3",
];

for text in texts {
    let entry = store.store_text(text, source.clone())?;
    println!("Stored: {}", entry.id);
}
```

### Query with Complex Filters

```rust
// Get entries from specific time range
let all_entries = store.get_history(1000, 0)?;

use chrono::Utc;
use std::collections::HashMap;

let mut by_type: HashMap<String, Vec<_>> = HashMap::new();

for entry in all_entries {
    let type_str = format!("{:?}", entry.content_type);
    by_type.entry(type_str).or_default().push(entry);
}

println!("Entries by type:");
for (type_name, entries) in by_type {
    println!("  {}: {}", type_name, entries.len());
}
```

---

## Best Practices

### 1. Always Initialize Once

```rust
// ✅ GOOD: Initialize once, reuse
lazy_static! {
    static ref CLIPBOARD_STORE: ClipboardStore = {
        ClipboardStore::new(
            "./clipboard.db",
            "./images"
        ).expect("Failed to initialize")
    };
};

fn use_store() -> &'static ClipboardStore {
    &CLIPBOARD_STORE
}

// ❌ BAD: Initialize multiple times
fn bad_function() {
    let store1 = ClipboardStore::new(...)?;
    let store2 = ClipboardStore::new(...)?; // Wastes resources
}
```

### 2. Use Proper Error Handling

```rust
// ✅ GOOD: Propagate errors with context
fn store_with_context(text: &str) -> Result<ClipboardEntry, DatabaseError> {
    store.store_text(text, source)
        .map_err(|e| DatabaseError::connection_error(
            "./clipboard.db".into(),
            format!("Failed to store text '{}'", text)
        ))
}

// ❌ BAD: Swallow errors
let _ = store.store_text(text, source); // Error is lost
```

### 3. Leverage Deduplication

```rust
// ✅ GOOD: Let the store handle deduplication
let entry1 = store.store_text("Hello", source)?;
let entry2 = store.store_text("Hello", source)?;
assert_eq!(entry1.id, entry2.id); // Same entry

// ❌ BAD: Check manually (unnecessary code)
if !store.entry_exists(&hash)? {
    store.store_text("Hello", source)?;
}
```

### 4. Use Pagination for Large Datasets

```rust
// ✅ GOOD: Use pagination
const PAGE_SIZE: usize = 100;
let mut offset = 0;

loop {
    let page = store.get_history(PAGE_SIZE, offset)?;
    if page.is_empty() {
        break;
    }
    process_page(page);
    offset += PAGE_SIZE;
}

// ❌ BAD: Load everything at once
let all_entries = store.get_history(100000, 0)?; // May use lots of memory
```

### 5. Handle Images Carefully

```rust
// ✅ GOOD: Stream large images
use std::io::Read;

fn store_large_image<R: Read>(reader: &mut R) -> Result<(), DatabaseError> {
    let mut buffer = Vec::new();
    reader.read_to_end(&mut buffer)?;

    let source = SourceApplication::current();
    store.store_image(&buffer, "png", source)?;

    Ok(())
}

// ❌ BAD: Load entire image into memory twice
let data = std::fs::read("large_image.png")?; // May fail on large files
let entry = store.store_image(&data, "png", source)?;
```

---

## Complete Examples

### Example 1: Simple Clipboard Logger

```rust
use pasty_core::services::ClipboardStore;
use pasty_core::models::SourceApplication;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let store = ClipboardStore::new("./clipboard.db", "./images")?;

    // Log the current clipboard content
    let source = SourceApplication::current();
    let clipboard_content = get_clipboard_content()?;

    let entry = store.store_text(&clipboard_content, source)?;
    println!("Logged: {} (from {})",
        entry.content,
        entry.source.app_name
    );

    Ok(())
}

fn get_clipboard_content() -> Result<String, Box<dyn std::error::Error>> {
    // Implementation depends on platform
    Ok("Sample text".to_string())
}
```

### Example 2: Clipboard History Viewer

```rust
use pasty_core::services::ClipboardStore;
use pasty_core::models::ContentType;

fn show_recent_history(limit: usize) -> Result<(), Box<dyn std::error::Error>> {
    let store = ClipboardStore::new("./clipboard.db", "./images")?;

    // Get most recent entries
    let entries = store.get_history(limit, 0)?;

    println!("Recent clipboard history ({} entries):", entries.len());
    println!("{:=<60}");

    for (i, entry) in entries.iter().enumerate() {
        println!("{}. {}", i + 1, entry.id);

        match &entry.content {
            pasty_core::models::Content::Text(text) => {
                let preview: String = text.chars().take(50).collect();
                println!("   Type: Text");
                println!("   Preview: \"{}\"", preview);
                if text.len() > 50 {
                    println!("   (... {} more chars)", text.len() - 50);
                }
            }
            pasty_core::models::Content::Image(img) => {
                println!("   Type: Image");
                println!("   Path: {}", img.path);
                println!("   Size: {} bytes", img.size);
            }
        }

        println!("   From: {} ({})",
            entry.source.app_name,
            entry.source.bundle_id
        );
        println!("   Time: {}", entry.timestamp.format("%Y-%m-%d %H:%M:%S"));
        println!();
    }

    Ok(())
}
```

### Example 3: Clipboard Analysis Tool

```rust
use pasty_core::services::ClipboardStore;
use pasty_core::models::ContentType;
use std::collections::HashMap;

fn analyze_clipboard_usage() -> Result<(), Box<dyn std::error::Error>> {
    let store = ClipboardStore::new("./clipboard.db", "./images")?;

    // Get all entries
    let entries = store.get_history(10_000, 0)?;

    // Count by content type
    let mut type_counts: HashMap<String, usize> = HashMap::new();
    let mut app_counts: HashMap<String, usize> = HashMap::new();

    for entry in &entries {
        // Count by type
        let type_str = format!("{:?}", entry.content_type);
        *type_counts.entry(type_str.clone()).or_insert(0) += 1;

        // Count by app
        *app_counts.entry(entry.source.app_name.clone()).or_insert(0) += 1;
    }

    // Display statistics
    println!("Clipboard Usage Statistics");
    println!("{:=<60}");
    println!("Total Entries: {}", entries.len());
    println!();

    println!("By Content Type:");
    for (type_name, count) in type_counts {
        println!("  {}: {} ({:.1}%)",
            type_name,
            count,
            (count as f64 / entries.len() as f64) * 100.0
        );
    }
    println!();

    println!("By Application:");
    let mut apps: Vec<_> = app_counts.into_iter().collect();
    apps.sort_by(|a, b| b.1.cmp(&a.1));

    for (app, count) in apps.iter().take(10) {
        println!("  {}: {} ({:.1}%)",
            app,
            count,
            (count as f64 / entries.len() as f64) * 100.0
        );
    }

    Ok(())
}
```

### Example 4: Error-Resilient Clipboard Manager

```rust
use pasty_core::services::ClipboardStore;
use pasty_core::models::SourceApplication;
use log::{info, error, warn};

struct ClipboardManager {
    store: ClipboardStore,
}

impl ClipboardManager {
    fn new() -> Result<Self, Box<dyn std::error::Error>> {
        let store = ClipboardStore::new(
            "./clipboard.db",
            "./images"
        )?;

        Ok(Self { store })
    }

    fn store_text_safe(&self, text: &str) -> Result<(), pasty_core::services::database::DatabaseError> {
        let source = SourceApplication::current();

        // Store with automatic retry for transient errors
        let mut attempts = 0;
        let max_attempts = 3;
        let delay = std::time::Duration::from_millis(100);

        loop {
            match self.store.store_text(text, source.clone()) {
                Ok(entry) => {
                    info!("Stored text entry: {}", entry.id);
                    return Ok(());
                }
                Err(e) if e.is_retryable() && attempts < max_attempts - 1 => {
                    warn!("Store failed (attempt {}), retrying...", attempts + 1);
                    std::thread::sleep(delay);
                    attempts += 1;
                }
                Err(e) => {
                    error!("Failed to store text after {} attempts: {}", attempts + 1, e);
                    return Err(e);
                }
            }
        }
    }

    fn get_recent_text(&self, limit: usize) -> Result<Vec<String>, Box<dyn std::error::Error>> {
        use pasty_core::models::ContentType;

        let entries = self.store.get_history_filtered(
            ContentType::Text,
            limit,
            0
        )?;

        let texts: Vec<String> = entries
            .iter()
            .filter_map(|entry| {
                if let pasty_core::models::Content::Text(text) = &entry.content {
                    Some(text.clone())
                } else {
                    None
                }
            })
            .collect();

        Ok(texts)
    }
}

// Usage
fn main() -> Result<(), Box<dyn std::error::Error>> {
    env_logger::init();

    let manager = ClipboardManager::new()?;

    // Store text with error handling
    manager.store_text_safe("Important data")?;

    // Get recent text entries
    let recent_texts = manager.get_recent_text(10)?;
    println!("Recent texts: {:?}", recent_texts);

    Ok(())
}
```

---

## Tips and Tricks

### Memory Efficiency

```rust
// Avoid keeping all entries in memory
// Process in batches instead:
const BATCH_SIZE: usize = 100;

let mut offset = 0;
loop {
    let batch = store.get_history(BATCH_SIZE, offset)?;
    if batch.is_empty() {
        break;
    }

    for entry in batch {
        process_entry(entry);  // Process and drop
    }

    offset += BATCH_SIZE;
}
```

### Performance Optimization

```rust
// Use prepared statement cache (automatic)
// The Database caches up to 100 prepared statements
// This is automatic - no manual configuration needed

// For bulk operations, consider transactions
// (not implemented in this version, but can be added)
```

### Debugging

```rust
// Enable logging
env_logger::init();

// Check database directly
sqlite3 clipboard.db "SELECT * FROM clipboard_entries ORDER BY timestamp DESC LIMIT 10;"

// Check image files
find images/ -type f -name "*.png" | head -10
```

---

## Common Patterns

### Pattern 1: Store with Metadata

```rust
let entry = store.store_text(
    "User's selection",
    SourceApplication::new(
        "com.apple.TextEdit".to_string(),
        "TextEdit".to_string(),
        std::process::id()
    )
)?;
```

### Pattern 2: Retrieve and Display

```rust
let entries = store.get_history(10, 0)?;

for entry in entries {
    display_entry(entry);
}

fn display_entry(entry: &ClipboardEntry) {
    println!("{} - {} ({})",
        entry.timestamp.format("%H:%M:%S"),
        match entry.content {
            Content::Text(s) => s.chars().take(30).collect::<String>(),
            Content::Image(_) => "[Image]".to_string(),
        },
        entry.source.app_name
    );
}
```

### Pattern 3: Error Recovery

```rust
fn robust_store(store: &ClipboardStore, text: &str) {
    let source = SourceApplication::current();

    let mut entry = None;
    for attempt in 0..3 {
        match store.store_text(text, source.clone()) {
            Ok(e) => {
                entry = Some(e);
                break;
            }
            Err(e) if e.is_retryable() && attempt < 2 => {
                println!("Retry {}...", attempt + 1);
                std::thread::sleep(std::time::Duration::from_millis(100));
            }
            Err(e) => {
                eprintln!("Failed: {}", e);
                return;
            }
        }
    }
}
```

---

## Resources

- [Quick Start Guide](quickstart.md) - Setup instructions
- [Feature Specification](spec.md) - Detailed feature specs
- [Data Model](data-model.md) - Data structures
- [FFI Contract](contracts/rust-ffi.md) - FFI boundary documentation

---

## Summary

This guide provides:

- ✅ Basic usage examples for all common operations
- ✅ Clipboard monitoring setup
- ✅ Content storage (text, images)
- ✅ History retrieval with pagination and filtering
- ✅ Comprehensive error handling patterns
- ✅ Advanced usage examples
- ✅ Best practices and common patterns
- ✅ Complete, runnable examples

For more information, see the [Quick Start Guide](quickstart.md).
