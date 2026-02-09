# Settings UI

## Purpose
管理和展示应用程序的设置界面逻辑。

## MODIFIED Requirements

### Requirement: 设置逻辑迁移
系统必须将现有设置逻辑迁移到新的 UI 框架，同时保持数据持久性。

#### Scenario: 常规设置迁移
- **WHEN** 加载常规设置页面
- **THEN** 它从底层平台 API 获取"登录时启动"状态
- **AND** 切换该选项会更新平台设置

#### Scenario: 剪贴板设置迁移
- **WHEN** 加载剪贴板设置页面
- **THEN** 它将历史记录大小和保留时长绑定到 Core 设置 API
- **AND** 更改会立即持久化

#### Scenario: 外观设置集成
- **WHEN** 更改主题颜色
- **THEN** 它更新 `DesignSystem` 以反映新主题颜色
- **AND** 持久化该偏好设置
- **AND** 界面所有相关元素立即应用新颜色

#### Scenario: 外观设置调整毛玻璃程度
- **WHEN** 调整"Window Blur"滑块
- **THEN** 它更新设置面板背景的毛玻璃模糊程度
- **AND** 持久化该偏好设置
- **AND** 设置面板背景立即显示新的模糊效果

#### Scenario: OCR 设置绑定
- **WHEN** 更改 OCR 设置
- **THEN** 它更新 OCR 服务配置
- **AND** 如果模型选择发生变化，则触发模型重新加载

#### Scenario: 快捷键管理
- **WHEN** 录制新的全局快捷键
- **THEN** 它向 HotkeyService 注册新的热键
- **AND** 注销旧的热键

## REMOVED Requirements

### Requirement: 主题模式设置
**Reason**: 主题模式（浅色/深色/跟随系统）概念不必要，macOS 系统自动管理外观更符合平台惯例
**Migration**: 从 AppearanceSettings 数据模型中移除 themeMode 字段，从 AppearanceSettingsView 移除 Theme Mode 控件，设置文件解码器继续接受该字段但忽略其值以保持向后兼容性

## ADDED Requirements

### Requirement: 存储目录设置集成
系统必须在 General 设置页面中提供存储目录管理功能。

#### Scenario: 显示当前存储目录
- **WHEN** 用户打开 General 设置页面
- **THEN** 系统显示当前设置和数据存储目录的完整路径

#### Scenario: 在 Finder 中显示存储目录
- **WHEN** 用户点击"Show in Finder"按钮
- **THEN** 系统在 Finder 中打开并选中存储目录

#### Scenario: 更改存储目录
- **WHEN** 用户点击"Change..."按钮并选择有效目录
- **THEN** 系统验证目录可写性并迁移现有数据
- **AND** 系统提示用户需要重启应用

### Requirement: 全局快捷键移至 General 设置
系统必须将全局快捷键设置从 Shortcuts 移至 General 设置页面。

#### Scenario: 全局快捷键在 General 中显示
- **WHEN** 用户打开 General 设置页面
- **THEN** 系统显示"Global Shortcuts"部分
- **AND** 用户可以在该部分录制和管理全局快捷键

## REMOVED Requirements

### Requirement: 应用内快捷键显示
**Reason**: 应用内快捷键是固定的（Cmd + F、Cmd + Shift + Backspace），无需在设置中显示
**Migration**: 从 ShortcutsSettingsView 移除 In-App Shortcuts 部分
