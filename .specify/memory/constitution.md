<!--
================================================================================
SYNC IMPACT REPORT
================================================================================
Version Change: INITIAL → 1.0.0
Rationale: Initial constitution ratification for Pasty cross-platform clipboard app

Added Principles:
- I. User Story Priority (NEW)
- II. Test-First Development (NEW)
- III. Documentation Before Implementation (NEW)
- IV. Simplicity & YAGNI (NEW)
- V. Cross-Platform Compatibility (NEW)
- VI. Privacy & Security First (NEW)

Added Sections:
- Core Principles (NEW)
- Development Workflow (NEW)
- Cross-Platform Standards (NEW)
- Security & Privacy Requirements (NEW)
- Governance (NEW)

Templates Status:
- ✅ spec-template.md: Aligned with user story priority and documentation requirements
- ✅ plan-template.md: Aligned with constitution check gates and technical context
- ✅ tasks-template.md: Aligned with user story organization and test-first principles
- ✅ commands/*.md: No updates needed (agent-agnostic)

Follow-up TODOs: None - all placeholders filled

================================================================================
-->

# Pasty Constitution

## Core Principles

### I. User Story Priority

Every feature MUST be decomposed into prioritized, independently testable user stories (P1, P2, P3...).

**Rules**:
- User stories MUST be prioritized by business value and implementation dependency
- Each user story MUST be independently completable, testable, and deployable
- P1 (MVP) features MUST deliver standalone value without requiring P2+ features
- Implementation MUST proceed in priority order: P1 complete and validated before P2 begins
- User stories MUST avoid interdependencies that prevent independent implementation

**Rationale**: Prioritized user stories enable incremental value delivery, risk mitigation, and faster feedback. This ensures the project delivers value early and can pivot based on real-world usage of each story.

### II. Test-First Development (NON-NEGOTIABLE)

Test-Driven Development (TDD) is MANDATORY for all feature implementation.

**Rules**:
- Tests MUST be written BEFORE implementation code
- Red-Green-Refactor cycle MUST be strictly enforced:
  1. RED: Write failing test for desired behavior
  2. GREEN: Write minimal implementation to pass test
  3. REFACTOR: Improve code while keeping tests green
- Tests MUST fail BEFORE implementation begins (validation of test validity)
- All acceptance scenarios from spec.md MUST have corresponding tests
- Tests MUST be automated and runnable in CI/CD pipeline

**Rationale**: TDD ensures code quality, prevents regressions, serves as living documentation, and catches design issues early. For a clipboard app handling user data, reliability is critical.

### III. Documentation Before Implementation

No implementation shall begin without complete design artifacts.

**Rules**:
- Feature specification (spec.md) MUST be completed and approved before planning
- Implementation plan (plan.md) MUST be completed before task breakdown
- Tasks (tasks.md) MUST be generated before coding begins
- All design documents MUST be stored in `.specify/memory/` or feature-specific `specs/` directories
- Incomplete or underspecified areas MUST be marked with `[NEEDS CLARIFICATION: ...]`
- Amendments to spec during implementation MUST update documentation first

**Rationale**: Documentation-first prevents ambiguity, ensures stakeholder alignment, and creates maintainable codebases. For cross-platform development, clear specs prevent platform inconsistencies.

### IV. Simplicity & YAGNI

You Aren't Gonna Need It (YAGNI) principles MUST be followed.

**Rules**:
- Implement ONLY what is needed for current user stories
- DO NOT build features for "future use" or "maybe someday"
- Prefer simple solutions over clever abstractions
- Avoid premature optimization - measure before optimizing
- Remove dead code and unused dependencies immediately
- Three similar lines of code are preferred over premature abstraction
- Complexity MUST be justified in plan.md "Complexity Tracking" section

**Rationale**: Simplicity reduces maintenance burden, minimizes bugs, and enables faster iteration. A clipboard app must be lightweight and responsive.

### V. Cross-Platform Compatibility

Pasty is a cross-platform clipboard application; platform differences MUST be handled carefully.

**Rules**:
- Core clipboard logic MUST be platform-agnostic
- Platform-specific code MUST be isolated behind abstraction layers
- Each platform (Windows, macOS, Linux, etc.) MUST have equal feature parity when feasible
- Platform-specific limitations MUST be documented in spec.md
- Clipboard history MUST handle platform-specific data types gracefully
- Native permissions and security model of each platform MUST be respected

**Rationale**: Cross-platform consistency ensures user experience quality across all supported platforms while respecting each platform's unique constraints and security models.

### VI. Privacy & Security First

Clipboard data is sensitive; privacy and security are non-negotiable.

**Rules**:
- Clipboard history MUST be stored locally ONLY (no cloud sync without explicit user consent)
- Sensitive data (passwords, tokens, private info) MUST be handled with care
- Clear indication of clipboard access status MUST be provided to users
- Data MUST be encrypted at rest when persisted
- User MUST have ability to clear clipboard history completely
- No telemetry or analytics that could leak clipboard content
- Privacy implications of each feature MUST be documented in spec.md

**Rationale**: Clipboards often contain passwords, private messages, and sensitive information. Security breaches could have severe consequences for users.

## Development Workflow

### Specification Phase

1. User provides feature description via `/speckit.specify`
2. Spec is generated with user stories, priorities, and acceptance criteria
3. Clarification questions asked via `/speckit.clarify` for underspecified areas
4. User approves spec before proceeding

### Planning Phase

1. `/speckit.plan` generates implementation plan from approved spec
2. Technical context is documented (platforms, frameworks, constraints)
3. Constitution check is performed - violations must be justified
4. Data model and contracts are designed
5. Plan is approved before task generation

### Task Generation Phase

1. `/speckit.tasks` generates task breakdown from plan and spec
2. Tasks are organized by user story (P1, P2, P3...)
3. Dependencies are clearly marked
4. Test tasks (if requested) precede implementation tasks

### Implementation Phase

1. `/speckit.implement` executes tasks in dependency order
2. Tests are written FIRST and validated to fail
3. Implementation follows red-green-refactor cycle
4. Each task is completed before moving to next
5. User stories are validated independently at checkpoints

### Quality Gates

- **Gate 1**: Spec approval before planning
- **Gate 2**: Constitution check validation before task generation
- **Gate 3**: Test failure verification before implementation
- **Gate 4**: User story independent testing before proceeding to next priority

## Cross-Platform Standards

### Platform Support Matrix

| Platform | Clipboard API | Permissions | Storage | Status |
|----------|---------------|-------------|---------|--------|
| Windows  | WinAPI        | Clipboard access | Local file system | Target |
| macOS    | NSPasteboard  | Clipboard access | Local file system | Target |
| Linux    | X11/Wayland   | Clipboard access | Local file system | Target |

### Code Organization

```
src/
├── core/              # Platform-agnostic clipboard logic
│   ├── models/        # Data models (clipboard entries, history)
│   ├── services/      # Business logic (encryption, history management)
│   └── interfaces/    # Abstractions for platform-specific code
├── platforms/         # Platform-specific implementations
│   ├── windows/
│   ├── macos/
│   └── linux/
└── shared/            # Utilities, constants, helpers

tests/
├── contract/          # API contract tests
├── integration/       # Cross-component tests
└── unit/              # Unit tests
```

### Platform-Specific Constraints

Each platform implementation MUST:
- Implement the core clipboard interface
- Handle platform-specific data types (images, formatted text, etc.)
- Respect platform permissions and security models
- Provide consistent user experience across platforms
- Document platform-specific limitations in spec.md

## Security & Privacy Requirements

### Data Handling

- **At Rest**: Clipboard history MUST be encrypted using platform-standard encryption (DPAPI on Windows, Keychain on macOS, libsecret on Linux)
- **In Transit**: Not applicable (local-only storage)
- **Access Control**: User MUST be able to configure which applications can access clipboard history
- **Retention**: User-configurable retention periods, with immediate deletion option

### Sensitive Data Handling

Features MUST consider:
- Password managers copying credentials
- Two-factor authentication codes
- Private messages and emails
- Financial information
- Personal identification information

### User Consent

- Clear privacy policy MUST be provided
- User MUST opt-in to clipboard history feature
- User MUST be able to disable history at any time
- Data export and deletion options MUST be provided

## Governance

### Amendment Procedure

1. Proposed amendment MUST be documented with rationale
2. Impact analysis MUST be performed on all dependent artifacts
3. Stakeholder approval MUST be obtained
4. Migration plan MUST be created for breaking changes
5. Version MUST be incremented according to semantic versioning

### Versioning Policy

- **MAJOR**: Backward-incompatible changes (principle removal/redefinition)
- **MINOR**: New principles added or material guidance expansion
- **PATCH**: Clarifications, wording improvements, non-semantic changes

### Compliance Review

- All pull requests MUST verify compliance with core principles
- Complexity violations MUST be justified in plan.md
- Constitution checks MUST pass before implementation
- Non-compliance MUST be addressed before merge

### Living Constitution

This constitution is a living document:
- Review quarterly for relevance
- Update based on lessons learned
- Maintain alignment with project goals
- Preserve backward compatibility when possible

---

**Version**: 1.0.0 | **Ratified**: 2026-02-04 | **Last Amended**: 2026-02-04
