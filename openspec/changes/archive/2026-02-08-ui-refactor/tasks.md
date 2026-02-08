## 1. 阶段 0：基线与回归清单

- [x] 1.1 记录当前主面板行为基线（热键 toggle、Esc 关闭、搜索 debounce、选中项拉取 full item）
- [x] 1.2 记录当前 NSPanel 半透明效果用于后续对比
- [x] 1.3 创建手工回归测试清单（toggle panel、Esc 关闭、搜索输入、列表选择、预览切换、图片预览）
- [x] 1.4 运行基线测试并记录性能指标（面板显示/隐藏时间、搜索响应时间、列表滚动 fps）

## 2. 阶段 1：纯结构拆分（不改视觉）

- [x] 2.1 创建 `platform/macos/Sources/View/MainPanel/` 目录结构
- [x] 2.2 在 MainPanel/ 目录下创建 `AppKit/` 子目录
- [x] 2.3 从 MainPanelView.swift 提取 MainPanelSearchBar 组件到独立文件
- [x] 2.4 从 MainPanelView.swift 提取 MainPanelContent 组件到独立文件（包含 55/45 分栏布局）
- [x] 2.5 从 MainPanelView.swift 提取 MainPanelPreviewPanel 组件到独立文件（包含 header、metadata grid、content slot）
- [x] 2.6 从 MainPanelView.swift 提取 MainPanelFooterView 组件到独立文件
- [x] 2.7 创建 MainPanelMaterials.swift 文件用于玻璃材质辅助
- [x] 2.8 重构 MainPanelView.swift 为组合视图，只做布局与子组件 wiring
- [x] 2.9 验证 MainPanelView 公开 API 保持不变（`MainPanelView(viewModel:)`）
- [x] 2.10 编译验证：运行 `./scripts/platform-build-macos.sh Debug` 确保结构拆分不破坏构建

## 3. 阶段 2：引入主面板 tokens（最小集）

- [x] 3.1 创建 `MainPanelTokens.swift` 文件定义 tokens 单一来源
- [x] 3.2 定义颜色 tokens（backgroundGradient、surface、card、border、textPrimary/Secondary/Muted、accentPrimary/Gradient）
- [x] 3.3 定义排版 tokens（body、bodyBold、small、smallBold、code）
- [x] 3.4 定义效果 tokens（materialHudWindow、materialUltraThin、materialRegular、panelShadow、buttonShadow）
- [x] 3.5 定义布局 tokens（cornerRadius、padding、paddingCompact、splitRatio）
- [x] 3.6 为每个 token 添加内联文档注释（用途、使用上下文）
- [x] 3.7 验证所有 tokens 与 `macOS-design-spec.md` 对齐
- [x] 3.8 将 tokens 映射到 SwiftUI/AppKit 类型（Color、Material、Font、CGFloat）
- [x] 3.9 更新现有组件使用 MainPanelTokens 而非硬编码值

## 4. 阶段 3：AppKit 列表与超长文本预览落地（先保正确性，再调性能）

- [x] 4.1 创建 `MainPanelItemTableRepresentable.swift` SwiftUI bridge 文件
- [x] 4.2 创建 `MainPanelItemTableView.swift` 封装 NSTableView 配置/复用/委托实现
- [x] 4.3 创建 `MainPanelItemTableCellView.swift` 行视图（两行文本 + icon + selected/hover 样式）
- [x] 4.4 在 MainPanelContent 中集成 NSTableView bridge 替换 SwiftUI List
- [x] 4.5 实现列表项 hover、selected、focus 视觉状态
- [x] 4.6 配置 NSTableView 支持键盘导航（Arrow Up/Down、Page Up/Down、Home/End）
- [x] 4.7 创建 `MainPanelLongTextRepresentable.swift` SwiftUI bridge 文件
- [x] 4.8 创建 `MainPanelLongTextView.swift` 封装 NSTextView 配置
- [x] 4.9 在 MainPanelPreviewPanel 中集成 NSTextView bridge 用于长文本预览
- [x] 4.10 配置 NSTextView 为不可编辑、可选择、等宽字体
- [x] 4.11 实现文本 content 只在选中项 id 变化或内容变化时更新（避免每次 state emission 重设）
- [x] 4.12 验证列表滚动和文本滚动平滑性
- [x] 4.13 暂时使用 `reloadData()` 确保正确性（性能优化留到后续）

## 5. 阶段 4：视觉对齐（逐项落地，避免大爆炸）

- [x] 5.1 对齐主面板根视图背景渐变（135deg，#1a1a2e 0%，#16213e 50%，#0f0f23 100%）
- [x] 5.2 实现主面板玻璃材质效果（使用 .hudWindow 或 .ultraThinMaterial）
- [x] 5.3 对齐搜索栏默认状态（半透明背景 bg-black/30、浅色边框 white/10）
- [x] 5.4 实现搜索栏聚焦状态（深色背景 bg-black/40、青色边框 #2DD4BF、发光效果）
- [x] 5.5 添加搜索栏左侧放大镜图标
- [x] 5.6 实现搜索栏清除按钮（有文本时显示，点击清除后恢复默认状态）
- [x] 5.7 对齐列表项默认状态（透明背景、32x32 图标、标题、副标题）
- [x] 5.8 实现列表项 hover 状态（半透明白色 bg-white/6）
- [x] 5.9 实现列表项 selected 状态（青色调 bg-[#2DD4BF]/12、左侧 3px 青色边框）
- [x] 5.10 对齐预览面板 header 操作按钮（Copy、Edit、Delete）
- [x] 5.11 实现预览面板 metadata grid（Type 徽章、源应用、日期/时间、大小/尺寸）
- [x] 5.12 对齐文本预览语法高亮（关键词紫色 #C084FC、字符串绿色 #4ADE80、函数黄色 #FDE047）
- [x] 5.13 对齐图片预览（适应容器、圆角）
- [x] 5.14 对齐卡片和 section 玻璃效果（ultraThinMaterial.opacity(0.3)、12px 圆角、浅色边框）
- [x] 5.15 对齐主按钮渐变（#0D9488 到 #14B8A6）和阴影
- [x] 5.16 实现状态栏快捷键提示（Esc 关闭等，使用静音文本颜色 #6B7280）
- [x] 5.17 调整 NSPanel 配置为完全透明底座（根据 design.md 方案 A 或 B）
- [x] 5.18 验证所有视觉状态与 `design-system/main-panel/` 资产对齐
- [x] 5.19 调整 55/45 分栏比例确保正确
- [x] 5.20 运行完整手工回归测试（面板 toggle、Esc、搜索、选择、预览）

## 6. 阶段 5：性能与体验补强

- [x] 6.1 实现异步图片加载机制（使用 DispatchQueue/Combine，避免新依赖）
- [x] 6.2 实现轻量图片缓存（避免重复加载相同图片）
- [x] 6.3 实现图片加载取消机制（用户快速切换项目时取消未完成的加载）
- [x] 6.4 在图片加载期间显示占位符
- [x] 6.5 优化大图片预览（缩放或显示缩略图）
- [x] 6.6 移除 MainPanelView.body 中的同步 `NSImage(contentsOfFile:)` 调用
- [x] 6.7 验证图片加载不阻塞主线程（监控主线程性能）
- [x] 6.8 实现 NSTableView 增量更新（避免每次全量 reload 造成抖动）
- [x] 6.9 实现列表项 cell 配置轻量化（不在 cell 中做图片读取或磁盘 IO）
- [x] 6.10 验证列表滚动保持 60fps 或更高
- [x] 6.11 禁用 NSTextView 编辑相关开销（自动替换、拼写检查等）
- [x] 6.12 验证长文本预览滚动平滑
- [x] 6.13 性能测试：面板显示/隐藏 <100ms
- [x] 6.14 性能测试：搜索输入立即更新，200ms 防抖后结果更新，不丢帧
- [x] 6.15 性能测试：预览切换 <100ms
- [x] 6.16 最终手工回归测试：验证所有高频交互无卡顿、无主线程阻塞
