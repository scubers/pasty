## Why

当前工程缺乏统一、高性能且跨平台的日志系统，导致难以追踪数据流向（特别是剪贴板数据变化）和调试关键行为（如 OCR、数据库操作）。为了提升应用的可观测性、调试效率并满足跨平台架构要求，需要引入成熟的日志库并建立分层日志架构。

## What Changes

*   **架构升级**:
    *   在 Core 层设计统一的日志接口，解耦具体实现。
    *   实现 Core 到 Platform 的日志回调机制，确保 Core 层纯净性。
    *   在 Platform 层 (macOS) 引入 `CocoaLumberjack` 并进行封装，避免业务代码直接依赖三方库。
*   **全面替换与埋点**:
    *   替换项目中现有的所有临时日志（如 `std::cout`, `print`）。
    *   在所有数据操作路径（数据走向）增加日志。
    *   在所有关键行为（包括但不限于 OCR 流程、数据库操作、生命周期、用户交互、剪贴板监控等）增加日志，确保全链路可追踪。
*   **性能与策略**:
    *   实施严格的日志等级策略：
        *   高频操作（如鼠标移动、频繁状态检查）使用 `DEBUG` 级别。
        *   低频关键操作（如用户交互、配置变更）使用 `INFO` 级别。
        *   异常情况使用 `ERROR` 级别。

## Capabilities

### New Capabilities
- `core-logging-architecture`: 定义 Core 层日志接口、跨平台回调机制及 C++ 侧的日志宏/工具封装。
- `platform-logging-integration`: macOS 平台的日志服务实现，集成 CocoaLumberjack，并桥接 Core 层日志回调。
- `system-observability`: 定义关键业务路径（数据流、OCR、数据库）的日志埋点规范与等级策略。

### Modified Capabilities
<!-- No existing functional specs are modified by this infrastructure change. -->

## Impact

*   **Dependencies**: 新增 `CocoaLumberjack` (通过 Swift Package Manager)。
*   **Core Layer**: 新增日志模块，修改现有业务逻辑以注入日志调用。
*   **Platform Layer**: 新增日志服务封装，初始化逻辑。
*   **Performance**: 需确保日志系统（特别是高频 Debug 日志）在 Release 模式或非 Debug 级别下对性能影响微乎其微。
