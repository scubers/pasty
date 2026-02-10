## ADDED Requirements

### Requirement: macOS 日志集成
系统 **必须** 在 macOS 平台集成 `CocoaLumberjack` 库作为日志后端实现。

#### Scenario: 依赖集成
- **WHEN** 项目构建时
- **THEN** 系统 **必须** 通过 Swift Package Manager 链接 `CocoaLumberjack` 和 `CocoaLumberjackSwift` 库

### Requirement: 多目标日志输出
系统 **必须** 同时支持向控制台和本地文件输出日志。

#### Scenario: 控制台输出
- **WHEN** 产生日志时
- **THEN** 系统 **必须** 使用 `DDOSLogger` 将日志输出到系统控制台 (Console.app)

#### Scenario: 文件输出
- **WHEN** 产生日志时
- **THEN** 系统 **必须** 使用 `DDFileLogger` 将日志写入本地文件
- **AND** 文件路径 **必须** 为 `~/Library/Application Support/Pasty/Logs`

### Requirement: 文件轮转策略
系统 **必须** 对日志文件实施轮转策略以管理磁盘空间。

#### Scenario: 轮转规则
- **WHEN** 日志文件达到 10MB 或达到 24 小时
- **THEN** 系统 **必须** 滚动日志文件
- **AND** 系统 **必须** 最多保留最近 7 个日志文件

### Requirement: Core 日志桥接
macOS 平台层 **必须** 提供机制接收并处理来自 C++ Core 层的日志请求。

#### Scenario: 回调注入
- **WHEN** 应用程序启动并初始化 `Pasty` 核心时
- **THEN** 平台层 **必须** 将一个兼容 C 接口的函数指针注册到 `Logger::init`

#### Scenario: 日志转发
- **WHEN** 平台层接收到 Core 层的日志回调时
- **THEN** 平台层 **必须** 解析日志等级、Tag、Message、File 和 Line
- **AND** 调用对应的 `DDLog` 方法进行记录
