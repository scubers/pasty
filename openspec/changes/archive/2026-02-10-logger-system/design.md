## Context

Pasty 目前依赖分散的 `std::cout` 和 `print` 进行调试，缺乏统一的日志管理、持久化存储和等级控制。随着功能增加（特别是 OCR 和数据库操作），调试难度增大。我们需要一个跨平台兼容、高性能的日志系统，既能满足 Core 层的调试需求，又能利用各平台的成熟日志生态（如 macOS 的 CocoaLumberjack）。

## Goals / Non-Goals

**Goals:**
*   建立 Core 层统一日志接口，解耦具体实现。
*   macOS 平台集成 `CocoaLumberjack`，实现日志持久化和控制台输出。
*   实现 Core -> Platform 的日志回调，使 C++ Core 的日志能统一由 Platform 层处理。
*   统一日志格式和等级策略，确保关键路径（OCR、Database）可观测。

**Non-Goals:**
*   在此阶段实现日志上传/云同步功能。
*   实现自定义的 C++ 文件日志库（Core 层不直接写文件，交由 Platform 处理）。

## Decisions

### 1. Core 层日志架构
*   **设计**: 在 `core/include/pasty/logger.h` 中定义日志等级枚举 (`LogLevel`) 和回调函数类型 (`LogCallback`)。
*   **实现**: 提供静态方法 `Logger::init(callback)` 和 `Logger::log(level, tag, message)`。
*   **封装**: 提供宏 `PASTY_LOG_INFO(tag, fmt, ...)` 等，自动注入 `__FILE__`, `__LINE__`，并使用 `fmt` 风格格式化（若引入 fmt 库）或 `snprintf`。
    *   *Rationale*: 宏可以方便地捕获源码位置，且能在预处理阶段根据 build type 移除部分日志（如果需要）。
    *   *Performance*: 在宏内部判断 `Logger::getLevel() <= currentLevel`，避免不必要的字符串格式化开销。

### 2. Platform 集成 (macOS)
*   **库选择**: 使用 `CocoaLumberjack/Swift`。
    *   *Rationale*: 成熟、高性能、线程安全、支持文件轮转。
*   **输出目标 (Targets)**:
    *   **Console**: 使用 `DDOSLogger` 输出到系统控制台 (Console.app)，方便开发调试。
    *   **File**: 使用 `DDFileLogger` 输出到本地文件，用于持久化记录和用户反馈。
*   **文件存储路径**:
    *   路径: `~/Library/Application Support/Pasty/Logs` (即 `AppPaths.appDataDirectory/Logs`)。
    *   策略: 每日滚动，保留最近 7 天日志，单个文件最大 10MB。
*   **适配器**: 创建 `LoggerService` 单例。
    *   初始化 CocoaLumberjack (`DDLog`, `DDFileLogger`, `DDOSLogger`)。
    *   将 C++ 回调桥接到 Swift，在 Swift 中调用 `DDLogXXX`。
*   **桥接**: 使用 `@_cdecl` 暴露 Swift 函数供 C++ 调用，或通过 C++ `std::function` 传递 lambda。考虑到跨语言边界，使用 C 风格函数指针作为回调最稳健。

### 3. 日志等级与埋点规划
*   **等级定义**: `VERBOSE`, `DEBUG`, `INFO`, `WARN`, `ERROR`。
*   **默认配置**: Debug build 开启 DEBUG，Release build 开启 INFO。
*   **关键埋点清单**:
    *   **数据层 (Core/History & Store)**:
        *   SQL 执行耗时与语句 (DEBUG)。
        *   事务开始/提交/回滚 (INFO)。
        *   数据库打开/关闭/迁移 (INFO)。
        *   所有 SQL 错误/约束冲突 (ERROR)。
    *   **业务层 (Core/History)**:
        *   剪贴板条目添加/删除/更新 (INFO, 包含 ID 和 Type，但不记录敏感内容)。
        *   搜索请求与结果数量 (DEBUG)。
        *   缓存命中/未命中 (VERBOSE)。
    *   **OCR 服务 (Platform/OCR)**:
        *   OCR 请求发起 (INFO, 包含 Image Hash)。
        *   OCR 识别成功 (INFO, 包含耗时)。
        *   OCR 识别失败 (ERROR, 包含错误码)。
    *   **应用生命周期 (Platform/App)**:
        *   App 启动/退出 (INFO, 包含版本号)。
        *   窗口前台/后台切换 (DEBUG)。
        *   系统权限变更 (INFO)。
    *   **设置变更 (Core/Settings)**:
        *   配置项变更 (INFO, Old -> New)。

## Risks / Trade-offs

*   **Risk**: 跨语言回调可能带来性能开销。
    *   *Mitigation*: Core 层增加 Level Check，低优先级日志直接在 C++ 侧过滤，不触发回调。
*   **Risk**: 字符串格式化安全问题。
    *   *Mitigation*: 优先使用安全的格式化方法，或者在 Core 层只传递 safe string。建议在 C++ 侧完成格式化传递最终 string 给 platform。

## Migration Plan

1.  引入 CocoaLumberjack 依赖。
2.  实现 Core 日志基础架构。
3.  实现 macOS 日志适配层。
4.  全局替换 `std::cout` / `print`。
5.  在关键业务逻辑中补充日志。
