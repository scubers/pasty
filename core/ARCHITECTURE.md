# C++ Core Architecture (Pasty)

本文件定义 `core/` 层的架构、目录约定、构建方式及开发规范。若其它文档与本文件冲突，以本文件为准。

## Declare (MUST FOLLOW)
如果读取了本文档，**必须** 在回复我的时候在 **最后** 说："我已阅读fileName。"。其中 fileName 为当前文件名

---

## 目标与边界

- Core 层是跨平台业务逻辑层：纯 C++17，禁止平台依赖。
- Core 层是业务规则与数据模型的唯一真相来源。
- 平台层只做 UI/系统集成/适配，不承载可移植业务逻辑。
- 依赖方向固定为：`platform/* -> core`。

---

## 目录结构（以当前代码为准）

```text
core/
├── CMakeLists.txt
├── ARCHITECTURE.md
├── include/                         # 对外公开头文件（稳定边界）
│   └── pasty/
│       ├── module.modulemap
│       ├── runtime_json_api.h
│       ├── logger.h
│       ├── api/
│       │   └── runtime_json_api.h  # 兼容转发头
│       ├── common/
│       │   └── logger.h            # 兼容转发头
│       ├── history/
│       │   ├── clipboard_types.h
│       │   └── clipboard_history_types.h
│       └── runtime/
│           ├── core_runtime.h
│           └── runtime_config.h
├── migrations/
├── src/                             # Core 内部实现
│   ├── api/
│   │   ├── runtime_json_api.h
│   │   └── runtime_json_api.cpp
│   ├── application/history/
│   │   ├── clipboard_service.h
│   │   └── clipboard_service.cpp
│   ├── history/
│   │   ├── clipboard_history_store.h
│   │   └── clipboard_history_types.h
│   ├── runtime/
│   │   ├── core_runtime.h
│   │   └── core_runtime.cpp
│   ├── store/
│   │   ├── sqlite_clipboard_history_store.h
│   │   └── sqlite_clipboard_history_store.cpp
│   ├── infrastructure/settings/
│   │   ├── in_memory_settings_store.h
│   │   └── in_memory_settings_store.cpp
│   ├── ports/
│   │   └── settings_store.h
│   ├── common/
│   │   ├── logger.h
│   │   └── logger.cpp
│   ├── utils/
│   │   ├── runtime_json_utils.h
│   │   └── runtime_json_utils.cpp
│   └── thirdparty/
│       └── nlohmann/json.hpp
└── tests/
```

---

## 分层与职责

### 1) API 层（`src/api` + `include/pasty`）

- 对外暴露 JSON 化 C API（FFI 友好）。
- API 不保存全局 runtime 状态，全部通过 `pasty_runtime_ref` 路由。
- API 只做参数边界校验、序列化/反序列化与调用编排。

### 2) Runtime 层（`src/runtime`）

- `CoreRuntime` 是 Core 唯一业务入口。
- 持有并管理 service 生命周期。
- 管理启动/停止、配置与 settings 读写协同。

### 3) Application 层（`src/application`）

- `ClipboardService` 承载 history 用例编排。
- 调用 store 接口处理持久化，不暴露存储细节。

### 4) Domain/Store 抽象（`src/history`）

- 定义 `ClipboardHistoryStore` 接口和核心类型。
- 不依赖具体存储实现。

### 5) Infrastructure 层（`src/store`, `src/infrastructure`）

- `sqlite_clipboard_history_store`：history 持久化实现。
- `in_memory_settings_store`：settings 存储实现。

### 6) Utils 层（`src/utils`）

- 放通用工具函数（JSON 拼装、字符串与时间工具）。
- 不放业务规则。

---

## 关键调用链（当前实现）

平台层调用路径：

`platform -> import PastyCore -> runtime_json_api -> CoreRuntime -> ClipboardService -> ClipboardHistoryStore(SQLite实现)`

这条链路中：

- 平台创建/销毁 runtime。
- API 接口全部显式接收 runtime 引用。
- Core 内部不依赖平台状态，也不依赖全局单例。

---

## Header 边界规则

- 平台层只应依赖 `core/include` 暴露的头文件边界。
- `core/src` 下头文件属于实现细节，不作为平台层依赖契约。
- `include/pasty/api/*` 与 `include/pasty/common/*` 为兼容转发头，建议新代码优先使用：
  - `#include <pasty/runtime_json_api.h>`
  - `#include <pasty/logger.h>`

---

## 构建约定

- Core 独立构建：`./scripts/core-build.sh Debug`
- macOS 集成构建：`./scripts/platform-build-macos.sh Debug`
- `PastyCore` target 负责编译 `core/src`；公开头来自 `core/include/pasty`。

---

## 扩展规则

新增模块时必须同步：

1. 落到对应层目录（api/runtime/application/store/infrastructure/utils）。
2. 更新 `CMakeLists.txt` 与 `core/include/pasty/module.modulemap`（若对外暴露）。
3. 补充或更新本文档的目录结构与调用链说明。
