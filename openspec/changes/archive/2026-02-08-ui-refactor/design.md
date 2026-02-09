## Context

本变更聚焦于主面板（Main Panel）的 UI 大型改造（视觉 + 组件拆分 + 样式收敛），设计来源为：

- `design-system/main-panel/design.png`（整体氛围/布局锚点）
- `design-system/main-panel/v2-dark-mode.html`（状态与交互示例、比例与控件组成）
- `design-system/main-panel/macOS-design-spec.md`（tokens + macOS 实现建议：materials、阴影、滚动条偏好等）

工程/架构约束以 `platform/macos/ARCHITECTURE.md` 与 `AGENTS.md` 为准：

- macOS 层必须是 thin shell（只做 UI + 系统集成 + 适配），业务规则必须留在 Core。
- 强制 MVVM + Combine：View 只渲染 + 发送 Action；副作用只在 ViewModel/Service。
- AppKit 外壳 + SwiftUI 混合：窗口/面板由 AppKit 管理，SwiftUI 作为内部 UI。

当前主面板实现与依赖边界（用于设计对齐与迁移切点）：

- Composition Root：`platform/macos/Sources/App.swift`
  - `MainPanelWindowController` 负责 show/hide
  - `MainPanelViewModel` 负责 state/action
  - `ClipboardHistoryServiceImpl` 负责 Core history bridge（异步队列 + cache）
- Window Host：`platform/macos/Sources/View/MainPanelWindowController.swift`（NSPanel + NSHostingController + SnapKit）
- SwiftUI View Tree：`platform/macos/Sources/View/MainPanelView.swift`（目前所有子组件以内嵌 struct 形式存在）
- ViewModel：`platform/macos/Sources/ViewModel/MainPanelViewModel.swift`（200ms debounce；search limit=100；选择项拉取 full item）
- History Service：`platform/macos/Sources/Utils/ClipboardHistoryServiceImpl.swift`（后台队列；search cache；previewLength=200）

## Goals / Non-Goals

**Goals:**

- 视觉对齐：将布局比例（55/45）、玻璃质感（materials/blur）、暗色渐变背景、卡片层次、按钮渐变与阴影、列表项 hover/selected/focus 等，与设计资产一致。
- 工程化：把主面板 UI 拆分为可 review、可演进的文件/组件结构；消除 `MainPanelView.swift` 中大块内嵌组件导致的耦合。
- Tokens 收敛：在不引入新依赖的前提下，形成“主面板范围 tokens”的单一来源，并规范 SwiftUI 消费方式。
- 性能守恒：保持主面板高频操作体验（显示/隐藏、搜索、选择、预览切换），避免主线程阻塞与无界资源占用。
- 行为不变：保持 show/hide、热键、Esc 关闭、搜索语义、列表/预览语义不发生需求级改变（只改 UI 表现与代码组织）。

**Non-Goals:**

- 不修改 Core 能力与历史数据语义，不引入新的 Core API。
- 不新增第三方 UI 框架或 token 生成流水线（如需引入必须单独提案审批）。
- 不做跨平台 UI 统一（本次落点是 macOS 主面板）。

## Decisions

### 1) 目录与文件规划（结合现有 macOS 工程结构）

遵循 `platform/macos/ARCHITECTURE.md` 的 View/ViewModel/Model/Utils 分层，并在不改变顶层目录的前提下，为主面板建立清晰的子目录：

- `platform/macos/Sources/View/MainPanel/`
  - `MainPanelView.swift`：主面板组合视图（Search + Content + Footer），只做布局与注入。
  - `MainPanelSearchBar.swift`：搜索输入、清空按钮、focus 表现（SwiftUI；只绑定 state/action）。
  - `MainPanelContent.swift`：中间内容区容器（左右分栏 55/45；SwiftUI 负责整体 split 布局）。
  - `MainPanelPreviewPanel.swift`：预览面板“外壳”（SwiftUI；header actions + metadata + content slot）。
  - `MainPanelFooterView.swift`：快捷键提示/状态条（SwiftUI）。
  - `MainPanelMaterials.swift`：glass/material 相关的 SwiftUI 辅助（以及必要的 AppKit VisualEffect wrapper）。
  - `MainPanelTokens.swift`：主面板 tokens（颜色/排版/圆角/阴影/间距/material 选择）的单一来源。
  - `AppKit/`
    - `MainPanelItemTableRepresentable.swift`：列表（AppKit `NSTableView` + `NSScrollView`）的 SwiftUI bridge。
    - `MainPanelItemTableView.swift`：封装 `NSTableView` 的配置/复用/委托实现（View 层，不含业务）。
    - `MainPanelItemTableCellView.swift`：行视图（两行文本 + icon + selected/hover 样式）。
    - `MainPanelLongTextRepresentable.swift`：超长文本预览（AppKit `NSTextView` + `NSScrollView`）的 SwiftUI bridge。
    - `MainPanelLongTextView.swift`：封装 `NSTextView` 的配置（不可编辑、等宽字体、增量更新 textStorage）。

保持现有入口文件路径不发生“行为级变化”的前提下，允许将 `platform/macos/Sources/View/MainPanelView.swift` 从“单文件多内嵌 struct”迁移为“MainPanel/ 目录多文件”，并在迁移过程中保持 public API（对外只暴露 `MainPanelView(viewModel:)`）一致。

为便于后续把本设计同步到 `platform/macos/ARCHITECTURE.md`，这里给出建议的目录树（目标形态）：

```text
platform/macos/Sources/
├── App.swift
├── Model/
│   ├── ClipboardItemRow.swift
│   └── ClipboardSourceAttribution.swift
├── Utils/
│   ├── AppPaths.swift
│   ├── ClipboardHistoryService.swift
│   ├── ClipboardHistoryServiceImpl.swift
│   ├── ClipboardWatcher.swift
│   ├── HotkeyService.swift
│   ├── HotkeyServiceImpl.swift
│   └── CombineExtensions.swift
├── ViewModel/
│   ├── MainPanelViewModel.swift
│   └── HistoryItemViewModel.swift
└── View/
    ├── MainPanelWindowController.swift
    ├── HistoryWindowController.swift
    ├── HistoryViewController.swift
    └── MainPanel/
        ├── MainPanelView.swift
        ├── MainPanelSearchBar.swift
        ├── MainPanelContent.swift
        ├── MainPanelPreviewPanel.swift
        ├── MainPanelFooterView.swift
        ├── MainPanelMaterials.swift
        ├── MainPanelTokens.swift
        └── AppKit/
            ├── MainPanelItemTableRepresentable.swift
            ├── MainPanelItemTableView.swift
            ├── MainPanelItemTableCellView.swift
            ├── MainPanelLongTextRepresentable.swift
            └── MainPanelLongTextView.swift
```

### 2) 组件设计（边界、输入输出、职责）

组件边界以“只依赖 Presentation Model / ViewModel State”作为硬约束：

- `MainPanelView`（SwiftUI）
  - 选择：SwiftUI
  - 输入：`@ObservedObject viewModel: MainPanelViewModel`
  - 输出：无；仅组合布局
  - 责任：布局与子组件 wiring（Binding/Action 转发）；不做副作用。

- `MainPanelSearchBar`（SwiftUI）
  - 选择：SwiftUI
  - 输入：`searchQuery: Binding<String>`（或 `text: Binding<String>`）
  - 输出：通过 Binding 驱动 `.searchChanged`
  - 责任：focus/clear/button 样式；键盘 focus 表现必须可控。

- `MainPanelItemList`（AppKit via SwiftUI bridge）
  - 选择：AppKit（`NSTableView` + `NSScrollView`）
  - 原因：你明确要求“列表因滚动条体验与性能问题使用 AppKit 实现”。同时现有项目已存在 AppKit 列表范式（`platform/macos/Sources/View/HistoryViewController.swift`）。
  - 输入：`items: [ClipboardItemRow]`、`selectedId: String?`、`onSelect(id: String)`（或 `onSelect(itemId:)`）
  - 输出：onSelect -> ViewModel `.itemSelected(...)`（以 id 映射回 item）
  - 责任（UI-only）：
    - 渲染两行文本 + icon，满足设计状态（hover/selected/focus）
    - 滚动条：使用 `NSScrollView` 原生滚动条
    - 选择：通过 `NSTableViewDelegate` 回调上抛 selection changes
  - 禁止：在 cell/view 中做搜索、过滤、图片读取或业务逻辑。

- `MainPanelPreviewPanel`（SwiftUI + AppKit text preview）
  - 选择：预览外壳 SwiftUI；超长文本内容区 AppKit
  - 输入：`item: ClipboardItemRow?`
  - 输出：actions（例如 Copy/Edit/Delete）以回调形式上抛到 `MainPanelView` -> ViewModel（若现状无对应行为，先保留 UI slot，不新增语义）。
  - 责任：
    - SwiftUI：header actions + metadata grid + content slot 布局
    - AppKit：当 `item.type == .text` 且内容可能超长时，使用 `NSTextView`（不可编辑、可选择、等宽字体）承载，规避 SwiftUI Text 在超长文本下的渲染/性能问题（你明确指出此痛点）。
    - 图片预览：暂保留 SwiftUI（后续若仍受 `NSImage(contentsOfFile:)` 主线程 IO 影响，再按性能边界改为异步 loader/或切到 AppKit `NSImageView`）。

- `MainPanelFooterView`（SwiftUI）
  - 选择：SwiftUI
  - 输入：可选（例如显示当前数量/快捷键提示）；默认静态
  - 责任：快捷键提示的视觉与排版对齐

为让 review 更直观，组件技术选型矩阵如下：

| Component | Tech | Files (proposed) | Why |
|---|---|---|---|
| Panel host (window) | AppKit | `platform/macos/Sources/View/MainPanelWindowController.swift` | NSPanel 生命周期/层级/空间行为必须在 AppKit |
| Layout shell (Search + Split + Footer) | SwiftUI | `platform/macos/Sources/View/MainPanel/MainPanelView.swift` | 保持 SwiftUI 组合优势，外层仍 thin shell |
| Search bar | SwiftUI | `platform/macos/Sources/View/MainPanel/MainPanelSearchBar.swift` | 简单、稳定 |
| Item list + scrollbar | AppKit | `platform/macos/Sources/View/MainPanel/AppKit/MainPanelItemTable*.swift` | 你要求；原生滚动条与大列表性能更可控 |
| Preview header + metadata | SwiftUI | `platform/macos/Sources/View/MainPanel/MainPanelPreviewPanel.swift` | 布局/样式更易对齐设计资产 |
| Preview long text | AppKit | `platform/macos/Sources/View/MainPanel/AppKit/MainPanelLongText*.swift` | 你要求；规避 SwiftUI 超长文本渲染问题 |
| Preview image | SwiftUI (暂定) | `platform/macos/Sources/View/MainPanel/MainPanelPreviewPanel.swift` | 暂保留；后续按性能风险再调整 |
| Footer | SwiftUI | `platform/macos/Sources/View/MainPanel/MainPanelFooterView.swift` | 简单、稳定 |

### 3) 视觉实现策略（glass + gradient + cards）

优先采用系统材料与轻量 shape，避免自绘 blur：

- Window/Panel 背景：以 `macOS-design-spec.md` 的建议为主
  - SwiftUI：`.background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))` 或 `.background(.ultraThinMaterial)`（最终实现择一）
  - AppKit：必要时在 `MainPanelWindowController` 的 contentView 下加 `NSVisualEffectView` 作为底层背景，再叠加 hosting view
- Cards/Sections：统一使用 tokens 中的 cornerRadius + border + shadow 配置，避免各处手写
- 渐变背景：限定在主面板根视图一处实现（避免多个渐变叠加造成过度绘制）

### 4) 性能边界（硬指标 + 关键风险点 + 守卫策略）

- P2（响应性）：主面板交互类操作目标 < 100ms（典型：列表滚动、选中切换、复制按钮反馈）。
- 搜索体验：现有 `MainPanelViewModel` 已设定 200ms debounce（`MainPanelViewModel.swift`），目标是“键入不掉帧 + 200ms 后触发查询 + 查询返回后 UI 更新不卡顿”。
- 数据/线程：
  - 查询已在后台队列执行（`ClipboardHistoryServiceImpl.swift` 的 `workQueue`）
  - UI 更新必须回到主线程（现状已经 `receive(on: DispatchQueue.main)`）

必须明确并修复/约束的现有高风险点（UI 改造时不能恶化）：

- 预览图片读取：当前 `MainPanelView.swift` 在 `body` 中执行 `NSImage(contentsOfFile:)`。
  - 风险：大图/磁盘 IO 可能阻塞主线程，引发卡顿。
  - 设计决策：实现阶段引入“异步图片加载 + 轻量缓存/取消”机制：
    - 在 `Utils/` 或 `View/MainPanel/` 内实现一个小型 `ImageLoader`（使用 `DispatchQueue`/Combine），避免新依赖；
    - PreviewPanel 只绑定一个 `@StateObject` loader 或由 ViewModel 预取缩略图（不改变 Core 语义）。

缓存边界（基于现状）：

- 搜索缓存：`ClipboardHistoryServiceImpl.swift` 已限制 `cacheLimit=50`，且 key 包含 query/limit/previewLength；保持该上限，避免无限增长。
- 搜索结果上限：现状查询 limit=100（`MainPanelViewModel.swift`）；UI 侧不应渲染无界列表。
- 预览文本：现状 previewLength=200（`ClipboardHistoryServiceImpl.swift`）；UI 侧不应对超长文本做复杂富文本排版。

新增的 AppKit 组件性能边界（由选型带来的守卫项）：

- AppKit 列表（`NSTableView`）必须满足：
  - 以稳定 `id` 驱动 selection（不使用 row index 作为状态源），避免 items 变动导致错选。
  - items 更新时避免“每次都全量 reload”造成抖动：实现阶段可先 `reloadData()` 达到正确性，再升级为增量更新（Oracle 建议：Coordinator 做 diff/apply；仍不引入新依赖）。
  - cell 配置轻量：不在 cell 中读取图片/磁盘 IO；文本截断在 Model/VM 侧（例如沿用 previewLength 与 `lineBreakMode`）。

- AppKit 超长文本预览（`NSTextView`）必须满足：
  - 只在选中项 id 变化或文本内容变化时更新 `textStorage`；避免每次 state emission 都重设全文。
  - 禁用编辑相关开销（不可编辑；禁用自动替换/拼写检查等），确保滚动/选择顺滑。

### 5) 迁移/落地计划（可 review、可回滚、符合目录结构）

阶段 0：基线与回归清单（不改代码或只补文档）

- 行为基线（与 `App.swift`/`MainPanelViewModel.swift` 一致）：
  - 热键 toggle（`HotkeyService` + `MainPanelViewModel.Action.togglePanel`）
  - 菜单 Open Panel（`App.openPanel` -> `.showPanel`）
  - Esc 关闭（`App.setupKeyboardMonitor` 监听 keyDown，keyCode=53 时 toggle）
  - 搜索 debounce（200ms）与结果更新
  - 选中项 -> 拉取 full item（`historyService.get`）

阶段 1：纯结构拆分（不改视觉）

- 将 `platform/macos/Sources/View/MainPanelView.swift` 内嵌组件拆到 `platform/macos/Sources/View/MainPanel/`，保持对外 `MainPanelView` API 不变。

阶段 2：引入主面板 tokens（最小集）

- 在 `MainPanelTokens.swift` 定义：
  - Colors：backgroundGradient、surface、card、border、textPrimary/Secondary/Muted、accentPrimary
  - Typography：body/bodyBold/small/smallBold/code
  - Effects：panelShadow/buttonShadow、materials（hudWindow/ultraThin/regular）
  - Layout：cornerRadius、padding、splitRatio（55/45）

阶段 3：AppKit 列表与超长文本预览落地（先保正确性，再调性能）

- 先引入 `NSTableView` 列表 bridge 替换 SwiftUI `List`（保持行为：选择/滚动/快捷键不变）。
- 再引入 `NSTextView` 作为 text 预览承载（保持：可选择、等宽字体、滚动顺滑）。
- 该阶段先允许 `reloadData()` 作为正确性手段，后续在性能验证通过后再做增量更新。

阶段 4：视觉对齐（逐项落地，避免大爆炸）

- 先对齐“整体容器与分栏比例”，再对齐“行/按钮状态”，最后对齐“预览区细节”。

阶段 5：性能与体验补强

- 异步图片加载与取消；避免 `body` 内同步 IO。
- 校验列表滚动/搜索输入期间无明显掉帧。

### 6) 验证策略（让 review 可落地）

- 编译验证：修改 `platform/macos/` 后，运行 `./scripts/platform-build-macos.sh Debug`。
- 手工回归（每次阶段性提交都跑）：
  - toggle panel（热键/菜单/点击）
  - Esc 关闭
  - 搜索输入连续键入（无卡顿；200ms 后更新结果）
  - 列表上下选择与预览切换（无主线程卡顿）
  - 图片预览（大图/丢失路径）

## Risks / Trade-offs

- [主线程阻塞（图片加载/富文本排版）] → 严禁在 `View.body` 执行磁盘 IO；图片预览引入异步 loader + 轻量缓存。
- [视觉对齐过度追求导致违反原生行为] → 滚动条优先保留原生（`macOS-design-spec.md` 也建议原生优先）。
- [大范围重排导致回归难定位] → 按阶段拆分：结构拆分 -> tokens -> 视觉对齐 -> 性能补强；每阶段可回滚。
- [tokens 抽象过度] → tokens 只覆盖主面板范围，不扩散到全局主题。

## Resolved Decisions

### 7) 样式落点与语义化策略

- 决策：样式通过"语义化 tokens"落到主面板范围，并优先选择可复用的命名，避免纯视觉值（例如不用 `#2DD4BF` 而用 `accentPrimary`）。
- 理由：语义化便于后续跨模块复用，且在实现阶段更容易与设计资产对齐（设计稿也以语义命名为主，如 `Text Primary` 而非 `Gray-200`）。
- 落点：在 `MainPanelTokens.swift` 中以语义化方式定义 tokens（例如 `accentPrimary`、`surface`、`textPrimary`），并在 SwiftUI 中映射到具体 SwiftUI/AppKit 实现（`.teal`、`.gray.opacity(0.9)` 等）。
- 未来扩展：如需要"全局通用"样式体系，可从主面板 tokens 抽出公共命名空间（例如 `AppTokens` 或 `DesignTokens`），但不在此阶段强制引入。

### 8) NSPanel 底座实现（完全透明底座）

### 背景

- 决策：NSPanel 作为"底座"应保持完全透明、无边框；所有可见 UI 由 SwiftUI 内容承载。
- 理由：你的需求是"在底层 NSPanel 上封装具体 UI，NSPanel 只做展示底座，需要完全透明/没有边界"。当前配置已使用 `.nonactivatingPanel` 实现 HUD 半透明风格，但未启用 `.fullSizeContentView`，这导致 `hostingController.view` 可能被 NSPanel 带有半透明背景。
- 参考资料：
  - Apple 文档：`NSPanel.styleMask` 包含 `.fullSizeContentView`，会让 `contentView` 区域完全透明（不受窗口样式影响）。
  - 社区实践：设置 `panel.backgroundColor = nil` 或使用 `NSVisualEffectView` 作为 `contentView` 时可达到全透明。

### 实现方案（二选一）

#### 方案 A：启用 `.fullSizeContentView`，移除 `.nonactivatingPanel`

**推荐**：用于需要"完全透明底座"的场景（SwiftUI 内容不接收任何窗口样式的干扰）。

```swift
let panel = NSPanel(
    contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
    styleMask: [.nonactivatingPanel, .borderless, .resizable, .fullSizeContentView],  // 关键：.fullSizeContentView
    backing: .buffered,
    defer: false
)
// 其他配置保持不变
```

**权衡**：`.fullSizeContentView` 会导致 NSPanel 完全失去系统背景/半透明特性（标题栏也会变成半透明），如果需要保留 HUD 半透明效果，则需配合 SwiftUI 的 `.visualEffect(.material)`。

---

#### 方案 B：保持现有配置，改用 `NSVisualEffectView` 作为底座

**备选**：用于希望保留窗口半透明/毛玻璃效果，同时确保 SwiftUI 内容不受背景色影响。

```swift
private let visualEffectView = NSVisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
visualEffectView.frame = contentView.bounds

// 方式 B.1：将 visualEffectView 作为 contentView（覆盖 hosting controller.view）
panel.contentView = visualEffectView
setupLayout()

// 方式 B.2：visualEffectView 放在底层，hosting view 堆加其上
contentView.addSubview(hostingController.view)
hostingController.view.snp.makeConstraints { make in
    make.edges.equalToSuperview()
}
visualEffectView.snp.makeConstraints { make in
    make.edges.equalToSuperview()
}
```

**权衡**：需要在 `MainPanelWindowController` 中管理额外约束（SnapKit），增加复杂度。

---

### 落点与迁移阶段

- **阶段 0（基线冻结）**：记录当前 NSPanel 半透明效果，确保迁移后效果可对比。
- **阶段 1（结构拆分）**：在迁移 `MainPanelView` 到多文件同时，调整 `MainPanelWindowController` 的 NSPanel 配置（按上述方案）。
- **阶段 2（视觉对齐）**：SwiftUI 内容中可选择性使用 `.containerBackground(.ultraThinMaterial)` 实现玻璃质感底座效果（与设计资产对齐）。
- **阶段 3（验证）**：验证 NSPanel 底座在不同 macOS 版本下的一致性，确认无边框/无背景色渲染正确。

### 风险与守卫

- [NSPanel 配置不当导致 SwiftUI 背景异常] → 优先验证阶段 0，对比迁移前后效果。
- [SnapKit 约束冲突] → 若选择方案 B，确保约束更新不破坏现有布局。
- [`.fullSizeContentView` 与 SwiftUI `.containerBackground` 混合] → 不在 SwiftUI 内容中再显式设置背景色，避免冲突。

### 验证清单（手工回归）

- NSPanel 窗口边界：确认无边框、无标题栏、无阴影。
- 透明效果：确认底座完全透明或预期半透明（根据方案）。
- SwiftUI 内容可见性：确认所有 UI 元素在底座之上正常显示。
- 窗口层级：确认 `panel.level = .floating` 确保面板在最顶层。
- 拖拽与位置：验证 `isMovableByWindowBackground` 与 `show(at:)` 行为一致。

---

## Open Questions（Resolved，以下为历史记录）

以下问题已在上文“Resolved Decisions”中明确回答，保留在此处便于追踪原始讨论：

- [已解决] `MainPanelTokens.swift` 的落点是否需要与现有工程（若存在）通用样式体系对齐？→ 使用语义化命名，优先复用，不强制全局化。
- [已解决] 预览区是否需要新增 actions（Copy/Edit/Delete）对应的 ViewModel Action？→ 不需要；预览区为只读展示。
- [已解决] AppKit bridge 的粒度：列表（`NSTableView`）与长文本预览（`NSTextView`）是否需要合并为一个“内容区 AppKit island”以减少状态同步复杂度？→ 不合并；拆为两个独立 bridge，降低同步复杂度与性能风险。
- [已解决] 图片预览的 SwiftUI vs AppKit 决策→ 图片预览暂保留 SwiftUI，仅在性能验证后考虑迁移。

（注：原始 Open Questions 段落已由Resolved Decisions 取代，保留在 Open Questions 下方便于追溯讨论过程。）
