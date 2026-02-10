## 1. Core 层基础架构

- [ ] 1.1 在 `core/include/pasty/logger.h` 定义日志等级 `LogLevel` 枚举。
- [ ] 1.2 在 `core/include/pasty/logger.h` 定义回调函数类型 `LogCallback`。
- [ ] 1.3 实现 `pasty::Logger` 类 (在 `core/src/logger.cpp`)，支持 `init` 和 `log` 静态方法。
- [ ] 1.4 定义 C++ 日志宏 (`PASTY_LOG_INFO`, `PASTY_LOG_DEBUG` 等)，实现等级过滤和 File/Line 捕获。
- [ ] 1.5 编写 Core 日志模块单元测试 `tests/logger_test.cpp` 并通过测试。

## 2. Platform 层集成 (macOS)

- [ ] 2.1 修改 `platform/macos/project.yml`，添加 `CocoaLumberjack` 和 `CocoaLumberjackSwift` 依赖。
- [ ] 2.2 运行 `xcodegen` 更新 Xcode 项目。
- [ ] 2.3 创建 `platform/macos/Sources/Utils/LoggerService.swift`，实现单例日志服务。
- [ ] 2.4 在 `LoggerService` 中配置 `DDOSLogger` (控制台) 和 `DDFileLogger` (文件，路径为 `appData/Logs`)。
- [ ] 2.5 实现 C++ 回调桥接函数，并在 `App.swift` 或 `LoggerService` 初始化时注入到 Core。

## 3. 全局替换与埋点

- [ ] 3.1 全局搜索并替换 Core 层中的 `std::cout`, `printf` 等为 `PASTY_LOG_*` 宏。
- [ ] 3.2 全局搜索并替换 Platform 层 (Swift) 中的 `print`, `NSLog` 为 `DDLog*`。
- [ ] 3.3 数据层埋点：在 `store_sqlite.cpp` 中添加 SQL 执行、事务和错误日志。
- [ ] 3.4 业务层埋点：在 `history.cpp` 中添加条目变动日志。
- [ ] 3.5 OCR 埋点：在 `OCRService.swift` 中添加请求和结果日志。
- [ ] 3.6 生命周期埋点：在 `App.swift` 添加启动/退出日志。

## 4. 文档更新

- [ ] 4.1 更新 `core/ARCHITECTURE.md`：增加日志模块说明和 Core 层日志开发规范。
- [ ] 4.2 更新 `platform/macos/ARCHITECTURE.md`：说明 Platform 日志架构和 CocoaLumberjack 使用规范。
- [ ] 4.3 更新 `docs/agents-development-flow.md`：在开发规范中强调使用统一日志接口，禁止使用 `print`/`cout`。

## 5. 验证

- [ ] 5.1 运行 macOS 应用，验证控制台是否有格式化日志。
- [ ] 5.2 检查 `~/Library/Application Support/Pasty2/Logs` 是否生成日志文件。
- [ ] 5.3 触发 OCR 和数据库操作，验证关键日志是否按预期记录。
- [ ] 5.4 验证 Release 模式下 DEBUG 日志是否被过滤。
