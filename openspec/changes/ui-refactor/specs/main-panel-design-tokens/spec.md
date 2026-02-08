## 新增需求

### 需求：主面板 token 定义
主面板 SHALL 定义设计 token，包括颜色、排版、效果和布局，作为所有样式决策的单一事实来源。

#### 场景：tokens 在 MainPanelTokens.swift 中定义
- **当** 实现主面板时
- **那么** tokens SHALL 在 `platform/macos/Sources/View/MainPanel/MainPanelTokens.swift` 中定义
- **那么** tokens SHALL 使用语义名称而不是原始值（例如，`accentPrimary` 而不是 `#2DD4BF`）
- **那么** tokens SHALL 将语义名称映射到具体的 SwiftUI/AppKit 实现

### 需求：颜色 token
颜色 token SHALL 定义主面板中使用的颜色调色板，将语义名称映射到具体的颜色值。

#### 场景：颜色 token 包括背景渐变
- **当** 渲染主面板背景时
- **那么** `backgroundGradient` token SHALL 定义线性渐变（135deg，`#1a1a2e` 0%，`#16213e` 50%，`#0f0f23` 100%）
- **那么** 渐变 SHALL 在主面板根视图处应用一次

#### 场景：颜色 token 包括表面颜色
- **当** 渲染表面叠加层时
- **那么** `surface` token SHALL 定义 `rgba(30, 30, 46, 0.85)` 用于主容器叠加层
- **那么** `card` token SHALL 定义 `rgba(255, 255, 255, 0.03)` 用于部分和卡片
- **那么** `border` token SHALL 定义 `rgba(255, 255, 255, 0.1)` 用于分隔符和卡片边框

#### 场景：颜色 token 包括强调色
- **当** 渲染强调元素时
- **那么** `accentPrimary` token SHALL 定义 `#2DD4BF` (Teal-400) 用于焦点环、图标和亮点
- **那么** `accentGradient` token SHALL 定义从 `#0D9488` 到 `#14B8A6` 的渐变用于主按钮
- **那么** 强调 token SHALL 一致地用于所有交互元素

#### 场景：颜色 token 包括文本颜色
- **当** 渲染文本元素时
- **那么** `textPrimary` token SHALL 定义 `#E5E7EB` (Gray-200) 用于主要内容
- **那么** `textSecondary` token SHALL 定义 `#9CA3AF` (Gray-400) 用于元数据和标签
- **那么** `textMuted` token SHALL 定义 `#6B7280` (Gray-500) 用于页脚和时间戳

### 需求：排版 token
排版 token SHALL 定义主面板中所有文本元素的字体系列、粗细和大小规范。

#### 场景：排版使用系统字体系列
- **当** 主面板中渲染文本时
- **那么** 字体系列 SHALL 是 SF Pro Text / SF Pro Display（系统字体）
- **那么** 排版 SHALL 与 macOS 系统排版一致

#### 场景：排版定义正文样式
- **当** 渲染标准列表文本时
- **那么** `body` token SHALL 定义 Regular 粗细，13pt
- **那么** `bodyBold` token SHALL 定义 Medium 粗细，13pt 用于突出显示的文本

#### 场景：排版定义小号样式
- **当** 渲染元数据或时间戳时
- **那么** `small` token SHALL 定义 Regular 粗细，11pt
- **那么** `smallBold` token SHALL 定义 Semibold 粗细，11pt 用于部分标题（UPPERCASE）

#### 场景：排版定义代码样式
- **当** 渲染代码段预览或代码时
- **那么** `code` token SHALL 定义 Monospace 字体，12pt
- **那么** 代码 SHALL 支持语法高亮颜色（关键词紫色 `#C084FC`，字符串绿色 `#4ADE80`，函数黄色 `#FDE047`）

### 需求：效果和深度 token
效果和深度 token SHALL 定义在整个主面板中使用的模糊材质、阴影和玻璃形态效果。

#### 场景：效果定义模糊材质
- **当** 应用玻璃形态效果时
- **那么** `materialHudWindow` token SHALL 映射到 `NSVisualEffectView` 材质 `.hudWindow`，混合模式 `.behindWindow`
- **那么** `materialUltraThin` token SHALL 映射到 SwiftUI `.ultraThinMaterial`
- **那么** `materialRegular` token SHALL 映射到 SwiftUI `.regularMaterial`

#### 场景：效果定义阴影
- **当** 应用阴影时
- **那么** `panelShadow` token SHALL 定义 `0 8px 32px rgba(0, 0, 0, 0.4)` 用于主面板
- **那么** `buttonShadow` token SHALL 定义 `0 2px 8px rgba(13, 148, 136, 0.4)` 用于主按钮
- **那么** 阴影 SHALL 与设计规范一致

### 需求：布局 token
布局 token SHALL 定义间距、圆角和比例规范，以在整个主面板中保持一致的布局。

#### 场景：布局定义圆角
- **当** 应用圆角时
- **那么** `cornerRadius` token SHALL 定义 12px 用于卡片和部分
- **那么** `cornerRadiusSmall` token SHALL 定义 8px 用于列表项（可选，如果需要）

#### 场景：布局定义填充和间距
- **当** 应用间距时
- **那么** `padding` token SHALL 定义容器的一致填充值
- **那么** `paddingCompact` token SHALL 定义列表项的更紧凑间距（3.5 或等效值）

#### 场景：布局定义分栏比例
- **当** 渲染主面板分栏视图时
- **那么** `splitRatio` token SHALL 定义 55/45 比例（列表 55%，预览 45%）
- **那么** 分栏比例 SHALL 在面板调整大小时保持

### 需求：token 使用一致性
Tokens SHALL 在整个主面板实现中一致使用，避免使用直接值而使用 token 引用。

#### 场景：tokens 在 SwiftUI 视图中使用
- **当** 实现 SwiftUI 视图时
- **那么** 视图 SHALL 引用 `MainPanelTokens` 中的 tokens，而不是硬编码值
- **那么** tokens SHALL 通过静态属性或计算属性访问
- **那么** 更改 `MainPanelTokens.swift` 中的 token SHALL 影响所有使用的视图

#### 场景：tokens 映射到 SwiftUI/AppKit
- **当** 实现 tokens 时
- **那么** 颜色 tokens SHALL 映射到 `Color` 类型或 Assets.xcassets 中的命名颜色
- **那么** 材质 tokens SHALL 映射到 `Material` 枚举值或 `NSVisualEffectView` 材质
- **那么** 排版 tokens SHALL 映射到 `Font` 类型配置
- **那么** 布局 tokens SHALL 映射到 `CGFloat` 值或 `Edge.Set` 配置

### 需求：token 可扩展性
token 系统 SHALL 可扩展以支持未来的全局设计系统，而无需强制立即采用全局系统。

#### 场景：tokens 作用于主面板
- **当** 定义 tokens 时
- **那么** tokens SHALL 作用于主面板命名空间（例如，`MainPanelTokens.accentPrimary`）
- **那么** tokens SHALL 不会被强制进入全局设计系统
- **那么** 未来的全局设计系统 SHALL 能够从主面板 tokens 中提取通用 tokens

#### 场景：tokens 支持语义命名
- **当** 添加新 tokens 时
- **那么** tokens SHALL 使用描述目的的语义名称（例如，`textPrimary`、`accentPrimary`）
- **那么** tokens SHALL 不使用原始视觉值作为名称（例如，避免将 tokens 命名为 `Teal400` 或 `Gray200`）
- **那么** 语义命名 SHALL 促进跨模块重用和设计对齐

### 需求：token 文档
Tokens SHALL 包括描述其目的、使用上下文和任何特殊注意事项的文档。

#### 场景：每个 token 都有文档
- **当** 定义 tokens 时
- **那么** 每个 token SHALL 有内联文档注释
- **那么** 文档 SHALL 描述 token 的目的以及应该在哪里使用
- **那么** 文档 SHALL 在适用时参考设计规范

### 需求：token 验证
token 定义 SHALL 被验证以确保它们完整、一致并与设计规范对齐。

#### 场景：所有设计规范 tokens 都被表示
- **当** 定义主面板 tokens 时
- **那么** `macOS-design-spec.md` 中指定的所有 tokens SHALL 被表示
- **那么** 缺失的 tokens SHALL 被添加或明确证明超出范围是合理的
- **那么** token 值 SHALL 与设计规范对齐

#### 场景：token 值一致
- **当** 使用 tokens 时
- **那么** token 值 SHALL 在所有组件中一致
- **那么** 应避免直接值覆盖
- **那么** 如果需要直接值，它们 SHALL 被合理化并记录
