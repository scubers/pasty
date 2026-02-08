# Spec: Main Panel Delete Confirm

删除确认对话框，二次确认删除操作。

## ADDED Requirements

### Requirement: Show confirmation dialog on delete request
系统 SHALL 在用户请求删除选中项时显示二次确认对话框。

#### Scenario: Show delete confirmation
- **WHEN** 用户按下 `Cmd+D` 或触发删除操作
- **AND** 有选中项
- **THEN** 系统显示删除确认对话框
- **AND** 对话框层级高于主面板
- **AND** 对话框显示警告信息和确认/取消按钮
- **AND** 主面板保持显示但不响应交互

---

### Requirement: Confirm delete operation
系统 SHALL 在用户确认后执行删除操作。

#### Scenario: User confirms delete
- **WHEN** 用户在确认对话框中点击"删除"按钮
- **THEN** 系统删除选中的历史记录
- **AND** 从 Core 层删除该记录
- **AND** 刷新历史记录列表
- **AND** 根据规则自动选中下一条或上一条记录
- **AND** 关闭确认对话框
- **AND** 搜索框保持焦点

---

### Requirement: Cancel delete operation
系统 SHALL 允许用户取消删除操作。

#### Scenario: User cancels delete
- **WHEN** 用户在确认对话框中点击"取消"按钮
- **OR** 用户按下 ESC 键
- **THEN** 系统不删除任何历史记录
- **AND** 关闭确认对话框
- **AND** 选中项保持不变
- **AND** 搜索框保持焦点

---

### Requirement: Use NSAlert sheet for confirmation
系统 SHALL 使用 `NSAlert` 作为 Sheet 挂载在主 Panel 上实现确认对话框。

#### Scenario: Sheet presentation
- **WHEN** 显示删除确认对话框
- **THEN** 对话框作为 Sheet 从主面板底部滑出
- **AND** 自动保证层级高于主面板
- **AND** 使用系统标准样式和动画

#### Scenario: Sheet dismissal
- **WHEN** 用户确认或取消删除
- **THEN** Sheet 以动画形式收起
- **AND** 主面板恢复交互状态

---

### Requirement: Prevent delete without selection
系统 SHALL 在没有选中项时阻止删除操作。

#### Scenario: Block delete without selection
- **WHEN** 用户按下 `Cmd+D`
- **AND** 没有选中项
- **THEN** 系统不显示确认对话框
- **AND** 不执行任何操作
- **AND** 保持当前状态

---

### Requirement: Handle delete during list update
系统 SHALL 在列表更新期间正确处理删除操作。

#### Scenario: Delete during loading
- **WHEN** 列表正在加载
- **AND** 用户尝试删除选中项
- **THEN** 系统显示确认对话框
- **AND** 确认后删除操作在后台执行
- **AND** 删除完成后刷新列表

#### Scenario: Delete with stale selection
- **WHEN** 选中项已在列表更新时被移除
- **AND** 用户尝试删除该选中项
- **THEN** 系统显示错误提示或忽略操作
- **AND** 不执行删除操作
