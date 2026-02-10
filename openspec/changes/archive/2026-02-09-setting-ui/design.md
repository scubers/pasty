# Settings Panel Design Document

## Context

Pasty 当前的设置面板基于标准的 macOS `TabView` 和系统控件，视觉风格平淡且与主应用现代化的设计语言不符。我们需要根据新的 Design System (`design-system/settings/index.html`) 对设置面板进行彻底的 UI 重构。

## Goals / Non-Goals

**Goals:**
- 实现 1:1 还原 HTML 原型的视觉设计（Glassmorphism, Deep Blue Theme, Custom Controls）。
- 构建一套可复用的 SwiftUI 设计组件库 (Tokens, Components)。
- 实现平滑的交互动画和细腻的状态反馈。
- 保持现有的设置数据逻辑不变，仅替换 UI 层。

**Non-Goals:**
- 修改底层的设置存储逻辑 (Core Layer)。
- 引入新的设置功能项（除非 UI 原型中有体现但后端未支持的，先做 UI）。

## Decisions

### 1. 窗口架构 (Window Architecture)

**Decision**: 使用 `fullSizeContentView` 样式的 `NSWindow`，去除标准标题栏。
**Rationale**: 设计稿要求全窗口背景模糊和无标题栏的一体化视觉。标准窗口无法实现这种沉浸式效果。
**Implementation**:
- `SettingsWindowController` 配置 `styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView]`。
- `titlebarAppearsTransparent = true`, `titleVisibility = .hidden`。
- 窗口尺寸固定为 800x550。
- 背景色设为 `.clear`，并在 SwiftUI 根视图层添加 `VisualEffectBlur`。

### 2. 布局结构 (Layout Structure)

**Decision**: 放弃 `TabView`，使用 `HStack` + `State` 实现自定义导航。
**Rationale**: 系统 `TabView` 的样式定制能力有限，无法实现设计稿中的侧边栏样式（透明度、悬停效果、自定义高度）。
**Implementation**:
```swift
HStack(spacing: 0) {
    SettingsSidebarView(selection: $currentTab)
        .frame(width: 200)
    Divider() // 细微分割线
    SettingsContentContainer(selection: currentTab)
}
```

### 3. 设计系统封装 (Design System Encapsulation)

**Decision**: 创建全局的 `DesignSystem` 模块，集中管理 App 级别的 Token。
**Rationale**: Settings Panel 和 Main Panel 共享了背景渐变、强调色 (Teal)、字体和玻璃拟态效果。提取公共 Token 可以确保两个核心面板的视觉一致性，并方便未来统一修改主题。
**Implementation**:
- `DesignSystem.Colors`: 定义 `backgroundStart`, `backgroundEnd`, `accent`, `textPrimary`, `borderLight` 等全局颜色。
- `DesignSystem.Materials`: 定义 `.glassEffect()`, `.panelBlur` 等通用的材质修饰符。
- `SettingsDesign`: 继承或使用 `DesignSystem`，并补充 Settings 特有的组件样式（如 Toggle 颜色）。

### 4. 自定义控件 (Custom Controls)

**Decision**: 不使用系统控件的 `.pickerStyle` 或 `.toggleStyle`，而是完全封装自定义视图组件。
**Rationale**: SwiftUI 的样式定制在 macOS 上有时受限（例如 Toggle 的大小和颜色过渡），为了精确还原 HTML 原型的效果，自定义视图更可控。
**List**:
- `PastyToggle`: 仿 iOS 风格但更紧凑的开关。
- `PastyPicker`: 半透明背景的下拉按钮。
- `PastySlider`: 细轨道、白色圆点的滑块。
- `DangerButton`: 红色半透明样式的按钮。

## Risks / Trade-offs

**Risk**: 自定义窗口可能导致拖拽移动窗口失效。
**Mitigation**: 在背景层添加 `.windowDrag` 手势或使用 `NSWindow.isMovableByWindowBackground = true`。

**Risk**: 复杂的 SwiftUI 视图层级可能影响渲染性能。
**Mitigation**: 尽量使用 `drawingGroup()` 对静态复杂的背景进行各种合成，但对于 Glassmorphism 效果需要实时渲染，需注意避免过度重绘。

**Risk**: 可访问性 (Accessibility) 可能降低。
**Mitigation**: 自定义组件必须手动添加 `.accessibilityElement` 和 `.accessibilityLabel`。

## Migration Plan

1. 创建新的 `SettingsDesignTokens.swift`。
2. 创建基础组件库 (`Components/`).
3. 实现各个设置页面的子视图 (`Views/Settings/Pages/`).
4. 替换 `SettingsView.swift` 为新架构。
5. 更新 `SettingsWindowController.swift`。
