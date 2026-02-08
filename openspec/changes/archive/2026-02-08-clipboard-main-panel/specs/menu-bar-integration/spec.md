## ADDED Requirements

### Requirement: 菜单栏图标显示

系统 SHALL 在系统菜单栏显示应用图标，提供应用访问入口。

#### Scenario: 菜单栏图标初始化

- **WHEN** 应用启动时
- **THEN** 系统 SHALL 在系统菜单栏右侧显示应用图标（如 📋）
- **THEN** 系统 SHALL 使用 NSStatusItem.squareLength 设置图标尺寸

### Requirement: 菜单栏菜单项

菜单栏图标 SHALL 提供一个下拉菜单，包含常用操作。

#### Scenario: 菜单项显示

- **WHEN** 用户点击菜单栏图标
- **THEN** 系统 SHALL 显示下拉菜单，包含以下菜单项：
  - "打开面板" - 用于显示主面板
  - 分隔线
  - "退出" - 用于退出应用

#### Scenario: 打开面板功能

- **WHEN** 用户选择"打开面板"菜单项
- **THEN** 系统 SHALL 显示主面板窗口
- **THEN** 系统 SHALL 将面板定位在当前鼠标所在屏幕的中心偏上位置

### Requirement: LSUIElement 配置

应用 SHALL 配置为不在 Dock 栏显示。

#### Scenario: 应用激活策略

- **WHEN** 应用启动时
- **THEN** 系统 SHALL 设置应用激活策略为 `.accessory`
- **THEN** 系统 SHALL 不在 Dock 栏显示应用图标
- **THEN** 系统 SHALL 不显示应用主窗口（如适用）

#### Scenario: 菜单栏作为唯一入口

- **WHEN** 应用配置为 LSUIElement=true
- **THEN** 系统 SHALL 通过菜单栏图标提供应用主要入口
- **THEN** 系统 SHALL 不在 Dock 栏提供应用入口

### Requirement: 菜单栏交互

菜单栏图标 SHALL 支持用户交互。

#### Scenario: 左键点击菜单

- **WHEN** 用户左键点击菜单栏图标
- **THEN** 系统 SHALL 显示下拉菜单
- **THEN** 系统 SHALL 响应菜单项选择

#### Scenario: 右键点击菜单（可选）

- **WHEN** 用户右键点击菜单栏图标（未来功能）
- **THEN** 系统 SHALL 显示上下文菜单
- **THEN** 系统 SHALL 提供额外的快捷操作（如快速复制最近项）

### Requirement: 菜单栏图标自定义

系统 SHALL 支持菜单栏图标自定义（未来功能）。

#### Scenario: 图标类型选择

- **WHEN** 用户在设置中配置菜单栏图标（未来功能）
- **THEN** 系统 SHALL 支持以下图标类型：
  - SF Symbols 图标
  - 自定义图片
  - 文字图标（如 "📋"）

#### Scenario: 图标状态显示（可选）

- **WHEN** 应用处于不同状态时（未来功能）
- **THEN** 系统 SHALL 可选显示不同的菜单栏图标状态：
  - 正常状态
  - 捕获状态（正在记录剪贴板）
  - 错误状态

### Requirement: 菜单栏性能

菜单栏图标 SHALL 具有高效的响应性能。

#### Scenario: 点击响应时间

- **WHEN** 用户点击菜单栏图标
- **THEN** 系统 SHALL 在 100ms 内显示下拉菜单
- **THEN** 系统 SHALL 遵守 P2 性能响应原则

### Requirement: 菜单栏辅助功能

菜单栏图标 SHALL 支持辅助功能（可选）。

#### Scenario: VoiceOver 兼容

- **WHEN** 用户使用 VoiceOver 屏幕阅读器（未来功能）
- **THEN** 系统 SHALL 为菜单栏图标提供可访问性标签
- **THEN** 系统 SHALL 为菜单项提供描述性文本
