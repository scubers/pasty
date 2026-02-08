# Design: Main Panel Control

## Context

### Current State
主面板（Main Panel）已具备基础展示功能：
- `MainPanelWindowController`: NSPanel 窗口，支持基本的 `show(at:)` / `hide()` 操作
- `MainPanelViewModel`: Redux 风格的状态管理（State + Action 模式）
- `MainPanelView`: SwiftUI 布局，包含搜索框、列表、预览区
- `MainPanelSearchBar`: 搜索框，使用 @FocusState
- `MainPanelItemTableView`: NSTableView 列表，已支持 Home/End/Page Up/Page Down
- `App.swift`: 应用主入口，已有 ESC 键监听和全局快捷键（cmd+shift+v）

### Missing Capabilities
缺少完整的用户交互逻辑：
- ❌ 窗口位置记忆（仅内存，不持久化）
- ❌ 点击外部关闭
- ❌ 焦点管理（切换应用焦点、搜索框焦点保持）
- ❌ 面板级键盘事件处理（上下箭头轮转选择、Enter/Cmd+Enter/Cmd+D 快捷键）
- ❌ 删除确认对话框
- ❌ 与其他应用的粘贴集成（发送模拟 Cmd+V）
- ❌ 列表更新后的默认选中逻辑

### Constraints
1. **Core 层不可修改**：所有 UI 和系统集成逻辑必须在 macOS 平台层实现
2. **Core 可移植性**：不能在 Core 中引入平台特定代码
3. **已有 Core API**：`pasty_history_delete` 已可用，无需新增接口
4. **单向依赖**：Platform → Core，禁止反向依赖
5. **最小变更**：优先选择能通过编译/测试的最小变更

### Stakeholders
- **终端用户**：需要流畅的剪贴板历史管理体验
- **开发者**：需要清晰的架构分层，易于维护和扩展

---

## Goals / Non-Goals

### Goals
1. **完整的面板交互**：实现所有用户需求的交互逻辑（展示/关闭/位置记忆/焦点管理）
2. **键盘优先操作**：提供完整的键盘快捷键支持，保持搜索框可输入状态
3. **智能位置管理**：同一屏幕记住拖动位置（仅内存），切换屏幕使用默认位置
4. **安全的删除操作**：二次确认删除，防止误操作
5. **无缝粘贴集成**：关闭面板后自动粘贴到上一个应用（若非本应用）
6. **架构清晰**：保持清晰的分层，逻辑集中在 ViewModel 和 Service

### Non-Goals
1. **持久化位置记忆**：窗口位置仅在内存中记录，重启后重置为默认位置
2. **Core 层变更**：不修改 C++ Core 层的业务逻辑或数据模型
3. **其他平台实现**：本次仅实现 macOS 平台层，不涉及 Windows/iOS/Android
4. **历史窗口改进**：不修改现有的 `HistoryViewController`，专注主面板
5. **多语言支持**：不考虑本地化，使用中文界面
6. **高级搜索功能**：保持现有搜索功能，不新增复杂搜索逻辑

---

## Decisions

### D1: 状态管理架构（Redux 模式）

**决策**: 扩展现有的 Redux 风格 `MainPanelViewModel`，添加新的状态字段和 Action

**理由**:
- 现有代码已采用 State + Action 模式，保持一致性
- 单一数据源，避免状态分散在多个组件
- 易于测试和调试
- 适合复杂的交互逻辑（键盘事件、列表选择、焦点管理）

**新增状态字段**:
```swift
struct State {
    // 现有字段...
    var selectionIndex: Int?                    // 当前选中索引
    var pendingDeleteItem: ClipboardItemRow?       // 待删除的项（确认对话框使用）
    var previousFrontmostApp: NSRunningApplication? // 上一个前台应用
    var shouldFocusSearch: Bool = false           // 搜索框焦点请求信号
}
```

**新增 Action**:
```swift
enum Action {
    // 现有 actions...
    case panelShown
    case panelHidden
    case moveSelectionUp
    case moveSelectionDown
    case selectFirstIfNeeded
    case deleteSelectedConfirmed
    case copySelected
    case pasteSelectedAndClose
    case prepareDeleteSelected
    case cancelDelete
}
```

**替代方案**:
- **SwiftUI @StateObject 分散在各个 View**: ❌ 状态分散，难以协调复杂交互
- **Coordinator 模式**: ❌ 引入额外抽象层，增加复杂度

---

### D2: 窗口位置记忆策略（仅内存）

**决策**: 在 `MainPanelWindowController` 中维护内存状态，不持久化到磁盘

**理由**:
- 用户需求明确："位置只记录内存，重启后会重置为默认位置"
- 简化实现，无需处理偏好存储
- 减少故障点（磁盘损坏、迁移等问题）
- 重启后恢复默认位置符合用户预期

**实现**:
```swift
final class MainPanelWindowController: NSWindowController {
    private var lastShownScreenID: String?       // 上次显示的屏幕 ID
    private var lastFrameOrigin: NSPoint?          // 上次窗口位置

    func show(at point: NSPoint) {
        let currentScreen = NSScreen.screens.first(where: { $0.frame.contains(point) })
        let currentScreenID = currentScreen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? String

        if currentScreenID == lastShownScreenID, let lastOrigin = lastFrameOrigin {
            panel.setFrameOrigin(lastOrigin)
        } else {
            // 使用当前屏幕的默认位置
            let defaultPosition = calculateDefaultPosition(screen: currentScreen)
            panel.setFrameOrigin(defaultPosition)
        }
    }
}
```

**替代方案**:
- **持久化位置（UserDefaults）**: ❌ 与用户需求冲突，重启后会恢复上次位置

---

### D3: 键盘事件监听层级（面板级）

**决策**: 在 `MainPanelWindow`（NSPanel 子类）中拦截 `keyDown`，而非在 App 层全局监听

**理由**:
- 面板可见时才响应快捷键，避免误触发
- 其他 modal/panel 打开时自动失效（keyWindow 机制）
- 符合 macOS UI 规范（窗口级键盘事件）
- 逻辑封装在窗口控制器，不污染 App.swift

**实现**:
```swift
private final class MainPanelWindow: NSPanel {
    var onKeyPress: ((NSEvent) -> Void)?

    override func keyDown(with event: NSEvent) {
        onKeyPress?(event)
        // 不调用 super，阻止默认行为
    }
}

// 在 MainPanelWindowController 中
panel.onKeyPress = { [weak self] event in
    self?.handleKeyPress(event)
}
```

**替代方案**:
- **App 层全局监听（NSEvent.addLocalMonitor）**: ❌ 难以判断面板是否为 keyWindow，可能误触发
- **SwiftView 的 .onReceive + Publisher**: ❌ SwiftUI 的键盘事件处理有限，不完整

---

### D4: 搜索框焦点保持机制

**决策**: 使用 `@FocusState` 配合信号机制，快捷键操作后主动恢复焦点

**理由**:
- SwiftUI 官方推荐的方式
- 声明式，符合 SwiftUI 设计理念
- 避免强制 firstResponder（不推荐）

**实现**:
```swift
struct MainPanelSearchBar: View {
    @Binding var text: String
    @FocusState private var focused: Bool
    @Binding var focusRequest: Bool  // 外部信号

    var body: some View {
        TextField(...)
            .focused($focused)
            .onChange(of: focusRequest) { _, _ in
                focused = true  // 恢复焦点
            }
    }
}

// 在 ViewModel 中
struct State {
    var shouldFocusSearch: Bool = false  // 每次设置为 true 都会触发焦点恢复
}
```

**替代方案**:
- **强制 firstResponder（window?.makeFirstResponder）**: ❌ 命令式风格，不符合 SwiftUI

---

### D5: 点击外部关闭（Global Monitor）

**决策**: 使用 `NSEvent.addGlobalMonitorForEvents(.mouseDown)` 监听全局鼠标事件

**理由**:
- 需要检测面板外部的点击（包括点击其他应用窗口）
- Global Monitor 能捕获所有应用的鼠标事件
- 在 `App.swift` 中管理生命周期，避免内存泄漏

**实现**:
```swift
@MainActor
class App {
    private var mouseDownMonitor: Any?

    func setupOutsideClickMonitor() {
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(.mouseDown) { [weak self] event in
            guard let self,
                  self.viewModel.state.isVisible,
                  let window = self.windowController.window else {
                return
            }

            let clickPoint = event.locationInWindow
            let windowFrame = window.frame

            if !windowFrame.contains(clickPoint) {
                self.viewModel.send(.hidePanel)
            }
        }
    }
}
```

**替代方案**:
- **Local Monitor（仅当前应用）**: ❌ 无法检测点击其他应用窗口

---

### D6: 删除确认对话框（Sheet）

**决策**: 使用 `NSAlert` 作为 Sheet 挂载在主 Panel 上

**理由**:
- Sheet 自动保证层级高于父窗口
- macOS 标准的二次确认模式
- 系统级样式，无需自定义 UI

**实现**:
```swift
func showDeleteConfirmation() {
    guard let item = state.pendingDeleteItem else { return }

    let alert = NSAlert()
    alert.messageText = "删除历史记录"
    alert.informativeText = "确定要删除这条记录吗？此操作无法撤销。"
    alert.alertStyle = .warning
    alert.addButton(withTitle: "删除")
    alert.addButton(withTitle: "取消")

    guard let window = windowController.window else { return }
    alert.beginSheetModal(for: window) { response in
        if response == .alertFirstButtonReturn {
            viewModel.send(.deleteSelectedConfirmed)
        } else {
            viewModel.send(.cancelDelete)
        }
    }
}
```

**替代方案**:
- **自定义 SwiftUI Sheet**: ❌ 需要额外的状态管理，增加复杂度
- **独立模态窗口**: ❌ 层级控制复杂，可能被主面板遮挡

---

### D7: 焦点恢复（追踪上一个应用）

**决策**: 在面板展示前记录 `NSWorkspace.shared.frontmostApplication`，关闭时恢复

**理由**:
- 需要切换回上一个应用，以便粘贴内容
- 使用系统 API 确保准确性
- 排除本应用，避免死循环

**实现**:
```swift
@MainActor
class App {
    private var previousFrontmostApp: NSRunningApplication?

    private func showPanel() {
        previousFrontmostApp = NSWorkspace.shared.frontmostApplication
        // ... 展示面板
    }

    private func hidePanel() {
        windowController.hide()
        viewModel.send(.panelHidden)

        // 恢复上一个应用（排除本应用）
        if let previousApp = previousFrontmostApp,
           previousApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp.activate()
        }
    }
}
```

**替代方案**:
- **仅记录应用 Bundle ID**: ❌ 无法激活应用

---

### D8: 发送模拟键盘事件（CGEvent）

**决策**: 使用 `CGEvent` 发送 Cmd+V 模拟粘贴操作

**理由**:
- 系统级 API，能发送到任何应用
- 不依赖应用自身的粘贴接口
- 与用户手动粘贴行为一致

**实现**:
```swift
func sendPasteCommand() {
    guard let previousApp = previousFrontmostApp,
          previousApp.bundleIdentifier != Bundle.main.bundleIdentifier else {
        return
    }

    // 发送 Cmd+V
    let source = CGEventSource(stateID: .combinedSessionState)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false)

    keyDown?.flags = .maskCommand
    keyUp?.flags = .maskCommand

    keyDown?.post(tap: .cgSessionEventTap)
    keyUp?.post(tap: .cgSessionEventTap)
}
```

**替代方案**:
- **NSPasteboard 直接写入**: ❌ 只是复制到剪贴板，不触发粘贴操作
- **AppleScript**: ❌ 性能差，兼容性问题

---

### D9: 平台交互服务封装（Service Layer）

**决策**: 新增 `MainPanelInteractionService` 封装平台特定的交互能力

**理由**:
- 分离平台逻辑和业务逻辑
- 提高可测试性（可以 mock）
- 保持 `App.swift` 简洁
- 便于未来扩展（如添加新的平台交互）

**职责**:
```swift
protocol MainPanelInteractionService {
    func trackAndRestoreFrontmostApplication() -> FrontmostAppTracker
    func copyToPasteboard(_ content: String) // 或 Image
    func sendPasteCommand()
    var outsideClickMonitor: AnyPublisher<Bool, Never> { get }
}

final class MainPanelInteractionServiceImpl: MainPanelInteractionService {
    // 实现...
}
```

**替代方案**:
- **所有逻辑直接放在 App.swift**: ❌ 违反单一职责原则，难以测试和维护

---

## File Structure

### 新增文件

```
platform/macos/Sources/Utils/
├── MainPanelInteractionService.swift      # 平台交互服务（必需）
└── MainPanelKeyCommand.swift               # 键盘命令解析器（可选，用于降低 App.swift 复杂度）
```

**MainPanelInteractionService.swift**：
- 封装平台特定的交互能力
- 职责：
  - 追踪并恢复前台应用（FrontmostAppTracker）
  - 复制内容到剪贴板（文本/图片）
  - 发送模拟键盘事件（Cmd+V）
  - 监听全局鼠标事件（点击外部关闭）

**MainPanelKeyCommand.swift**（可选）：
- 将 keyCode + modifiers 解析为语义命令
- 降低 App.swift 的复杂度
- 示例：
  ```swift
  enum KeyCommand {
      case arrowUp
      case arrowDown
      case enter
      case commandEnter
      case commandD
  }
  ```

---

### 修改的文件

```
platform/macos/Sources/
├── ViewModel/
│   └── MainPanelViewModel.swift          # 扩展 State 和 Action，添加交互逻辑
├── Utils/
│   ├── ClipboardHistoryService.swift      # 添加 delete(id:) 接口
│   └── ClipboardHistoryServiceImpl.swift  # 实现 delete(id:)，桥接 Core API
├── View/
│   ├── MainPanelWindowController.swift   # 添加位置记忆、窗口移动监听
│   ├── MainPanelView.swift              # 集成新的交互能力
│   └── MainPanel/
│       ├── MainPanelSearchBar.swift      # 添加焦点请求信号
│       └── AppKit/
│           └── MainPanelItemTableView.swift  # 补充程序化选择 API（可选）
└── App.swift                             # 平台事件监听、焦点管理、删除确认
```

### 目录结构总览（变更后）

```
platform/macos/Sources/
├── ViewModel/
│   └── MainPanelViewModel.swift          [修改] 扩展状态机和 Action
├── Utils/
│   ├── ClipboardHistoryService.swift      [修改] 添加删除接口
│   ├── ClipboardHistoryServiceImpl.swift  [修改] 实现删除接口
│   ├── ClipboardWatcher.swift
│   ├── HotkeyService.swift
│   ├── HotkeyServiceImpl.swift
│   ├── CombineExtensions.swift
│   ├── AppPaths.swift
│   ├── MainPanelInteractionService.swift  [新增] 平台交互服务
│   └── MainPanelKeyCommand.swift         [新增] 键盘命令解析（可选）
├── View/
│   ├── MainPanelWindowController.swift   [修改] 位置记忆、窗口移动监听
│   ├── MainPanelView.swift              [修改] 集成新的交互能力
│   ├── MainPanel/
│   │   ├── MainPanelContent.swift
│   │   ├── MainPanelSearchBar.swift      [修改] 添加焦点请求信号
│   │   ├── MainPanelPreviewPanel.swift
│   │   ├── MainPanelTokens.swift
│   │   ├── MainPanelMaterials.swift
│   │   ├── MainPanelFooterView.swift
│   │   ├── MainPanelImageLoader.swift
│   │   ├── MainPanelLongTextRepresentable.swift
│   │   ├── MainPanelLongTextView.swift
│   │   └── AppKit/
│   │       ├── MainPanelItemTableView.swift       [修改] 补充程序化选择 API
│   │       ├── MainPanelItemTableCellView.swift
│   │       └── MainPanelItemTableRepresentable.swift
│   ├── HistoryWindowController.swift
│   └── HistoryViewController.swift
├── Model/
│   ├── ClipboardItemRow.swift
│   ├── ClipboardSourceAttribution.swift
│   └── HistoryItemViewModel.swift
└── App.swift                             [修改] 平台事件监听、焦点管理、删除确认
```

### 文件变更说明

| 文件 | 类型 | 主要变更 |
|------|------|---------|
| `MainPanelInteractionService.swift` | 新增 | 封装平台交互能力（焦点追踪、复制粘贴、外部点击监听） |
| `MainPanelKeyCommand.swift` | 新增（可选） | 键盘命令解析器，降低 App.swift 复杂度 |
| `MainPanelViewModel.swift` | 修改 | 添加新状态字段（selectionIndex、pendingDeleteItem、previousFrontmostApp、shouldFocusSearch）和新 Action |
| `ClipboardHistoryService.swift` | 修改 | 添加 `delete(id:) -> AnyPublisher<Void, Error>` 接口 |
| `ClipboardHistoryServiceImpl.swift` | 修改 | 实现 `delete(id:)`，桥接 `pasty_history_delete` Core API |
| `MainPanelWindowController.swift` | 修改 | 添加位置记忆（lastShownScreenID、lastFrameOrigin）、窗口移动监听、默认位置计算 |
| `MainPanelView.swift` | 修改 | 集成 `shouldFocusSearch` 绑定到搜索框 |
| `MainPanelSearchBar.swift` | 修改 | 添加 `@Binding var focusRequest: Bool` 参数和 `onChange` 监听器 |
| `MainPanelItemTableView.swift` | 修改（可选） | 补充程序化选择 API，确保选中项可见 |
| `App.swift` | 修改 | 添加平台事件监听（鼠标、键盘）、焦点管理、删除确认对话框 |

---

## Risks / Trade-offs

### R1: 焦点管理复杂性
**风险**: 多层级焦点管理（搜索框、列表、预览区、其他应用）可能导致焦点混乱或丢失

**缓解措施**:
- 使用明确的焦点信号机制（`shouldFocusSearch`）
- 所有键盘操作后统一恢复搜索框焦点
- 充分测试边界场景（modal 打开、外部面板显示等）

---

### R2: 多显示器位置计算
**风险**: 窗口位置在多显示器环境下可能越界或显示在错误屏幕

**缓解措施**:
- 使用 NSScreen 的 API 获取正确的屏幕
- 添加边界检查，确保窗口在屏幕范围内
- 测试多显示器热插拔场景

---

### R3: 键盘事件冲突
**风险**: 全局快捷键（cmd+shift+v）可能与系统或其他应用冲突

**缓解措施**:
- 使用 `KeyboardShortcuts` 库（已集成），自动处理冲突
- 在面板可见时禁用全局快捷键（已由 keyWindow 机制保证）

---

### R4: 模拟粘贴失败
**风险**: `CGEvent` 发送 Cmd+V 可能被某些应用忽略（如某些安全应用）

**缓解措施**:
- 在粘贴前先复制内容到剪贴板（确保至少有内容）
- 如果上一个应用是本应用，跳过发送 Cmd+V
- 记录错误日志，但不中断用户流程

---

### R5: 外部点击监听性能
**风险**: Global Monitor 可能频繁触发，影响性能

**缓解措施**:
- 仅在面板可见时监听
- 关闭面板时移除监听器
- 使用 `weak self` 避免内存泄漏

---

### R6: 删除后的列表更新时序
**风险**: 删除后列表刷新和选中重选可能出现竞态条件

**缓解措施**:
- 使用 Combine 的 `sink` 确保顺序执行
- 删除前记录选中索引，删除后基于索引选择（而非 ID）
- 添加 loading 状态，防止重复操作

---

## Migration Plan

### 部署步骤
1. **阶段 1**: 扩展 Service 和 ViewModel（无 UI 变更）
   - 添加 `MainPanelInteractionService`
   - 扩展 `ClipboardHistoryService` 删除接口
   - 扩展 `MainPanelViewModel` 状态和 Action

2. **阶段 2**: 窗口行为（独立功能）
   - 实现窗口位置记忆
   - 实现点击外部关闭
   - 实现焦点恢复

3. **阶段 3**: 键盘交互（独立功能）
   - 实现面板级键盘监听
   - 实现快捷键映射
   - 实现搜索框焦点保持

4. **阶段 4**: 删除集成（独立功能）
   - 实现删除确认对话框
   - 实现删除后重选逻辑

5. **阶段 5**: 粘贴集成（独立功能）
   - 实现复制到剪贴板
   - 实现发送 Cmd+V
   - 整合 Enter 键逻辑

### 回滚策略
- 所有变更集中在 macOS 平台层，不影响 Core 层
- 每个阶段独立提交，可按阶段回滚
- 使用 `git revert` 回滚特定 commit
- 保留原有 ESC 键监听，确保基本功能可用

---

## Open Questions

### Q1: 删除确认对话框样式
**问题**: 使用标准的 `NSAlert.warning` 还是自定义样式？

**建议**: 使用标准 `NSAlert.warning`，理由：
  - 符合 macOS 设计规范
  - 无需额外开发成本
  - 用户熟悉的标准交互

---

### Q2: 窗口默认位置策略
**问题**: 屏幕中心偏上 100px 是最佳默认位置吗？

**建议**: 使用屏幕中心（用户可以后续拖动调整），理由：
  - 简化逻辑
  - 避免某些屏幕尺寸下的边界问题
  - 用户可自由调整

---

### Q3: 列表选择滚动策略
**问题**: 程序化选中时如何确保可见？（scrollToRow 是否足够？）

**建议**: 复用 `MainPanelItemTableView.selectCurrentRowIfNeeded()`，理由：
  - 已实现 `scrollRowToVisible`
  - 统一选中逻辑入口
  - 避免重复代码

---

### Q4: 粘贴板历史变更时的选择行为
**问题**: 用户复制新内容后，列表更新时是否始终选中第一条？

**建议**: 是，始终选中第一条，理由：
  - 用户最可能操作最新内容
  - 行为一致，易于理解
  - 便于快速访问最新记录

---

### Q5: 空列表时的快捷键行为
**问题**: 空列表时 Enter/Cmd+Enter/Cmd+D 应该静默失败还是显示提示？

**建议**: 静默失败，理由：
  - 减少视觉噪音
  - 符合 macOS UI 规范（禁用状态通常不显示错误）
  - 避免打断用户流程
