# Data Model: Clipboard Main Panel (macOS)

**Feature**: `specs/002-clipboard-main-panel/spec.md`  
**Research**: `specs/002-clipboard-main-panel/research.md`  
**Date**: 2026-02-07

This document describes the UI-facing (presentation) data model for the macOS main panel and how it maps to Core history items.

## Core Entity: ClipboardHistoryItem

**Source of truth**: Core (`pasty::ClipboardHistoryItem`).

**Fields used by this feature**

- `id` (string)
- `type` (`text` | `image`)
- `content` (string; text)
- `imagePath` (string; image; relative path)
- `imageWidth` / `imageHeight` (int; image)
- `imageFormat` (string; image)
- `lastCopyTimeMs` (int64)
- `sourceAppId` (string; may be empty)

## Presentation Model: MainPanelRow

Represents one row in the left results list.

- `id` (string)
- `type` (`text` | `image`)
- `title` (string; short summary for display)
- `subtitle` (string; metadata summary for display)

**Mapping rules (presentation-only)**

- Text row title is a trimmed prefix of content (e.g., first 80 characters).
- Image row title is derived from dimensions and format (e.g., `image 1200x800 png`).
- Subtitle includes `sourceAppId` (or `unknown`) and `lastCopyTimeMs` formatted for UI.

## Presentation Model: PreviewState

Represents the right-side preview.

- `selectedId` (string; optional)
- `type` (`text` | `image`; optional)
- `text` (string; optional)
- `imageAbsolutePath` (string; optional)
- `metadata` (key/value list for UI): includes `type`, `lastCopyTimeMs`, optional `sourceAppId`, and image dimensions when applicable

**Invariants**

- If `type=text`, then `text` is present and `imageAbsolutePath` is absent.
- If `type=image`, then `imageAbsolutePath` is present and `text` is absent.

## ViewModel State: MainPanelState

Minimal state owned by the ViewModel.

- `query` (string)
- `rows` ([MainPanelRow])
- `selectedId` (string; optional)
- `preview` (PreviewState)
- `isVisible` (bool)
- `errorMessage` (string; optional)
