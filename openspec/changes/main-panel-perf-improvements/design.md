## Context

**背景**
主面板目前存在严重的性能问题和用户体验缺陷。用户反馈点击包含长字符串的剪贴板历史项时，UI 会冻结约 2 秒，严重影响了使用流畅度。同时，列表不会在剪贴板变化后自动更新，ESC 键无法切换面板，主面板还有不必要的交通灯窗口控制按钮。

**当前状态**
- 核心层通过 C++ API `pasty_history_search` 返回 JSON 字符串
- 平台层（Swift）将 JSON 反序列化为 `ClipboardItemRow` 数组
- 每次搜索或选择 item 都会触发完整的 JSON 序列化/反序列化流程
- ClipboardWatcher 仅检测剪贴板变化并持久化，缺少通知 UI 的机制
- MainPanelView 显示 "Esc to close" 但实际未实现
- MainPanelWindowController 使用标准 NSPanel 配置，包含交通灯按钮
- 核心层 `SQLiteClipboardHistoryStore` 没有互斥锁保护，存在线程安全问题

**约束**
根据 AGENTS.md 规定：
- **Prime Directive**: 优先选择能通过编译/测试的最小安全变更
- **Architecture**: C++ Core 是业务逻辑和数据模型的真理来源，平台层是薄壳（UI、OS 集成、权限和适配器）
- **Repo boundaries**: 不创建新顶级目录，不引入新第三方依赖
- **C++ Core rules**: 保持可移植性，无平台头文件，所有平台交互通过接口（ports）
- **Quality gates**: 必须确保变更后构建成功、测试通过

根据 constitution.md 规定：
- **P2: Performance Responsive**: UI 操作 <100ms，内存 <200MB/10K条目，启动 <2s
- **P3: Cross-Platform Compatibility**: 支持 macOS/Windows/Linux，功能对等

根据 core/ARCHITECTURE.md 规定：
- Core 层是数据模型与规则的唯一真相来源
- 依赖方向永远是 `platform/*` -> `core`（单向）
- Core 禁止依赖任何平台头文件/库

根据 platform/macos/ARCHITECTURE.md 规定：
- macOS 层是 thin shell：只做 UI、系统集成、适配层
- 开发模式：MVVM + Combine
- View 只能绑定 ViewModel State，禁止 View 直接操作数据
- ViewModel 是唯一可以触发副作用的层（通过依赖注入的 Service/Adapter）

**利益相关者**
- 最终用户：需要流畅的剪贴板历史浏览体验（UI 响应 <100ms）
- 开发团队：需要保持代码可维护性和跨平台性

## Goals / Non-Goals

**Goals:**
- 消除点击 item 时的 2 秒 UI 冻结，实现 <100ms 响应
- 在剪贴板内容成功持久化后自动刷新列表
- 实现 ESC 键切换面板显示/隐藏功能
- 移除主面板的交通灯按钮，保持简洁外观
- 保持核心层的跨平台可移植性
- 确保不引入新的第三方依赖
- 遵循 MVVM + Combine 架构模式

**Non-Goals:**
- 不修改核心数据模型或存储结构
- 不改变其他平台（如未来可能的 Windows/Linux）的架构
- 不引入新的依赖库（如 Protocol Buffers）
- 不影响现有的历史搜索功能
- 不破坏现有的剪贴板监视机制
- 不在 View 层实现业务逻辑（包括数据传输优化）

## Decisions

### 1. 性能瓶颈分析与最小化优化

**性能瓶颈分析**：
1. **JSON 序列化/反序列化**：核心层返回 JSON 字符串，Swift 端解码，对于长字符串（如 10K+ 字符）开销巨大
2. **SwiftUI 渲染性能**：PreviewPanel 中的 `Text(item.content)` 对于超长字符串会导致 SwiftUI 大量布局计算
3. **线程不安全**：核心层 SQLite 数据库访问没有互斥锁，可能导致并发访问问题

**决策：优先解决最严重的性能瓶颈，采用最小化变更**

**理由**：
- 根据 AGENTS.md Prime Directive："Prefer smallest safe change that passes build/tests"
- 一次性解决所有问题违反了最小化原则
- 应该先解决最严重的性能问题（JSON 序列化），然后逐步优化其他方面

**技术方案（分阶段）**：

**阶段 1：减少不必要的字符串操作（立即实施）**
- ItemRow 中的 `trimmingCharacters` 操作在列表渲染时对每个 item 都会执行
- 优化：在 Core 层搜索时返回已截断的预览内容（如前 200 字符）
- 在 `SearchOptions` 中添加 `previewLength` 参数

**阶段 2：缓存机制（快速优化）**
- 在 `ClipboardHistoryServiceImpl` 中添加简单的内存缓存
- 缓存最近查询的结果，避免重复的 JSON 解码
- 使用 LRU 缓存策略，限制缓存大小

**阶段 3：核心层线程安全（确保稳定性）**
- 在 `SQLiteClipboardHistoryStore` 中添加 `std::mutex` 保护数据库访问
- 保护所有数据库操作（search, getItem, upsert 等）
- 避免并发访问导致的数据损坏或崩溃

**替代方案（不采用）**：
- 新增基于指针的 C API：引入复杂度，违反最小化原则 ❌
- SwiftUI 渲染重构：应在后续单独的变更中处理 ❌

### 2. ClipboardWatcher 回调机制

**决策**：为 ClipboardWatcher 添加可选的 `onChange` 闭包参数

**理由**：
- 最小侵入性，不改变现有剪贴板监视逻辑
- 符合 Swift 的 Combine/Publisher 模式
- 符合 MVVM 架构：ViewModel 通过 Service 订阅数据变化
- 符合 platform/macos/ARCHITECTURE.md："禁止滥用全局通知（NotificationCenter），业务交互使用 Coordinator 模式"

**技术方案**：
```swift
func start(interval: TimeInterval = 0.4, onChange: (() -> Void)? = nil)
```
- `onChange` 闭包在 `captureCurrentClipboard` 成功后调用
- App.swift 中组装依赖：将 ClipboardWatcher 的 onChange 绑定到 ViewModel 的列表刷新操作
- ViewModel 添加新的 Action：`case clipboardContentChanged`

**替代方案**：
- NotificationCenter：违反架构规范，增加全局状态管理复杂度 ❌
- Combine Publisher：可以但引入异步，增加复杂度，违反最小化原则 ⚠️

### 3. ESC 键事件处理

**决策**：在 App.swift 中添加本地事件监视器（NSEvent.addLocalMonitorForEvents），仅在应用激活且面板显示时响应

**理由**：
- 最小改动，无需修改 MainPanelView 的键盘事件处理
- 可以全局捕获 ESC 键，无论当前焦点在哪个子视图
- 符合 macOS 应用中键盘快捷键的常见模式
- App.swift 设置了 `NSApp.setActivationPolicy(.accessory)`，需要检查应用是否激活

**技术方案**：
```swift
NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
    // 只在应用激活时响应 ESC 键
    guard NSApp.isActive, self.viewModel.state.isVisible else {
        return event
    }
    if event.keyCode == 53 { // ESC
        self.viewModel.send(.togglePanel)
        return nil // 消费事件
    }
    return event
}
```
- 仅在应用激活（`NSApp.isActive`）且面板显示时响应 ESC 键
- 使用 `viewModel.state.isVisible` 判断面板状态
- 应用的激活策略为 `.accessory`，不会在 Dock 中显示

**替代方案**：
- SwiftUI `.onKeyPress` 修饰符：需要在 MainPanelView 中添加，且可能被子视图拦截 ⚠️
- NSWindow.keyDown 重写：需要在 NSWindowController 中实现，侵入性较大 ⚠️

### 4. 移除交通灯按钮

**决策**：修改 NSPanel 的 styleMask，移除 `.titled`，添加 `.nonactivatingPanel` 和 `.borderless`

**理由**：
- `.titled` 样式会自动添加交通灯按钮
- 面板应通过热键或 ESC 切换，不需要窗口控制按钮
- `.nonactivatingPanel` 保持面板浮动特性

**技术方案**：
```swift
let panel = NSPanel(
    contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
    styleMask: [.nonactivatingPanel, .resizable], // 移除 .titled, .closable
    backing: .buffered,
    defer: false
)
panel.titleVisibility = .hidden
panel.titlebarAppearsTransparent = true
```

**替代方案**：
- 自定义标题栏视图覆盖：需要额外 UI 代码，复杂度高 ❌
- 保留交通灯但隐藏：`.titled` 样式下无法完全隐藏，视觉效果不佳 ⚠️

## Risks / Trade-offs

**风险 1**：缓存机制可能引入数据一致性问题
→ **缓解措施**：使用简单的 LRU 缓存，限制缓存大小（如 50 条目）；在剪贴板内容变化时清除相关缓存

**风险 2**：ESC 键全局事件监视器可能与其他键盘快捷键冲突
→ **缓解措施**：仅在面板显示时响应 ESC；检查事件是否已被其他处理器消费；提供用户可配置的快捷键设置（后续变更）

**风险 3**：移除 `.titled` 样式后，窗口可能失去某些 macOS 集成特性（如 Spaces 集成）
→ **缓解措施**：测试 Spaces 集成行为；如必要，添加 `.utilityWindow` 样式保持部分窗口特性

**风险 4**：核心层添加互斥锁可能影响性能
→ **缓解措施**：使用轻量级的 `std::mutex`；确保锁的持有时间尽可能短；在后续变更中考虑使用读写锁优化读多写少场景

**权衡**：
- 性能 vs 可维护性：采用分阶段优化策略，优先解决最严重的问题。接受权衡，因为符合"smallest safe change"原则。
- 简洁性 vs 功能完整性：移除交通灯简化了 UI，但减少了标准窗口控制。接受权衡，因为面板设计应通过热键/ESC 控制。

## Migration Plan

**阶段 1：立即实施（性能优化）**

1. 核心层修改
   - 在 `SearchOptions` 中添加 `previewLength` 字段
   - 修改 `search` 方法，对返回的文本内容进行截断（前 200 字符）
   - 在 `SQLiteClipboardHistoryStore` 中添加 `std::mutex` 保护数据库访问
   - 在 `include/pasty/api/history_api.h` 中添加新参数
   - 在 `core/src/Pasty.cpp` 中更新 C API

2. 平台层修改
   - 修改 `ClipboardHistoryServiceImpl` 添加简单的 LRU 缓存
   - 在 `ClipboardItemRow` 中移除不必要的 `trimmingCharacters` 操作
   - 更新 `Model/ClipboardItemRow.swift`

3. 测试
   - 运行 `./scripts/core-build.sh` 验证 Core 层编译
   - 运行 `./scripts/platform-build-macos.sh Debug` 验证平台层编译
   - 性能测试：对比优化前后的响应时间

**阶段 2：列表自动刷新**

4. 修改 `ClipboardWatcher`
   - 添加 `onChange` 闭包参数
   - 在 `captureCurrentClipboard` 成功后调用 onChange

5. 修改 `MainPanelViewModel`
   - 添加新的 Action：`case clipboardContentChanged`
   - 添加对应的处理逻辑：触发 `performSearch` 刷新列表

6. 修改 `App.swift`
   - 组装依赖：将 ClipboardWatcher 的 onChange 绑定到 ViewModel

**阶段 3：ESC 键和交通灯移除**

7. 修改 `App.swift`
   - 添加 NSEvent 监听器处理 ESC 键
   - 添加 `NSApp.isActive` 检查

8. 修改 `MainPanelWindowController`
   - 修改 NSPanel 的 styleMask

9. 最终测试
   - 运行完整的集成测试
   - 验证所有功能正常工作

**回滚策略**：
- Git 版本控制支持快速回退到已知稳定状态
- 每个阶段独立提交，便于分阶段回滚
- 如遇问题，通过注释代码快速禁用新功能

## Testing Strategy

### 单元测试

**核心层测试**（`core/tests/`）：
- `SQLiteClipboardHistoryStore` 线程安全测试：并发调用 search/ingest
- 搜索功能测试：验证 `previewLength` 参数的正确性
- 缓存一致性测试：验证缓存机制不会导致数据不一致

**平台层测试**：
- `ClipboardHistoryServiceImpl` 缓存测试：验证 LRU 缓存正确性
- `ClipboardWatcher` 回调测试：验证 onChange 正确触发

### 性能测试

**基准测试**：
- 测试点击长字符串 item 的响应时间（目标：<100ms）
- 测试列表刷新的响应时间（目标：<100ms）
- 测试内存使用（目标：<200MB/10K条目）

**测试环境**：
- macOS 14+（最低支持版本）
- 10K+ 历史条目
- 长字符串内容（10K+ 字符）

### 集成测试

**端到端测试**：
- 剪贴板内容变化后，列表自动刷新
- ESC 键正确切换面板显示/隐藏
- 面板没有交通灯按钮
- UI 响应流畅，无卡顿

## Open Questions

1. **缓存策略**：是否需要持久化缓存？还是仅内存缓存足够？
   - 建议：仅内存缓存，避免增加持久化复杂度

2. **预览长度**：200 字符的预览长度是否合适？是否需要可配置？
   - 建议：使用固定值 200 字符，后续可根据用户反馈调整

3. **性能目标**：是否需要更严格的性能指标（如 P50/P95/P99）？
   - 建议：先实现基础优化，在后续变更中引入详细的性能监控

4. **跨平台扩展**：ESC 键的处理方式是否需要在其他平台保持一致？
   - 建议：其他平台也使用 ESC 进行 toggle 面板隐藏，保持跨平台一致性
