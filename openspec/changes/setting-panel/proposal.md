# 设置面板 (Settings Panel)

## Why

Pasty2 当前将众多配置硬编码在代码中（如轮询间隔 0.4s、最大历史 1000 条、OCR 语言等），用户无法根据个人需求进行调整。通过设置面板，用户可自定义剪贴板行为、OCR 策略、外观样式等，提升应用的灵活性和个性化体验。

## What Changes

- **新增设置面板 UI**: 菜单栏增加"设置"入口，支持 ⌘+, 快捷键打开
- **新增 Settings Core 模块**: C++ Core 层定义设置数据结构、默认值、持久化接口
- **新增 Settings Service**: macOS 层实现基于 UserDefaults 的持久化
- **新增设置页面**: SwiftUI 实现的分组设置界面
- **修改现有模块以支持配置**:
  - `ClipboardWatcher`: 支持可配置的轮询间隔和大小限制
  - `OCRService`: 支持可配置的语言、置信度、识别级别
  - `MainPanelWindowController`: 支持可配置的快捷键
  - `MainPanelView`: 支持可配置的外观（主题色、模糊）
- **应用黑名单功能**: 新增应用黑名单检测机制

## Capabilities

### New Capabilities

- `settings-core`: 设置系统的核心架构，包括设置项定义、默认值管理、持久化接口
- `settings-clipboard`: 剪贴板监听相关配置（轮询周期、大小限制、记录数量）
- `settings-ocr`: OCR 相关配置（启用状态、语言、置信度、识别级别、搜索开关）
- `settings-blacklist`: 应用黑名单管理（添加、删除、启用/禁用）
- `settings-appearance`: 面板外观配置（主题色、背景模糊程度）
- `settings-general`: 通用设置（启动时运行、全局快捷键）
- `settings-ui`: 设置面板 UI 组件和交互逻辑

### Modified Capabilities

- `clipboard-watcher`: 需要支持可配置的轮询间隔和内容大小限制
- `history-store`: 需要支持可配置的最大记录数量
- `ocr-service`: 需要支持可配置的识别参数

## Impact

**Core 层 (C++)**:
- 新增 `core/include/pasty/settings/` 模块
- 新增 settings API (`pasty/api/settings_api.h`)
- 修改 `history.cpp` 以读取设置

**Platform 层 (macOS/Swift)**:
- 新增 `SettingsView.swift` 设置页面
- 新增 `SettingsWindowController.swift`
- 修改 `App.swift` 菜单栏增加设置入口
- 修改 `ClipboardWatcher.swift`、`OCRService.swift` 等使用配置值
- 依赖新增: SwiftUI 设置表单组件

**用户体验**:
- 菜单栏新增"设置"选项
- 支持 ⌘+, 标准快捷键
- 设置变更实时生效（部分需重启）
