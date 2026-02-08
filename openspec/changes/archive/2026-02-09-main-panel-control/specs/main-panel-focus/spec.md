# Spec: Main Panel Focus

面板焦点管理，包括搜索框焦点和应用间焦点切换。

## ADDED Requirements

### Requirement: Auto-focus search field on panel show
系统 SHALL 在面板显示后自动将焦点设置到搜索框，使其可以立即输入。

#### Scenario: Focus search field after showing panel
- **WHEN** 面板显示
- **THEN** 搜索框获得焦点
- **AND** 用户可以立即输入搜索内容

---

### Requirement: Restore focus to previous app on panel hide
系统 SHALL 在面板隐藏时将焦点返回到上一个应用程序。

#### Scenario: Restore focus to external app
- **WHEN** 面板隐藏且上一个应用程序不是本应用
- **THEN** 系统激活上一个应用程序
- **AND** 焦点返回到该应用

#### Scenario: No focus restoration when previous app is self
- **WHEN** 面板隐藏且上一个应用程序是本应用
- **THEN** 系统不尝试恢复焦点
- **AND** 避免激活循环

---

### Requirement: Maintain search field focus after keyboard operations
系统 SHALL 在所有键盘快捷键操作后保持搜索框的焦点状态。

#### Scenario: Keep focus after navigation keys
- **WHEN** 用户使用上下箭头导航历史记录
- **THEN** 搜索框保持焦点
- **AND** 用户可以继续输入搜索内容

#### Scenario: Keep focus after Enter key
- **WHEN** 用户按下 Enter 复制并关闭面板
- **THEN** 搜索框保持焦点直到面板关闭
- **AND** 下次显示面板时搜索框获得焦点

#### Scenario: Keep focus after Cmd+Enter
- **WHEN** 用户按下 Cmd+Enter 复制选中项
- **THEN** 搜索框保持焦点
- **AND** 用户可以继续输入搜索内容

#### Scenario: Keep focus after delete confirmation
- **WHEN** 用户确认删除选中项
- **THEN** 搜索框保持焦点
- **AND** 用户可以继续输入搜索内容

---

### Requirement: Focus request signal mechanism
系统 SHALL 提供焦点请求信号机制，确保搜索框在需要时获得焦点。

#### Scenario: Focus request triggers focus restoration
- **WHEN** 系统发送焦点请求信号（shouldFocusSearch = true）
- **THEN** 搜索框获得焦点
- **AND** 光标显示在搜索框中

#### Scenario: Multiple focus requests
- **WHEN** 系统多次发送焦点请求信号
- **THEN** 每次都触发焦点恢复
- **AND** 确保搜索框始终有焦点
