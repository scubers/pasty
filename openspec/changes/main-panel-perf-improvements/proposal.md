## Why

主面板的性能和用户体验问题阻碍了正常使用。点击包含超长字符串的 item 会导致 UI 冻结约 2 秒，原因是核心层与平台层之间的 JSON 序列化效率低下。此外，列表在剪贴板内容变化后不会自动更新，ESC 键无法切换面板显示（虽然 FooterView 显示了 "Esc to close"），且主面板有不必要的交通灯窗口控制按钮。

## What Changes

- **性能优化**：移除点击 item 时的冗余 JSON 序列化。核心层目前对所有搜索结果返回完整的 JSON 载荷，导致大内容时 UI 冻结。实现更高效的数据传输方式（例如，直接的 C++ 到 Swift 桥接，避免 JSON 往返）。
- **列表自动刷新**：在剪贴板内容成功持久化后触发列表更新。ClipboardWatcher 目前缺少 onChange 回调来通知 UI。
- **ESC 键切换**：实现 ESC 键处理器，在面板显示时切换面板可见性。FooterView 显示 "Esc to close" 但此功能缺失。
- **移除交通灯**：从主面板窗口中移除关闭/最小化/最大化按钮（交通灯）。面板应仅通过热键或 ESC 切换。

## Capabilities

### New Capabilities
- `main-panel-perf`：优化主面板性能，支持长字符串内容显示
- `clipboard-change-list-sync`：剪贴板持久化后自动更新列表
- `panel-keyboard-controls`：键盘事件处理，用于面板可见性控制（ESC）
- `panel-window-styling`：简洁的面板外观，无标准窗口控制按钮

### Modified Capabilities
- 无（现有能力的规范级别需求无变更）

## Impact

**受影响的代码**：
- `platform/macos/Sources/Utils/ClipboardHistoryServiceImpl.swift` - 移除 JSON 序列化瓶颈
- `platform/macos/Sources/Utils/ClipboardWatcher.swift` - 添加 onChange 回调机制
- `platform/macos/Sources/App.swift` - 绑定剪贴板监视器到列表刷新，添加 ESC 键处理器
- `platform/macos/Sources/View/MainPanelWindowController.swift` - 从 styleMask 移除交通灯
- `platform/macos/Sources/View/MainPanelView.swift` - 添加键盘事件处理
- `platform/macos/Sources/ViewModel/MainPanelViewModel.swift` - 添加剪贴板变化刷新的操作

**受影响的 API**：
- 核心层：可能需要新的 C API 用于高效数据传输（非 JSON 路径）
- 平台层：ClipboardWatcher onChange 回调接口

**依赖关系**：
- 无新的第三方依赖

**系统**：
- 主面板 UI 响应性
- 剪贴板变化检测和 UI 同步
- 窗口生命周期和键盘事件处理
