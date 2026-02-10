## Why

当前应用的持久化路径结构不够清晰和灵活。所有数据（settings、database、images、migrations）都混合在同一个目录下，导致数据管理不便。需要将应用数据和剪贴板数据分离，使数据结构更加清晰，同时支持用户自定义剪贴板数据存储位置。

## What Changes

- 引入两个独立目录概念：
  - **appData**: 固定为 `~/Application Support/Pasty`，仅用于应用级操作（不存放持久化数据）
  - **clipboardData**: 用户可配置，默认为 `${appData}/ClipboardData`，用于存放 settings.json、history.sqlite3 和 images/
- 迁移文件直接从 bundle 读取，不复制到 appData
- 修改 SettingsManager 以支持两个独立目录
- 更新 App.swift 中的初始化逻辑，分别处理 appData 和 clipboardData，移除 copyMigrations() 调用
- 修改 Core 层的迁移文件查找逻辑，支持从 bundle 读取
- 更新 UI 设置界面，允许用户配置 clipboardData 路径，添加"恢复默认路径"按钮

## Capabilities

### New Capabilities
- `path-management`: 应用路径管理能力，包括 appData 和 clipboardData 的获取、设置和验证

### Modified Capabilities
- `settings-storage`: 现有设置存储能力需要修改，从单一目录改为支持两个独立目录（appData 和 clipboardData）

## Impact

**影响的代码**：
- `platform/macos/Sources/Settings/SettingsManager.swift` - 需要添加 appData 和 clipboardData 属性
- `platform/macos/Sources/App.swift` - 需要更新初始化逻辑，获取 Bundle 路径并传递给 Core 层，移除 copyMigrations() 方法
- `platform/macos/Sources/Utils/AppPaths.swift` - 需要更新以支持 appData 路径获取
- `platform/macos/Sources/Settings/StorageLocationHelper.swift` - 简化逻辑，只验证新目录，不执行数据迁移
- `platform/macos/Sources/Settings/StorageLocationSettingsView.swift` - UI 需要更新以反映新的路径结构，添加"恢复默认路径"按钮
- `core/include/pasty/api/history_api.h` - 需要新增 `pasty_history_set_migration_directory()` API 声明
- `core/src/history/store_sqlite.cpp` - 需要新增迁移路径全局变量，修改迁移文件查找逻辑
- `platform/macos/project.yml` - 保持迁移文件的打包（仍需包含在 bundle 中）
