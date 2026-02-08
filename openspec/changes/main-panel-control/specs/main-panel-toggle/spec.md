# Spec: Main Panel Toggle

主面板的显示/隐藏控制，包括位置记忆和快捷键触发。

## ADDED Requirements

### Requirement: Toggle main panel visibility with global hotkey
系统 SHALL 允许用户通过全局快捷键 `Cmd+Shift+V` 切换主面板的显示/隐藏状态。

#### Scenario: Show panel with hotkey
- **WHEN** 用户按下 `Cmd+Shift+V` 且面板当前隐藏
- **THEN** 系统显示主面板
- **AND** 面板显示在鼠标当前所在屏幕
- **AND** 面板在默认位置或上次记住的位置（取决于屏幕）

#### Scenario: Hide panel with hotkey
- **WHEN** 用户按下 `Cmd+Shift+V` 且面板当前可见
- **THEN** 系统隐藏主面板
- **AND** 清空搜索框内容
- **AND** 焦点返回上一个应用

---

### Requirement: Remember panel position in memory
系统 SHALL 在内存中记住面板在同一屏幕上的拖动位置，重启后重置为默认位置。

#### Scenario: Use remembered position on same screen
- **WHEN** 用户在同一屏幕上多次显示面板
- **AND** 上次显示时用户拖动了面板位置
- **THEN** 面板显示在上次拖动的位置
- **AND** 位置仅在内存中记录

#### Scenario: Reset position after restart
- **WHEN** 用户重启应用后首次显示面板
- **THEN** 面板显示在当前屏幕的默认位置
- **AND** 忽略重启前记住的位置

#### Scenario: Use default position on different screen
- **WHEN** 用户切换到不同屏幕后显示面板
- **THEN** 面板显示在新屏幕的默认位置
- **AND** 忽略其他屏幕上记住的位置

---

### Requirement: Close panel on outside click
系统 SHALL 在用户点击面板外部区域时关闭面板。

#### Scenario: Click outside panel
- **WHEN** 面板可见且用户点击面板外的任何区域（包括其他应用窗口）
- **THEN** 系统关闭面板
- **AND** 清空搜索框内容
- **AND** 焦点返回上一个应用

#### Scenario: Click inside panel
- **WHEN** 面板可见且用户点击面板内部区域
- **THEN** 面板保持显示状态
- **AND** 不关闭面板

---

### Requirement: Close panel with ESC key
系统 SHALL 允许用户通过 ESC 键关闭面板。

#### Scenario: Close panel with ESC
- **WHEN** 面板可见且用户按下 ESC 键
- **THEN** 系统关闭面板
- **AND** 清空搜索框内容
- **AND** 焦点返回上一个应用

#### Scenario: ESC key ignored when panel hidden
- **WHEN** 面板隐藏且用户按下 ESC 键
- **THEN** 系统忽略 ESC 键
- **AND** 不显示面板
