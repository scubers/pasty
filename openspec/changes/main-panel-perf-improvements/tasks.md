## 1. 阶段 1：立即实施（性能优化）

### 核心层修改

- [x] 1.1 在 `core/include/pasty/history/types.h` 中的 `SearchOptions` 结构体添加 `previewLength` 字段（默认值：200）
- [x] 1.2 修改 `core/src/history/store_sqlite.cpp` 中的 `search` 方法，对返回的文本内容进行截断（使用 `substr` 或类似方法）
- [x] 1.3 在 `core/src/history/store_sqlite.cpp` 中的 `SQLiteClipboardHistoryStore` 类添加 `std::mutex` 成员变量
- [x] 1.4 在 `core/src/history/store_sqlite.cpp` 中的所有数据库操作方法（search, getItem, upsert 等）添加互斥锁保护
- [x] 1.5 更新 `core/include/pasty/api/history_api.h` 中的 `pasty_history_search` 函数声明，添加 `previewLength` 参数
- [x] 1.6 更新 `core/src/Pasty.cpp` 中的 `pasty_history_search` C API 实现，传递 `previewLength` 参数到核心层

### 平台层修改

- [x] 1.7 修改 `platform/macos/Sources/Utils/ClipboardHistoryServiceImpl.swift`，添加简单的 LRU 缓存机制（使用 NSCache 或字典）
- [x] 1.8 在 `platform/macos/Sources/Model/ClipboardItemRow.swift` 中移除不必要的 `trimmingCharacters` 操作（因为核心层已截断）
- [x] 1.9 更新 `platform/macos/Sources/Utils/ClipboardHistoryServiceImpl.swift`，使用缓存避免重复的 JSON 解码

### 验证与测试

- [x] 1.10 运行 `./scripts/core-build.sh` 验证 Core 层编译成功，无错误和警告
- [x] 1.11 运行 `./scripts/platform-build-macos.sh Debug` 验证平台层编译成功，无错误和警告
- [ ] 1.12 性能测试：点击包含长字符串（10K+ 字符）的 item，测量响应时间，确保 <100ms

## 2. 阶段 2：列表自动刷新

### ClipboardWatcher 修改

- [x] 2.1 修改 `platform/macos/Sources/Utils/ClipboardWatcher.swift` 中的 `start` 方法签名，添加 `onChange: (() -> Void)? = nil` 参数
- [x] 2.2 在 `platform/macos/Sources/Utils/ClipboardWatcher.swift` 中的 `captureCurrentClipboard` 成功后调用 `onChange` 闭包（如果已配置）
- [x] 2.3 更新 `platform/macos/Sources/Utils/ClipboardWatcher.swift` 文档，说明 onChange 回调的使用方式

### ViewModel 修改

- [x] 2.4 在 `platform/macos/Sources/ViewModel/MainPanelViewModel.swift` 中的 `Action` 枚举添加 `case clipboardContentChanged`
- [x] 2.5 在 `platform/macos/Sources/ViewModel/MainPanelViewModel.swift` 中的 `send` 方法添加处理 `clipboardContentChanged` 的逻辑
- [x] 2.6 在 `platform/macos/Sources/ViewModel/MainPanelViewModel.swift` 中实现 `refreshList` 私有方法，触发 `performSearch` 刷新列表

### App 组装

- [x] 2.7 修改 `platform/macos/Sources/App.swift` 中的 `setupDependencies` 方法，在启动 ClipboardWatcher 时传入 onChange 闭包
- [x] 2.8 在 `platform/macos/Sources/App.swift` 中组装依赖时，将 `clipboardWatcher.start(..., onChange: { [weak self] in self?.viewModel.send(.clipboardContentChanged) })` 绑定到 ViewModel
- [x] 2.9 运行 `./scripts/platform-build-macos.sh Debug` 验证编译成功

### 验证与测试

- [ ] 2.10 单元测试：`ClipboardWatcher` 回调测试，验证 onChange 在成功持久化后正确触发
- [ ] 2.11 单元测试：`MainPanelViewModel` 测试，验证 `clipboardContentChanged` Action 正确处理并触发列表刷新
- [ ] 2.12 集成测试：复制剪贴板内容，验证列表自动刷新且响应时间 <100ms

## 3. 阶段 3：ESC 键和交通灯移除

### ESC 键处理

- [x] 3.1 在 `platform/macos/Sources/App.swift` 中添加 `NSEvent.addLocalMonitorForEvents` 全局事件监听器
- [x] 3.2 在 `platform/macos/Sources/App.swift` 中的 ESC 键处理逻辑添加 `NSApp.isActive` 检查
- [x] 3.3 在 `platform/macos/Sources/App.swift` 中的 ESC 键处理逻辑添加 `viewModel.state.isVisible` 检查
- [x] 3.4 在 `platform/macos/Sources/App.swift` 中实现 ESC 键按下时发送 `.togglePanel` Action 到 ViewModel
- [x] 3.5 确保事件监听器在应用生命周期内保持活跃（存储在 `cancellables` 中）

### 窗口样式修改

- [x] 3.6 修改 `platform/macos/Sources/View/MainPanelWindowController.swift` 中的 NSPanel styleMask
- [x] 3.7 移除 `.titled` 和 `.closable` 样式，添加 `.nonactivatingPanel` 和 `.borderless`
- [x] 3.8 保留 `.resizable` 样式以支持窗口调整
- [x] 3.9 运行 `./scripts/platform-build-macos.sh Debug` 验证编译成功

### 验证与测试

- [ ] 3.10 集成测试：按 ESC 键，验证面板正确切换显示/隐藏
- [ ] 3.11 集成测试：验证面板不显示交通灯按钮
- [ ] 3.12 集成测试：验证应用未激活时 ESC 键不触发面板切换
- [ ] 3.13 集成测试：测试窗口拖动和调整大小功能是否正常

## 4. 最终验证与部署

### 完整集成测试

- [ ] 4.1 运行完整的端到端测试场景：
  - 剪贴板内容变化后，列表自动刷新
  - 点击长字符串 item，响应时间 <100ms
  - ESC 键正确切换面板显示/隐藏
  - 面板没有交通灯按钮
- [ ] 4.2 验证所有功能正常工作，无卡顿或崩溃

### 性能基准测试

- [ ] 4.3 测试点击长字符串 item（10K+ 字符）的响应时间，记录优化前后的对比
- [ ] 4.4 测试列表刷新的响应时间，确保 <100ms
- [ ] 4.5 使用 Activity Monitor 或 Instruments 验证内存使用 <200MB/10K 条目

### 文档与清理

- [x] 4.6 更新相关文档（如 core/ARCHITECTURE.md 或 platform/macos/ARCHITECTURE.md）说明新增的 API 和行为
- [x] 4.7 清理临时代码或调试日志（如有）
- [ ] 4.8 确保所有变更已提交到 Git（如果用户确认）

## 5. 回滚准备

- [x] 5.1 验证 Git 版本控制支持快速回退到已知稳定状态
- [ ] 5.2 确认每个阶段已独立提交，便于分阶段回滚
- [x] 5.3 准备回滚策略：如遇问题，通过注释代码快速禁用新功能
