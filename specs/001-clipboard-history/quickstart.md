# Quickstart: Clipboard History MVP (macOS)

**Feature**: [spec.md](./spec.md)  
**Plan**: [plan.md](./plan.md)  
**Date**: 2026-02-06

This quickstart describes how to build and manually verify the clipboard-history MVP on macOS.

## Prerequisites

- macOS 14.0+
- Installed tooling:
  - `xcodebuild`
  - `xcodegen`
  - `clang++`

Verify environment:

```bash
./scripts/check-requirements.sh
```

## Build

Build the macOS app:

```bash
./scripts/build.sh macos Debug
```

Run the app:

```bash
open build/macos/Build/Products/Debug/Pasty2.app
```

## Manual Verification Checklist (MVP)

1) **Capture text**

- Copy a short text snippet in any app.
- Expected: a new history item appears in the UI list with type `text` and the copied content.

2) **Capture image**

- Copy an image (e.g., from Preview or a browser).
- Expected: a new history item appears with type `image`, width/height populated, and an `image_path` set.

Image format coverage (recommended): validate at least PNG and JPEG; optionally validate TIFF/HEIC/WebP if you can copy such images from a source app.

3) **Dedupe**

- Copy the exact same text again.
- Expected: no new item is created; the existing item’s `last_copy_time_ms` updates and item moves to most-recent.

4) **Refresh**

- Press the refresh button.
- Expected: list reloads from persistent storage (no in-memory-only artifacts).

5) **Delete text item**

- Delete a text item.
- Expected: item disappears after refresh and does not reappear after app restart.

6) **Delete image item (cascading file deletion)**

- Delete an image item.
- Expected: item disappears after refresh and the referenced image file is removed from disk.

7) **Source app id**

- Copy text from two different apps.
- Expected: `source_app_id` is best-effort: present when detectable; otherwise empty/unknown.

8) **File/folder clipboard content ignored**

- Copy a file or folder in Finder.
- Expected: no history item is created; a diagnostic log entry is emitted.

## Notes

- The Core is currently a skeleton; the demo UI + persistence are introduced as part of this feature implementation.
- Some clipboard content may be marked transient or concealed by source apps; the MVP defaults to not persisting such content for privacy.

## Validation Log

- 2026-02-07: `./scripts/core-build.sh` passed.
- 2026-02-07: `xcodegen generate` (from `platform/macos`) passed.
- 2026-02-07: `./scripts/platform-build-macos.sh Debug` passed and produced `build/macos/Build/Products/Debug/Pasty2.app`.
