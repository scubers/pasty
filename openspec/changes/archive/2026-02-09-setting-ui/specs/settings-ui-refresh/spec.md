## ADDED Requirements

### Requirement: 现代设置布局
系统必须为设置面板使用侧边栏 + 内容区域的布局。

#### Scenario: 布局结构
- **WHEN** 打开设置面板
- **THEN** 左侧显示宽度为 200px 的侧边栏
- **AND** 右侧显示内容区域
- **AND** 窗口大小固定为 800x550

### Requirement: 导航侧边栏
系统必须通过侧边栏提供到所有设置部分的导航。

#### Scenario: 侧边栏项目
- **WHEN** 用户查看侧边栏
- **THEN** 它显示以下项目：常规 (General)、剪贴板 (Clipboard)、外观 (Appearance)、OCR、快捷键 (Shortcuts)、关于 (About)
- **AND** 当前活动部分高亮显示

### Requirement: 自定义 UI 组件
系统必须提供符合玻璃拟态设计的自定义样式组件。

#### Scenario: 自定义开关 (Toggle)
- **WHEN** 显示开关控件
- **THEN** 它使用带有颜色过渡动画的自定义设计
- **AND** 激活时使用强调色

#### Scenario: 自定义滑块 (Slider)
- **WHEN** 显示滑块控件
- **THEN** 它使用细轨道和白色圆形滑块

### Requirement: 设置部分
系统必须实现所有设置部分的视觉结构。

#### Scenario: 部分内容
- **WHEN** 选择一个设置部分
- **THEN** 在内容区域显示相应的控件
- **AND** 如果内容超出可用高度，则可滚动
