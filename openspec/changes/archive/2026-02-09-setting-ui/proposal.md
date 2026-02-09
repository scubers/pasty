# 设置面板 UI 重构 (Settings Panel UI Refactor)

## Why

目前设置面板使用标准的系统控件，视觉风格不够统一且缺乏品牌特色。为了提升用户体验，我们需要根据 `design-system/settings` 下的设计规范和 `index.html` 原型，将设置面板重构为现代、深色模式、玻璃拟态（Glassmorphism）风格，确保与 Pasty2 的整体视觉语言保持一致。

## What Changes

- **视觉重构**:
  - 应用 Deep Blue/Purple 线性渐变背景和高斯模糊叠加效果。
  - 窗口采用无标题栏设计，固定尺寸 **800x550**。
  - 全面应用 Teal (#2DD4BF) 作为强调色。
- **布局重构**:
  - 采用 **Sidebar + Content** 的两栏布局 (侧边栏宽度 200px)。
  - 侧边栏包含 6 个固定模块：General, Clipboard, Appearance, OCR, Shortcuts, About。
- **组件定制**:
  - **Toggle**: 自定义样式的开关控件，带颜色过渡动画。
  - **Select**: 半透明背景的自定义下拉选择框。
  - **Slider**: 细轨道、白色圆形滑块的自定义滑动条。
  - **Danger Button**: 红色半透明背景的警告按钮。
  - **Theme Picker**: 带预览图的主题选择卡片 (System/Dark/Light)。
- **功能模块 UI 实现**:
  - **General**: 启动选项 (登录自启、菜单栏图标)。
  - **Clipboard**: 历史记录策略 (数量、时间)、性能参数 (轮询、大小)、数据清除区。
  - **Appearance**: 主题切换、模糊强度调节。
  - **OCR**: 语言选择列表 (支持搜索)、置信度阈值、模型选择。
  - **Shortcuts**: 全局快捷键录制器、快捷键列表展示。
  - **About**: 品牌展示、版本信息、相关链接。

## Capabilities

### New Capabilities

- `design-system-core`: 实现全应用共享的设计系统基础，包括颜色 Token、字体样式和基础视觉效果（Glassmorphism）。这将作为 MainPanel 和 Settings Panel 的共同基础。
- `settings-ui-refresh`: 实现设置面板的新视觉设计系统，基于 `design-system-core`，包括自定义布局、样式修饰符（Modifiers）和组件样式。
  - 实现基于 `design-system/settings/index.html` 的所有自定义组件。
  - 实现 6 个具体的设置页面视图。

### Modified Capabilities

- `settings-ui`: 现有的设置 UI 逻辑将迁移到新的视觉框架中。原有的功能逻辑保持不变，但 UI 载体将完全替换为新的 SwiftUI 实现。

## Impact

- **Platform 层 (macOS/Swift)**:
  - 新增 `AppDesign.swift` (或 `DesignSystem/`) 模块，存放全局复用的颜色 (`#1a1a2e`, `#2DD4BF` 等)、字体和材质定义。
  - 重写 `SettingsView.swift` 为 `HStack` 布局结构。
  - 创建 `SettingsSidebarView`, `SettingsContentContainer` 等容器组件。
  - 实现 `CustomToggle`, `CustomPicker`, `CustomSlider`, `ThemePicker` 等通用组件。
  - 修改 `SettingsWindowController.swift` 去除标题栏，设置窗口尺寸和背景效果。
- **用户体验**:
  - 提供更沉浸、精致的视觉体验，与主面板风格统一。
  - 交互反馈更加细腻（自定义的悬停、点击状态）。
