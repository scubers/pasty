# Spec: Main Panel Paste Integration

与其他应用的粘贴集成，发送模拟 Cmd+V 操作。

## ADDED Requirements

### Requirement: Copy selected item to clipboard
系统 SHALL 能够将选中的历史记录内容复制到系统剪贴板。

#### Scenario: Copy text to clipboard
- **WHEN** 用户触发复制操作（Enter 或 Cmd+Enter）
- **AND** 选中项是文本类型
- **THEN** 系统将文本内容写入 `NSPasteboard.general`
- **AND** 内容在剪贴板中可用

#### Scenario: Copy image to clipboard
- **WHEN** 用户触发复制操作（Enter 或 Cmd+Enter）
- **AND** 选中项是图片类型
- **THEN** 系统将图片数据写入 `NSPasteboard.general`
- **AND** 内容在剪贴板中可用

---

### Requirement: Send Cmd+V to previous application
系统 SHALL 在关闭面板后向上一个应用程序发送 `Cmd+V` 模拟粘贴操作。

#### Scenario: Send paste command to external app
- **WHEN** 用户按下 Enter
- **AND** 有选中项
- **AND** 上一个应用程序不是本应用
- **THEN** 系统将选中项复制到剪贴板
- **AND** 关闭面板
- **AND** 激活上一个应用程序
- **AND** 使用 `CGEvent` 发送 `Cmd+V` 模拟粘贴

#### Scenario: Skip paste command to self
- **WHEN** 用户按下 Enter
- **AND** 有选中项
- **AND** 上一个应用程序是本应用
- **THEN** 系统将选中项复制到剪贴板
- **AND** 关闭面板
- **AND** 不发送 `Cmd+V` 模拟粘贴

---

### Requirement: Track frontmost application before showing panel
系统 SHALL 在显示面板前记录当前前台应用程序。

#### Scenario: Track external app as frontmost
- **WHEN** 面板显示前的前台应用程序不是本应用
- **THEN** 系统记录该应用程序
- **AND** 用于后续恢复焦点和发送粘贴命令

#### Scenario: Track self as frontmost
- **WHEN** 面板显示前的前台应用程序是本应用
- **THEN** 系统记录本应用
- **AND** 后续不会发送粘贴命令

#### Scenario: No frontmost app tracking when already tracking
- **WHEN** 面板已在前台应用为 X 时显示
- **AND** 再次显示面板（切换显示/隐藏）
- **THEN** 系统更新记录为新的前台应用
- **AND** 确保使用最新记录

---

### Requirement: Use CGEvent for keyboard simulation
系统 SHALL 使用 `CGEvent` API 发送模拟键盘事件。

#### Scenario: Send Cmd+V key combination
- **WHEN** 系统需要发送粘贴命令
- **THEN** 系统创建 `Cmd+V` 的 key down 事件
- **AND** 创建 `Cmd+V` 的 key up 事件
- **AND** 使用 `CGEvent.post()` 发送到系统事件流
- **AND** 确保事件按正确的顺序和间隔发送

#### Scenario: Use correct event flags for Cmd key
- **WHEN** 创建键盘事件
- **THEN** 系统设置正确的 flags（`.maskCommand`）
- **AND** 确保 Cmd 键状态正确

---

### Requirement: Handle paste command failures gracefully
系统 SHALL 在模拟粘贴失败时优雅处理，不中断用户流程。

#### Scenario: Paste command ignored by target app
- **WHEN** 目标应用忽略粘贴命令
- **THEN** 系统不显示错误提示
- **AND** 记录错误日志
- **AND** 用户仍可手动粘贴（内容已在剪贴板）

#### Scenario: Paste command simulation error
- **WHEN** `CGEvent` 发送失败（如权限问题）
- **THEN** 系统不显示错误提示
- **AND** 记录错误日志
- **AND** 用户仍可手动粘贴（内容已在剪贴板）

---

### Requirement: Ensure clipboard content before sending paste
系统 SHALL 在发送粘贴命令前确保剪贴板中已有正确内容。

#### Scenario: Verify clipboard content
- **WHEN** 系统准备发送粘贴命令
- **THEN** 系统先执行复制操作
- **AND** 确保剪贴板包含选中项的内容
- **AND** 然后发送 `Cmd+V` 命令

#### Scenario: Copy failure prevents paste
- **WHEN** 复制到剪贴板失败
- **THEN** 系统不发送粘贴命令
- **AND** 记录错误日志
- **AND** 面板保持显示状态
