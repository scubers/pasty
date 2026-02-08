# C++ Core Architecture (Pasty2)

本文件定义 `core/` 层的架构、目录约定、构建方式及开发规范。若其它文档与本文件冲突，以本文件为准。

## Declare (MUST FOLLOW)
如果读取了本文档，**必须** 在回复我的时候在 **最后** 说："我已阅读fileName。"。其中 fileName 为当前文件名

---

## 目标与边界

- Core 层是 **跨平台业务逻辑层**：纯 C++17 实现，禁止平台依赖。
- Core 层是 **数据模型与规则的唯一真相来源**：去重、保留策略、搜索语义、存储逻辑等必须在 Core 实现。
- Platform 层（macOS/Windows/iOS/Android）是 **thin shell**：只做 UI、系统集成、适配器。
- 依赖方向永远是：`platform/*` -> `core`（单向）。Core 禁止依赖任何平台头文件/库。

---

## 目录结构（以此为准）

```text
core/
├── CMakeLists.txt              # CMake 构建配置（支持独立构建）
├── ARCHITECTURE.md             # 本文件
├── include/                    # 公共头文件（对外 API）
│   ├── pasty/                  # 命名空间对应目录
│   │   ├── pasty.h             # 主入口头文件（平台层 import 此文件）
│   │   ├── history/            # 剪贴板历史模块
│   │   │   ├── types.h         # 数据类型定义
│   │   │   ├── history.h       # ClipboardHistory 类
│   │   │   └── store.h         # ClipboardHistoryStore 接口
│   │   └── api/                # C API（供 FFI / Swift 互操作）
│   │       └── history_api.h   # 历史模块 C 接口
│   └── module.modulemap        # Swift 模块映射（保留在 include/ 根目录）
└── src/                        # 实现文件（内部）
    ├── pasty.cpp               # 主入口实现（含 C API 实现）
    └── history/                # 历史模块实现
        ├── history.cpp
        └── store_sqlite.cpp    # SQLite 存储实现
```

### 目录职责

| 目录 | 职责 |
|------|------|
| `include/pasty/` | 公共 API 头文件，平台层可 include |
| `include/pasty/history/` | 剪贴板历史模块公共接口 |
| `include/pasty/api/` | C 语言 API（供 Swift/Kotlin FFI 调用） |
| `src/` | 实现文件，不对外暴露 |
| `src/history/` | 历史模块实现 |

---

## 模块设计

### 1. History 模块 (`pasty/history/`)

剪贴板历史的核心模块，包含：

- **types.h**: 数据类型定义（`ClipboardHistoryItem`, `ClipboardHistoryIngestEvent` 等）
- **history.h**: `ClipboardHistory` 类，历史管理的主入口
- **store.h**: `ClipboardHistoryStore` 接口（存储抽象）

```cpp
// 使用示例
#include <pasty/history/history.h>
#include <pasty/history/types.h>

pasty::ClipboardHistory history(pasty::createClipboardHistoryStore());
history.initialize("/path/to/storage");
history.ingest(event);
auto result = history.list(100, "");
```

### 2. API 模块 (`pasty/api/`)

C 语言接口层，供平台层通过 FFI 调用：

```cpp
// C API（Swift 可直接调用）
#include <pasty/api/history_api.h>

pasty_history_ingest_text("Hello", "com.app.source");
const char* json = pasty_history_list_json(100);
bool success = pasty_history_search("Hello", 10, &out_json);
pasty_history_delete("item-id");
```

### 3. 主入口 (`pasty/pasty.h`)

统一入口头文件，包含所有公共 API：

```cpp
#include <pasty/pasty.h>  // 包含所有公共头文件
```

---

## 构建系统

### CMake 独立构建

Core 层支持 CMake 独立构建，不依赖 Xcode 或其他平台工具链：

```bash
# 构建
cd core
mkdir build && cd build
cmake ..
cmake --build .

# 运行测试（如果有）
ctest
```

CMake 配置要点：
- 目标名称：`PastyCore`（静态库）
- C++ 标准：C++17
- 编译选项：`-Wall -Wextra -Wpedantic`
- 依赖：SQLite3（系统库）

### 平台集成构建

- **macOS**: 通过 XcodeGen (`platform/macos/project.yml`) 集成
- **Windows**: 通过 CMake + Visual Studio
- **iOS/Android**: 待实现

### 构建脚本

```bash
# 独立构建（CMake）
./scripts/core-build.sh Debug    # 或 Release

# macOS 集成构建
./scripts/platform-build-macos.sh Debug
```

---

## 编码规范

### 命名约定

| 类型 | 风格 | 示例 |
|------|------|------|
| 命名空间 | 小写 | `pasty`, `pasty::history` |
| 类名 | PascalCase | `ClipboardHistory`, `ClipboardHistoryStore` |
| 函数 | camelCase | `initialize()`, `ingestText()` |
| 成员变量 | m_ 前缀 | `m_initialized`, `m_store` |
| 常量 | k 前缀 + PascalCase | `kMaxHistoryItems` |
| 宏 | SCREAMING_SNAKE | `PASTY_VERSION` |
| C API | pasty_ 前缀 + snake_case | `pasty_history_ingest_text()` |

### 头文件约定

```cpp
// 头文件保护（使用 #pragma once 或 include guard）
#ifndef PASTY_HISTORY_TYPES_H
#define PASTY_HISTORY_TYPES_H

// 版权声明
// Pasty2 - Copyright (c) 2026. MIT License.

// 内容...

#endif
```

### Include 顺序

```cpp
// 1. 对应的头文件（如果是 .cpp）
#include "pasty/history/history.h"

// 2. 同模块头文件
#include "store_sqlite.h"

// 3. 其他 Core 模块头文件
#include <pasty/history/types.h>

// 4. 标准库
#include <memory>
#include <string>
#include <vector>

// 5. 第三方库（如果有）
#include <sqlite3.h>
```

---

## 设计原则

### 1. 接口隔离

- 公共接口放在 `include/pasty/`
- 内部实现细节放在 `src/`（不对外暴露）
- 使用抽象接口（如 `ClipboardHistoryStore`）隔离实现

### 2. 依赖注入

```cpp
// 通过构造函数注入依赖
ClipboardHistory history(createClipboardHistoryStore());

// 便于测试：注入 mock 实现
ClipboardHistory history(std::make_unique<MockStore>());
```

### 3. 错误处理

- 优先使用返回值表示成功/失败（`bool`, `std::optional`, `Result` 类型）
- 避免跨 API 边界抛出异常
- C API 使用返回值 + 错误码模式

```cpp
// C++ API
bool initialize(const std::string& path);
std::optional<ClipboardHistoryItem> getById(const std::string& id);

// C API
bool pasty_history_delete(const char* id);  // 返回 false 表示失败
```

### 4. 内存管理

- 使用 RAII 管理资源
- 优先使用智能指针（`std::unique_ptr`, `std::shared_ptr`）
- C API 返回的字符串由 Core 管理生命周期

---

## 平台适配

### Swift 互操作

通过 `module.modulemap` 将 Core 暴露给 Swift：

```swift
import PastyCore

pasty_history_ingest_text("Hello", "com.app.source")
```

### 禁止的平台依赖

Core 层**禁止**包含以下头文件：

- `<Cocoa/Cocoa.h>`, `<AppKit/AppKit.h>`, `<UIKit/UIKit.h>`
- `<windows.h>`, `<winrt/...>`
- `<android/...>`, `<jni.h>`
- 任何平台特定的系统调用

如需平台能力，通过接口（port）定义在 Core，由平台层实现。

---

## 测试

### 单元测试

- 测试文件放在 `core/tests/`
- 使用 CMake 自带的 CTest 框架
- 通过 CMake 集成：`cmake --build .` 后运行 `ctest`

### 测试覆盖

| 模块 | 必须测试 |
|------|----------|
| History | ingest、list、delete、去重逻辑 |
| Store | SQLite 读写、数据完整性 |
| API | C 接口正确性 |

---

## 版本与兼容性

- C++ 标准：C++17（最低）
- 编译器支持：Clang 14+, GCC 11+, MSVC 2019+
- 平台：macOS 14+, Windows 10+, Ubuntu 20.04+

---

## 扩展指南

### 添加新模块

1. 在 `include/pasty/` 下创建模块目录
2. 在 `src/` 下创建对应实现目录
3. 更新 `CMakeLists.txt` 添加源文件
4. 更新 `module.modulemap` 添加头文件
5. 更新本文档的目录结构

### 添加新依赖

1. 必须是跨平台库
2. 必须得到明确批准
3. 在 `CMakeLists.txt` 中添加 `find_package` 或 `FetchContent`
4. 更新本文档记录依赖
