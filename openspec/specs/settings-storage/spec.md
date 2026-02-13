# Settings Storage

## Purpose

管理应用程序设置的持久化存储，支持从单一目录架构迁移到双目录架构（appData + clipboardData）。

## Requirements

### Requirement: 设置文件路径

系统必须将 settings.json 文件存储在 clipboardData 目录中。

#### Scenario: 初始化默认设置路径

- **WHEN** 应用首次启动
- **THEN** 系统 MUST 将 settingsFileURL 设置为 `${clipboardData}/settings.json`
- **AND** 系统 MUST 确保 clipboardData 默认为 `${appData}/ClipboardData`
- **AND** 系统 MUST 在文件不存在时创建默认设置文件

### Requirement: 设置文件监控

系统必须监控 settings.json 文件的变更，以便外部编辑时能及时同步。

#### Scenario: 外部编辑设置文件

- **WHEN** 用户在应用外部修改 settings.json
- **THEN** 系统 MUST 通过文件监控检测到变更
- **AND** 系统 MUST 在 150ms 内重新加载设置文件
- **AND** 系统 MUST 更新 SettingsManager.settings 属性
- **AND** 系统 MUST 触发 `syncToCore()` 同步设置到 Core 层

#### Scenario: 设置自动保存

- **WHEN** 应用内部修改设置（通过 SettingsManager.updateSettings()）
- **THEN** 系统 MUST 在 500ms 去抖动后自动保存
- **AND** 系统 MUST 确保 settingsFileURL 的目录存在
- **AND** 系统 MUST 以原子方式写入文件避免损坏

### Requirement: 设置文件损坏恢复

系统必须在检测到设置文件损坏时提供恢复机制。

#### Scenario: 设置文件损坏

- **WHEN** 加载 settings.json 时遇到 JSON 解析错误
- **THEN** 系统 MUST 将损坏文件备份为 `settings.json.corrupted`
- **AND** 系统 MUST 创建新的默认设置文件
- **AND** 系统 MUST 显示警告提示用户
- **AND** 系统 MUST 发布通知让 UI 显示错误消息

### Requirement: 设置同步到 Core

系统必须将设置同步到 Core 层以确保行为一致性。

#### Scenario: 初始化 Core 设置

- **WHEN** 应用首次启动
- **THEN** 系统 MUST 调用 `pasty_settings_initialize()` 传入 max history count
- **AND** 系统 MUST 设置标志 `didInitializeCoreSettings` 为 true

#### Scenario: 更新 Core 设置

- **WHEN** 用户修改 history.maxCount 设置
- **THEN** 系统 MUST 调用 `pasty_settings_update("history.maxCount", <value>)`
- **AND** 系统 MUST 调用 `pasty_history_enforce_retention()` 应用新的保留限制
- **AND** 系统 MUST 确保 Core 层立即生效

### Requirement: 设置版本管理

系统必须管理设置文件的版本号以支持未来迁移。

#### Scenario: 检测旧版本设置

- **WHEN** 加载 settings.json 且 version 字段小于当前版本
- **THEN** 系统 MUST 升级 version 到当前版本号
- **AND** 系统 MUST 写回更新后的设置文件
- **AND** 系统 MUST 在升级过程中保留用户的自定义值

#### Scenario: 新版本默认值合并

- **WHEN** 加载 settings.json 且缺少某些字段
- **THEN** 系统 MUST 为缺失字段使用默认值
- **AND** 系统 MUST 保留用户已配置的字段
- **AND** 系统 MUST 合并后保存文件

### Requirement: 设置目录管理

系统必须将设置目录存储在 appData 下的 clipboardData 目录中。

#### Scenario: 初始化双目录

- **WHEN** SettingsManager 初始化
- **THEN** 系统 MUST 设置 `appData` 为固定路径 `~/Application Support/Pasty`
- **AND** 系统 MUST 设置 `clipboardData` 为 `${appData}/ClipboardData`
- **AND** 系统 MUST 确保 `appData` 不是 `@Published` 属性（固定不变）
- **AND** 系统 MUST 确保 `clipboardData` 不是 `@Published` 属性（固定不变）

### Requirement: 设置文件路径计算

系统必须确保 settingsFileURL 始终基于 clipboardData 路径计算。

#### Scenario: 访问设置文件路径

- **WHEN** 任何组件需要访问 settings.json 路径
- **THEN** 系统 MUST 通过 `SettingsManager.settingsFileURL` 计算属性获取
- **AND** 系统 MUST 返回 `clipboardData/settings.json`
- **AND** 系统 MUST 不依赖其他全局或缓存路径

