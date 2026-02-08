## ADDED Requirements

### Requirement: 显示主面板窗口

系统 SHALL 提供一个主面板窗口，用于访问和管理剪贴板历史记录。

#### Scenario: 快捷键唤起面板

- **WHEN** 用户按下全局快捷键 Cmd+Shift+V
- **THEN** 系统应在当前鼠标所在屏幕的中心偏上位置显示主面板

#### Scenario: 菜单栏唤起面板

- **WHEN** 用户点击菜单栏图标并选择"打开面板"菜单项
- **THEN** 系统应在当前鼠标所在屏幕的中心偏上位置显示主面板

#### Scenario: 面板自动聚焦搜索框

- **WHEN** 主面板显示时
- **THEN** 搜索输入框 SHALL 自动获得焦点，用户可直接输入搜索内容

### Requirement: 三层布局结构

主面板窗口 SHALL 采用三层布局结构：顶部搜索区、中间内容区、底部页脚区。

#### Scenario: 布局结构展示

- **WHEN** 主面板窗口显示
- **THEN** 系统 SHALL 显示三个清晰的区域：
  - 顶部：搜索输入框
  - 中间：左右分栏（左侧结果列表，右侧预览区）
  - 底部：快捷键说明页脚

### Requirement: 面板窗口行为

主面板窗口 SHALL 表现为浮动工具窗口，具有特定的窗口行为。

#### Scenario: 面板窗口属性

- **WHEN** 主面板窗口创建
- **THEN** 系统 SHALL 设置以下窗口属性：
  - 窗口类型为 NSPanel（非激活面板）
  - 窗口级别为 floating（保持在其他窗口之上）
  - 标题栏隐藏
  - 可通过拖动窗口背景移动
  - 窗口关闭后隐藏而非退出应用

#### Scenario: 窗口定位

- **WHEN** 主面板显示时
- **THEN** 系统 SHALL 将面板定位在鼠标当前所在屏幕的中心偏上约 100pt 的位置
- **THEN** 系统 SHALL 确保面板完全在屏幕边界内

### Requirement: 面板隐藏

主面板窗口 SHALL 支持多种隐藏方式。

#### Scenario: 失去焦点隐藏

- **WHEN** 主面板失去焦点（用户点击其他窗口）
- **THEN** 系统 SHALL 自动隐藏主面板

#### Scenario: 快捷键切换显示/隐藏

- **WHEN** 用户再次按下全局快捷键 Cmd+Shift+V
- **THEN** 系统 SHALL 切换面板的可见性（显示变为隐藏，隐藏变为显示）

### Requirement: 面板尺寸

主面板窗口 SHALL 具有最小尺寸限制。

#### Scenario: 最小尺寸约束

- **WHEN** 主面板窗口创建
- **THEN** 系统 SHALL 设置最小尺寸为宽度 800pt、高度 600pt
- **THEN** 系统 SHALL 防止用户将窗口调整至小于此尺寸

### Requirement: 面板持久化状态

主面板窗口 SHALL 记忆面板位置和尺寸（可选功能）。

#### Scenario: 记忆面板位置

- **WHEN** 用户手动拖动或调整面板大小
- **THEN** 系统 SHALL 记忆面板的位置和尺寸
- **THEN** 下次显示面板时，系统 SHALL 使用上次的位置和尺寸
