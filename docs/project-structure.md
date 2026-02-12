# Pasty 项目结构

## Declare (MUST FOLLOW)
如果读取了本文档，**必须** 在回复我的时候在 **最后** 说：“我已阅读fileName。”。其中 fileName 为当前文件名

## 概述

Pasty 采用 **C++ Core + Platform Shell** 架构：

- `core/`：跨平台业务逻辑与数据模型（C++17）
- `platform/*`：平台层（UI、系统能力、适配）

依赖方向固定为：`platform -> core`。

## 目录结构（当前）

```text
pasty/
├── core/
│   ├── CMakeLists.txt
│   ├── ARCHITECTURE.md
│   ├── include/                     # 对外头文件边界
│   │   └── pasty/
│   │       ├── module.modulemap
│   │       ├── runtime_json_api.h
│   │       ├── logger.h
│   │       ├── api/runtime_json_api.h
│   │       ├── common/logger.h
│   │       ├── history/
│   │       └── runtime/
│   ├── src/                         # 内部实现
│   │   ├── api/runtime_json_api.cpp
│   │   ├── application/history/
│   │   ├── runtime/
│   │   ├── history/
│   │   ├── store/
│   │   ├── infrastructure/
│   │   ├── ports/
│   │   ├── common/
│   │   ├── utils/
│   │   └── thirdparty/
│   ├── migrations/
│   └── tests/
├── platform/
│   ├── macos/
│   │   ├── project.yml
│   │   ├── ARCHITECTURE.md
│   │   └── Sources/
│   ├── windows/
│   ├── ios/
│   └── android/
├── scripts/
├── docs/
└── AGENTS.md
```

## Core 入口与 API 约定

当前 Core 入口是 `CoreRuntime`，平台层通过 JSON 化 C API 调用：

- 公开 API 头：`core/include/pasty/runtime_json_api.h`
- 运行时句柄：`pasty_runtime_ref`
- 生命周期：
  - `pasty_runtime_create`
  - `pasty_runtime_start`
  - `pasty_runtime_stop`
  - `pasty_runtime_destroy`

核心调用链：

`platform -> runtime_json_api -> CoreRuntime -> ClipboardService -> ClipboardHistoryStore`

## macOS 与 Core 的集成约定

`platform/macos/project.yml` 约定如下：

- `PastyCore` target 编译 `core/src` 的 C++ 源码。
- `Pasty` target 通过 `import PastyCore` 使用 Core，不直接依赖 `core/src`。
- 对外边界固定为 `core/include`。

## 构建命令

```bash
./scripts/core-build.sh Debug
./scripts/platform-build-macos.sh Debug
```

## 关键原则

1. Core 保持可移植，不引入平台头文件。
2. 平台层不承载可移植业务逻辑。
3. 对外 API 统一从 `core/include` 暴露。
4. 目录结构或 API 发生变化时，必须同步更新本文档与架构文档。
