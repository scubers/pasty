## ADDED Requirements

### Requirement: 移除面板窗口交通灯按钮

主面板窗口 SHALL 不显示标准的 macOS 交通灯按钮（关闭、最小化、最大化），保持简洁外观。

#### Scenario: 移除 .titled 样式

- **WHEN** MainPanelWindowController 创建 NSPanel
- **THEN** styleMask SHALL 移除 `.titled` 选项
- **THEN** styleMask SHALL 仅包含 `.nonactivatingPanel` 和 `.resizable`
- **THEN** 窗口 SHALL 无交通灯按钮
- **THEN** 面板 SHALL 保持浮动特性

#### Scenario: 透明标题栏

- **WHEN** NSPanel 被配置
- **THEN** `titleVisibility` SHALL 被设置为 `.hidden`
- **THEN** `titlebarAppearsTransparent` SHALL 被设置为 `true`
- **THEN** 标题栏 SHALL 视觉上透明
- **THEN** 面板 SHALL 保持简洁外观

#### Scenario: 面板切换控制

- **WHEN** 用户需要切换面板显示/隐藏
- **THEN** 面板 SHALL 通过热键（Cmd+Shift+V）或 ESC 键切换
- **THEN** 不应依赖交通灯按钮进行窗口控制
- **THEN** 切换响应时间 SHALL <100ms（constitution.md P2）

#### Scenario: 边框和调整

- **WHEN** 面板显示
- **THEN** 面板 SHALL 支持拖动移动
- **THEN** 面板 SHALL 支持调整大小（`.resizable` 样式）
- **THEN** 面板 SHALL 保持浮动特性（`.nonactivatingPanel`）

#### Scenario: Spaces 集成兼容性

- **WHEN** 用户在多个桌面空间之间切换
- **THEN** 面板 SHALL 正常显示在各个空间
- **THEN** 面板行为 SHALL 与标准窗口一致
- **THEN** 如果出现 Spaces 集成问题，SHALL 考虑添加 `.utilityWindow` 样式

### Requirement: 保持窗口控制能力

尽管移除交通灯按钮，面板 SHALL 仍然支持基本的窗口控制功能。

#### Scenario: 窗口关闭

- **WHEN** 用户需要关闭面板
- **THEN** 热键（Cmd+Shift+V）或 ESC 键 SHALL 切换面板
- **THEN** 面板 SHALL 被隐藏
- **THEN** 用户 SHALL 无需使用交通灯按钮

#### Scenario: 窗口调整

- **WHEN** 用户需要调整面板大小
- **THEN** 面板 SHALL 支持通过拖拽调整（`.resizable` 样式）
- **THEN** 用户 SHALL 无需使用交通灯按钮
- **THEN** 调整 SHALL 响应时间 <100ms

#### Scenario: 窗口移动

- **WHEN** 用户需要移动面板
- **THEN** 面板 SHALL 支持通过拖拽移动
- **THEN** 面板 SHALL 保持浮动特性（`.nonactivatingPanel`）
- **THEN** 用户 SHALL 无需使用交通灯按钮
