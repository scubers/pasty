# Implementation Plan: Clipboard Operation Logic

**Branch**: `004-clipboard-operations` | **Date**: 2026-02-06 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-clipboard-operations/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement clipboard copy, paste, and delete operations (plus main panel key handling) by extending and aligning existing Swift macOS UI code and Rust core storage. Reuse current panel window, view models, and clipboard history retrieval to avoid duplicate models or services; add only the missing delete/paste/copy mechanics required by the spec and keep operation logic consistent with existing panel behavior.

## Technical Context

<!--
  ACTION REQUIRED: Replace the content in this section with the technical details
  for the project. The structure here is presented in advisory capacity to guide
  the iteration process.
-->

**Language/Version**: Swift 5.9+ (macOS UI), Rust 1.70+ (core storage)  
**Primary Dependencies**: AppKit, SwiftUI, Combine, KeyboardShortcuts, NSPasteboard, CGEvent (ApplicationServices)  
**Storage**: SQLite database + image files via Rust core (core/services/database.rs, core/services/storage.rs)  
**Testing**: XCTest (macOS), cargo test (Rust core)  
**Target Platform**: macOS 14+  
**Project Type**: Single macOS app with Rust core library (FFI)  
**Performance Goals**: Copy <200ms, copy+paste <500ms, delete <500ms (per Success Criteria)  
**Constraints**: Reuse existing ClipboardPanelWindow/MainPanelViewModel; avoid duplicate models/services; keep search focus during panel key handling; no new persistence beyond existing SQLite history; strictly follow MVVM and data-driven UI updates only  
**Scale/Scope**: Single-user desktop app, up to 10k entries (existing core limit)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### I. User Story Priority ✅ PASS
- **Status**: PASS
- **Evidence**: Spec defines P1 copy and copy+paste; P2 delete; each with acceptance scenarios.

### II. Test-First Development ✅ PASS
- **Status**: PASS (process requirement)
- **Plan**: Add/extend XCTest + Rust tests to cover acceptance scenarios before implementation.

### III. Documentation Before Implementation ✅ PASS
- **Status**: PASS
- **Evidence**: spec.md updated; plan.md in progress; research/data-model/contracts/quickstart generated in this plan.

### IV. Simplicity & YAGNI ✅ PASS
- **Status**: PASS
- **Evidence**: Scope limited to copy/paste/delete and panel logic; reuse existing models/services.

### V. Cross-Platform Compatibility ✅ PASS (Scoped)
- **Status**: PASS
- **Evidence**: Clipboard operations are platform-specific (NSPasteboard/CGEvent) while deletion and storage live in Rust core; FFI boundary preserved.

### VI. Privacy & Security First ✅ PASS
- **Status**: PASS
- **Evidence**: Operations stay local; no telemetry; deletion removes data; storage handled by existing core services.

### Overall Gate Status: ✅ PASS

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
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
├── src/
│   ├── models/
│   ├── services/
│   └── ffi/
└── tests/

macos/PastyApp/
├── Sources/
│   ├── AppKitViews/
│   ├── Coordinators/
│   ├── Models/
│   ├── PlatformLogic/
│   ├── Services/
│   ├── SwiftUIViews/
│   └── ViewModels/
└── Tests/
```

**Structure Decision**: Single repository with Rust core (core/) and macOS UI app (macos/PastyApp/). Clipboard operations reuse existing AppKit panel, view models, and Rust storage services.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| [e.g., 4th project] | [current need] | [why 3 projects insufficient] |
| [e.g., Repository pattern] | [specific problem] | [why direct DB access insufficient] |

## Phase 0: Outline & Research

**Outputs**:
- `specs/004-clipboard-operations/research.md`

**Research tasks**:
- Best practices for NSPasteboard copy/write and reading (Apple docs)
- Global shortcut handling and CGEvent-based paste (KeyboardShortcuts + CGEventTap guidance)
- Inventory existing code paths to avoid duplicate definitions (panel window, view models, Rust storage)

## Phase 1: Design & Contracts

**Outputs**:
- `specs/004-clipboard-operations/data-model.md`
- `specs/004-clipboard-operations/contracts/clipboard-operations.openapi.yaml`
- `specs/004-clipboard-operations/quickstart.md`

**Design notes (reuse-first)**:
- Reuse `ClipboardPanelWindow` for panel-level key handling and selection logic.
- Reuse `MainPanelViewModel`/`PreviewPanelViewModel` for copy/paste/delete actions; only adjust behavior to match spec.
- Reuse `ClipboardHistory` and Rust `ClipboardStore` for data access and latest_copy_time updates.

## Phase 1: Update Agent Context

Run:
- `.specify/scripts/bash/update-agent-context.sh claude`

## Constitution Check (Post-Design)

Re-evaluate gates after design artifacts are generated. No expected violations if scope remains limited to copy/paste/delete and panel key handling.
