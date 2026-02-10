## ADDED Requirements

### Requirement: 核心日志接口 (Core Logging Interface)
系统 **必须** 在 Core 层提供统一的、线程安全的日志接口 (`pasty::Logger`)，将日志请求与底层实现解耦。

#### Scenario: 初始化
- **WHEN** Core 系统初始化时
- **THEN** `pasty::Logger` **必须** 支持配置回调函数，以便进行平台特定的日志处理

#### Scenario: 回调注册
- **WHEN** 平台通过 `Logger::init` 注册日志回调时
- **THEN** 所有后续的日志事件 **必须** 路由到此回调

### Requirement: 日志等级 (Log Levels)
系统 **必须** 定义标准的日志等级，以区分日志消息的重要性。

#### Scenario: 等级定义
- **WHEN** 记录日志消息时
- **THEN** **必须** 指定以下等级之一：VERBOSE, DEBUG, INFO, WARN, ERROR

#### Scenario: 等级过滤
- **WHEN** 发起的日志请求等级低于当前配置的等级时
- **THEN** 系统 **必须** 忽略该请求，**不** 调用回调
- **AND** 系统 **必须** 跳过该请求昂贵的字符串格式化操作

### Requirement: 日志宏 (Logging Macros)
系统 **必须** 为每个日志等级提供 C++ 宏（如 `PASTY_LOG_INFO`），以简化使用并捕获上下文。

#### Scenario: 上下文捕获
- **WHEN** 开发者使用日志宏时
- **THEN** 宏 **必须** 自动捕获当前的源文件名和行号
- **AND** 将它们传递给日志系统

#### Scenario: 安全格式化
- **WHEN** 使用带有格式化字符串的日志宏时
- **THEN** 系统 **必须** 在传递给回调之前安全地格式化消息（例如使用 `snprintf`）
