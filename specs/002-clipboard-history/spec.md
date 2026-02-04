# Feature Specification: Clipboard History Manager

**Feature Branch**: `002-clipboard-history`
**Created**: 2026-02-04
**Status**: Draft
**Input**: User description: "实现粘贴板历史记录功能（macos 端）监听粘贴板变更，识别内容类型，记录元信息到本地数据库，支持去重"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Monitor and Record Clipboard Changes (Priority: P1)

Users need the system to automatically detect and record clipboard changes on their macOS device. When they copy text or images, the system should capture the content along with relevant metadata without requiring any manual action.

**Why this priority**: This is the core foundation of the clipboard history feature. Without monitoring and recording, no other functionality is possible. It delivers immediate value by creating a persistent history of the user's clipboard activity.

**Independent Test**: Can be fully tested by copying various types of content (text, images, files) and verifying that the system correctly records supported types (text, images) while logging unsupported types (files, folders). The test passes when all clipboard events are captured and appropriate action is taken for each content type.

**Acceptance Scenarios**:

1. **Given** the system is monitoring clipboard, **When** user copies plain text, **Then** system records the text content with metadata (source, timestamp, type, hash)
2. **Given** the system is monitoring clipboard, **When** user copies an image, **Then** system records the image metadata and saves image content to file system with hash-based filename
3. **Given** the system is monitoring clipboard, **When** user copies a file or folder reference, **Then** system logs the event and does not create a database record
4. **Given** the system is monitoring clipboard, **When** user copies content they have previously copied, **Then** system updates the timestamp on existing record instead of creating duplicate

---

### User Story 2 - Retrieve Clipboard History (Priority: P2)

Users need to access their clipboard history to find and reuse previously copied content. The system should provide a way to view and search through recorded clipboard entries.

**Why this priority**: While recording creates the history, retrieval makes it useful. Users can only benefit from the feature if they can access what was recorded. This is lower priority than recording because the history must exist before it can be retrieved.

**Independent Test**: Can be fully tested by copying multiple items, then querying the database to retrieve them. The test passes when all recorded clipboard entries are returned with their complete metadata and content is accessible.

**Acceptance Scenarios**:

1. **Given** multiple clipboard entries exist in database, **When** user requests clipboard history, **Then** system returns all entries ordered by most recent timestamp
2. **Given** clipboard history contains text and images, **When** user filters by content type, **Then** system returns only entries matching the specified type
3. **Given** a clipboard entry exists, **When** user requests entry by its unique identifier, **Then** system returns the complete entry including metadata and content

---

### Edge Cases

- What happens when clipboard content is extremely large (e.g., 10MB of text or high-resolution image)?
- How does system handle rapid clipboard changes (multiple copies within milliseconds)?
- What happens when image file cannot be saved to file system (disk full, permissions)?
- How does system handle special characters or unicode in text content?
- What happens when database is locked or corrupted during write operation?
- How does system behave when clipboard contains mixed content types (e.g., text + image)? **RESOLUTION**: System prioritizes text over image, then processes first matching type in priority order (text > image > file > unsupported)
- What happens during system sleep or hibernation - are clipboard changes detected on wake? **RESOLUTION**: System resumes monitoring on wake and checks for changes that occurred during sleep
- How does system handle duplicate detection when content has minor differences (e.g., trailing whitespace)? **RESOLUTION**: Text content is normalized (trimmed) before hashing for more intuitive deduplication

## Requirements *(mandatory)*

### Functional Requirements

#### Clipboard Monitoring
- **FR-001**: System MUST automatically detect when clipboard content changes on macOS system-wide (not just within the application)
- **FR-002**: System MUST identify the type of clipboard content (text, image, file/folder reference, other)
- **FR-003**: System MUST process text clipboard content and record to database
- **FR-004**: System MUST process image clipboard content, save to file system, and record metadata to database
- **FR-005**: System MUST log clipboard events for file/folder references without creating database records
- **FR-006**: System MUST ignore clipboard content that is neither text, image, nor file/folder
- **FR-007**: When clipboard contains multiple content types, system MUST prioritize processing in order: text > image > file/folder > unsupported

#### Metadata Recording
- **FR-008**: System MUST capture and store clipboard content timestamp with millisecond precision
- **FR-009**: System MUST identify and record the source application that provided the clipboard content
- **FR-010**: System MUST record the content type (text or image) for each clipboard entry
- **FR-011**: System MUST generate and store a content hash (e.g., SHA-256) for deduplication
- **FR-012**: System MUST assign a unique identifier to each clipboard entry for unambiguous reference
- **FR-013**: System MUST track and update the most recent copy timestamp (latest_copy_time_ms) for each clipboard entry

#### Data Persistence
- **FR-014**: System MUST store clipboard metadata in a local database for persistent access
- **FR-015**: System MUST save image content to file system using hash-based filename for efficient storage
- **FR-016**: System MUST store text content directly in the database for quick retrieval
- **FR-017**: System MUST ensure database schema uses unique identifier as primary key for data integrity
- **FR-018**: System MUST maintain database schema version to support future migrations

#### Deduplication
- **FR-019**: System MUST detect duplicate clipboard entries by comparing content hashes
- **FR-020**: System MUST update timestamp and latest_copy_time_ms when duplicate content is detected
- **FR-021**: System MUST NOT create duplicate database entries for identical content
- **FR-022**: System MUST replace existing image file when duplicate image is detected

#### Cross-Platform Architecture
- **FR-023**: System MUST implement clipboard monitoring in platform-specific layer to handle OS-specific clipboard APIs
- **FR-024**: System MUST implement database operations in cross-platform layer for code reuse across platforms
- **FR-025**: System MUST implement file system operations in cross-platform layer for consistent behavior
- **FR-026**: System MUST implement deduplication logic in cross-platform layer to ensure consistent duplicate detection
- **FR-027**: System MUST provide clear interface between platform-specific and cross-platform layers for maintainability

#### Platform-Specific Architecture (macOS/Swift)
- **FR-028**: System MUST implement extensible handler architecture with dedicated handlers for each content type (TextHandler, ImageHandler, FileHandler)
- **FR-029**: System MUST separate clipboard monitoring (Monitor), content type detection (Detector), and content processing (Handler) into distinct components
- **FR-030**: Handlers MUST NOT directly access FFI layer; instead, they MUST delegate to platform-specific business logic layer
- **FR-031**: Platform-specific business logic layer MUST coordinate between handlers and FFI layer for database operations

### Key Entities

- **ClipboardEntry**: Represents a single clipboard event with all recorded metadata. Attributes: unique identifier (primary key), content hash, content type (text/image), timestamp (initial copy time), latest_copy_time_ms (most recent copy time), source application, text content (for text type), file path (for image type)
- **ContentHash**: Represents the cryptographic hash of clipboard content used for deduplication. Attributes: hash value, hash algorithm, reference to ClipboardEntry
- **SourceApplication**: Represents the application that provided the clipboard content. Attributes: application name, bundle identifier, process ID
- **ImageFile**: Represents an image saved to the file system. Attributes: file path (hash-based), file size, dimensions (width × height), format (PNG, JPEG, etc.)
- **DatabaseVersion**: Represents the current database schema version for migration support. Attributes: version number, migration date, applied migrations

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Clipboard changes are detected and processing begins within 100 milliseconds of user copying content
- **SC-002**: Text clipboard entries are successfully recorded to database with 100% accuracy for all supported text formats
- **SC-003**: Image clipboard entries are successfully saved to file system and metadata recorded to database with 100% accuracy
- **SC-004**: Duplicate content detection prevents duplicate database entries in 100% of cases where content hash matches
- **SC-005**: System handles at least 100 clipboard entries per second without performance degradation
- **SC-006**: Database queries for clipboard history return results in under 50 milliseconds for databases with up to 10,000 entries
- **SC-007**: Image files are stored using hash-based naming, ensuring identical images share the same file on disk
- **SC-008**: System logs all file/folder clipboard events without creating database records, providing complete audit trail
- **SC-009**: Cross-platform layer handles all database and file system operations, maintaining clean separation from platform-specific code
- **SC-010**: System gracefully handles edge cases (large content, rapid changes, file system errors) without crashing or data loss
