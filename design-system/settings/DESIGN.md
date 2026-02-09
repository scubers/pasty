# 设置面板设计系统 (Settings Panel Design System)

## 概述
本文档定义了 Pasty2 设置面板的视觉设计系统，基于 HTML 原型 (`design-system/settings/index.html`)。设计采用了专为 macOS 定制的现代、深色模式、玻璃拟态美学风格。

## 配色方案 (Color Palette)

### 背景色 (Backgrounds)
- **窗口背景**: `线性渐变 (135deg)`
  - 起始: `#1a1a2e` (0%)
  - 中间: `#16213e` (50%)
  - 结束: `#0f0f23` (100%)
- **面板容器**: `rgba(30, 30, 46, 0.85)` 叠加背景模糊 (Backdrop Blur)
- **侧边栏**: `Color.black.opacity(0.1)`
- **输入框/选择框背景**: `Color.black.opacity(0.3)`

### 强调色与文本 (Accents & Text)
- **主要强调色 (青色)**: `#2DD4BF` (Teal-400)
- **主要文本**: `#e5e7eb` (Gray-200)
- **次要文本**: `#9ca3af` (Gray-400)
- **三级文本**: `#6b7280` (Gray-500)
- **危险色 (红色)**: `#ef4444` (Red-500)

### 边框与分隔线 (Borders & Separators)
- **细微边框**: `Color.white.opacity(0.1)`
- **悬停/激活边框**: `Color.white.opacity(0.2)`

## 排版/字体 (Typography)
使用系统字体 (SF Pro)，并指定具体的字重和字间距。

- **窗口标题**: 14pt (text-sm), Bold, Tracking Wide
- **章节标题**: 20pt (text-xl), Bold
- **子章节标题**: 14pt (text-sm), Semibold
- **正文文本**: 14pt (text-sm), Medium
- **说明/描述**: 12pt (text-xs), Regular

## 组件 (Components)

### 窗口 / 主面板 (Window / Main Panel)
- **尺寸**: 固定 800x550
- **圆角**: 12px (rounded-xl)
- **视觉效果**:
  - 背景模糊: 40px
  - 饱和度: 180%
  - 阴影: `0 8px 32px rgba(0, 0, 0, 0.4)`
  - 边框: 1px solid `rgba(255, 255, 255, 0.1)`

### 侧边导航 (Sidebar Navigation)
- **项目容器**: 圆角 (6px), 垂直边距 2px
- **状态: 正常**: 文字 `#9ca3af`
- **状态: 悬停**: 背景 `Color.white.opacity(0.06)`, 文字 `#e5e7eb`
- **状态: 激活**: 背景 `rgba(45, 212, 191, 0.15)`, 文字 `#2DD4BF`
- **图标**: 16x16 (w-4 h-4), 不透明度 75%

### 设置组/卡片 (Settings Group / Card)
- **背景**: `Color.white.opacity(0.03)`
- **边框**: 1px solid `Color.white.opacity(0.08)`
- **圆角**: 8px
- **内边距**: 16px

### 控件 (Controls)

#### 开关 (Toggle Switch)
- **轨道 (未选中)**: `bg-gray-700`
- **轨道 (选中)**: `#2DD4BF`
- **滑块**: 白色, 全圆角, 带阴影

#### 下拉选择框 (Select / Dropdown)
- **背景**: `Color.black.opacity(0.3)`
- **边框**: 1px solid `Color.white.opacity(0.1)`
- **文字**: `#e5e7eb`
- **焦点状态**: 边框 `#2DD4BF`, 光晕环 `rgba(45, 212, 191, 0.15)`

#### 危险操作按钮 (Danger Button)
- **背景**: `rgba(239, 68, 68, 0.1)` (Red-500/10)
- **边框**: `rgba(239, 68, 68, 0.3)`
- **文字**: `#f87171` (Red-400)
- **悬停状态**: 背景 `rgba(239, 68, 68, 0.2)`

## SwiftUI 实现指南 (SwiftUI Implementation Guide)

### 基础样式 (Base Styles)
```swift
extension Color {
    static let settingsBackgroundStart = Color(hex: "1a1a2e")
    static let settingsBackgroundMid = Color(hex: "16213e")
    static let settingsBackgroundEnd = Color(hex: "0f0f23")
    static let settingsPanelBg = Color(red: 30/255, green: 30/255, blue: 46/255, opacity: 0.85)
    static let settingsAccent = Color(hex: "2DD4BF")
}

struct GlassPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.thinMaterial) // 或者自定义 VisualEffectBlur
            .background(Color.settingsPanelBg)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.4), radius: 32, x: 0, y: 8)
    }
}
```

### 布局结构 (Layout Structure)
- 使用 **HStack** 组合 侧边栏 + 内容区域
  - **侧边栏 (Sidebar)**: 宽度 200px, 背景色 `Color.black.opacity(0.1)`
  - **内容区域 (Content)**: 弹性宽度, 透明背景

### 图标 (Icons)
使用 **SF Symbols** 替换 HTML 中的 SVG 图标：
- 常规 (General): `gearshape`
- 剪贴板 (Clipboard): `clipboard`
- 外观 (Appearance): `paintpalette`
- 快捷键 (Shortcuts): `command`
- 关于 (About): `info.circle`
