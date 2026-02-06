# Quickstart: Clipboard Main Panel (macOS)

**Feature**: `specs/002-clipboard-main-panel/spec.md`  
**Plan**: `specs/002-clipboard-main-panel/plan.md`  
**Date**: 2026-02-07

This quickstart describes how to build and manually verify the clipboard main panel on macOS.

## Prerequisites

- macOS 14.0+
- Installed tooling:
  - `xcodebuild`
  - `xcodegen`
  - `cmake`

Verify environment:

```bash
./scripts/check-requirements.sh
```

## Build

Build the Core library:

```bash
./scripts/core-build.sh Debug
```

Build the macOS app:

```bash
./scripts/platform-build-macos.sh Debug
```

Run the app:

```bash
open build/macos/Build/Products/Debug/Pasty2.app
```

## Manual Verification Checklist

1) **Background utility behavior**

- Launch the app.
- Expected: app does not appear in the Dock during normal use.
- Expected: no demo/history window opens automatically on launch.

2) **Toggle main panel**

- Press `cmd+shift+v`.
- Expected: main panel appears.
- Press `cmd+shift+v` again.
- Expected: main panel hides.

3) **Panel placement**

- With multiple monitors, move the mouse to a non-main screen.
- Press `cmd+shift+v`.
- Expected: main panel appears on the screen containing the mouse cursor, centered horizontally and slightly above vertical center.

4) **Search input focus**

- Open the main panel.
- Expected: the search input is focused and typing immediately edits the search query.

5) **Search like-matching**

- Ensure there are known clipboard history items (copy some text before opening the panel).
- Type a partial query.
- Expected: results list updates as you type and includes items that like-match the query.
- Clear the query.
- Expected: results show the default (most recent) items.

6) **Selection and preview**

- Click a text item.
- Expected: preview shows the text content and basic metadata.
- Click an image item (if present).
- Expected: preview shows an image preview and basic metadata.

## Notes

- macOS code must follow MVVM + Combine (`platform/macos/ARCHITECTURE.md`).
- Search semantics live in portable Core (`core/ARCHITECTURE.md`).
- macOS shell uses Swift Packages `KeyboardShortcuts` (hotkey) and `SnapKit` (layout) configured via XcodeGen `platform/macos/project.yml`.
