# Implementation Plan: Clipboard History Source Management (macOS)

**Branch**: `001-clipboard-history` | **Date**: 2026-02-06 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-clipboard-history/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement macOS clipboard history capture that records text/images, deduplicates repeated copies by content, persists items locally (SQLite + image files), and provides a demo UI to list/refresh/delete items.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: C++17 (Core), Swift 5.9 (macOS shell)  
**Primary Dependencies**: Cocoa.framework (macOS UI/system integration), system SQLite (local storage), XcodeGen (project generation)  
**Storage**: Local SQLite database for history + local files for image assets (paths stored as relative references)  
**Testing**: Core unit tests via a minimal clang++-built test executable; manual macOS end-to-end verification using demo UI  
**Target Platform**: macOS 14.0+ (MVP); design kept portable for future Windows/Linux parity  
**Project Type**: Desktop application (C++ Core + macOS native shell)  
**Performance Goals**: Capture processing <100ms typical (<=1000 items); UI refresh/list <100ms for 200 items; startup <2s  
**Constraints**: Privacy-first (local-only by default, no network); Core must remain portable (no platform headers); atomic persistence; no new top-level directories; no new third-party dependencies  
**Scale/Scope**: Retain 1000 most recent items; UI displays at least 200 most recent; support `text` and `image`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Check | Status | Notes |
|-----------|-------|--------|-------|
| **P1: Privacy First** | Does feature handle sensitive clipboard data? | [x] | Store locally only; skip transient markers; default-skip concealed markers; no remote sync; optional masking in UI. |
| **P2: Performance Responsive** | Are performance goals within constitutional limits? | [x] | Poll `changeCount` (cheap); adaptive polling interval; avoid heavy work on UI thread; list shows 200 items. |
| **P3: Cross-Platform Compatibility** | Is feature feasible across macOS, Windows, Linux? | [x] | macOS shell provides clipboard events; Core owns policy/dedupe/persistence; platform interaction via ports. |
| **P4: Data Integrity** | Are atomic writes and data validation addressed? | [x] | Store image file via temp+rename; SQLite transactions; write blob first then commit item; handle missing files on delete. |
| **P5: Extensible Architecture** | Does feature support plugin/extension model? | [x] | Introduce stable Core service + ports (clipboard event source, clock, store, filesystem). |

Re-check after Phase 1 design: PASS (data model + contracts keep Core portable; no remote sync; atomic persistence requirements captured in research).

## Project Structure

### Documentation (this feature)

```text
specs/001-clipboard-history/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)
<!--
  ACTION REQUIRED: Replace the placeholder tree below with the concrete layout
  for this feature. Delete unused options and expand the chosen structure with
  real paths (e.g., apps/admin, packages/something). The delivered plan must
  not include Option labels.
-->

```text
core/
├── include/
│   ├── Pasty.h
│   └── module.modulemap
└── src/
    └── Pasty.cpp

platform/
└── macos/
    ├── project.yml
    ├── Info.plist
    ├── ARCHITECTURE.md
    ├── Pasty2.xcodeproj/
    └── Sources/
        ├── App.swift
        ├── Utils/
        ├── Model/
        ├── ViewModel/
        └── View/

scripts/
├── build.sh
├── core-build.sh
└── platform-build-macos.sh

specs/
└── 001-clipboard-history/
    ├── spec.md
    ├── plan.md
    ├── research.md
    ├── data-model.md
    ├── quickstart.md
    └── contracts/
```

**Structure Decision**: Keep all business rules (dedupe, retention, persistence schema, deletion semantics) in portable C++ Core. macOS is a thin shell that watches NSPasteboard and renders the demo UI.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |

## Phase 0: Research (output: research.md)

- Confirm macOS clipboard change detection approach and timer strategy.
- Confirm how to read text and images reliably from NSPasteboard.
- Confirm supported image formats from pasteboard and how to persist them (PNG/JPEG/TIFF/WebP/HEIC/HEIF/GIF/BMP).
- Confirm realistic source application attribution behavior and limitations.
- Confirm behavior for file/folder clipboard content (ignore + diagnostic logging).
- Decide persistence approach (SQLite + assets) and crash-consistency rules.
- Decide privacy filtering rules for transient/concealed pasteboard content.

## Phase 1: Design & Contracts (outputs: data-model.md, contracts/*, quickstart.md)

- Define Core entities (HistoryItem, AssetBlob) and invariants.
- Define Core ports/services: clipboard event source (platform), store, filesystem, clock.
- Define a minimal contract describing history query/delete operations and ingestion of clipboard events.
- Provide quickstart steps to build and manually verify the feature.

## Phase 2: Planning Handoff

- Decompose implementation into tasks.md (done by `/speckit.tasks`).
