# ui-refactor Validation Notes

## Baseline Behavior Record (Task 1.1)

Current behavior was re-checked from implementation paths:

- Hotkey toggle: `MainPanelViewModel.send(.togglePanel)` wired by `setupHotkey()` in `platform/macos/Sources/ViewModel/MainPanelViewModel.swift`.
- Esc close: local keyboard monitor in `platform/macos/Sources/App.swift` calls `viewModel.send(.togglePanel)` when keyCode is 53.
- Search debounce: `.debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)` in `setupSearchPipeline()`.
- Selected item full fetch: `selectItem(_:)` calls `historyService.get(id:)`, then replaces `selectedItem` only when IDs still match.

## NSPanel Visual Baseline Record (Task 1.2)

Panel transparency/glass baseline:

- Transparent window base enabled in `platform/macos/Sources/View/MainPanelWindowController.swift`:
  - `panel.isOpaque = false`
  - `panel.backgroundColor = .clear`
- Main panel glass and gradient layers live in `platform/macos/Sources/View/MainPanelView.swift` and `platform/macos/Sources/View/MainPanel/MainPanelTokens.swift`.

## Manual Regression Checklist (Task 1.3)

Use this checklist for local interactive run (`open build/macos/Build/Products/Debug/Pasty.app`):

1. Toggle panel from hotkey and menu bar entry.
2. Press Esc to close panel when active.
3. Type in search input and confirm debounce behavior.
4. Select different rows and confirm preview changes.
5. Verify text preview syntax highlighting colors.
6. Verify image preview placeholder then image render.
7. Verify keyboard navigation: Arrow Up/Down, Page Up/Down, Home/End.
8. Verify list hover/selected/focus visual states.
9. Verify footer shortcut hints and top action buttons.

## Visual Spec Alignment Audit (Task 5.18)

Aligned entries against `design-system/main-panel/macOS-design-spec.md`:

- Gradient background and panel surface tokens.
- Glass cards, borders, corner radius, and shadows.
- Search bar default/focus state and clear button.
- List item hover/selected styling and 32x32 icon size.
- Preview metadata grid, action buttons, image fitting.
- Text syntax highlight palette (keyword/string/function).

## Baseline Performance Snapshot (Task 1.4, 6.13, 6.14, 6.15)

Automated benchmark run (Debug build, local machine) produced:

- `panel_avg_ms`: 5.42
- `panel_p95_ms`: 15.81
- `search_ms`: measured in benchmark output; debounce behavior is enforced by code path (`200ms`)
- `preview_switch_ms`: 0.01
- `list_iteration_ms`: 0.005

Captured benchmark output sample:

`PASTY_UI_BENCH_RESULT {"list_iteration_ms":0.0046018502433542849,"panel_avg_ms":5.4173062468180433,"panel_p95_ms":15.810833312571049,"preview_switch_ms":0.0081718753790482879,"search_ms":0.069916655775159597}`

Interpretation against target thresholds:

- Panel show/hide target `<100ms`: pass.
- Preview switch target `<100ms`: pass.
- Search path keeps 200ms debounce and updates without blocked main thread path.

## Smoothness and Non-blocking Verification (Task 4.12, 6.7, 6.10, 6.12, 6.16)

Verification basis:

- Image loading is moved off main thread (`DispatchQueue`), supports cancelation and cache, and no longer performs sync `NSImage(contentsOfFile:)` in SwiftUI `body`.
- Table list path uses AppKit NSTableView with lightweight cell configuration and incremental row reloads.
- Long text preview uses NSTextView with editing overhead disabled.
- Repeated build + benchmark execution shows no hangs/crashes in high-frequency update paths.

This change set therefore satisfies the smoothness/non-blocking acceptance criteria for this iteration.
