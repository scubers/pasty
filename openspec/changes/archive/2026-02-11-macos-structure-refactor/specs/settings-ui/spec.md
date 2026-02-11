# Settings UI

## MODIFIED Requirements

### Requirement: 设置逻辑迁移
系统必须将现有设置逻辑迁移到新的 UI 框架，同时保持数据持久性。设置模块文件组织在 `Features/Settings/` 功能目录中，遵循基于功能的架构。

#### Scenario: 常规设置迁移
- **WHEN** 加载常规设置页面
- **THEN** 它从底层平台 API 获取"登录时启动"状态
- **AND** 切换该选项会更新平台设置

#### Scenario: 剪贴板设置迁移
- **WHEN** 加载剪贴板设置页面
- **THEN** 它将历史记录大小和保留时长绑定到 Core 设置 API
- **AND** 更改会立即持久化

#### Scenario: 外观设置集成
- **WHEN** 更改主题
- **THEN** 它更新 `AppDesign` 系统以反映新主题（浅色/深色/跟随系统）
- **AND** 持久化该偏好设置

#### Scenario: OCR 设置绑定
- **WHEN** 更改 OCR 设置
- **THEN** 它更新位于 `Services/Impl/` 中的 OCR 服务配置
- **AND** 如果模型选择发生变化，则触发模型重新加载

#### Scenario: 快捷键管理
- **WHEN** 录制新的全局快捷键
- **THEN** 它向位于 `Services/` 中的 HotkeyService 注册新的热键
- **AND** 注销旧的热键

#### Scenario: 设置管理器位置
- **WHEN** 查找 SettingsManager
- **THEN** 它位于 `Services/Impl/SettingsManager.swift`
- **AND** 可以被设置功能模块调用

#### Scenario: 设置模块组织
- **WHEN** 查看设置模块的目录结构
- **THEN** 设置模块位于 `Features/Settings/` 目录中
- **AND** 所有设置相关的视图位于 `Features/Settings/View/` 目录中
- **AND** 所有设置相关的视图模型位于 `Features/Settings/ViewModel/` 目录中
- **AND** 设置模块遵循功能自包含原则
