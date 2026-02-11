# Pasty 项目结构

## Declare (MUST FOLLOW)
如果读取了本文档，**必须** 在回复我的时候在 **最后** 说：“我已阅读fileName。”。其中 fileName 为当前文件名

## 概述

Pasty 是一个跨平台剪贴板管理应用，采用 **C++ Core + 平台 Shell** 架构：
- **C++ Core**：跨平台业务逻辑层，纯 C++17 实现
- **Platform Shell**：各平台原生 UI 和系统集成层

## 目录结构

```
pasty/
├── core/                          # C++ 跨平台核心层
│   ├── CMakeLists.txt            # CMake 构建配置（支持独立构建）
│   ├── ARCHITECTURE.md           # Core 层架构与开发规范（目录结构以此为准）
│   ├── include/                   # 公共头文件
│   │   ├── module.modulemap      # Swift 模块映射
│   │   └── pasty/                # 命名空间对应目录
│   │       ├── pasty.h           # 主入口头文件
│   │       ├── api/              # C API（供 FFI / Swift 互操作）
│   │       │   └── history_api.h
│   │       ├── history/          # 剪贴板历史模块
│   │       │   ├── types.h
│   │       │   ├── history.h
│   │       │   └── store.h
│   │       └── settings/         # 设置模块
│   │           └── settings_api.h
│   ├── src/                       # 实现文件
│   │   ├── Pasty.cpp             # 主入口实现
│   │   ├── history/              # 历史模块实现
│   │   │   ├── history.cpp
│   │   │   └── store_sqlite.cpp
│   │   └── settings/             # 设置模块实现
│   │       └── settings_api.cpp
│   ├── migrations/                # 数据库迁移脚本
│   │   ├── 0001-initial-schema.sql
│   │   ├── 0002-add-search-index.sql
│   │   ├── 0003-add-metadata.sql
│   │   └── 0004-add-ocr-support.sql
│   └── tests/                     # 单元测试
│       ├── CMakeLists.txt
│       ├── history_test.cpp
│       └── settings_api_test.cpp
│
├── openspec/                      # 开放规范（OpenSpec）
│   ├── changes/                  # 变更记录（包含设计文档与 specs）
│   └── config.yaml               # OpenSpec 配置
│
├── platform/                      # 平台特定代码
│   ├── macos/                     # macOS 平台
│   │   ├── project.yml           # XcodeGen 配置
│   │   ├── Info.plist            # 应用配置
│   │   ├── ARCHITECTURE.md       # macOS 层架构与开发规范（目录结构以此为准）
│   │   ├── Pasty.xcodeproj/     # 生成产物：Xcode 工程（不要手工编辑）
│   │   └── Sources/              # macOS 层源码
│   │       ├── App.swift
│   │       ├── DesignSystem/     # 设计系统与通用 UI 组件
│   │       ├── Features/         # 按功能组织的模块
│   │       │   ├── MainPanel/
│   │       │   │   ├── Model/
│   │       │   │   ├── ViewModel/
│   │       │   │   └── View/
│   │       │   ├── Settings/
│   │       │   │   ├── ViewModel/
│   │       │   │   └── View/
│   │       │   └── FutureModules/
│   │       ├── Services/         # 业务服务层
│   │       │   ├── Interface/
│   │       │   └── Impl/
│   │       └── Utilities/        # 纯工具函数与扩展
│   ├── windows/                   # Windows 平台（待实现）
│   ├── ios/                       # iOS 平台（待实现）
│   └── android/                   # Android 平台（待实现）
│
├── build/                         # 编译输出目录（git忽略）
│   ├── core/                      # Core 独立构建产物
│   │   └── lib/libPastyCore.a
│   └── macos/                     # macOS 编译产物
│       └── Build/Products/Debug/
│           ├── Pasty.app        # 应用包
│           └── libPastyCore.a    # Core 静态库
│
├── scripts/                       # 构建和工具脚本
│   ├── check-requirements.sh     # 环境检查
│   ├── install-requirements.sh   # 依赖安装
│   ├── build.sh                  # 主构建入口
│   ├── core-build.sh             # Core 层构建（CMake）
│   ├── platform-build-macos.sh   # macOS 构建
│   ├── platform-build-windows.sh # Windows 构建（占位）
│   ├── platform-build-ios.sh     # iOS 构建（占位）
│   └── platform-build-android.sh # Android 构建（占位）
│
├── docs/                          # 项目文档
│   └── project-structure.md      # 本文件
│
├── AGENTS.md                      # AI 代理指令
└── .gitignore                     # Git 忽略规则
```

## 架构设计

### 双目录架构

应用维护两个独立目录：

1. **appData**: 固定为 `~/Application Support/Pasty`
   - 用于应用级操作
   - 不存放持久化用户数据
   - 通过 `AppPaths.appDataDirectory()` 获取

2. **clipboardData**: 用户可配置，默认为 `${appData}/ClipboardData`
   - 存放用户数据（settings.json、history.sqlite3、images/）
   - 支持用户在设置界面自定义位置
   - 路径通过 UserDefaults 持久化（key: "PastyClipboardDataDirectory"）
   - 由 SettingsManager 管理

### 层次结构

```
┌─────────────────────────────────────────────────────┐
│                   Platform Shell                    │
│  ┌───────────┬───────────┬───────────┬───────────┐  │
│  │   macOS   │  Windows  │    iOS    │  Android  │  │
│  │   swift   │   C++/WRL │  Swift    │  Kotlin   │  │
│  └─────┬─────┴─────┬─────┴─────┬─────┴─────┬─────┘  │
│        │           │           │           │        │
│        └───────────┴───────────┴───────────┘        │
│                        │                            │
│                  ┌─────▼─────┐                      │
│                  │ C++ Core  │                      │
│                  │ (Portable)│                      │
│                  └───────────┘                      │
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
   open build/macos/Build/Products/Debug/Pasty.app
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

### 关键原则

1. **Core 可移植性**：Core 层禁止包含平台头文件
2. **单向依赖**：Platform → Core，禁止反向
3. **接口隔离**：平台交互通过 Core 定义的接口
4. **最小变更**：优先选择能通过编译/测试的最小变更
5. **更新原则**：代码过程中有修改到关于本文档的描述时，需要更新本文档
