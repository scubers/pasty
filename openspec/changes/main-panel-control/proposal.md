# Proposal: Main Panel Control

## Why

当前主面板（Main Panel）虽然已经具备了基本的展示和列表浏览功能，但缺少完整的交互逻辑，无法提供流畅的用户体验。用户需要一个功能完整的剪贴板历史管理界面，包括：快速切换面板、智能位置记忆、键盘快捷操作、删除确认、粘贴集成等核心功能。这些功能对于提升用户的工作效率和操作体验至关重要。

## What Changes

本次变更将为 macOS 平台层添加主面板的完整交互控制逻辑：

### 核心功能

1. **面板展示与关闭**
   - 按 `Cmd+Shift+V` 切换面板显示/隐藏
   - 智能位置记忆：同一屏幕显示时记住拖动位置（仅内存，重启重置）
   - 切换屏幕时使用当前屏幕的默认位置
   - ESC 键或点击面板外区域关闭面板
   - 关闭时清空搜索框内容

2. **焦点管理**
   - 面板展示后搜索框自动获得焦点
   - 关闭时焦点恢复到上一个应用
   - 所有键盘操作不影响搜索框焦点状态

3. **历史记录列表交互**
   - 面板展示后默认选中第一条记录
   - 列表实时更新，更新后默认选中第一条
   - 上下箭头轮转选择（首尾环形）
   - Home/End/Page Up/Page Down 导航（已有，保持）
   - 删除后自动选中下一条（无下条则选上一条）

4. **键盘快捷键**
   - `↑/↓`：轮转选择历史记录
   - `Enter`：复制选中项 + 关闭面板 + 发送 Cmd+V 到上一个应用（若上一个应用非本应用）
   - `Cmd+Enter`：复制选中项到剪贴板（不关闭面板）
   - `Cmd+D`：删除选中项（二次确认）

5. **预览区**
   - 文字预览支持选中复制（已有，保持）
   - 选中记录后实时更新预览（已有，保持）

6. **删除确认**
   - Cmd+D 触发二次确认对话框
   - 确认框层级高于主面板

### 技术实现

1. 新增 `MainPanelInteractionService`：封装平台交互能力（焦点追踪、复制粘贴、外部点击监听）
2. 扩展 `MainPanelViewModel`：新增状态和 Action
3. 扩展 `ClipboardHistoryService`：新增删除接口
4. 增强 `MainPanelWindowController`：位置记忆和层级管理
5. 新增面板级键盘事件监听
6. 优化搜索框焦点控制

## Capabilities

### New Capabilities
- `main-panel-toggle`: 主面板的显示/隐藏控制，包括位置记忆和快捷键触发
- `main-panel-focus`: 面板焦点管理，包括搜索框焦点和应用间焦点切换
- `main-panel-keyboard`: 面板级键盘事件处理，包括选择、复制、删除等快捷键
- `main-panel-delete-confirm`: 删除确认对话框，二次确认删除操作
- `main-panel-paste-integration`: 与其他应用的粘贴集成，发送模拟 Cmd+V 操作

### Modified Capabilities
（无需修改现有 spec，本次为新增功能）

## Impact

### 代码变更范围
- **macOS 平台层（仅）**：所有变更集中在 `platform/macos/Sources/` 目录
- **Core 层**：无需修改，使用现有 `pasty_history_delete` API

### 修改的文件
- `platform/macos/Sources/ViewModel/MainPanelViewModel.swift` - 扩展状态机和 Action
- `platform/macos/Sources/Utils/ClipboardHistoryService.swift` - 新增删除接口
- `platform/macos/Sources/Utils/ClipboardHistoryServiceImpl.swift` - 实现删除接口
- `platform/macos/Sources/View/MainPanelWindowController.swift` - 位置记忆和层级管理
- `platform/macos/Sources/View/MainPanelView.swift` - 集成新的交互能力
- `platform/macos/Sources/View/MainPanel/MainPanelSearchBar.swift` - 焦点控制优化
- `platform/macos/Sources/App.swift` - 平台事件监听和协调
- `platform/macos/Sources/View/MainPanel/AppKit/MainPanelItemTableView.swift` - 补充程序化选择 API（可选）

### 新增的文件
- `platform/macos/Sources/Utils/MainPanelInteractionService.swift` - 封装平台交互能力
- `platform/macos/Sources/Utils/MainPanelKeyCommand.swift` - 键盘命令解析（可选）

### 不影响的部分
- Core 层业务逻辑和数据结构
- 其他平台实现（Windows/iOS/Android）
- 现有的历史窗口（HistoryViewController）
- 剪贴板监听器（ClipboardWatcher）

### 风险评估
- **低风险**：所有变更集中在 macOS 平台层，不影响 Core 层可移植性
- **中等复杂度**：需要处理焦点管理、多屏幕、窗口层级等平台特定逻辑
- **测试重点**：多显示器、焦点切换、键盘事件、外部点击关闭等边界场景
