## ADDED Requirements

### Requirement: 剪贴板内容变化后自动刷新列表

剪贴板内容成功持久化后，主面板列表 SHALL 自动刷新以反映最新数据。

#### Scenario: 剪贴板内容变化并持久化

- **WHEN** ClipboardWatcher 检测到剪贴板变化
- **AND** 变化的内容被成功持久化到数据库
- **THEN** ClipboardWatcher SHALL 调用 onChange 回调（如果已配置）
- **THEN** onChange 回调 SHALL 触发列表刷新操作
- **THEN** 主面板列表 SHALL 显示最新的剪贴板历史

#### Scenario: 列表刷新机制

- **WHEN** ClipboardWatcher 的 onChange 回调被调用
- **THEN** MainPanelViewModel SHALL 接收到 `clipboardContentChanged` Action
- **THEN** ViewModel SHALL 触发 `performSearch` 刷新列表
- **THEN** 列表 SHALL 在 <100ms 内完成刷新
- **THEN** 用户 SHALL 无需手动刷新即可看到最新内容

#### Scenario: MVVM 架构一致性

- **WHEN** 剪贴板内容变化触发列表刷新
- **THEN** ClipboardWatcher（Service 层）SHALL 通过 onChange 回调通知 ViewModel
- **THEN** ViewModel SHALL 处理 Action 并更新 State
- **THEN** View SHALL 通过 Combine 订阅自动更新
- **THEN** 不违反 platform/macos/ARCHITECTURE.md 的分层职责

#### Scenario: 性能目标

- **WHEN** 列表自动刷新被触发
- **THEN** 刷新操作 SHALL 在 <100ms 内完成（constitution.md P2）
- **THEN** UI SHALL 保持响应，无卡顿或冻结
- **THEN** 内存使用 SHALL 保持在 <200MB/10K条目

### Requirement: ClipboardWatcher 回调接口

ClipboardWatcher SHALL 提供可选的 onChange 回调参数，用于通知剪贴板内容变化。

#### Scenario: 配置 onChange 回调

- **WHEN** App.swift 启动并配置 ClipboardWatcher
- **THEN** start 方法 SHALL 支持可选的 onChange 参数
- **THEN** onChange 参数类型 SHALL 为 `(() -> Void)?`
- **THEN** 回调 SHALL 在 captureCurrentClipboard 成功后调用

#### Scenario: 回调触发时机

- **WHEN** captureCurrentClipboard 成功捕获并持久化剪贴板内容
- **THEN** onChange 回调 SHALL 被调用
- **THEN** 回调 SHALL 仅在成功持久化后触发（不包括跳过的情况）
- **THEN** 回调 SHALL 提供成功/失败信息（可选）

#### Scenario: 回调可选性

- **WHEN** ClipboardWatcher 被使用但不需通知 UI
- **THEN** onChange 参数 SHALL 可为 nil
- **THEN** start 方法 SHALL 正常工作，无 onChange 回调
- **THEN** 保持向后兼容性，不影响现有使用方式

### Requirement: 防止滥用全局通知

系统 SHALL 使用 Coordinator 模式而非 NotificationCenter 进行剪贴板变化通知，遵循 platform/macos/ARCHITECTURE.md 约束。

#### Scenario: Coordinator 模式实现

- **WHEN** App.swift 组装应用依赖
- **THEN** ClipboardWatcher 的 onChange SHALL 直接绑定到 ViewModel Action
- **THEN** ViewModel SHALL 处理 Action 并更新 State
- **THEN** View 通过 Combine 订阅 State 变化自动更新
- **THEN** 不使用 NotificationCenter 进行全局通知

#### Scenario: 业务交互清晰性

- **WHEN** 剪贴板内容变化触发列表刷新
- **THEN** 数据流向 SHALL 清晰：ClipboardWatcher → ViewModel → View
- **THEN** 每个组件职责 SHALL 明确（Service → ViewModel → View）
- **THEN** 遵循 MVVM 架构模式

#### Scenario: 可测试性

- **WHEN** 单元测试 ClipboardWatcher 回调功能
- **THEN** onChange 回调 SHALL 可被模拟或 spy
- **THEN** 测试 SHALL 验证回调被正确触发
- **THEN** 测试 SHALL 验证回调参数正确性
