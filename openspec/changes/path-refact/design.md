## Context

当前 Pasty2 应用的所有持久化数据（settings.json、database、images）和迁移文件都混合存储在同一个目录 `~/Application Support/Pasty2` 下。这种结构存在以下问题：
- 数据管理不便，无法清晰区分应用配置和用户数据
- 迁移文件被复制到 appData，造成重复存储
- 用户无法自定义剪贴板数据的存储位置
- 缺乏灵活性，难以支持未来的多用户或数据分离需求

项目采用 **C++ Core + Platform Shell** 架构，Core 层负责业务逻辑，Platform 层负责 UI 和系统集成。Core 层通过 `pasty_history_set_storage_directory()` 接收存储目录路径，当前传入的是单一目录路径。迁移文件通过 App.swift 中的 `copyMigrations()` 复制到 appData/migrations，Core 层从多个搜索路径中查找迁移文件。

**约束**: Core 层是跨平台 C++ 代码，无法直接访问平台特定的 Bundle 路径。需要 Platform 层传递 Bundle 路径给 Core 层。

## Goals / Non-Goals

**Goals:**
- 将应用数据和剪贴板数据分离到两个独立目录
- appData 固定在 `~/Application Support/Pasty2`，不存放持久化数据
- clipboardData 支持用户自定义配置，默认为 `${appData}/ClipboardData`
- 迁移文件直接从 bundle 读取，不复制
- 修改路径相关代码，确保 Core 层使用 clipboardData 作为存储目录
- 更新 UI 设置界面，允许用户配置 clipboardData 路径
- 简化目录切换逻辑，不执行数据迁移

**Non-Goals:**
- 不提供旧目录结构的数据迁移逻辑
- 不支持跨平台路径差异处理（每个平台独立实现）

## Decisions

### 1. 双目录架构设计

**决策**: 引入两个独立目录概念 - appData 和 clipboardData

**理由**:
- **职责分离**: appData 存放应用级文件（migrations），clipboardData 存放用户数据（settings、database、images）
- **灵活性**: clipboardData 可配置，允许用户将数据放在自定义位置（如外部磁盘或云同步目录）
- **简洁性**: appData 固定路径，避免用户误操作影响应用运行

**替代方案考虑**:
- 单目录 + 子目录结构: 仍将所有数据放在一个根目录下，职责分离不清晰
- 三个目录（settings、database、images 分别配置）: 过于复杂，用户配置成本高

### 2. SettingsManager 重构

**决策**: SettingsManager 添加两个属性：
- `appData`: 普通存储属性，固定路径
- `clipboardData`: `@Published` 属性，支持用户配置

**理由**:
- **响应式**: clipboardData 使用 `@Published` 确保路径变化时 UI 自动更新
- **简洁性**: appData 固定不变，无需响应式
- **单一真实源**: SettingsManager 作为路径管理的中心，其他组件通过它获取路径
- **持久化**: clipboardData 路径通过 UserDefaults 持久化（使用 key "PastyClipboardDataDirectory"），appData 固定计算

**实现要点**:
```swift
private(set) var appData: URL
@Published private(set) var clipboardData: URL

private let clipboardDataKey = "PastyClipboardDataDirectory"  // UserDefaults 中存储用户自定义路径的 key
```

### 3. 路径获取逻辑

**决策**: 使用 `AppPaths` 提供静态方法获取 appData，clipboardData 由 SettingsManager 管理

**理由**:
- **职责分离**: AppPaths 负责系统级路径计算（固定），SettingsManager 负责用户配置（可变）
- **可测试性**: 静态方法易于单元测试
- **清晰语义**: appData 永远是系统默认位置，clipboardData 可能是自定义位置

### 4. Core 层新增迁移路径 API

**决策**: 在 Core 层新增 `pasty_history_set_migration_directory(const char* path)` API

**理由**:
- **职责分离**: Platform 层通过 Bundle API 获取迁移文件路径，传递给 Core 层
- **跨平台**: Core 层接受路径字符串，不依赖特定平台的路径 API
- **简洁性**: Core 层只从迁移路径查找，移除旧的多路径搜索逻辑

**实现要点**:
```cpp
// C++ Core 层新增全局变量
std::string g_migration_directory;

// 新增 API
extern "C" {
    void pasty_history_set_migration_directory(const char* path) {
        if (path) {
            g_migration_directory = path;
        }
    }
}

// store_sqlite.cpp 中的 applyMigration() 只从迁移路径读取
std::string migrationPath = g_migration_directory + "/" + migrationFile;
std::ifstream file(migrationPath);
if (!file.is_open()) {
    logStoreMessage("migration file not found: " + migrationPath);
    return false;
}
```

**Platform 层调用**:
```swift
// App.swift 中获取 Bundle 中的迁移文件路径
let bundlePath = Bundle.main.resourceURL?.appendingPathComponent("migrations")
if let bundlePath = bundlePath {
    bundlePath.withCString { ptr in
        pasty_history_set_migration_directory(ptr)
    }
}
```

### 5. 目录切换简化

**决策**: 用户切换 clipboardData 目录时，直接使用新目录，不执行数据迁移

**理由**:
- **用户明确意图**: 用户主动切换目录，期望使用新位置的数据
- **简洁性**: 避免复杂的迁移逻辑，减少出错可能
- **自动创建**: 新目录在使用时自动创建必要的文件（settings.json、database、images/）

**实现**: StorageLocationHelper 只需验证新目录可读写，移除 `migrateAndSetDirectory()` 中的文件复制逻辑

### 6. 迁移文件处理

**决策**: 通过 Platform 层获取 Bundle 路径，Core 层只从迁移路径读取

**理由**:
- **简洁性**: bundle 中的迁移文件是只读资源，无需复制
- **空间节省**: 避免重复存储迁移文件
- **实现简化**: 移除 App.swift 中的 `copyMigrations()` 调用
- **架构清晰**: Platform 层负责获取 Bundle 路径，Core 层负责读取和执行迁移

**实现步骤**:
1. Platform 层（App.swift）在 Core 初始化前调用 `pasty_history_set_migration_directory()`
2. Core 层（store_sqlite.cpp）的 `applyMigration()` 只从迁移路径读取，移除多路径搜索逻辑
3. 移除 App.swift 中的 `copyMigrations(to:)` 方法调用
4. 移除 `copyMigrations()` 方法本身（不再需要）

## Risks / Trade-offs

### 风险 1: 用户切换目录后数据丢失
**描述**: 用户修改 clipboardData 路径后，旧目录中的数据（history、settings、images）无法访问

**缓解措施**:
- 在 UI 中添加确认对话框，明确提示"切换目录将使用新位置的数据"
- 添加"恢复默认路径"按钮，允许用户快速恢复到默认的 `${appData}/ClipboardData`

### 风险 2: 自定义路径权限问题
**描述**: 用户选择的自定义路径可能因权限问题无法写入

**缓解措施**:
- 在切换前验证目录可读写（现有 `validateDirectory()` 逻辑）
- 验证失败时显示错误提示，并保持在当前目录

### 风险 3: 并发访问冲突
**描述**: Core 层正在使用旧目录写入数据时，用户切换路径

**缓解措施**:
- 切换目录需要重启应用（现有逻辑已实现）
- `setSettingsDirectory()` 触发 `showRestartAlert`，确保数据一致性

### 权衡: 路径管理复杂度 vs 用户体验
**描述**: 增加路径管理逻辑会增加代码复杂度

**权衡**:
- 接受适度的代码复杂度提升
- 换来清晰的目录结构和用户自定义能力
- 通过职责分离（AppPaths、SettingsManager、StorageLocationHelper）控制复杂度

### 风险 4: 不同平台的 Bundle 路径差异
**描述**: 不同平台获取迁移文件路径的方式不同（macOS Bundle、Windows 资源目录等）

**缓解措施**:
- Core 层只接受路径字符串，不关心平台差异
- 每个平台的 Platform 层负责获取对应的资源路径
- 通过 `pasty_history_set_migration_directory()` 统一接口

## 路径使用清单与修改方案

### 1. AppPaths.swift

**当前实现**:
```swift
// 第 6-19 行
static func appDataDirectory(fileManager: FileManager = .default) -> URL {
    let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    let directory = base.appendingPathComponent("Pasty2", isDirectory: true)

    do {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    } catch {
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("Pasty2", isDirectory: true)
    }

    return directory
}
```

**修改方案**: 保持不变，返回 `~/Application Support/Pasty2` 作为 appData

---

### 2. SettingsManager.swift

**当前路径使用**:
```swift
// 第 20 行: settingsDirectory 属性（需要拆分）
@Published private(set) var settingsDirectory: URL

// 第 25 行: UserDefaults key（需要重命名）
private let settingsDirectoryKey = "PastySettingsDirectory"

// 第 33-35 行: settingsFileURL 计算使用 settingsDirectory
var settingsFileURL: URL {
    settingsDirectory.appendingPathComponent("settings.json")
}

// 第 38 行: 初始化使用 defaultSettingsDirectory()
self.settingsDirectory = SettingsManager.defaultSettingsDirectory()

// 第 201 行: saveSettings() 创建目录
try FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)

// 第 83 行: 备份文件路径
let backupURL = settingsDirectory.appendingPathComponent("settings.json.corrupted")

// 第 222 行: setSettingsDirectory() 方法
func setSettingsDirectory(_ url: URL) {
    userDefaults.set(url.path, forKey: settingsDirectoryKey)
    settingsDirectory = url
    resolveAndValidateSettingsDirectory()
    loadSettings()
    setupFileMonitor()
}
```

**修改方案**:
```swift
// 拆分为两个属性
@Published private(set) var appData: URL  // 从 AppPaths.appDataDirectory() 获取
@Published private(set) var clipboardData: URL  // 从 UserDefaults 读取，默认为 appData/ClipboardData

// UserDefaults key 改名
private let clipboardDataKey = "PastyClipboardDataDirectory"

// settingsFileURL 改用 clipboardData
var settingsFileURL: URL {
    clipboardData.appendingPathComponent("settings.json")
}

// setSettingsDirectory() 改名为 setClipboardDataDirectory()
func setClipboardDataDirectory(_ url: URL) {
    userDefaults.set(url.path, forKey: clipboardDataKey)
    clipboardData = url
    // 验证新目录可读写
    guard validateDirectory(url) else {
        // 显示错误提示
        return
    }
    loadSettings()
    setupFileMonitor()
}

// 新增恢复默认路径方法
func restoreDefaultClipboardDataDirectory() {
    let defaultPath = appData.appendingPathComponent("ClipboardData")
    setClipboardDataDirectory(defaultPath)
}
```

---

### 3. App.swift

**当前路径使用**:
```swift
// 第 41 行: 获取 settingsDirectory 路径
let appDataPath = settingsManager.settingsDirectory.path

// 第 58 行: 复制迁移文件到 settingsDirectory
copyMigrations(to: settingsManager.settingsDirectory)

// 第 60-62 行: 传递路径给 Core 层
appDataPath.withCString { pointer in
    pasty_history_set_storage_directory(pointer)
}

// 第 286-325 行: copyMigrations() 方法实现
private func copyMigrations(to destination: URL) {
    let destMigrationsPath = destination.appendingPathComponent("migrations")
    // ... 复制逻辑
}
```

**修改方案**:
```swift
// 第 41 行: 获取 clipboardData 路径
let clipboardDataPath = settingsManager.clipboardData.path

// 第 58 行: 移除 copyMigrations() 调用
// copyMigrations(to: settingsManager.settingsDirectory)  // 删除

// 新增第 57 行: 获取 Bundle 迁移文件路径并传递给 Core 层
if let bundleMigrationsPath = Bundle.main.resourceURL?.appendingPathComponent("migrations") {
    bundleMigrationsPath.withCString { pointer in
        pasty_history_set_migration_directory(pointer)
    }
}

// 第 60-62 行: 传递 clipboardData 路径给 Core 层
clipboardDataPath.withCString { pointer in
    pasty_history_set_storage_directory(pointer)
}

// 删除 copyMigrations() 方法（第 286-325 行全部删除）
```

---

### 4. StorageLocationHelper.swift

**当前路径使用**:
```swift
// 第 23 行: 获取旧目录
let oldURL = settingsManager.settingsDirectory

// 第 33 行: 迁移的文件列表
let itemsToCopy = ["settings.json", "history.sqlite3", "images"]

// 第 35-45 行: migrateAndSetDirectory() 复制文件
for item in itemsToCopy {
    let source = oldURL.appendingPathComponent(item)
    let dest = url.appendingPathComponent(item)
    // ... 复制逻辑
}
```

**修改方案**:
```swift
// 获取旧目录（现在是 clipboardData）
let oldURL = settingsManager.clipboardData

// 简化 migrateAndSetDirectory() 为 validateAndSetDirectory()
static func validateAndSetDirectory(_ url: URL, settingsManager: SettingsManager, showError: @escaping (String) -> Void, showRestart: @escaping () -> Void) {
    guard validateDirectory(url) else {
        showError("The selected directory is not writable.")
        return
    }
    settingsManager.setClipboardDataDirectory(url)
    showRestart()
}
```

---

### 5. StorageLocationSettingsView.swift

**当前路径使用**:
```swift
// 第 13 行: 显示 settingsDirectory 路径
Text(settingsManager.settingsDirectory.path)

// 第 22 行: 在 Finder 中显示 settingsDirectory
NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settingsManager.settingsDirectory.path)
```

**修改方案**:
```swift
// 改为显示 clipboardData 路径
Text(settingsManager.clipboardData.path)

// 改为在 Finder 中显示 clipboardData
NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settingsManager.clipboardData.path)

// 新增"恢复默认路径"按钮
Button("Restore Default") {
    settingsManager.restoreDefaultClipboardDataDirectory()
}
```

---

### 6. Core 层 (core/src/history/store_sqlite.cpp)

**当前路径使用**:
```cpp
// 第 101 行: 数据库路径
m_dbPath = m_baseDirectory + "/history.sqlite3";

// 第 741-745 行: 迁移文件搜索路径
std::vector<std::string> searchPaths = {
    m_baseDirectory + "/migrations/" + migrationFile,
    m_baseDirectory + "/../migrations/" + migrationFile,
    "migrations/" + migrationFile,
    "core/migrations/" + migrationFile,
    "../../core/migrations/" + migrationFile
};
```

**修改方案**:
```cpp
// 数据库路径保持不变（使用 m_baseDirectory，即 clipboardData）
m_dbPath = m_baseDirectory + "/history.sqlite3";  // 无需修改

// 新增全局变量（在匿名命名空间中）
namespace {
    std::string g_migration_directory;
}

// 修改 applyMigration() 的迁移文件查找（第 740 行起）
std::string migrationPath = g_migration_directory + "/" + migrationFile;
std::ifstream file(migrationPath);
if (!file.is_open()) {
    logStoreMessage("migration file not found: " + migrationPath);
    return false;
}
// 读取 SQL 文件内容
std::string sql((std::istreambuf_iterator<char>(file)),
                std::istreambuf_iterator<char>());
```

---

### 7. Core API (core/include/pasty/api/history_api.h)

**需要新增**:
```cpp
// 新增 API（在现有声明末尾）
void pasty_history_set_migration_directory(const char* path);
```

---

### 8. Platform 层实现迁移路径传递 (App.swift)

**需要新增**（在 applicationDidFinishLaunching() 中 Core 初始化前）:
```swift
// 获取 Bundle 中的迁移文件路径
if let bundleMigrationsPath = Bundle.main.resourceURL?.appendingPathComponent("migrations") {
    bundleMigrationsPath.withCString { pointer in
        pasty_history_set_migration_directory(pointer)
    }
}
```
