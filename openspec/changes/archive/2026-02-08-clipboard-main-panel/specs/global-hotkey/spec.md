## ADDED Requirements

### Requirement: 全局快捷键注册

系统 SHALL 支持全局快捷键注册，用于显示和隐藏主面板。

#### Scenario: 注册默认快捷键

- **WHEN** 应用启动时
- **THEN** 系统 SHALL 自动注册默认全局快捷键 Cmd+Shift+V 用于切换主面板

#### Scenario: 快捷键触发显示面板

- **WHEN** 用户在任何应用中按下 Cmd+Shift+V
- **THEN** 系统 SHALL 显示主面板窗口
- **THEN** 系统 SHALL 将面板定位在当前鼠标所在屏幕的中心偏上位置

#### Scenario: 快捷键切换面板可见性

- **WHEN** 主面板当前可见，用户按下 Cmd+Shift+V
- **THEN** 系统 SHALL 隐藏主面板
- **THEN** 系统 SHALL 记录面板为不可见状态

### Requirement: 快捷键持久化

系统 SHALL 将用户自定义的快捷键设置持久化到 UserDefaults。

#### Scenario: 保存自定义快捷键

- **WHEN** 用户在设置中修改快捷键（未来功能）
- **THEN** 系统 SHALL 将新的快捷键设置保存到 UserDefaults
- **THEN** 系统 SHALL 注销旧的快捷键监听
- **THEN** 系统 SHALL 注册新的快捷键监听

### Requirement: 快捷键冲突检测

系统 SHALL 检测并提示快捷键冲突。

#### Scenario: 系统保留快捷键冲突

- **WHEN** 用户尝试注册与系统保留快捷键相同的组合
- **THEN** 系统 SHALL 提示快捷键冲突警告
- **THEN** 系统 SHALL 阻止注册该快捷键

#### Scenario: 应用菜单快捷键冲突

- **WHEN** 用户尝试注册与应用主菜单项相同的快捷键
- **THEN** 系统 SHALL 提示与菜单项冲突
- **THEN** 系统 SHALL 显示冲突的菜单项名称

### Requirement: KeyboardShortcuts 库集成

系统 SHALL 使用 KeyboardShortcuts 第三方库实现全局快捷键功能。

#### Scenario: 库依赖管理

- **WHEN** macOS 平台层构建时
- **THEN** 系统 SHALL 通过 Swift Package Manager 集成 KeyboardShortcuts 库
- **THEN** 系统 SHALL 使用版本 2.0.0 或更高版本

#### Scenario: 快捷键名称定义

- **WHEN** 定义全局快捷键
- **THEN** 系统 SHALL 使用强类型名称（如 `KeyboardShortcuts.Name.togglePanel`）注册快捷键
- **THEN** 系统 SHALL 避免使用字符串硬编码

### Requirement: 快捷键监听管理

系统 SHALL 正确管理快捷键监听的生命周期。

#### Scenario: 应用启动时注册

- **WHEN** 应用启动完成初始化
- **THEN** 系统 SHALL 注册所有全局快捷键监听
- **THEN** 系统 SHALL 准备响应快捷键事件

#### Scenario: 应用退出时注销

- **WHEN** 应用即将退出
- **THEN** 系统 SHALL 注销所有全局快捷键监听
- **THEN** 系统 SHALL 释放相关资源

### Requirement: 快捷键禁用机制

系统 SHALL 提供禁用快捷键的机制（用于故障恢复）。

#### Scenario: 禁用快捷键监听

- **WHEN** 快捷键注册失败或用户选择禁用（未来功能）
- **THEN** 系统 SHALL 停止监听快捷键事件
- **THEN** 系统 SHALL 在菜单栏显示提示信息（可选）

### Requirement: 多快捷键支持

系统 SHALL 支持注册多个全局快捷键（为未来功能预留）。

#### Scenario: 扩展性设计

- **WHEN** 需要添加新的快捷键功能（如固定项、删除项）
- **THEN** 系统 SHALL 支持注册多个独立的快捷键
- **THEN** 系统 SHALL 每个快捷键对应不同的功能名称
