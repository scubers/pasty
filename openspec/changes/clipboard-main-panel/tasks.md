## 1. Core 层实现

- [ ] 1.1 在 `core/include/pasty/history/history.h` 中添加 `SearchOptions` 结构体
- [ ] 1.2 在 `core/include/pasty/history/history.h` 中添加 `search()` 方法声明到 `ClipboardHistory` 类
- [ ] 1.3 在 `core/include/pasty/history/types.h` 中确保 `ClipboardHistoryItem` 包含所有必需字段
- [ ] 1.4 在 `core/include/pasty/api/history_api.h` 中添加 `pasty_history_search()` C API
- [ ] 1.5 在 `core/include/pasty/api/history_api.h` 中添加 `pasty_history_get_json()` C API
- [ ] 1.6 在 `core/include/pasty/api/history_api.h` 中添加 `pasty_free_string()` C API
- [ ] 1.7 在 `core/src/history/history.cpp` 中实现 `ClipboardHistory::search()` 方法
- [ ] 1.8 在 `core/src/history/history.cpp` 中实现 LIKE 查询逻辑
- [ ] 1.9 在 `core/src/Pasty.cpp` 中实现新的 C API 函数
- [ ] 1.10 在 `core/CMakeLists.txt` 中添加新源文件到编译目标

## 2. 数据库迁移实现

- [ ] 2.1 创建 `core/migrations/` 目录
- [ ] 2.2 创建 `core/migrations/0001-initial-schema.sql` 迁移文件（版本 1）
- [ ] 2.3 创建 `core/migrations/0002-add-search-index.sql` 迁移文件（版本 2）
- [ ] 2.4 在 `core/src/history/store_sqlite.cpp` 中实现 `migrateSchema()` 版本读取逻辑
- [ ] 2.5 在 `core/src/history/store_sqlite.cpp` 中实现 `applyMigration()` 方法
- [ ] 2.6 在 `core/src/history/store_sqlite.cpp` 中实现增量迁移执行逻辑
- [ ] 2.7 在 `core/src/history/store_sqlite.cpp` 中实现事务回滚机制
- [ ] 2.8 在 `core/src/history/store_sqlite.cpp` 中实现迁移失败日志记录
- [ ] 2.9 在 `core/src/history/store_sqlite.cpp` 中添加 `content` 列搜索索引优化
- [ ] 2.10 在 `core/CMakeLists.txt` 中添加迁移文件到构建目标

## 3. macOS 平台层环境配置

- [ ] 3.1 在 `platform/macos/project.yml` 中添加 KeyboardShortcuts SPM 依赖（2.0.0）
- [ ] 3.2 在 `platform/macos/project.yml` 中添加 SnapKit SPM 依赖（5.0.0）
- [ ] 3.3 创建 `platform/macos/Sources/` 目录结构
- [ ] 3.4 创建 `platform/macos/Sources/ViewModel/` 目录
- [ ] 3.5 创建 `platform/macos/Sources/Model/` 目录
- [ ] 3.6 创建 `platform/macos/Sources/View/` 目录
- [ ] 3.7 创建 `platform/macos/Sources/Utils/` 目录
- [ ] 3.8 运行 `cd platform/macos && xcodegen generate` 生成 Xcode 工程
- [ ] 3.9 验证 `platform/macos/Pasty2.xcodeproj` 已正确生成
- [ ] 3.10 在 `platform/macos/Info.plist` 中添加 `LSUIElement` 键并设置为 `true`

## 4. Model 层实现

- [ ] 4.1 创建 `platform/macos/Sources/Model/ClipboardItemRow.swift` 文件
- [ ] 4.2 实现 `ClipboardItemRow` 结构体（Presentation Model）
- [ ] 4.3 添加从 Core 类型到 Presentation Model 的映射逻辑
- [ ] 4.4 实现 `Equatable` 协议支持
- [ ] 4.5 创建 `platform/macos/Sources/Model/ClipboardSearchResult.swift` 文件
- [ ] 4.6 实现 `ClipboardSearchResult` 结构体（搜索结果模型）
- [ ] 4.7 添加搜索元数据字段（结果数量、查询时间）

## 5. Service/Adapter 层实现

- [ ] 5.1 创建 `platform/macos/Sources/Utils/HotkeyService.swift` 文件
- [ ] 5.2 定义 `HotkeyService` 协议
- [ ] 5.3 添加 `register(name:) -> AnyPublisher` 方法声明
- [ ] 5.4 添加 `unregister()` 方法声明
- [ ] 5.5 创建 `platform/macos/Sources/Utils/HotkeyServiceImpl.swift` 文件
- [ ] 5.6 实现 `HotkeyServiceImpl` 类，使用 KeyboardShortcuts 库
- [ ] 5.7 添加 KeyboardShortcuts 库 import 语句
- [ ] 5.8 实现快捷键注册方法（返回 Publisher）
- [ ] 5.9 实现快捷键名称扩展（`KeyboardShortcuts.Name.togglePanel`）
- [ ] 5.10 创建 `platform/macos/Sources/Utils/ClipboardHistoryService.swift` 文件
- [ ] 5.11 定义 `ClipboardHistoryService` 协议
- [ ] 5.12 添加 `search(query:limit:) -> AnyPublisher` 方法声明
- [ ] 5.13 创建 `platform/macos/Sources/Utils/ClipboardHistoryServiceImpl.swift` 文件
- [ ] 5.14 实现 `ClipboardHistoryServiceImpl` 类
- [ ] 5.15 实现 Core C API 调用（`pasty_history_search()`）
- [ ] 5.16 实现 JSON 数据解析（解析 C API 返回的 JSON 字符串）
- [ ] 5.17 实现 C 字符串内存管理（调用 `pasty_free_string()`）
- [ ] 5.18 创建 `platform/macos/Sources/Utils/CombineExtensions.swift` 文件
- [ ] 5.19 添加 Combine 辅助扩展（如 debounce 操作）

## 6. ViewModel 层实现

- [ ] 6.1 创建 `platform/macos/Sources/ViewModel/MainPanelViewModel.swift` 文件
- [ ] 6.2 定义 `MainPanelViewModel` 类，标记为 `@MainActor`
- [ ] 6.3 定义 `State` 结构体（包含 isVisible、items、selectedItem、searchQuery、isLoading、errorMessage）
- [ ] 6.4 实现 State 为 `Equatable` 协议
- [ ] 6.5 定义 `Action` 枚举（togglePanel、showPanel、hidePanel、searchChanged、itemSelected）
- [ ] 6.6 添加 `@Published private(set) var state` 属性
- [ ] 6.7 添加 `private var cancellables = Set<AnyCancellable>()` 属性
- [ ] 6.8 定义 `historyService` 和 `hotkeyService` 依赖注入属性
- [ ] 6.9 实现 `init()` 方法，注入依赖
- [ ] 6.10 实现 `send(_ action:)` 方法，处理所有 Action
- [ ] 6.11 实现 `private func search(query:)` 方法
- [ ] 6.12 实现 `private func setupHotkey()` 方法
- [ ] 6.13 实现 Combine 流水线（调用 Service，更新 State）
- [ ] 6.14 添加错误处理逻辑（捕获 Service 错误并更新 errorMessage）
- [ ] 6.15 实现搜索去抖动（debounce）优化

## 7. View 层实现 - AppKit 窗口

- [ ] 7.1 创建 `platform/macos/Sources/View/MainPanelWindowController.swift` 文件
- [ ] 7.2 定义 `MainPanelWindowController` 类继承自 `NSWindowController`
- [ ] 7.3 添加 `hostingController` 属性（`NSHostingController<MainPanelView>`）
- [ ] 7.4 添加 `viewModel` 属性
- [ ] 7.5 实现 `init(viewModel:)` 方法
- [ ] 7.6 创建 `NSPanel` 实例（非激活面板、floating 级别）
- [ ] 7.7 设置 panel 属性（title 隐藏、可拖动、floating）
- [ ] 7.8 初始化 `NSHostingController` 并设置 SwiftUI View
- [ ] 7.9 调用 `super.init(window:)` 初始化父类
- [ ] 7.10 添加 SnapKit import 语句
- [ ] 7.11 实现 `private func setupLayout()` 方法
- [ ] 7.12 使用 SnapKit 添加约束（`make.edges.equalToSuperview()`）
- [ ] 7.13 实现 `func show(at point:)` 方法
- [ ] 7.14 实现屏幕检测逻辑（`NSScreen.screens.first`）
- [ ] 7.15 实现屏幕中心偏上计算（约 100pt）
- [ ] 7.16 实现 `func hide()` 方法
- [ ] 7.17 添加边界检查逻辑（确保窗口在屏幕内）

## 8. View 层实现 - SwiftUI 视图

- [ ] 8.1 创建 `platform/macos/Sources/View/MainPanelView.swift` 文件
- [ ] 8.2 定义 `MainPanelView` 结构体为 `View`
- [ ] 8.3 添加 `@ObservedObject var viewModel` 属性
- [ ] 8.4 实现 `var body: some View` 计算属性
- [ ] 8.5 实现 `VStack` 三层布局
- [ ] 8.6 实现顶部搜索栏（SearchBar 组件）
- [ ] 8.7 添加 `Divider()` 分隔符
- [ ] 8.8 实现中间 `HSplitView` 左右分栏
- [ ] 8.9 实现左侧 ItemList 组件
- [ ] 8.10 实现右侧 PreviewPanel 组件
- [ ] 8.11 添加底部 `Divider()` 分隔符
- [ ] 8.12 实现底部 FooterView 组件
- [ ] 8.13 设置 `.frame(minWidth: 800, minHeight: 600)` 约束
- [ ] 8.14 实现 SearchBar 组件（搜索输入框）
- [ ] 8.15 实现 ItemList 组件（结果列表，支持点击选择）
- [ ] 8.16 实现 PreviewPanel 组件（预览区，支持文本和图片）
- [ ] 8.17 实现 FooterView 组件（快捷键说明）

## 9. 菜单栏集成实现

- [ ] 9.1 在 `platform/macos/Sources/App.swift` 中创建 `NSApplication.shared` 实例
- [ ] 9.2 实现 `app.setActivationPolicy(.accessory)` 配置 LSUIElement
- [ ] 9.3 创建 `NSStatusBar.system.statusItem(withLength:)` 菜单栏图标
- [ ] 9.4 设置菜单栏图标为 "📋"
- [ ] 9.5 创建 `NSMenu()` 实例
- [ ] 9.6 添加 "打开面板" 菜单项
- [ ] 9.7 添加菜单分隔符（`NSMenuItem.separator()`）
- [ ] 9.8 添加 "退出" 菜单项，keyEquivalent 为 "q"
- [ ] 9.9 将菜单关联到菜单栏图标（`statusItem.menu = menu`）

## 10. 全局快捷键集成

- [ ] 10.1 在 `platform/macos/Sources/Utils/HotkeyService.swift` 中添加 KeyboardShortcuts 名称扩展
- [ ] 10.2 定义 `static let togglePanel = Self("togglePanel")`
- [ ] 10.3 在 `platform/macos/Sources/App.swift` 中导入 KeyboardShortcuts
- [ ] 10.4 设置默认快捷键 `KeyboardShortcuts.Name.togglePanel.defaultShortcut = Shortcut(key: "v", modifiers: [.command, .shift])`
- [ ] 10.5 在 `MainPanelViewModel` 中集成快捷键监听
- [ ] 10.6 使用 `KeyboardShortcuts.onKeyDown(for: .togglePanel)` 创建 Publisher
- [ ] 10.7 将快捷键事件绑定到 `togglePanel` Action
- [ ] 10.8 添加快捷键冲突处理（捕获 KeyboardShortcuts 库的警告）

## 11. 组装和依赖注入

- [ ] 11.1 在 `platform/macos/Sources/App.swift` 中实现 Composition Root
- [ ] 11.2 实例化 `ClipboardHistoryServiceImpl`
- [ ] 11.3 实例化 `HotkeyServiceImpl`（或使用单例）
- [ ] 11.4 实例化 `MainPanelViewModel`，注入 historyService
- [ ] 11.5 实例化 `MainPanelWindowController`，注入 viewModel
- [ ] 11.6 在 ViewModel 中设置快捷键监听（注入 hotkeyService）
- [ ] 11.7 绑定 ViewModel 状态到窗口可见性
- [ ] 11.8 使用 `viewModel.$state.map { $0.isVisible }` 监听可见性变化
- [ ] 11.9 实现窗口显示逻辑（获取鼠标位置并调用 `windowController.show(at:)`）
- [ ] 11.10 实现窗口隐藏逻辑（调用 `windowController.hide()`）
- [ ] 11.11 在快捷键触发时切换面板可见性
- [ ] 11.12 添加错误处理和日志记录

## 12. 编译和构建验证

- [ ] 12.1 运行 `cd platform/macos && xcodegen generate` 重新生成 Xcode 工程
- [ ] 12.2 运行 `./scripts/core-build.sh Debug` 编译 Core 层
- [ ] 12.3 运行 `./scripts/platform-build-macos.sh Debug` 编译 macOS 平台层
- [ ] 12.4 验证 Core 层编译成功（无错误）
- [ ] 12.5 验证 macOS 平台层编译成功（无错误）
- [ ] 12.6 验证 `Pasty2.app` 已生成到 `build/macos/Build/Products/Debug/`
- [ ] 12.7 验证 SPM 依赖已正确下载和链接
- [ ] 12.8 运行应用验证基本启动（无崩溃）
- [ ] 12.9 验证菜单栏图标显示正常
- [ ] 12.10 验证全局快捷键注册成功

## 13. 功能测试

- [ ] 13.1 测试全局快捷键 Cmd+Shift+V 是否能唤起主面板
- [ ] 13.2 测试菜单栏"打开面板"功能
- [ ] 13.3 测试多显示器环境下的窗口定位
- [ ] 13.4 测试搜索框输入功能（实时搜索）
- [ ] 13.5 测试 LIKE 匹配搜索逻辑（部分匹配、不区分大小写）
- [ ] 13.6 测试搜索结果显示和更新
- [ ] 13.7 测试点击列表项后的预览显示
- [ ] 13.8 测试文本内容预览
- [ ] 13.9 测试图片内容预览
- [ ] 13.10 测试元数据显示（来源应用、时间戳）

## 14. 性能测试

- [ ] 14.1 测试搜索响应时间（目标 <100ms）
- [ ] 14.2 测试 UI 操作响应时间（目标 <100ms）
- [ ] 14.3 测试应用启动时间（目标 <2s）
- [ ] 14.4 测试内存占用（目标 <200MB/10K条目）
- [ ] 14.5 测试大文本预览加载性能
- [ ] 14.6 测试大图片预览加载性能
- [ ] 14.7 测试搜索索引优化效果
- [ ] 14.8 测试面板切换的流畅性
- [ ] 14.9 使用 Instruments 工具进行性能分析
- [ ] 14.10 记录性能测试结果

## 15. 数据库迁移测试

- [ ] 15.1 测试从空数据库到版本 1 的初始迁移
- [ ] 15.2 测试从版本 1 到版本 2 的增量迁移
- [ ] 15.3 测试迁移失败时的回滚机制
- [ ] 15.4 测试迁移后的数据完整性
- [ ] 15.5 测试 `PRAGMA user_version` 正确更新
- [ ] 15.6 测试搜索索引是否正确创建
- [ ] 15.7 测试跨版本跳跃迁移（直接从版本 0 到版本 2）
- [ ] 15.8 验证迁移事务的原子性
- [ ] 15.9 测试 `.broken` 文件是否正确保留
- [ ] 15.10 验证迁移日志记录功能

## 16. 错误处理和日志

- [ ] 16.1 在 Core 层添加迁移失败错误处理
- [ ] 16.2 在 Core 层添加搜索失败的错误处理
- [ ] 16.3 在 Platform 层添加 Core API 调用失败的错误处理
- [ ] 16.4 在 ViewModel 中添加 Service 错误的错误显示
- [ ] 16.5 实现统一的错误日志记录机制
- [ ] 16.6 添加用户友好的错误提示信息
- [ ] 16.7 实现快捷键冲突的警告显示
- [ ] 16.8 添加调试日志输出（开发阶段）
- [ ] 16.9 实现异常捕获和恢复机制
- [ ] 16.10 验证所有错误路径都覆盖

## 17. 文档和清理

- [ ] 17.1 更新 `platform/macos/ARCHITECTURE.md`（如有架构变更）
- [ ] 17.2 更新 `core/ARCHITECTURE.md`（如有架构变更）
- [ ] 17.3 添加代码注释说明关键设计决策
- [ ] 17.4 清理临时文件和调试代码
- [ ] 17.5 验证所有 TODO 注释都已处理或记录
- [ ] 17.6 运行格式化工具统一代码风格
- [ ] 17.7 验证无编译警告
- [ ] 17.8 验证无 LSP 诊断错误
- [ ] 17.9 更新 README 或文档（如有新增功能）
- [ ] 17.10 准备发布说明文档
