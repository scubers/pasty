# Path Management

## Purpose

管理应用程序的两个关键目录：appData（应用数据）和 clipboardData（剪贴板数据），确保职责分离和用户可配置性。

## Requirements

### Requirement: 双目录架构定义

系统必须维护两个独立的目录概念：appData 和 clipboardData。

#### Scenario: 应用启动初始化

- **WHEN** 应用首次启动
- **THEN** 系统 MUST 将 appData 设置为 `~/Application Support/Pasty2`
- **AND** 系统 MUST 将 clipboardData 设置为默认值 `${appData}/ClipboardData`
- **AND** 系统 MUST 创建必要的目录结构

#### Scenario: 用户自定义数据目录

- **WHEN** 用户在设置界面选择自定义 clipboardData 路径
- **THEN** 系统 MUST 将自定义路径持久化到 UserDefaults
- **AND** 系统 MUST 验证新目录可读写
- **AND** 系统 MUST 使用新目录进行所有剪贴板数据存储操作
- **AND** 应用 MUST 重启以使更改生效

#### Scenario: 恢复默认数据目录

- **WHEN** 用户点击"恢复默认路径"按钮
- **THEN** 系统 MUST 将 clipboardData 重置为 `${appData}/ClipboardData`
- **AND** 系统 MUST 清除 UserDefaults 中的自定义路径
- **AND** 应用 MUST 重启以使更改生效

#### Scenario: appData 访问

- **WHEN** 任何组件需要访问 appData 路径
- **THEN** 系统 MUST 通过 `AppPaths.appDataDirectory()` 获取固定路径
- **AND** 系统 MUST 不允许修改 appData 路径
- **AND** 系统 MUST 确保 appData 目录存在

### Requirement: 迁移文件路径管理

系统必须通过 Platform 层将 Bundle 中的迁移文件路径传递给 Core 层。

#### Scenario: Core 初始化

- **WHEN** Core 层需要执行数据库迁移
- **THEN** Platform 层 MUST 在 Core 初始化前调用 `pasty_history_set_migration_directory()`
- **AND** Platform 层 MUST 传递 Bundle 中的 migrations 目录绝对路径
- **AND** Core 层 MUST 接收路径字符串并存储在全局变量中

#### Scenario: 迁移执行

- **WHEN** Core 层执行 `applyMigration()`
- **THEN** 系统 MUST 只从迁移路径读取 SQL 文件
- **AND** 系统 MUST 不搜索多个备用路径
- **AND** 系统 MUST 在迁移文件不存在时记录错误并返回 false

### Requirement: 路径验证

系统必须验证用户选择的目录具备必要的读写权限。

#### Scenario: 验证新目录

- **WHEN** 用户选择新的 clipboardData 路径
- **THEN** 系统 MUST 验证目录可创建
- **AND** 系统 MUST 验证目录可读
- **AND** 系统 MUST 验证目录可写
- **AND** 系统 MUST 验证失败时显示错误提示
- **AND** 系统 MUST 保持在当前目录

### Requirement: 目录切换确认

系统必须在用户切换目录前明确提示风险。

#### Scenario: 确认目录切换

- **WHEN** 用户点击"更改"按钮并选择新目录
- **THEN** 系统 MUST 显示确认对话框，明确提示"切换目录将使用新位置的数据"
- **AND** 系统 MUST 提供"显示旧目录"按钮以允许用户备份数据
- **AND** 系统 MUST 只有在用户确认后才会应用新目录

### Requirement: 路径持久化

系统必须持久化用户的路径配置选择。

#### Scenario: 保存自定义路径

- **WHEN** 用户确认切换到新的 clipboardData 路径
- **THEN** 系统 MUST 将新路径保存到 UserDefaults（key: "PastyClipboardDataDirectory"）
- **AND** 系统 MUST 更新 SettingsManager.clipboardData 属性
- **AND** 系统 MUST 触发应用重启
- **AND** 系统 MUST 在下次启动时加载保存的路径

#### Scenario: 加载保存的路径

- **WHEN** 应用启动
- **THEN** 系统 MUST 从 UserDefaults 读取 "PastyClipboardDataDirectory" key
- **AND** 系统 MUST 如果存在保存的路径则使用它
- **AND** 系统 MUST 如果不存在则使用默认值 `${appData}/ClipboardData`
