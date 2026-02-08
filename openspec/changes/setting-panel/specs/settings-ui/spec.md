## ADDED Requirements

### Requirement: 设置面板访问入口
系统 SHALL 提供多种方式访问设置面板。

#### Scenario: 通过菜单栏打开设置
- **WHEN** 用户点击菜单栏中的"偏好设置..."
- **THEN** 设置面板 SHALL 打开

#### Scenario: 通过快捷键打开设置
- **WHEN** 用户按下 ⌘,（Command + 逗号）
- **THEN** 设置面板 SHALL 打开

### Requirement: 设置面板窗口行为
系统 SHALL 使用单例窗口模式管理设置面板。

#### Scenario: 单例窗口限制
- **GIVEN** 设置面板已打开
- **WHEN** 用户再次尝试打开设置（菜单栏或快捷键）
- **THEN**  SHALL 将现有设置窗口提到最前
- **AND** SHALL 不创建新窗口

#### Scenario: 关闭窗口销毁
- **WHEN** 用户关闭设置窗口
- **THEN** 窗口 SHALL 被完全销毁
- **AND** 下次打开时 SHALL 重新创建

### Requirement: 设置面板布局
系统 SHALL 使用分组方式组织设置项。

#### Scenario: 分组导航
- **WHEN** 用户打开设置面板
- **THEN** SHALL 显示以下分组：
  - 通用（启动时运行、快捷键）
  - 剪贴板（轮询、大小限制、历史数量）
  - OCR（启用、语言、置信度）
  - 外观（主题色、模糊程度）

#### Scenario: 选中分组高亮
- **WHEN** 用户选择某个分组
- **THEN** 该分组 SHALL 高亮显示
- **AND** 右侧 SHALL 显示对应设置项

### Requirement: 设置修改实时反馈
系统 SHALL 在用户修改设置时提供反馈。

#### Scenario: 设置保存成功
- **WHEN** 用户修改设置并保存
- **THEN** 系统 SHALL 自动保存（无需手动点击保存按钮）
- **AND** MAY 显示"已保存"提示

#### Scenario: 设置验证失败
- **WHEN** 用户输入无效设置值
- **THEN** 输入框 SHALL 显示红色边框
- **AND** SHALL 显示错误提示信息
- **AND** SHALL 阻止保存直到修正

### Requirement: 设置目录选择界面
系统 SHALL 提供界面让用户选择和更改设置目录。

#### Scenario: 显示当前设置目录
- **WHEN** 用户打开设置
- **THEN** SHALL 显示当前设置目录路径
- **AND** SHALL 显示目录使用情况（数据库大小、图片占用）

#### Scenario: 更改设置目录
- **WHEN** 用户点击"更改目录"按钮
- **THEN** 系统 SHALL 打开系统文件选择器
- **AND** 用户选择目录后 SHALL 提示需要重启

#### Scenario: 打开设置目录
- **WHEN** 用户点击"在 Finder 中打开"
- **THEN** 系统 SHALL 在 Finder 中打开设置目录
