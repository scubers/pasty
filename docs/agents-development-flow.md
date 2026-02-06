# AI Agent 开发工作流

## Declare (MUST FOLLOW)
如果读取了本文档，**必须** 在回复我的时候在 **最后** 说："我已阅读fileName。"。其中 fileName 为当前文件名

## 概述

本文档定义 AI Agent 在 Pasty2 项目中进行开发工作的标准流程。所有 AI Agent 必须严格遵循此流程，确保代码质量和项目一致性。

---

## 1. 开发前准备

### 1.1 必读文档

在开始任何开发工作之前，AI Agent **必须** 阅读以下文档：

| 文档 | 路径 | 内容 |
|------|------|------|
| 项目宪法 | `.specify/memory/constitution.md` | 核心原则 P1-P5，治理规则 |
| 项目结构 | `docs/project-structure.md` | 目录结构，架构设计，构建流程 |
| Agent 指令 | `AGENTS.md` | 最高优先级规则，架构约束 |

### 1.2 核心原则速查

| 原则 | 要求 |
|------|------|
| **P1: 隐私优先** | 数据本地存储，云同步必须用户明确授权 |
| **P2: 性能响应** | UI 操作 <100ms，内存 <200MB/10K条目，启动 <2s |
| **P3: 跨平台兼容** | macOS/Windows/Linux 功能对等 |
| **P4: 数据完整** | 原子写入，无损捕获 |
| **P5: 可扩展架构** | 插件系统，稳定 API |

---

## 2. 开发工作流

### 2.1 流程图

```
┌─────────────────────────────────────────────────────────────────┐
│                     AI Agent 开发工作流                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐  │
│  │ 1. 阅读  │───▶│ 2. 规划  │───▶│ 3. 实现  │───▶│ 4. 验证  │  │
│  │   规范   │    │   方案   │    │   代码   │    │   编译   │  │
│  └──────────┘    └──────────┘    └──────────┘    └────┬─────┘  │
│                                                       │        │
│                                                       ▼        │
│                                  ┌──────────┐    ┌──────────┐  │
│                                  │ 6. 提交  │◀───│ 5. 修复  │  │
│                                  │ (需确认) │    │   错误   │  │
│                                  └──────────┘    └──────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 详细步骤

#### Step 1: 阅读规范

```bash
# 必须阅读的文档
.specify/memory/constitution.md  # 项目宪法
docs/project-structure.md        # 项目结构
```

#### Step 2: 规划方案

在修改代码前，必须明确：
- 将要修改哪些文件
- 如何保持跨平台兼容性
- 如何测试变更

#### Step 3: 实现代码

遵循架构约束：
- **Core 层**：纯 C++17，禁止平台头文件
- **Platform 层**：仅 UI 和系统集成
- **依赖方向**：Platform → Core（单向）

#### Step 4: 验证编译

**必须** 执行对应的编译脚本检查：

```bash
# 跨平台 Core 层（修改 core/ 目录时必须执行）
./scripts/core-build.sh

# macOS 平台（修改 platform/macos/ 时必须执行）
./scripts/platform-build-macos.sh Debug

# Windows 平台（修改 platform/windows/ 时必须执行）
./scripts/platform-build-windows.sh Debug

# iOS 平台（修改 platform/ios/ 时必须执行）
./scripts/platform-build-ios.sh Debug

# Android 平台（修改 platform/android/ 时必须执行）
./scripts/platform-build-android.sh Debug
```

#### Step 5: 处理编译错误

如果编译失败：

1. **给出完整错误信息**
2. **提供最小修复建议**
3. **如涉及重大修改，必须得到用户确认后再执行**

示例输出格式：
```
❌ 编译失败

错误信息：
  core/src/Pasty.cpp:42:5: error: use of undeclared identifier 'foo'

最小修复建议：
  - 在 core/include/Pasty.h 中声明 foo 函数
  - 或移除对 foo 的调用

⚠️ 此修复涉及 API 变更，需要确认后执行。是否继续？
```

#### Step 6: Git 操作

**⚠️ 重要：commit 和 push 操作必须得到用户明确确认！**

```
❓ 准备提交以下变更：

  modified:   core/src/Pasty.cpp
  modified:   core/include/Pasty.h

提交信息：fix: 修复剪贴板初始化崩溃问题

是否确认提交？(y/n)
```

---

## 3. 编译脚本说明

### 3.1 脚本列表

| 脚本 | 用途 | 触发条件 |
|------|------|----------|
| `scripts/core-build.sh` | 编译 C++ Core 层 | 修改 `core/` 目录 |
| `scripts/platform-build-macos.sh` | 编译 macOS 应用 | 修改 `platform/macos/` |
| `scripts/platform-build-windows.sh` | 编译 Windows 应用 | 修改 `platform/windows/` |
| `scripts/platform-build-ios.sh` | 编译 iOS 应用 | 修改 `platform/ios/` |
| `scripts/platform-build-android.sh` | 编译 Android 应用 | 修改 `platform/android/` |
| `scripts/check-requirements.sh` | 检查开发环境 | 首次设置 |
| `scripts/install-requirements.sh` | 安装依赖 | 缺少依赖时 |

### 3.2 编译参数

```bash
# Debug 构建（默认）
./scripts/platform-build-macos.sh Debug

# Release 构建
./scripts/platform-build-macos.sh Release
```

### 3.3 编译输出位置

```
build/
├── macos/Build/Products/Debug/
│   ├── Pasty2.app          # macOS 应用
│   └── libPastyCore.a      # Core 静态库
├── windows/                 # Windows 产物
├── ios/                     # iOS 产物
└── android/                 # Android 产物
```

---

## 4. 错误处理规范

### 4.1 编译错误分类

| 错误级别 | 处理方式 |
|----------|----------|
| **语法错误** | 直接修复，无需确认 |
| **类型错误** | 直接修复，无需确认 |
| **链接错误** | 分析原因，可能需确认 |
| **架构违规** | 必须得到确认后修复 |
| **API 变更** | 必须得到确认后修复 |

### 4.2 错误报告模板

```markdown
## ❌ 编译失败

### 错误信息
```
[完整错误输出]
```

### 错误分析
- 错误类型：[语法/类型/链接/架构违规]
- 影响范围：[单文件/多文件/跨模块]
- 根本原因：[简要说明]

### 修复建议
1. [修复步骤 1]
2. [修复步骤 2]

### 确认要求
- [ ] 无需确认，可直接修复
- [ ] 需要确认后修复（原因：[说明]）
```

---

## 5. Git 操作规范

### 5.1 禁止的操作

| 操作 | 状态 |
|------|------|
| `git commit` 未经确认 | ❌ 禁止 |
| `git push` 未经确认 | ❌ 禁止 |
| `git push --force` | ❌ 禁止 |
| `git reset --hard` | ❌ 禁止 |
| 修改 `.git/config` | ❌ 禁止 |

### 5.2 允许的操作

| 操作 | 状态 |
|------|------|
| `git status` | ✅ 允许 |
| `git diff` | ✅ 允许 |
| `git log` | ✅ 允许 |
| `git branch` | ✅ 允许 |
| `git add` | ✅ 允许 |

### 5.3 确认流程

```
┌─────────────────────────────────────────────────────────┐
│                    Git 操作确认流程                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. 展示变更内容 (git status + git diff)                │
│                    ↓                                    │
│  2. 生成提交信息建议                                     │
│                    ↓                                    │
│  3. 请求用户确认                                         │
│                    ↓                                    │
│  4. 用户确认后执行 commit                                │
│                    ↓                                    │
│  5. 如需 push，再次请求确认                              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 6. 检查清单

### 6.1 开发前检查

- [ ] 已阅读 `.specify/memory/constitution.md`
- [ ] 已阅读 `docs/project-structure.md`
- [ ] 已理解修改范围和影响

### 6.2 开发中检查

- [ ] Core 层代码无平台依赖
- [ ] Platform 层仅包含 UI 和系统集成
- [ ] 依赖方向正确（Platform → Core）
- [ ] 遵循 C++17 标准

### 6.3 开发后检查

- [ ] 执行了对应的编译脚本
- [ ] 编译成功，无错误
- [ ] 编译警告已处理或已说明
- [ ] 重大修改已得到确认
- [ ] Git 操作已得到确认

---

## 7. 常见问题

### Q1: Core 层可以使用哪些库？

**A**: 仅限标准 C++ 库和已批准的跨平台库。不可使用平台特定库（Cocoa、Win32 等）。

### Q2: 如何添加新的第三方依赖？

**A**: 必须得到明确批准。在请求中说明：
- 依赖名称和版本
- 添加原因
- 跨平台兼容性
- 许可证

### Q3: 编译失败但修复涉及多个文件怎么办？

**A**: 
1. 列出所有需要修改的文件
2. 说明每个文件的修改内容
3. 请求确认后再执行

### Q4: 可以创建新的顶级目录吗？

**A**: 不可以。参见 AGENTS.md 第 2 条规则。

---

## 附录：快速参考卡

```
╔═══════════════════════════════════════════════════════════════╗
║                   AI Agent 开发速查卡                          ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  📖 开发前必读                                                 ║
║     .specify/memory/constitution.md                           ║
║     docs/project-structure.md                                 ║
║                                                               ║
║  🔨 编译检查                                                   ║
║     Core:    ./scripts/core-build.sh                          ║
║     macOS:   ./scripts/platform-build-macos.sh Debug          ║
║     Windows: ./scripts/platform-build-windows.sh Debug        ║
║     iOS:     ./scripts/platform-build-ios.sh Debug            ║
║     Android: ./scripts/platform-build-android.sh Debug        ║
║                                                               ║
║  ⚠️ 必须确认                                                   ║
║     - git commit                                              ║
║     - git push                                                ║
║     - 重大代码修改                                             ║
║     - API 变更                                                ║
║                                                               ║
║  ❌ 禁止操作                                                   ║
║     - 创建顶级目录                                             ║
║     - 添加未批准的依赖                                         ║
║     - Core 层使用平台头文件                                    ║
║     - git push --force                                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```
