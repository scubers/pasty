## ADDED Requirements

### Requirement: ESC 键切换面板显示

当主面板显示时，用户按下 ESC 键 SHALL 切换面板可见性（隐藏面板）。

#### Scenario: ESC 键隐藏面板

- **WHEN** 主面板当前显示（`state.isVisible = true`）
- **AND** 应用处于激活状态（`NSApp.isActive = true`）
- **AND** 用户按下 ESC 键（keyCode = 53）
- **THEN** 系统 SHALL 捕获键盘事件
- **THEN** MainPanelViewModel SHALL 接收 `.togglePanel` Action
- **THEN** 面板 SHALL 被隐藏
- **THEN** 响应时间 SHALL <100ms（constitution.md P2）

#### Scenario: ESC 键显示面板

- **WHEN** 主面板当前隐藏（`state.isVisible = false`）
- **AND** 应用处于激活状态（`NSApp.isActive = true`）
- **AND** 用户按下 ESC 键（keyCode = 53）
- **THEN** 系统 SHALL 捕获键盘事件
- **THEN** MainPanelViewModel SHALL 接收 `.togglePanel` Action
- **THEN** 面板 SHALL 被显示
- **THEN** 面板 SHALL 显示在鼠标位置附近

#### Scenario: 应用未激活时不响应 ESC

- **WHEN** 应用未激活（`NSApp.isActive = false`）
- **AND** 用户按下 ESC 键
- **THEN** 系统 SHALL 捕获键盘事件
- **THEN** 事件 SHALL 不被消费，传递给其他处理器
- **THEN** MainPanelViewModel SHALL 不接收任何 Action
- **THEN** 面板状态 SHALL 保持不变

#### Scenario: 全局事件监听

- **WHEN** App.swift 启动
- **THEN** 系统 SHALL 注册本地事件监听器（`NSEvent.addLocalMonitorForEvents`）
- **THEN** 监听器 SHALL 监听 `.keyDown` 事件
- **THEN** 监听器 SHALL 在应用生命周期内保持活跃

### Requirement: 面板激活状态检查

ESC 键处理 SHALL 仅在应用激活且面板显示时响应，避免在后台触发不必要的操作。

#### Scenario: 激活状态检查

- **WHEN** 用户按下 ESC 键
- **THEN** 系统 SHALL 检查 `NSApp.isActive` 状态
- **THEN** 仅在应用激活时处理 ESC 事件
- **THEN** 如果应用未激活，事件 SHALL 被忽略

#### Scenario: 面板可见性检查

- **WHEN** 用户按下 ESC 键
- **AND** 应用处于激活状态
- **THEN** 系统 SHALL 检查 `viewModel.state.isVisible` 状态
- **THEN** 仅在面板显示时处理 ESC 事件
- **THEN** 如果面板隐藏，事件 SHALL 被忽略（避免意外显示）

### Requirement: 应用激活策略

应用使用 `.accessory` 激活策略，ESC 键处理 SHALL 与此策略保持一致。

#### Scenario: accessory 模式行为

- **WHEN** 应用使用 `NSApp.setActivationPolicy(.accessory)`
- **THEN** 应用 SHALL 不在 Dock 中显示
- **THEN** 应用 SHALL 保持为后台 accessory 应用
- **THEN** ESC 键监听器 SHALL 正常工作

#### Scenario: 激活面板时的应用激活

- **WHEN** 用户通过热键或 ESC 显示面板
- **THEN** 应用 SHALL 被临时激活（`NSApp.activate(ignoringOtherApps: true)`）
- **THEN** 面板 SHALL 获得焦点
- **THEN** ESC 键监听器 SHALL 正常响应
