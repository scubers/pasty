# Spec: Main Panel Keyboard

面板级键盘事件处理，包括选择、复制、删除等快捷键。

## ADDED Requirements

### Requirement: Handle keyboard events at panel level
系统 SHALL 在面板可见时在面板层拦截并处理键盘事件。

#### Scenario: Process keyboard events when panel is key window
- **WHEN** 面板可见且是当前 key window
- **AND** 用户按下相关按键
- **THEN** 系统在面板层处理按键
- **AND** 执行相应的操作

#### Scenario: Ignore keyboard events when panel is not key window
- **WHEN** 面板可见但不是 key window（如其他 modal 打开）
- **AND** 用户按下相关按键
- **THEN** 系统忽略面板的键盘事件处理
- **AND** 按键由其他窗口处理

---

### Requirement: Navigate history items with arrow keys
系统 SHALL 允许用户使用上下箭头键轮转选择历史记录，支持首尾环形选择。

#### Scenario: Navigate up with arrow key
- **WHEN** 用户按下上箭头键
- **AND** 当前选中项不是第一条
- **THEN** 系统选中上一条历史记录
- **AND** 滚动列表确保选中项可见

#### Scenario: Navigate up wraps to last item
- **WHEN** 用户按下上箭头键
- **AND** 当前选中项是第一条
- **THEN** 系统选中最后一条历史记录
- **AND** 滚动列表确保选中项可见

#### Scenario: Navigate down with arrow key
- **WHEN** 用户按下下箭头键
- **AND** 当前选中项不是最后一条
- **THEN** 系统选中下一条历史记录
- **AND** 滚动列表确保选中项可见

#### Scenario: Navigate down wraps to first item
- **WHEN** 用户按下下箭头键
- **AND** 当前选中项是最后一条
- **THEN** 系统选中第一条历史记录
- **AND** 滚动列表确保选中项可见

#### Scenario: Navigate when list is empty
- **WHEN** 历史记录列表为空
- **AND** 用户按下上下箭头键
- **THEN** 系统忽略按键
- **AND** 不选中任何项

---

### Requirement: Copy selected item with Cmd+Enter
系统 SHALL 允许用户通过 `Cmd+Enter` 复制选中项到剪贴板，但不关闭面板。

#### Scenario: Copy selected item
- **WHEN** 用户按下 `Cmd+Enter`
- **AND** 有选中项
- **THEN** 系统将选中项的内容复制到系统剪贴板
- **AND** 面板保持显示
- **AND** 搜索框保持焦点

#### Scenario: Copy without selection
- **WHEN** 用户按下 `Cmd+Enter`
- **AND** 没有选中项
- **THEN** 系统忽略按键
- **AND** 不执行任何操作

---

### Requirement: Delete selected item with Cmd+D
系统 SHALL 允许用户通过 `Cmd+D` 删除选中项，需要二次确认。

#### Scenario: Initiate delete with Cmd+D
- **WHEN** 用户按下 `Cmd+D`
- **AND** 有选中项
- **THEN** 系统显示删除确认对话框
- **AND** 对话框层级高于主面板
- **AND** 搜索框保持焦点

#### Scenario: Confirm delete
- **WHEN** 用户在确认对话框中点击"删除"
- **THEN** 系统删除选中的历史记录
- **AND** 刷新历史记录列表
- **AND** 根据规则选中下一条或上一条记录
- **AND** 关闭确认对话框

#### Scenario: Cancel delete
- **WHEN** 用户在确认对话框中点击"取消"
- **THEN** 系统不删除历史记录
- **AND** 关闭确认对话框
- **AND** 选中项保持不变

#### Scenario: Delete without selection
- **WHEN** 用户按下 `Cmd+D`
- **AND** 没有选中项
- **THEN** 系统忽略按键
- **AND** 不显示确认对话框

---

### Requirement: Copy and paste with Enter key
系统 SHALL 允许用户通过 Enter 键复制选中项到剪贴板、关闭面板，并向上一个应用发送 `Cmd+V` 粘贴操作。

#### Scenario: Copy and paste to external app
- **WHEN** 用户按下 Enter
- **AND** 有选中项
- **AND** 上一个应用程序不是本应用
- **THEN** 系统将选中项的内容复制到系统剪贴板
- **AND** 关闭面板
- **AND** 将焦点返回上一个应用程序
- **AND** 向上一个应用程序发送 `Cmd+V` 模拟粘贴

#### Scenario: Copy without pasting to self
- **WHEN** 用户按下 Enter
- **AND** 有选中项
- **AND** 上一个应用程序是本应用
- **THEN** 系统将选中项的内容复制到系统剪贴板
- **AND** 关闭面板
- **AND** 不发送 `Cmd+V` 模拟粘贴

#### Scenario: Enter without selection
- **WHEN** 用户按下 Enter
- **AND** 没有选中项
- **THEN** 系统忽略按键
- **AND** 不执行任何操作

---

### Requirement: Preserve existing navigation keys
系统 SHALL 继续支持现有的 Home/End/Page Up/Page Down 导航键。

#### Scenario: Home key navigation
- **WHEN** 用户按下 Home 键
- **THEN** 系统选中第一条历史记录
- **AND** 滚动到列表顶部

#### Scenario: End key navigation
- **WHEN** 用户按下 End 键
- **THEN** 系统选中最后一条历史记录
- **AND** 滚动到列表底部

#### Scenario: Page Up navigation
- **WHEN** 用户按下 Page Up 键
- **THEN** 系统选中当前选中项上方约 10 条的位置
- **AND** 滚动列表确保选中项可见

#### Scenario: Page Down navigation
- **WHEN** 用户按下 Page Down 键
- **THEN** 系统选中当前选中项下方约 10 条的位置
- **AND** 滚动列表确保选中项可见
