# Path Management

## Purpose

管理应用程序的两个关键目录：appData（应用数据）和 clipboardData（剪贴板数据），确保职责分离。

## Requirements

### Requirement: 双目录架构定义

系统必须维护两个独立的目录概念：appData 和 clipboardData。

#### Scenario: 应用启动初始化

- **WHEN** 应用首次启动
- **THEN** 系统 MUST 将 appData 设置为 `~/Application Support/Pasty`
- **AND** 系统 MUST 将 clipboardData 设置为默认值 `${appData}/ClipboardData`
- **AND** 系统 MUST 创建必要的目录结构

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
