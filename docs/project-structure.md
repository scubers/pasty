# Pasty2 项目结构

## Declare (MUST FOLLOW)
如果读取了本文档，**必须** 在回复我的时候在 **最后** 说：“我已阅读fileName。”。其中 fileName 为当前文件名

## 概述

Pasty2 是一个跨平台剪贴板管理应用，采用 **C++ Core + 平台 Shell** 架构：
- **C++ Core**：跨平台业务逻辑层，纯 C++17 实现
- **Platform Shell**：各平台原生 UI 和系统集成层

## 目录结构

```
pasty2/
├── core/                          # C++ 跨平台核心层
│   ├── include/                   # 公共头文件
│   │   └── Pasty.h               # Core API 定义
│   └── src/                       # 实现文件
│       └── Pasty.cpp             # Core 实现
│
├── platform/                      # 平台特定代码
│   ├── macos/                     # macOS 平台
│   │   ├── project.yml           # XcodeGen 配置
│   │   ├── Info.plist            # 应用配置
│   ├── windows/                   # Windows 平台（待实现）
│   ├── ios/                       # iOS 平台（待实现）
│   └── android/                   # Android 平台（待实现）
│
├── build/                         # 编译输出目录（git忽略）
│   └── macos/                     # macOS 编译产物
│       └── Build/Products/Debug/
│           ├── Pasty2.app        # 应用包
│           └── libPastyCore.a    # Core 静态库
│
├── scripts/                       # 构建和工具脚本
│   ├── check-requirements.sh     # 环境检查
│   ├── install-requirements.sh   # 依赖安装
│   ├── build.sh                  # 主构建入口
│   ├── core-build.sh             # Core 层构建
│   ├── platform-build-macos.sh   # macOS 构建
│   ├── platform-build-windows.sh # Windows 构建（占位）
│   ├── platform-build-ios.sh     # iOS 构建（占位）
│   └── platform-build-android.sh # Android 构建（占位）
│
├── docs/                          # 项目文档
│   └── project-structure.md      # 本文件
│
├── .specify/memory/               # AI 记忆和配置
│   └── constitution.md           # 项目宪法
│
├── AGENTS.md                      # AI 代理指令
└── .gitignore                     # Git 忽略规则
```

## 架构设计

### 层次结构

```
┌─────────────────────────────────────────────────────┐
│                   Platform Shell                     │
│  ┌───────────┬───────────┬───────────┬───────────┐  │
│  │   macOS   │  Windows  │    iOS    │  Android  │  │
│  │ Obj-C++   │   C++/WRL │  Swift    │  Kotlin   │  │
│  └─────┬─────┴─────┬─────┴─────┬─────┴─────┬─────┘  │
│        │           │           │           │         │
│        └───────────┴───────────┴───────────┘         │
│                        │                             │
│                  ┌─────▼─────┐                       │
│                  │ C++ Core  │                       │
│                  │ (Portable)│                       │
│                  └───────────┘                       │
└─────────────────────────────────────────────────────┘
```

### 依赖方向

- Platform → Core（单向依赖）
- Core 不依赖任何平台头文件
- Core 通过接口（ports）与平台交互

## 构建流程

### macOS

1. **环境准备**
   ```bash
   ./scripts/check-requirements.sh    # 检查依赖
   ./scripts/install-requirements.sh  # 安装缺失依赖
   ```

2. **生成 Xcode 工程**
   ```bash
   cd platform/macos
   xcodegen generate
   ```

3. **编译**
   ```bash
   ./scripts/platform-build-macos.sh Debug
   # 或
   ./scripts/platform-build-macos.sh Release
   ```

4. **运行**
   ```bash
   open build/macos/Build/Products/Debug/Pasty2.app
   ```

### 其他平台

- **Windows**：使用 CMake + Visual Studio
- **iOS**：使用 XcodeGen（待实现）
- **Android**：使用 Gradle + NDK（待实现）

## 核心 API

```cpp
namespace pasty {

class ClipboardManager {
public:
    static std::string getVersion();   // 获取版本号
    static std::string getAppName();   // 获取应用名称
    
    bool initialize();                  // 初始化
    void shutdown();                    // 关闭
};

} // namespace pasty
```

## 开发规范

参见 [constitution.md](../.specify/memory/constitution.md) 了解完整的开发规范和约束。

### 关键原则

1. **Core 可移植性**：Core 层禁止包含平台头文件
2. **单向依赖**：Platform → Core，禁止反向
3. **接口隔离**：平台交互通过 Core 定义的接口
4. **最小变更**：优先选择能通过编译/测试的最小变更
5. **更新原则**：代码过程中有修改到关于本文档的描述时，需要更新本文档