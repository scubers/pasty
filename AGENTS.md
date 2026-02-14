# AGENTS.md — Pasty 跨平台剪贴板应用

## Declare (MUST FOLLOW)
如果读取了本文档，**必须** 在回复我的时候在 **最后** 说："我已阅读AGENTS.md。"

本文件定义 AI 编码助手和贡献者的 **最高优先级、不可协商** 规则。

---

## 1. 核心原则 (Prime Directive)

- 优先选择 **最小安全变更**，确保通过编译和测试
- 如果请求与本文件冲突，**立即停止并提出替代方案**
- 所有 md 编写必须 **用中文**

---

## 2. 架构约束 (Non-negotiable)

| 约束 | 说明 |
|------|------|
| **C++ Core + Platform Shell** | Core 层是业务逻辑和数据模型的唯一真相来源 |
| **平台层是薄壳** | macOS/Windows/Linux 层仅包含 UI、系统集成、权限、适配 |
| **依赖方向固定** | `platform/* -> core`（单向），Core 禁止依赖任何平台头文件 |
| **可移植性** | Core 禁止使用 Cocoa/Win32/Android 等平台特定头文件 |

---

## 3. 构建/测试命令

### 3.1 Core (C++) 构建

```bash
# 推荐：使用脚本
./scripts/core-build.sh Debug          # Debug 构建
./scripts/core-build.sh Release        # Release 构建

# 手动 CMake
cmake -S core -B build/core -DCMAKE_BUILD_TYPE=Debug -DPASTY_BUILD_TESTS=ON
cmake --build build/core
```

**输出位置**: `build/core/lib/libPastyCore.a`

### 3.2 Core 测试

```bash
# 运行所有测试
./scripts/core-test.sh                 # 标准输出
./scripts/core-test.sh --verbose       # 详细输出

# 直接使用 ctest
cd build/core && ctest --output-on-failure

# 运行单个测试
cd build/core && ./tests/pasty_test              # 直接执行
cd build/core && ctest -R history_test -V        # 按名称运行
cd build/core && ctest -R encryption_test -V     # 加密测试
```

### 3.3 macOS 构建

```bash
./scripts/platform-build-macos.sh Debug
./scripts/platform-build-macos.sh Release
```

**输出位置**: `build/macos/Build/Products/Debug/PastyDebug.app`

### 3.4 环境检查

```bash
./scripts/check-requirements.sh        # 检查开发环境
./scripts/install-requirements.sh      # 安装依赖 (Homebrew)
```

---

## 4. 代码风格指南

### 4.1 C++ (Core 层)

| 规范 | 要求 |
|------|------|
| **标准** | C++17 |
| **命名空间** | `pasty::` |
| **类名** | PascalCase: `ClipboardService`, `CoreRuntime` |
| **函数/方法** | camelCase: `initialize()`, `getMaxHistoryCount()` |
| **成员变量** | `m_` 前缀: `m_config`, `m_clipboardService` |
| **常量/枚举** | PascalCase 枚举值: `LogLevel::Verbose` |
| **头文件保护** | `#pragma once` |
| **跨 API 边界** | 避免异常，使用返回值/错误码 |

**Include 顺序**:
1. 对应的头文件（如 `foo.cpp` 先 include `foo.h`）
2. 项目头文件 (`"..."`)
3. 系统头文件 (`<...>`)
4. 第三方库

**日志规范**:
```cpp
// Core 层必须使用 PASTY_LOG_* 宏，禁止 std::cout
PASTY_LOG_INFO("Tag", "Message: %s", value);
PASTY_LOG_ERROR("Tag", "Failed: %d", errorCode);
```

### 4.2 Swift (macOS 层)

| 规范 | 要求 |
|------|------|
| **架构** | MVVM + Combine |
| **ViewModel** | `@MainActor`, `ObservableObject` |
| **State** | 嵌套 `struct State: Equatable` |
| **Action** | 嵌套 `enum Action` |
| **数据流** | `Action -> ViewModel -> Service -> State` |
| **UI 更新** | 必须在主线程 (`receive(on: DispatchQueue.main)`) |

**日志规范**:
```swift
// macOS 层必须通过 LoggerService，禁止 print/NSLog
LoggerService.info("Application started")
LoggerService.error("Failed: \(error)")
```

**禁止**:
- View 直接调用 Core API
- View 内部持有业务状态
- 使用 `print` / `NSLog` / `DDLog*` 直接调用

### 4.3 目录结构

```
pasty/
├── core/                     # C++ Core 层
│   ├── include/pasty/        # 公开 API 头文件
│   ├── src/                  # 内部实现
│   │   ├── api/              # JSON C API
│   │   ├── application/      # 业务用例
│   │   ├── runtime/          # CoreRuntime 入口
│   │   ├── store/            # 持久化
│   │   ├── infrastructure/   # 基础设施
│   │   └── common/           # 通用工具
│   └── tests/                # 单元测试
├── platform/
│   └── macos/Sources/
│       ├── App.swift         # 入口与依赖组装
│       ├── Features/         # 功能模块
│       ├── Services/         # 服务层
│       └── DesignSystem/     # 设计系统
└── scripts/                  # 构建脚本
```

---

## 5. 质量门禁 (Before You Claim Done)

- [ ] 执行对应编译脚本验证通过
- [ ] Core 修改: 运行 `./scripts/core-build.sh && ./scripts/core-test.sh`
- [ ] macOS 修改: 运行 `./scripts/platform-build-macos.sh Debug`
- [ ] LSP 错误可忽略，以 **编译脚本结果为准**
- [ ] 不遗留关键路径的 TODO；如有必要，在 PR 描述中说明

---

## 6. LSP 与编译错误处理

**重要**: 忽略 LSP (clangd/VSCode) 报错，以 **编译脚本输出为准**！

| 情况 | 处理 |
|------|------|
| LSP 报错 + 编译通过 | 忽略 LSP |
| 编译报错 | 必须修复 |
| 编译警告 | 处理或说明原因 |

---

## 7. 禁止操作

| 操作 | 状态 |
|------|------|
| 创建新顶级目录 | ❌ 禁止 |
| 添加未批准的第三方依赖 | ❌ 禁止 |
| Core 层使用平台头文件 | ❌ 禁止 |
| `git commit` 未经确认 | ❌ 禁止 |
| `git push --force` | ❌ 禁止 |
| `as any` / `@ts-ignore` | ❌ 禁止 |
| 删除失败测试以"通过" | ❌ 禁止 |

---

## 8. 必读文档

开始任何任务前 **必须** 阅读：

| 文档 | 内容 |
|------|------|
| `docs/project-structure.md` | 项目结构、架构设计 |
| `docs/agents-development-flow.md` | 开发工作流、Git 规范 |
| `core/ARCHITECTURE.md` | Core 层架构（修改 core/ 时必读） |
| `platform/macos/ARCHITECTURE.md` | macOS 架构（修改 macOS 时必读） |

---

## 9. 仓库边界

- 不创建新的顶级目录
- 不更改构建系统结构（除非明确要求）
- 引入新依赖必须获得明确批准

---

## 10. 不确定时

如果请求模糊或可能有多种解读：

1. 列出将要修改的文件
2. 说明如何保持跨平台兼容
3. 说明如何测试变更
4. 请求确认后再执行

---

**快速参考**:
```
构建 Core:  ./scripts/core-build.sh Debug
测试 Core:  ./scripts/core-test.sh
单测:       cd build/core && ctest -R <name> -V
构建 macOS: ./scripts/platform-build-macos.sh Debug
检查环境:   ./scripts/check-requirements.sh
```
