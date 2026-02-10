## 1. Core 层迁移路径 API

- [x] 1.1 新增全局变量 `g_migration_directory` 到 store_sqlite.cpp 匿名命名空间
- [x] 1.2 在 history_api.h 中添加 `pasty_history_set_migration_directory(const char* path)` API 声明
- [x] 1.3 在 store_sqlite.cpp 中实现 `pasty_history_set_migration_directory()` 函数
- [x] 1.4 确保 `g_migration_directory` 变量在 C API 实现前初始化

## 2. Core 层迁移文件查找逻辑

- [x] 2.1 修改 applyMigration() 方法，移除多路径搜索逻辑
- [x] 2.2 将迁移文件查找改为只从 `g_migration_directory` 读取
- [x] 2.3 构建完整迁移路径：`g_migration_directory + "/" + migrationFile`
- [x] 2.4 添加迁移文件存在性检查：文件不存在时记录错误并返回 false
- [x] 2.5 读取 SQL 文件内容到字符串
- [x] 2.6 测试迁移文件读取逻辑

## 3. Platform 层迁移路径传递

- [x] 3.1 在 App.swift 的 applicationDidFinishLaunching() 中获取 Bundle migrations 目录路径
- [x] 3.2 调用 `Bundle.main.resourceURL?.appendingPathComponent("migrations")` 获取路径
- [x] 3.3 在 Core 初始化前调用 `pasty_history_set_migration_directory()`
- [x] 3.4 使用 `withCString` 将 Swift 字符串转换为 C 字符串指针
- [x] 3.5 添加 nil 检查，确保 migrations 目录存在

## 4. Platform 层移除迁移文件复制

- [x] 4.1 删除 App.swift 中第 58 行的 `copyMigrations(to:)` 方法调用
- [x] 4.2 删除 `copyMigrations(to: destination: URL)` 方法实现（第 286-325 行）
- [x] 4.3 验证不再有任何代码调用 `copyMigrations()` 方法
- [x] 4.4 从 project.yml 中移除 migration files 的资源配置（如果存在）

## 5. SettingsManager 双目录架构

- [x] 5.1 添加 `appData` 属性：`private(set) var appData: URL`（非 @Published）
- [x] 5.2 将现有的 `settingsDirectory` 属性改名为 `clipboardData`
- [x] 5.3 确保 `clipboardData` 是 `@Published private(set) var clipboardData: URL`
- [x] 5.4 添加 UserDefaults key 常量：`private let clipboardDataKey = "PastyClipboardDataDirectory"`
- [x] 5.5 修改 `settingsDirectoryKey` 的使用位置为 `clipboardDataKey`

## 6. SettingsManager 默认路径初始化

- [x] 6.1 在 init() 中初始化 `appData` 属性为 `AppPaths.appDataDirectory()`
- [x] 6.2 从 UserDefaults 读取用户自定义的 clipboardData 路径
- [x] 6.3 如果 UserDefaults 中无自定义路径，则使用默认值 `${appData}/ClipboardData`
- [x] 6.4 确保 `appData` 在 `resolveAndValidateSettingsDirectory()` 之前已初始化

## 7. SettingsManager 设置文件路径

- [x] 7.1 修改 `settingsFileURL` 计算属性，使用 `clipboardData` 而非 `settingsDirectory`
- [x] 7.2 更新为：`clipboardData.appendingPathComponent("settings.json")`
- [x] 7.3 验证 saveSettings() 中的目录创建使用 `clipboardData`
- [x] 7.4 验证 loadSettings() 中的备份路径使用 `clipboardData`
- [x] 7.5 更新 setupFileMonitor() 中的路径引用为 settingsFileURL

## 8. SettingsManager 路径持久化方法

- [x] 8.1 将 `setSettingsDirectory(_ url:)` 方法改名为 `setClipboardDataDirectory(_ url:)`
- [x] 8.2 修改方法内部使用 `clipboardDataKey` 替代 `settingsDirectoryKey`
- [x] 8.3 保存路径到 UserDefaults：`userDefaults.set(url.path, forKey: clipboardDataKey)`
- [x] 8.4 更新属性赋值：`clipboardData = url`
- [x] 8.5 保持调用 `resolveAndValidateSettingsDirectory()` 验证目录

## 9. SettingsManager 恢复默认路径方法

- [x] 9.1 添加 `restoreDefaultClipboardDataDirectory()` 方法到 SettingsManager
- [x] 9.2 实现默认路径计算：`appData.appendingPathComponent("ClipboardData")`
- [x] 9.3 调用 `setClipboardDataDirectory()` 设置默认路径
- [x] 9.4 确保该方法会清除 UserDefaults 中的自定义路径

## 10. SettingsManager 目录验证更新

- [x] 10.1 重命名 `resolveAndValidateSettingsDirectory()` 方法或保持不变
- [x] 10.2 验证 `validateDirectory(_ url:)` 方法正确验证 `clipboardData` 目录
- [x] 10.3 确保验证失败时设置 `lastWarningMessage` 并发送通知

## 11. App.swift 初始化更新

- [x] 11.1 修改第 41 行：将 `appDataPath` 改名为 `clipboardDataPath`
- [x] 11.2 确保 `clipboardDataPath` 使用 `settingsManager.clipboardData.path`
- [x] 11.3 在 Core 初始化前添加 Bundle 迁移路径传递（第 3 组任务）
- [x] 11.4 移除第 58 行的 `copyMigrations(to:)` 方法调用（已在第 4 组删除）

## 12. App.swift Core 层调用更新

- [x] 12.1 确保 `pasty_history_set_storage_directory()` 使用 `clipboardDataPath`
- [x] 12.2 验证 Core 初始化在新路径下正常工作
- [x] 12.3 测试数据库文件创建在正确的 clipboardData 目录

## 13. StorageLocationHelper 简化

- [x] 13.1 将 `migrateAndSetDirectory()` 方法重命名为 `validateAndSetDirectory()`
- [x] 13.2 移除文件复制逻辑（settings.json、history.sqlite3、images）
- [x] 13.3 保留目录验证逻辑：`validateDirectory(_ url:)`
- [x] 13.4 更新方法调用为 `settingsManager.setClipboardDataDirectory(url)`
- [x] 13.5 确保 `showRestart` 回调仍然被调用

## 14. StorageLocationHelper 错误提示

- [x] 14.1 验证验证失败时的错误提示消息："The selected directory is not writable."
- [x] 14.2 确保 `showError` 回调被正确调用
- [x] 14.3 验证失败后不会应用新目录

## 15. StorageLocationSettingsView UI 更新

- [x] 15.1 修改第 13 行：将 `settingsManager.settingsDirectory.path` 改为 `settingsManager.clipboardData.path`
- [x] 15.2 修改第 22 行：将 `settingsManager.settingsDirectory.path` 改为 `settingsManager.clipboardData.path`
- [x] 15.3 更新 "Data Location" 标签为显示两个路径（可选）

## 16. StorageLocationSettingsView 恢复默认路径按钮

- [x] 16.1 在操作按钮区域添加 "Restore Default" 按钮
- [x] 16.2 按钮调用 `settingsManager.restoreDefaultClipboardDataDirectory()`
- [x] 16.3 确保按钮文案清晰："恢复默认路径"
- [x] 16.4 验证恢复操作会触发应用重启

## 17. AppPaths 保持不变

- [x] 17.1 验证 `AppPaths.appDataDirectory()` 方法保持不变
- [x] 17.2 确认返回 `~/Application Support/Pasty` 路径
- [x] 17.3 验证方法正确处理目录创建失败情况

## 18. Core 层测试

- [x] 18.1 编写单元测试验证 `pasty_history_set_migration_directory()` 接收路径并存储
- [x] 18.2 编写单元测试验证 `applyMigration()` 只从迁移路径读取
- [x] 18.3 测试迁移文件不存在时的错误处理
- [x] 18.4 验证数据库仍然存储在 baseDirectory（clipboardData）下

## 19. SettingsManager 测试

- [ ] 19.1 编写单元测试验证 `appData` 和 `clipboardData` 正确初始化
- [ ] 19.2 测试 `settingsFileURL` 返回 `clipboardData/settings.json`
- [ ] 19.3 测试 `restoreDefaultClipboardDataDirectory()` 清除 UserDefaults 并设置默认值
- [ ] 19.4 测试 `setClipboardDataDirectory()` 正确保存到 UserDefaults

## 20. 集成测试

- [ ] 20.1 启动应用验证 App.swift 正确传递迁移路径和存储路径
- [ ] 20.2 验证数据库迁移从 Bundle 正确执行
- [ ] 20.3 测试设置界面显示正确的 clipboardData 路径
- [ ] 20.4 测试"恢复默认路径"按钮功能正常工作
- [ ] 20.5 验证应用重启后路径配置正确加载

## 21. 文档更新

- [x] 21.1 更新 AGENTS.md 添加路径管理说明（如需要）
- [x] 21.2 更新 project-structure.md 反映新的目录结构
- [x] 21.3 确保 project.yml 配置正确（如修改了资源配置）
- [x] 21.4 添加代码注释说明双目录架构的用途
