# Tasks: Main Panel Control

实现任务清单，按依赖关系分组。

## 1. Service Layer Extensions

- [x] 1.1 扩展 `ClipboardHistoryService` 协议，添加 `delete(id:) -> AnyPublisher<Void, Error>` 接口
- [x] 1.2 在 `ClipboardHistoryServiceImpl` 中实现 `delete(id:)` 方法，桥接 `pasty_history_delete` API
- [x] 1.3 创建 `MainPanelInteractionService` 协议，定义平台交互能力（焦点追踪、复制粘贴、外部点击监听）
- [x] 1.4 实现 `MainPanelInteractionServiceImpl`，包含 `FrontmostAppTracker`、复制到剪贴板、发送 Cmd+V、外部点击监听功能
- [x] 1.5 为 `MainPanelInteractionService` 添加 `outsideClickMonitor` Publisher，用于检测面板外点击

## 2. ViewModel State Machine

- [x] 2.1 在 `MainPanelViewModel.State` 中添加新字段：`selectionIndex`、`pendingDeleteItem`、`previousFrontmostApp`、`shouldFocusSearch`
- [x] 2.2 在 `MainPanelViewModel.Action` 中添加新 Action：`panelShown`、`panelHidden`、`moveSelectionUp`、`moveSelectionDown`、`selectFirstIfNeeded`、`deleteSelectedConfirmed`、`copySelected`、`pasteSelectedAndClose`、`prepareDeleteSelected`、`cancelDelete`
- [x] 2.3 实现 `send(_:)` 方法中的新 Action 处理逻辑
- [x] 2.4 实现轮转选择逻辑（上下箭头首尾环形）
- [x] 2.5 实现删除后自动选中规则（优先下一条，无下条选上一条）
- [x] 2.6 实现 `shouldFocusSearch` 信号机制，确保快捷键后恢复搜索框焦点

## 3. Window Behavior

- [x] 3.1 在 `MainPanelWindowController` 中添加内存位置记忆字段：`lastShownScreenID`、`lastFrameOrigin`
- [x] 3.2 修改 `show(at:)` 方法，实现同屏恢复位置、不同屏使用默认位置逻辑
- [x] 3.3 实现 `calculateDefaultPosition(screen:)` 方法，计算屏幕默认位置（中心偏上 100px）
- [x] 3.4 添加窗口移动边界检查，确保窗口位置在屏幕范围内
- [x] 3.5 监听 `NSWindowDelegate.windowDidMove`，实时更新 `lastFrameOrigin`
- [x] 3.6 在 `MainPanelWindow` 中添加 `windowDidMove` 回调机制

## 4. Focus Management

- [x] 4.1 在 `App.swift` 中添加 `previousFrontmostApp` 追踪逻辑
- [x] 4.2 在 `showPanel()` 方法中记录 `NSWorkspace.shared.frontmostApplication`
- [x] 4.3 在 `hidePanel()` 方法中实现焦点恢复逻辑（排除本应用）
- [x] 4.4 修改 `MainPanelSearchBar`，添加 `@Binding var focusRequest: Bool` 参数
- [x] 4.5 在 `MainPanelSearchBar` 中实现 `onChange(of: focusRequest)` 监听器，触发 `focused = true`
- [x] 4.6 在 `MainPanelView` 中传递 `viewModel.$state.shouldFocusSearch` 绑定到搜索框
- [x] 4.7 确保所有快捷键操作后都设置 `shouldFocusSearch = true`（通过 ViewModel Action）

## 5. Keyboard Event Handling

- [x] 5.1 在 `MainPanelWindow` 类中添加 `var onKeyPress: ((NSEvent) -> Void)?` 回调属性
- [x] 5.2 重写 `MainPanelWindow.keyDown(with:)` 方法，拦截键盘事件并调用 `onKeyPress`
- [x] 5.3 在 `MainPanelWindowController` 中实现 `handleKeyPress(_:)` 方法，分发键盘事件
- [x] 5.4 实现上下箭头键映射，调用 ViewModel 的 `moveSelectionUp/Down` Action
- [x] 5.5 实现 Enter 键映射，调用 ViewModel 的 `pasteSelectedAndClose` Action
- [x] 5.6 实现 Cmd+Enter 映射，调用 ViewModel 的 `copySelected` Action
- [x] 5.7 实现 Cmd+D 映射，调用 ViewModel 的 `prepareDeleteSelected` Action
- [x] 5.8 确保键盘事件仅在面板为 keyWindow 时生效

## 6. Outside Click Detection

- [x] 6.1 在 `App.swift` 中添加 `mouseDownMonitor` 属性
- [x] 6.2 实现 `setupOutsideClickMonitor()` 方法，使用 `NSEvent.addGlobalMonitorForEvents(.mouseDown)`
- [x] 6.3 实现点击区域检测逻辑，判断点击点是否在面板 frame 外
- [x] 6.4 面板外点击时触发 `viewModel.send(.hidePanel)`
- [x] 6.5 在 `applicationDidFinishLaunching` 中调用 `setupOutsideClickMonitor()`
- [x] 6.6 在 `applicationWillTerminate` 中移除 monitor

## 7. Delete Confirmation Dialog

- [x] 7.1 在 `App.swift` 中实现 `showDeleteConfirmation()` 方法
- [x] 7.2 创建 `NSAlert` 实例，设置警告样式和信息文本
- [x] 7.3 添加"删除"和"取消"按钮
- [x] 7.4 使用 `alert.beginSheetModal(for: window)` 显示 Sheet 挂载在主面板上
- [x] 7.5 实现 `response` 回调处理：确认时调用 `viewModel.send(.deleteSelectedConfirmed)`，取消时调用 `viewModel.send(.cancelDelete)`
- [x] 7.6 在 ViewModel 中处理 `prepareDeleteSelected`，设置 `state.pendingDeleteItem`
- [x] 7.7 在 ViewModel 中处理 `deleteSelectedConfirmed`，调用 Service 删除并刷新列表
- [x] 7.8 在 ViewModel 中处理 `cancelDelete`，清空 `state.pendingDeleteItem`

## 8. Copy and Paste Integration

- [x] 8.1 在 `MainPanelInteractionServiceImpl` 中实现 `copyToPasteboard(_ content: String)` 方法
- [x] 8.2 在 `MainPanelInteractionServiceImpl` 中实现 `copyToPasteboard(_ image: NSImage)` 方法
- [x] 8.3 在 `MainPanelInteractionServiceImpl` 中实现 `sendPasteCommand()` 方法，使用 `CGEvent` 发送 Cmd+V
- [x] 8.4 实现正确的 `CGEvent` flags 设置（`.maskCommand`）
- [x] 8.5 在 `App.swift` 中集成复制功能，根据 `ClipboardItemRow.type` 调用对应的复制方法
- [x] 8.6 在 `pasteSelectedAndClose` Action 中先复制到剪贴板，再关闭面板，最后发送粘贴命令
- [x] 8.7 实现粘贴命令失败时的优雅处理（记录日志，不显示错误）

## 9. List Selection Rules

- [x] 9.1 在 `panelShown` Action 后触发列表刷新，确保默认选中第一条
- [x] 9.2 修改 `refreshList()` 方法，刷新后调用 `selectFirstIfNeeded`
- [x] 9.3 实现 `selectFirstIfNeeded` Action，在列表非空时选中第一条
- [x] 9.4 修改 `MainPanelItemTableView`，确保 `selectCurrentRowIfNeeded()` 包含 `scrollRowToVisible`
- [x] 9.5 在删除后刷新列表时，基于删除前的索引选择下一条或上一条
- [x] 9.6 实现空列表处理逻辑，清除选中状态

## 10. Panel Show/Hide Integration

- [x] 10.1 修改 `showPanel()` 方法，调用 `interactionService.trackAndRestoreFrontmostApplication()`
- [x] 10.2 修改 `hidePanel()` 方法，调用 `interactionService.restoreFrontmostApplication()`
- [x] 10.3 在 `panelHidden` Action 中清空搜索框：`state.searchQuery = ""`
- [x] 10.4 在 `panelHidden` Action 后触发列表刷新，恢复默认状态
- [x] 10.5 确保 `showPanel` 和 `hidePanel` 都设置 `state.isVisible` 并触发相应的 `panelShown/panelHidden` Action

## 11. Focus Restoration on Close

- [x] 11.1 在 `hidePanel()` 方法中检查 `previousFrontmostApp`
- [x] 11.2 如果上一个应用不是本应用，调用 `previousFrontmostApp.activate()`
- [x] 11.3 如果上一个应用是本应用，跳过激活操作
- [x] 11.4 确保焦点恢复在面板关闭后执行

## 12. Testing and Validation

- [x] 12.1 运行 `./scripts/platform-build-macos.sh Debug`，确保编译成功
- [x] 12.2 手动测试：快捷键 `Cmd+Shift+V` 切换面板显示/隐藏
- [x] 12.3 手动测试：同一屏幕位置记忆（拖动后再次显示保持位置）
- [x] 12.4 手动测试：不同屏幕默认位置（切换屏幕后使用默认位置）
- [x] 12.5 手动测试：ESC 键关闭面板
- [x] 12.6 手动测试：点击面板外关闭面板
- [x] 12.7 手动测试：搜索框焦点（显示后自动获得，快捷键后保持）
- [x] 12.8 手动测试：上下箭头轮转选择（首尾环形）
- [x] 12.9 手动测试：Enter 复制+关闭+发送 Cmd+V
- [x] 12.10 手动测试：Cmd+Enter 仅复制不关闭
- [x] 12.11 手动测试：Cmd+D 删除确认对话框
- [x] 12.12 手动测试：删除后自动选中下一条/上一条
- [x] 12.13 手动测试：多显示器场景
- [x] 12.14 手动测试：空列表时的快捷键行为
- [x] 12.15 手动测试：其他 modal/panel 打开时主面板快捷键不生效
- [x] 12.16 边界测试：窗口位置边界检查
- [x] 12.17 回归测试：确保现有功能不受影响

## 13. Documentation and Cleanup

- [x] 13.1 添加代码注释，说明关键逻辑（位置记忆、焦点管理、键盘事件处理）
- [x] 13.2 更新 `AGENTS.md`（如有必要）
- [x] 13.3 确认所有 LSP 错误已修复（KeyboardShortcuts 和 SnapKit 模块缺失是正常的未构建状态）
- [x] 13.4 代码格式化和风格检查
- [x] 13.5 提交代码，使用清晰的 commit message
