# Quickstart: Clipboard Operation Logic

This guide validates copy, paste, and delete operations using the existing macOS UI.

## Prerequisites

- Rust 1.70+
- Xcode 14+

## Run the App

1. Build and launch:

```bash
./scripts/build.sh release
./scripts/run.sh
```

2. Start clipboard monitoring (app starts it on launch).

## Validate Copy / Paste / Delete

1. Press `Cmd+Shift+V` to open the main panel.
2. Ensure the search bar is focused and the first entry is selected.
3. Copy:
   - Press `Cmd+Enter` on a selected entry.
   - Paste in another app to confirm contents.
4. Paste (copy + paste):
   - Press `Enter` on a selected entry.
   - Panel closes and content is pasted into the previously active app.
5. Delete:
   - Press `Cmd+D` on a selected entry.
   - Confirm the dialog; entry is removed from the list and storage.

## Notes

- Copy/paste use `NSPasteboard` and simulated `Cmd+V` via `CGEvent` in existing view models.
- The global shortcut uses the `KeyboardShortcuts` library; Accessibility permission may be required.
