## Why

当前主面板（Main Panel）的 UI 视觉与交互细节缺少统一、可复用的设计基线，导致样式分散、迭代成本高，并且与 `design-system/main-panel/` 中沉淀的设计稿/规范存在偏差。
现在需要基于 `design-system/main-panel` 文件夹下的全部设计资产（规范、原型、截图；尤其是 `design-system/main-panel/design.png`、`design-system/main-panel/v2-dark-mode.html`、`design-system/main-panel/macOS-design-spec.md`）对主面板 UI 做一次系统性重构，形成稳定的视觉语言与组件边界，降低后续功能迭代与跨平台适配成本。

## What Changes

- 主面板 UI 视觉重构：对齐 `design-system/main-panel/design.png`、`design-system/main-panel/macOS-design-spec.md` 与 `design-system/main-panel/v2-dark-mode.html` 的布局、层级、色彩、字体与交互状态（hover/selected/focus/disabled）。
- 引入“可复用的主面板 UI 约束”：沉淀主面板使用的设计 tokens（颜色/排版/圆角/阴影/模糊/间距等）与组件结构（搜索栏、列表项、预览区、操作按钮、状态栏）。
- 在不改变核心业务逻辑的前提下重组 UI 代码：收敛重复样式与布局逻辑，明确组件边界，降低耦合。
- 修复/补齐主面板可用性细节：一致的键盘焦点表现、可访问性标签、滚动条/长文本/图片预览等边界行为（以现有功能语义为准，不新增数据能力）。

## Capabilities

### New Capabilities
- `main-panel-ui-refresh`: 定义主面板 UI 的结构与交互/视觉要求（左右分栏、搜索、列表、预览、操作区、状态栏），并规定关键状态（hover/selected/focus/loading/error）的表现与一致性。
- `main-panel-design-tokens`: 定义主面板 UI 使用的设计 tokens（颜色、排版、深度/模糊、边框、间距等）及其在实现层的映射规则，确保主面板样式来源可追溯、可复用。

### Modified Capabilities
<!-- 当前仓库未发现 openspec/specs/ 目录中的既有 capability 规格文件；本次先以新增 capability 为主。如后续确认存在既有主面板相关 spec，再补充 delta spec。 -->

## Impact

- 影响范围（预期）：主面板相关的 macOS 平台 UI（SwiftUI 视图与其宿主窗口/面板封装），以及与主面板 UI 直接相关的资源与样式组织方式。
- 不影响范围（目标）：Core 层业务逻辑与数据模型不做语义变更；不新增第三方依赖；不改变构建系统结构。
- 风险与注意事项：需要确保重构不引入性能回退（列表渲染、搜索响应、预览切换），并保持主面板显示/隐藏、热键与焦点管理行为稳定。
