## Context

这是 Pasty2 剪贴板应用的首个核心功能实现。当前项目采用 **C++ Core + Platform Shell** 架构：

- **Core 层** (`core/`)：跨平台业务逻辑层，纯 C++17 实现，是数据模型与规则的唯一真相来源
- **macOS 平台层** (`platform/macos/`)：thin shell，只做 UI、系统集成、适配器

**强制约束**：
- 依赖方向：Platform → Core（单向），Core 禁止依赖任何平台头文件
- macOS 层强制遵循 **MVVM + Combine** 模式
- UI 技术栈：**AppKit 外壳 + SwiftUI 混合**（简单 UI 允许使用 SwiftUI）
- 布局：AppKit View 统一使用 **SnapKit**
- 依赖管理：macOS 层统一使用 **SPM**

**宪法原则**（必须遵守）：
- **P1 隐私优先**：数据本地存储，云同步需用户授权（本功能不涉及）
- **P2 性能响应**：UI 操作 <100ms，内存 <200MB/10K条目，启动 <2s
- **P3 跨平台兼容**：平台特定 API 必须通过接口抽象
- **P4 数据完整**：原子写入，无损捕获
- **P5 可扩展架构**：稳定 API，插件支持

## Goals / Non-Goals

**Goals:**
- 实现 macOS 平台的主面板窗口（AppKit + SwiftUI 混合）
- 建立全局快捷键系统（`Cmd+Shift+V`）
- 实现菜单栏集成（`NSStatusItem`）
- 提供实时搜索功能（LIKE 匹配，响应 <100ms）
- 创建预览系统（支持文本、图片，UI 操作 <100ms）
- 定义清晰的 Core-Platform 接口（支持跨平台扩展）
- 遵循 MVVM + Combine 架构
- 使用 SnapKit 进行 AppKit 布局
- 建立数据库版本管理和迁移机制

**Non-Goals:**
- 剪贴板数据捕获和管理逻辑（后续 feature 实现）
- 复杂的剪贴板操作（编辑、删除、固定）
- 高级搜索（正则表达式、标签过滤）
- 其他平台（Windows、Linux）的实现

## Constitution Check

| 原则 | 检查项 | 状态 |
|------|--------|------|
| **P1: 隐私优先** | 数据本地存储，无云端同步 | ✅ 符合 |
| **P2: 性能响应** | UI 操作 <100ms，搜索响应 <100ms | ✅ 符合（需通过测试验证） |
| **P3: 跨平台兼容** | Core 层无平台依赖，通过接口抽象 | ✅ 符合 |
| **P4: 数据完整** | Core 层使用原子写入，无损捕获 | ✅ 符合（由现有 History 模块保证） |
| **P5: 可扩展架构** | Core API 稳定，便于插件扩展 | ✅ 符合 |

## Decisions

### 1. Core 层接口设计：扩展现有 History 模块

**决策**：在 Core 层的 `pasty/history/` 模块基础上扩展，新增搜索和过滤接口。

**理由**：
- 保持 Core 层作为数据唯一真相来源
- 遵循接口隔离原则，通过 `ClipboardHistory` 类暴露必要接口
- 支持 C API 供 Swift FFI 调用
- 便于单元测试和跨平台扩展

**新增接口**（在 `core/include/pasty/history/history.h`）：
```cpp
namespace pasty {

struct SearchOptions {
    std::string query;           // LIKE 匹配查询
    size_t limit = 100;           // 返回结果数量限制
    std::string contentType;     // 可选：内容类型过滤
};

struct ClipboardHistoryItem {
    std::string id;
    std::string content;
    std::string source;          // 来源应用
    std::int64_t timestamp;      // Unix 时间戳
    std::string contentType;     // "text", "image", etc.
    std::string metadata;        // JSON 格式的元数据
};

class ClipboardHistory {
public:
    // 现有接口（保持不变）
    bool initialize(const std::string& storagePath);
    std::vector<ClipboardHistoryItem> list(size_t limit, const std::string& cursor = "");

    // 新增接口
    std::vector<ClipboardHistoryItem> search(const SearchOptions& options);
    std::optional<ClipboardHistoryItem> getById(const std::string& id);
};

} // namespace pasty
```

**C API 扩展**（在 `core/include/pasty/api/history_api.h`）：
```c
// 新增 C API（供 Swift 调用）
bool pasty_history_search(const char* query, size_t limit, char** out_json, int* out_count);
char* pasty_history_get_json(const char* id);
void pasty_free_string(char* str);  // 释放 C API 返回的字符串
```

**考虑的替代方案**：
- 在 Core 层新增独立的 `Search` 模块：增加复杂度，耦合度更高
- 在 Platform 层实现搜索：违反 Core 层作为数据真相来源的原则

---

### 2. macOS 层架构：MVVM + Combine + AppKit/SwiftUI 混合

**决策**：主面板采用 MVVM 架构，Combine 管理响应式数据流，AppKit 实现外层窗口，SwiftUI 实现内部 UI。

**理由**：
- 符合 macOS 架构规范（`platform/macos/ARCHITECTURE.md`）
- AppKit 适合管理窗口生命周期、全局快捷键、菜单栏
- SwiftUI 适合实现简单的列表、搜索框等 UI
- Combine 提供响应式数据流，便于状态管理

**架构分层**：

```
┌─────────────────────────────────────────────┐
│  AppKit (NSPanel, NSStatusItem, KeyboardShortcuts)  │  ← 应用入口、系统集成
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│  SwiftUI (NSHostingController)              │  ← UI 组件（嵌入 AppKit）
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│  ViewModel (Combine + @MainActor)            │  ← 业务逻辑编排
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│  Service / Adapter (协议注入)               │  ← Core API 调用
└─────────────────┬───────────────────────────┘
                  │
┌─────────────────▼───────────────────────────┐
│  C++ Core (PastyCore)                       │  ← 数据层
└─────────────────────────────────────────────┘
```

**文件结构**（`platform/macos/Sources/`）：
```
Sources/
├── App.swift                           # Composition Root，组装依赖
├── ViewModel/
│   └── MainPanelViewModel.swift        # 主面板 ViewModel（MVVM）
├── Model/
│   ├── ClipboardItemRow.swift          # Presentation Model
│   └── ClipboardSearchResult.swift     # 搜索结果模型
├── View/
│   ├── MainPanelView.swift            # SwiftUI 主面板 UI
│   └── MainPanelWindowController.swift # AppKit 窗口控制器
└── Utils/
    ├── HotkeyService.swift             # 全局快捷键服务（协议）
    ├── HotkeyServiceImpl.swift         # 快捷键实现（KeyboardShortcuts）
    ├── ClipboardHistoryService.swift   # 剪贴板历史服务（协议）
    ├── ClipboardHistoryServiceImpl.swift # Core API 调用
    └── CombineExtensions.swift         # Combine 辅助扩展
```

**ViewModel 实现**（遵循 MVVM + Combine）：
```swift
@MainActor
final class MainPanelViewModel: ObservableObject {
    struct State: Equatable {
        var isVisible = false
        var items: [ClipboardItemRow] = []
        var selectedItem: ClipboardItemRow? = nil
        var searchQuery = ""
        var isLoading = false
        var errorMessage: String? = nil
    }

    enum Action {
        case togglePanel
        case showPanel
        case hidePanel
        case searchChanged(String)
        case itemSelected(ClipboardItemRow)
    }

    @Published private(set) var state = State()
    private var cancellables = Set<AnyCancellable>()
    private let historyService: ClipboardHistoryService

    init(historyService: ClipboardHistoryService) {
        self.historyService = historyService
        setupHotkey()
    }

    func send(_ action: Action) {
        switch action {
        case .togglePanel:
            state.isVisible.toggle()
        case .showPanel:
            state.isVisible = true
        case .hidePanel:
            state.isVisible = false
        case let .searchChanged(query):
            search(query: query)
        case let .itemSelected(item):
            state.selectedItem = item
        }
    }

    private func search(query: String) {
        state.searchQuery = query
        guard !query.isEmpty else {
            state.items = []
            return
        }

        state.isLoading = true
        historyService.search(query: query, limit: 100)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.state.isLoading = false
                    if case let .failure(error) = completion {
                        self?.state.errorMessage = String(describing: error)
                    }
                },
                receiveValue: { [weak self] items in
                    self?.state.items = items
                }
            )
            .store(in: &cancellables)
    }

    private func setupHotkey() {
        KeyboardShortcuts.onKeyDown(for: .togglePanel)
            .sink { [weak self] in
                self?.send(.togglePanel)
            }
            .store(in: &cancellables)
    }
}
```

**考虑的替代方案**：
- 纯 AppKit 实现：开发效率低，UI 代码冗长
- 纯 SwiftUI 实现：全局快捷键、菜单栏等系统集成更困难

---

### 3. 全局快捷键实现：使用 KeyboardShortcuts 库

**决策**：全局快捷键通过 **KeyboardShortcuts** 第三方库实现。

**理由**：
- KeyboardShortcuts 是成熟的开源库，专门用于 macOS 全局快捷键
- 提供简洁的 API 和 Combine 集成
- 自动处理快捷键冲突和系统保留快捷键
- 支持 UserDefaults 存储，用户可自定义（后续功能）
- Mac App Store 兼容，无需额外权限

**SPM 配置**（在 `platform/macos/project.yml`）：
```yaml
packages:
  KeyboardShortcuts:
    url: https://github.com/sindresorhus/KeyboardShortcuts
    from: "2.0.0"
```

**实现**（`platform/macos/Sources/Utils/HotkeyServiceImpl.swift`）：
```swift
import KeyboardShortcuts

final class HotkeyServiceImpl: HotkeyService {
    func register(name: KeyboardShortcuts.Name) -> AnyPublisher<Void, Never> {
        return KeyboardShortcuts.onKeyDown(for: name)
            .eraseToAnyPublisher()
    }

    func unregister() {
        // KeyboardShortcuts 库自动管理，无需手动注销
    }
}
```

**快捷键名称注册**（`platform/macos/Sources/Utils/HotkeyService.swift`）：
```swift
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel")
}
```

**默认快捷键设置**（在 `App.swift` 初始化）：
```swift
import KeyboardShortcuts

@main
struct App {
    static func main() {
        // 设置默认快捷键 Cmd+Shift+V
        KeyboardShortcuts.Name.togglePanel.defaultShortcut = Shortcut(
            key: "v",
            modifiers: [.command, .shift]
        )

        // ... 其他初始化
    }
}
```

**考虑的替代方案**：
- 使用 `NSEvent.addGlobalMonitorForEvents`：需要手动管理快捷键冲突、系统保留快捷键检测
- 使用 `CGEventTap`：需要配置辅助功能权限，实现复杂度高

---

### 4. 布局实现：AppKit 窗口 + SnapKit，内部 UI 使用 SwiftUI

**决策**：主面板窗口使用 AppKit 的 `NSPanel`，布局使用 SnapKit；内部 UI 组件（搜索框、列表、预览）使用 SwiftUI，通过 `NSHostingController` 嵌入。

**理由**：
- `NSPanel` 适合工具类面板，默认非激活窗口
- SnapKit 提供简洁的约束语法，符合 macOS 架构规范
- SwiftUI 提供声明式 UI，开发效率高
- 混合使用兼顾性能和开发效率

**窗口实现**（`platform/macos/Sources/View/MainPanelWindowController.swift`）：
```swift
import Cocoa
import SnapKit

final class MainPanelWindowController: NSWindowController {
    private let hostingController: NSHostingController<MainPanelView>
    private let viewModel: MainPanelViewModel

    init(viewModel: MainPanelViewModel) {
        self.viewModel = viewModel
        let view = MainPanelView(viewModel: viewModel)
        self.hostingController = NSHostingController(rootView: view)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.nonactivatingPanel, .titled, .closable],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true

        super.init(window: panel)
        setupLayout()
    }

    private func setupLayout() {
        guard let panel = window, let contentView = panel.contentView else { return }

        contentView.addSubview(hostingController.view)
        hostingController.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    func show(at point: NSPoint) {
        guard let panel = window else { return }
        panel.setFrameOrigin(point)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        window?.orderOut(nil)
    }
}
```

**SwiftUI UI 实现**（`platform/macos/Sources/View/MainPanelView.swift`）：
```swift
import SwiftUI

struct MainPanelView: View {
    @ObservedObject var viewModel: MainPanelViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 上：搜索框
            SearchBar(text: Binding(
                get: { viewModel.state.searchQuery },
                set: { viewModel.send(.searchChanged($0)) }
            ))

            Divider()

            // 中：左右分栏
            HSplitView {
                // 左：搜索结果列表
                ItemList(
                    items: viewModel.state.items,
                    selectedItem: viewModel.state.selectedItem,
                    onSelect: { viewModel.send(.itemSelected($0)) }
                )

                // 右：预览
                PreviewPanel(item: viewModel.state.selectedItem)
            }

            Divider()

            // 下：Footer（快捷键说明）
            FooterView()
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}
```

**考虑的替代方案**：
- 纯 AppKit 布局：开发效率低，代码冗长
- 纯 SwiftUI 布局：窗口管理、全局快捷键等系统集成更困难

---

### 5. 数据库版本管理：使用 PRAGMA user_version 进行增量迁移

**决策**：使用 SQLite 的 `PRAGMA user_version` 进行版本管理，实现增量迁移策略。

**理由**：
- `PRAGMA user_version` 是 SQLite 内置的版本跟踪机制，无需额外表
- 支持增量迁移（version 1 → 2 → 3），每个迁移独立可测试
- 迁移失败时可以回滚到之前版本
- 符合业界最佳实践

**迁移策略**：

1. **版本跟踪**：使用 `PRAGMA user_version` 存储当前数据库版本
2. **增量迁移**：每个版本对应一个迁移脚本（`000N-description.sql`）
3. **原子性**：迁移操作在事务中执行，失败则回滚
4. **向前兼容**：支持从任何旧版本迁移到最新版本

**迁移文件结构**（`core/migrations/`）：
```
core/migrations/
├── 0001-initial-schema.sql       # 版本 1：初始 schema
├── 0002-add-search-index.sql    # 版本 2：添加搜索索引
└── 0003-add-preview-field.sql   # 版本 3：添加预览字段
```

**迁移文件示例**（`core/migrations/0001-initial-schema.sql`）：
```sql
-- 版本 1：初始 schema
CREATE TABLE IF NOT EXISTS items (
    id TEXT PRIMARY KEY,
    type TEXT NOT NULL,
    content TEXT,
    image_path TEXT,
    image_width INTEGER,
    image_height INTEGER,
    image_format TEXT,
    create_time_ms INTEGER NOT NULL,
    update_time_ms INTEGER NOT NULL,
    last_copy_time_ms INTEGER NOT NULL,
    source_app_id TEXT NOT NULL DEFAULT '',
    content_hash TEXT NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_items_last_copy_time ON items(last_copy_time_ms DESC);
CREATE INDEX IF NOT EXISTS idx_items_type ON items(type);
CREATE UNIQUE INDEX IF NOT EXISTS idx_items_type_hash ON items(type, content_hash);

PRAGMA user_version = 1;
```

**迁移文件示例**（`core/migrations/0002-add-search-index.sql`）：
```sql
-- 版本 2：添加搜索索引
CREATE INDEX IF NOT EXISTS idx_items_content_search ON items(content COLLATE NOCASE);

PRAGMA user_version = 2;
```

**迁移器实现**（`core/src/history/store_sqlite.cpp` - 修改 `migrateSchema()` 方法）：
```cpp
bool SQLiteClipboardHistoryStore::migrateSchema() {
    // 读取当前版本
    int currentVersion = 0;
    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(m_db, "PRAGMA user_version;", -1, &stmt, nullptr) == SQLITE_OK) {
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            currentVersion = sqlite3_column_int(stmt, 0);
        }
        sqlite3_finalize(stmt);
    }

    // 执行增量迁移
    const std::vector<std::function<bool()>> migrations = {
        [&]() { return applyMigration(1, "0001-initial-schema.sql"); },
        [&]() { return applyMigration(2, "0002-add-search-index.sql"); },
        // 未来版本继续添加...
    };

    for (size_t i = currentVersion; i < migrations.size(); ++i) {
        if (!migrations[i]()) {
            logStoreMessage("migration failed at version " + std::to_string(i + 1));
            return false;
        }
    }

    return true;
}

bool SQLiteClipboardHistoryStore::applyMigration(int targetVersion, const std::string& migrationFile) {
    // 检查迁移文件是否存在
    const std::string migrationPath = m_baseDirectory + "/migrations/" + migrationFile;
    std::ifstream file(migrationPath);
    if (!file.is_open()) {
        logStoreMessage("migration file not found: " + migrationFile);
        return false;
    }

    // 读取迁移 SQL
    std::string sql((std::istreambuf_iterator<char>(file)),
                   std::istreambuf_iterator<char>());

    // 在事务中执行迁移
    if (sqlite3_exec(m_db, "BEGIN TRANSACTION;", nullptr, nullptr, nullptr) != SQLITE_OK) {
        logStoreMessage("failed to begin transaction");
        return false;
    }

    char* error = nullptr;
    int rc = sqlite3_exec(m_db, sql.c_str(), nullptr, nullptr, &error);
    if (rc != SQLITE_OK) {
        sqlite3_exec(m_db, "ROLLBACK;", nullptr, nullptr, nullptr);
        logStoreMessage("migration failed: " + std::string(error ? error : "unknown"));
        sqlite3_free(error);
        return false;
    }

    if (sqlite3_exec(m_db, "COMMIT;", nullptr, nullptr, nullptr) != SQLITE_OK) {
        logStoreMessage("failed to commit transaction");
        return false;
    }

    // 验证版本已更新
    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(m_db, "PRAGMA user_version;", -1, &stmt, nullptr) == SQLITE_OK) {
        if (sqlite3_step(stmt) == SQLITE_ROW) {
            const int version = sqlite3_column_int(stmt, 0);
            if (version != targetVersion) {
                logStoreMessage("version mismatch after migration");
                sqlite3_finalize(stmt);
                return false;
            }
        }
        sqlite3_finalize(stmt);
    }

    logStoreMessage("migration succeeded: version " + std::to_string(targetVersion));
    return true;
}
```

**回滚策略**：
- 迁移失败时，自动回滚事务
- 保留损坏的数据库为 `.broken` 文件
- 重新创建数据库到最新版本
- 记录失败日志供用户反馈

**考虑的替代方案**：
- 使用额外的 `schema_version` 表：增加复杂性，不如 `PRAGMA user_version` 简洁
- 每次启动都执行完整的 schema：性能差，无法跟踪增量变更

---

### 6. 搜索算法：Core 层客户端 LIKE 匹配

**决策**：搜索在 Core 层实现，使用 SQLite 的 `LIKE` 匹配算法。

**理由**：
- 剪贴板历史数据量通常较小（数百到数千条），SQLite LIKE 性能足够
- 实时搜索响应快（目标 <100ms）
- 无需引入额外的依赖或复杂机制
- 便于未来扩展（模糊搜索、正则表达式、全文搜索）

**实现**（`core/src/history/history.cpp`）：
```cpp
std::vector<ClipboardHistoryItem> ClipboardHistory::search(const SearchOptions& options) {
    std::vector<ClipboardHistoryItem> results;

    if (options.query.empty()) {
        return results;
    }

    // 使用 SQLite LIKE 查询
    const std::string sql =
        "SELECT id, content, source, timestamp, content_type, metadata "
        "FROM clipboard_items "
        "WHERE content LIKE ? "
        "ORDER BY timestamp DESC "
        "LIMIT ?;";

    sqlite3_stmt* stmt = nullptr;
    if (sqlite3_prepare_v2(m_db, sql.c_str(), -1, &stmt, nullptr) != SQLITE_OK) {
        return results;
    }

    // LIKE 查询模式：%query%
    const std::string pattern = "%" + options.query + "%";
    sqlite3_bind_text(stmt, 1, pattern.c_str(), -1, SQLITE_TRANSIENT);
    sqlite3_bind_int64(stmt, 2, static_cast<int64_t>(options.limit));

    while (sqlite3_step(stmt) == SQLITE_ROW) {
        ClipboardHistoryItem item;
        item.id = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 0));
        item.content = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 1));
        item.source = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 2));
        item.timestamp = sqlite3_column_int64(stmt, 3);
        item.contentType = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 4));
        item.metadata = reinterpret_cast<const char*>(sqlite3_column_text(stmt, 5));
        results.push_back(item);
    }

    sqlite3_finalize(stmt);
    return results;
}
```

**性能优化**：
- 添加 `content` 列的索引（版本 2 迁移）：`CREATE INDEX idx_items_content_search ON items(content COLLATE NOCASE);`
- 限制返回结果数量（默认 100 条）
- LIKE 匹配不区分大小写（`COLLATE NOCASE`）

**考虑的替代方案**：
- 全文搜索引擎（如 SQLite FTS5）：初期实现复杂度高，后续可根据性能需求添加

---

### 7. 窗口定位：基于鼠标位置和 NSScreen

**决策**：面板显示在鼠标当前所在屏幕的中心偏上位置。

**理由**：
- 多显示器环境下，用户可能在任意屏幕工作
- 基于鼠标位置的定位更符合直觉
- 避免用户需要跨屏幕查看面板

**实现**（`platform/macos/Sources/View/MainPanelWindowController.swift`）：
```swift
func show(at point: NSPoint) {
    guard let panel = window else { return }

    // 找到包含鼠标点的屏幕
    let screen = NSScreen.screens.first { screen in
        screen.frame.contains(point)
    }

    // 计算屏幕中心偏上位置
    if let screen = screen {
        let screenCenter = NSPoint(
            x: screen.frame.midX - panel.frame.width / 2,
            y: screen.frame.midY + panel.frame.height / 2 - 100 // 向上偏移 100pt
        )
        panel.setFrameOrigin(screenCenter)
    } else {
        panel.setFrameOrigin(point)
    }

    panel.makeKeyAndOrderFront(nil)
}
```

**考虑的替代方案**：
- 固定在主屏幕中心：多显示器场景下用户体验差

---

### 8. 菜单栏集成：使用 NSStatusItem

**决策**：菜单栏图标使用 `NSStatusItem`，提供"打开面板"菜单项。

**理由**：
- 符合 macOS 应用常规实践
- 提供应用入口点，方便用户访问
- 与 `LSUIElement=true` 配合，不在 Dock 显示

**实现**（`platform/macos/Sources/App.swift`）：
```swift
import AppKit

@main
struct App {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory) // LSUIElement = true

        // 创建菜单栏图标
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "📋"

        // 创建菜单
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "打开面板", action: #selector(showPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(terminate), keyEquivalent: "q"))

        statusItem.menu = menu

        // ... 组装其他依赖
    }
}
```

---

### 9. 依赖注入：Composition Root 模式

**决策**：在 `App.swift` 作为 Composition Root 组装所有依赖，ViewModel 通过依赖注入获取 Service。

**理由**：
- 符合依赖注入原则
- 便于单元测试（注入 mock 对象）
- 清晰的依赖关系

**组装代码**（`platform/macos/Sources/App.swift`）：
```swift
@main
struct App {
    static func main() {
        let app = NSApplication.shared

        // Service 层
        let historyService = ClipboardHistoryServiceImpl()

        // ViewModel 层
        let viewModel = MainPanelViewModel(
            historyService: historyService
        )

        // View 层
        let windowController = MainPanelWindowController(viewModel: viewModel)

        // 绑定 ViewModel 状态到窗口可见性
        viewModel.$state
            .map { $0.isVisible }
            .removeDuplicates()
            .sink { isVisible in
                if isVisible {
                    let mouseLocation = NSEvent.mouseLocation
                    windowController.show(at: mouseLocation)
                } else {
                    windowController.hide()
                }
            }
            .store(in: &viewModel.cancellables)

        app.run()
    }
}
```

---

## Risks / Trade-offs

### 风险 1：全局快捷键可能与其他应用冲突

**风险**：`Cmd+Shift+V` 是一个较为常用的快捷键组合，可能被其他应用占用。

**缓解措施**：
- KeyboardShortcuts 库自动检测并提示快捷键冲突
- 提供快捷键配置选项（后续功能）
- 允许用户手动禁用快捷键监听

### 风险 2：多显示器环境下的窗口定位可能不准确

**风险**：在特殊屏幕配置下（如镜像模式、不同 DPI 屏幕），计算的中心点可能不理想。

**缓解措施**：
- 添加边界检查，确保窗口完全在屏幕内
- 提供面板位置记忆功能（后续功能）
- 允许用户手动拖动面板调整位置

### 风险 3：预览大型内容可能导致性能问题

**风险**：预览大型图片或长文本时可能导致界面卡顿，违反 P2 性能响应原则（<100ms）。

**缓解措施**：
- 限制预览内容的最大尺寸和长度
- 对图片进行缩略图处理而非全尺寸显示
- 实现异步加载，避免阻塞主线程
- 添加性能监控，确保 UI 操作 <100ms

### 风险 4：Core-Platform 接口设计可能不够灵活

**风险**：早期定义的接口可能无法覆盖未来的功能需求，导致频繁 API 变更。

**缓解措施**：
- 接口设计时保持一定的扩展性（如使用可选参数、参数化配置）
- 预留版本化接口的机制
- 保持接口变更的向后兼容性（遵循 P5 可扩展架构原则）

### 风险 5：SQLite LIKE 性能可能不满足 <100ms 响应要求

**风险**：当历史记录数量增长时，SQLite LIKE 查询可能超过 100ms，违反 P2 性能响应原则。

**缓解措施**：
- 添加 `content` 列的索引（`COLLATE NOCASE`）
- 实现结果缓存机制
- 考虑使用 SQLite FTS5 全文搜索（如需要）
- 添加性能测试，确保搜索响应 <100ms

### 风险 6：数据库迁移可能失败导致数据丢失

**风险**：迁移脚本执行失败可能导致数据库处于不一致状态。

**缓解措施**：
- 所有迁移操作在事务中执行，失败自动回滚
- 保留损坏的数据库为 `.broken` 文件
- 提供迁移失败日志，便于问题诊断
- 在开发阶段进行充分的迁移测试

---

## Migration Plan

### 部署步骤

#### Step 1: Core 层开发

**新增文件**：
- `core/include/pasty/history/search.h`（搜索接口）
- `core/include/pasty/api/history_search_api.h`（搜索 C API）
- `core/src/history/search.cpp`（搜索实现）
- `core/migrations/0001-initial-schema.sql`（版本 1：初始 schema）
- `core/migrations/0002-add-search-index.sql`（版本 2：搜索索引）

**修改文件**：
- `core/include/pasty/history/history.h`（新增 `search()` 方法）
- `core/include/pasty/history/types.h`（新增 `SearchOptions` 结构体）
- `core/include/pasty/api/history_api.h`（新增搜索 C API）
- `core/src/history/store_sqlite.cpp`（改进 `migrateSchema()` 方法，实现增量迁移）
- `core/CMakeLists.txt`（添加新源文件和迁移文件）

**编译验证**：
```bash
./scripts/core-build.sh Debug
```

#### Step 2: macOS 平台层开发

**新增文件**：
```
platform/macos/Sources/
├── ViewModel/
│   └── MainPanelViewModel.swift
├── Model/
│   ├── ClipboardItemRow.swift
│   └── ClipboardSearchResult.swift
├── View/
│   ├── MainPanelView.swift
│   └── MainPanelWindowController.swift
└── Utils/
    ├── HotkeyService.swift
    ├── HotkeyServiceImpl.swift
    ├── ClipboardHistoryService.swift
    ├── ClipboardHistoryServiceImpl.swift
    └── CombineExtensions.swift
```

**修改文件**：
- `platform/macos/Sources/App.swift`（Composition Root，设置默认快捷键）
- `platform/macos/Info.plist`（添加 `LSUIElement = true`）
- `platform/macos/project.yml`（添加新源文件、SPM 依赖 KeyboardShortcuts）

**SPM 依赖配置**（`platform/macos/project.yml`）：
```yaml
packages:
  KeyboardShortcuts:
    url: https://github.com/sindresorhus/KeyboardShortcuts
    from: "2.0.0"
  SnapKit:
    url: https://github.com/SnapKit/SnapKit
    from: "5.0.0"
```

**编译验证**：
```bash
cd platform/macos
xcodegen generate
./scripts/platform-build-macos.sh Debug
```

#### Step 3: 集成测试

**功能测试**：
- 测试快捷键唤起面板
- 测试菜单栏"打开面板"功能
- 测试多屏幕环境下的窗口定位
- 测试搜索功能的实时响应
- 测试不同类型内容的预览显示

**迁移测试**：
- 测试从旧版本数据库迁移到新版本
- 测试迁移失败时的回滚机制
- 测试迁移后的数据完整性

**性能测试**：
- 测试搜索响应时间（目标 <100ms）
- 测试 UI 操作响应时间（目标 <100ms）
- 测试内存占用（目标 <200MB/10K条目）
- 测试应用启动时间（目标 <2s）

#### Step 4: 性能优化

- 根据测试结果优化 SQLite 查询性能
- 优化图片预览加载机制
- 优化 Combine 数据流

### 回滚策略

由于这是初始功能实现，回滚策略相对简单：
- 如遇到严重问题，可以暂时禁用全局快捷键注册
- 通过代码回滚到上一个稳定版本
- 保持 Core 层接口稳定，便于快速替换实现
- 数据库迁移失败时，保留 `.broken` 文件便于问题诊断

---

## Files to Modify

### Core 层
- `core/include/pasty/history/history.h`（新增 `search()` 方法）
- `core/include/pasty/history/types.h`（新增 `SearchOptions`）
- `core/include/pasty/api/history_api.h`（新增搜索 C API）
- `core/src/history/history.cpp`（实现 `search()`）
- `core/src/history/store_sqlite.cpp`（改进 `migrateSchema()`）
- `core/migrations/`（新增迁移文件）
- `core/CMakeLists.txt`（添加新源文件）

### macOS 平台层
- `platform/macos/Sources/App.swift`（Composition Root，设置默认快捷键）
- `platform/macos/Info.plist`（`LSUIElement = true`）
- `platform/macos/project.yml`（配置源文件、SPM 依赖）
- 新增 `platform/macos/Sources/ViewModel/`（所有 ViewModel）
- 新增 `platform/macos/Sources/Model/`（所有 Model）
- 新增 `platform/macos/Sources/View/`（所有 View）
- 新增 `platform/macos/Sources/Utils/`（所有 Service）

---

## Cross-Platform Compatibility

本设计严格遵循 Core-Platform 分层架构：

- **Core 层**（可移植）：
  - 纯 C++17 实现，无平台依赖
  - 定义数据模型和业务逻辑
  - 通过接口（C API）与 Platform 层交互

- **Platform 层**（macOS 特定）：
  - 实现 Core 定义的接口
  - 处理 UI、系统集成、权限等平台特定逻辑
  - 未来扩展其他平台时，Core 层代码无需修改

**跨平台扩展路径**：
- Windows：复用 Core 层接口，实现 Windows 特定的 UI 和系统集成
- Linux：复用 Core 层接口，实现 Linux 特定的 UI 和系统集成

---

## Testing Plan

### 单元测试

**Core 层测试**（`core/tests/`）：
- 测试 `ClipboardHistory::search()` 方法的正确性
- 测试 LIKE 匹配的各种场景
- 测试边界情况（空查询、特殊字符等）
- 测试数据库迁移的各个版本
- 测试迁移失败时的回滚机制

**macOS 层测试**：
- 测试 `MainPanelViewModel` 的 Action → State 转换
- 测试 `ClipboardHistoryService` 的数据映射
- 测试 `HotkeyService` 的快捷键注册

### 集成测试

- 测试完整的数据流：用户输入搜索 → ViewModel 调用 Service → Core 搜索 → 返回结果 → UI 更新
- 测试全局快捷键的触发流程
- 测试窗口定位的正确性
- 测试数据库迁移的完整流程

### 性能测试

- 搜索响应时间测试（<100ms）
- UI 操作响应时间测试（<100ms）
- 内存占用测试（<200MB/10K条目）
- 应用启动时间测试（<2s）

### 迁移测试

- 测试从空数据库到版本 1 的迁移
- 测试从版本 1 到版本 2 的增量迁移
- 测试迁移失败时的数据完整性
- 测试跨版本跳跃迁移（如直接从版本 1 迁移到版本 3）

---

## Open Questions

1. **搜索匹配的灵敏度**：是否需要支持大小写敏感、部分匹配等配置？（初期实现简单的 LIKE 匹配，后续根据用户反馈调整）
2. **预览内容的最大限制**：文本预览最大字符数、图片预览的最大分辨率等具体数值需要通过用户体验测试确定。
3. **面板隐藏的触发条件**：除了失去焦点外，是否支持按 Esc 键或再次按快捷键隐藏？（根据用户体验决定）
4. **国际化支持**：是否需要支持多语言？（后续需求）
5. **KeyboardShortcuts 默认快捷键设置**：如何正确设置默认快捷键并持久化到 UserDefaults？（需要验证库的具体 API）

---

我已阅读agents-development-flow.md、constitution.md、project-structure.md、platform/macos/ARCHITECTURE.md、core/ARCHITECTURE.md。
