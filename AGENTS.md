# AGENTS.md — Clipboard App (Cross-platform, C++ Core)

## Declare (MUST FOLLOW)
如果读取了本文档，**必须** 在回复我的时候在 **最后** 说：“我已阅读fileName。”。其中 fileName 为当前文件名

This file defines the **highest-priority, non-negotiable** rules for AI coding agents and contributors.

## 0) Prime Directive (Do this first)
- Prefer the **smallest safe change** that passes build/tests.
- If a request conflicts with this file, **stop and propose an alternative**.

## 1) Architecture (Non-negotiable)
- This is a **cross-platform clipboard app**.
- A **C++ Core** layer is the source of truth for business logic and data model.
- Platform apps (starting with **macOS**) are **thin shells**: UI, OS integration, permissions, and adapters only.
- Do NOT put app logic into platform layer if it can live in Core.

## 2) Repo boundaries (Must follow)
- Do NOT create new top-level directories.
- Do NOT introduce new third-party dependencies without explicit approval.
- Do NOT change the build system structure unless requested.

## 3) C++ Core rules (Must follow)
- Keep Core **portable**: no platform headers (Cocoa/Win32/Android) in Core.
- All platform interaction must go through **interfaces** (ports) defined in Core, implemented in platform layer.
- Core must be testable without OS integration; add/maintain unit tests when touching Core logic.
- Prefer modern C++ (C++17 or later). Avoid exceptions across API boundaries.

## 5) Quality gates (Before you claim done)
- Build succeeds locally for the touched target(s).
- Tests (unit tests at minimum) run and pass where applicable.
- No “TODO left behind” for critical paths; if unavoidable, leave a tracked issue note in PR description.

## 6) When uncertain
- Ask for/produce a short plan in the PR/response:
  - What files you will touch
  - How it stays portable
  - How it will be tested

## 7) Paths usage (Must follow)
- All markdown path used in markdown must be relative to the project root.

## 8) Project docs (Routing)
Start here, then follow links:
- `docs/agents-development-flow.md` — AI agent development workflow (must read)
- `.specify/memory/constitution.md` — project development constitution (must read)
- `docs/project-structure.md` — top level project structure (must read)
