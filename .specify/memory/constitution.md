<!--
Sync Impact Report:
- Version change: (none) → 1.0.0
- Modified principles: (none) → Initial creation
- Added sections: All sections (initial constitution)
- Removed sections: (none)
- Templates requiring updates:
  - ✅ .specify/templates/plan-template.md - Constitution Check section aligns with principles
  - ✅ .specify/templates/spec-template.md - Scope/requirements align with principles
  - ✅ .specify/templates/tasks-template.md - Task categorization aligns with principles
  - ✅ .opencode/commands/speckit.constitution.md - No outdated references
- Follow-up TODOs: None
-->

# Pasty2 Project Constitution

**Project**: Pasty2 - Modern Clipboard Application
**Version**: 1.0.0
**Ratified**: 2026-02-06
**Last Amended**: 2026-02-06

## Project Vision

Pasty2 is a modern clipboard application built with AI-assisted development, designed to provide seamless clipboard history management with an emphasis on user privacy, performance, and cross-platform compatibility.

---

## Core Principles

### P0: Declare
如果读取了本文档，**必须** 在回复我的时候在 **最后** 说：“我已阅读fileName。”。其中 fileName 为当前文件名

### P1: Privacy First

Clipboard data contains sensitive user information (passwords, tokens, personal messages). Pasty2 MUST store clipboard history locally on the user's device without remote synchronization by default. Any cloud storage feature MUST be opt-in and explicitly user-controlled.

**Rationale**: Clipboard content is inherently sensitive. Default local storage prevents inadvertent data exposure and maintains user trust.

---

### P2: Performance Responsive

Pasty2 MUST maintain responsive UI operations with clipboard history capture and retrieval completing within 100ms for typical use (up to 1000 items). Memory footprint MUST remain under 200MB with 10,000 history items. Application startup MUST complete within 2 seconds.

**Rationale**: Clipboard access is a high-frequency operation. Performance degradation directly impacts user workflow and perceived responsiveness.

---

### P3: Cross-Platform Compatibility

Pasty2 MUST support macOS, Windows, and Linux platforms with consistent feature parity across platforms. Platform-specific APIs MUST be abstracted through a common interface. Differences in behavior due to platform limitations MUST be documented.

**Rationale**: Modern development workflows span multiple operating systems. Consistent experience ensures adoption and reduces user friction.

---

### P4: Data Integrity

Pasty2 MUST ensure clipboard items are captured accurately without corruption or truncation. Text formatting, images, and rich content types MUST be preserved when supported by the platform. Data storage MUST use atomic writes to prevent corruption during crashes or unexpected termination.

**Rationale**: Loss of clipboard data can result in lost work and user frustration. Data integrity is critical for a clipboard manager's core function.

---

### P5: Extensible Architecture

Pasty2 MUST use a plugin or extension architecture that allows third-party developers to add functionality without modifying core application code. Core APIs for clipboard monitoring, storage, and UI integration MUST be documented and stable across minor version releases.

**Rationale**: Clipboard usage patterns vary significantly across users. Extensability allows community-driven innovation while maintaining core stability.

---

## Governance

### Amendment Procedure

1. **Proposal**: Any contributor may propose a constitutional amendment by creating a draft with the following:
   - Clear statement of the change
   - Rationale for the amendment
   - Impact analysis on existing features and templates

2. **Review**: The proposal MUST be reviewed for consistency with existing principles and project vision.

3. **Version Bump**: Constitution versions follow semantic versioning:
   - **MAJOR**: Backward incompatible governance/principle removals or redefinitions
   - **MINOR**: New principle/section added or materially expanded guidance
   - **PATCH**: Clarifications, wording, typo fixes, non-semantic refinements

4. **Ratification**: Amendments require explicit approval and date update.

### Versioning Policy

- Version MUST be incremented on any change to the constitution content
- Version format: MAJOR.MINOR.PATCH
- Ratification date remains the original adoption date
- Last amended date updates with each change

### Compliance Review

All feature specifications, implementation plans, and tasks MUST pass constitutional compliance checks:

1. **Plan Check**: Implementation plans MUST explicitly reference relevant principles in the Constitution Check section
2. **Analyze Check**: Analysis MUST flag any constitutional conflicts as CRITICAL
3. **Principle Validation**: Features MUST NOT violate core principles without explicit documented justification

### Template Synchronization

Constitution changes require review of dependent templates to ensure consistency:

- `.specify/templates/plan-template.md` - Constitution Check gates
- `.specify/templates/spec-template.md` - Mandatory requirements sections
- `.specify/templates/tasks-template.md` - Principle-driven task categorization
- `.opencode/commands/*.md` - Agent references and workflow guidance

Templates requiring updates MUST be marked in the Sync Impact Report.

---

## Appendix

### Principle Application Guidelines

#### P1: Privacy First

- Local storage is the default behavior
- Any data export features MUST include user confirmation
- Clipboard content redaction for sensitive patterns (passwords, API keys) is encouraged but not mandatory
- Audit logging of clipboard access is optional

#### P2: Performance Responsive

- Performance metrics MUST be collected and monitored
- Degradation beyond thresholds triggers optimization priority
- Large clipboard items (>10MB) may be handled with special consideration (deduplication, compression)

#### P3: Cross-Platform Compatibility

- Minimum supported versions MUST be documented (e.g., macOS 12+, Windows 10+, Ubuntu 20.04+)
- Platform-specific features are permitted but MUST not create dependency incompatibility
- Testing pipeline MUST verify feature parity across supported platforms

#### P4: Data Integrity

- Atomic writes MUST be used for all persistence operations
- Data validation MUST occur on clipboard item capture
- Corruption recovery mechanisms SHOULD be implemented (automatic repair, backup restoration)

#### P5: Extensible Architecture

- Plugin API documentation MUST be maintained
- Breaking changes to plugin APIs require MAJOR version bump
- Core application MUST remain functional without any plugins installed
