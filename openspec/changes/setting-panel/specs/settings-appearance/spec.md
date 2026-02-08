## ADDED Requirements

### Requirement: 主题色配置
系统 SHALL 允许用户选择面板的主题色。

#### Scenario: 选择系统主题色
- **WHEN** 用户选择 "System" 主题色
- **THEN** 面板 SHALL 跟随 macOS 系统强调色

#### Scenario: 选择自定义主题色
- **WHEN** 用户选择 "Blue" 作为主题色
- **THEN** 面板 SHALL 使用蓝色作为强调色
- **AND** 选择高亮、按钮等 SHALL 使用蓝色

#### Scenario: 主题色选项
- **WHEN** 用户查看主题色选项
- **THEN** SHALL 显示以下选项：
  - System（跟随系统）
  - Blue、Purple、Pink、Red、Orange、Yellow、Green

#### Scenario: 主题色默认值
- **WHEN** 首次启动应用
- **THEN** 主题色 SHALL 默认为 "System"

### Requirement: 背景模糊程度配置
系统 SHALL 允许用户调整面板背景的模糊程度。

#### Scenario: 调整模糊程度
- **WHEN** 用户将模糊程度设置为 50%
- **THEN** 面板背景 SHALL 应用 50% 的模糊效果
- **AND** 效果 SHALL 立即生效无需重启

#### Scenario: 无模糊效果
- **WHEN** 用户将模糊程度设置为 0%
- **THEN** 面板 SHALL 无模糊效果（纯色背景）

#### Scenario: 最大模糊效果
- **WHEN** 用户将模糊程度设置为 100%
- **THEN** 面板 SHALL 应用最大模糊效果

#### Scenario: 模糊程度默认值
- **WHEN** 首次启动应用
- **THEN** 模糊程度 SHALL 默认为 90%

### Requirement: 面板尺寸配置
系统 SHALL 允许用户配置面板的默认尺寸。

#### Scenario: 设置面板尺寸
- **WHEN** 用户设置面板宽度为 900px，高度为 600px
- **THEN** 下次打开面板时 SHALL 使用此尺寸

#### Scenario: 面板尺寸下限
- **WHEN** 用户尝试设置宽度低于 600px
- **THEN** 系统 SHALL 自动限制为 600px
- **AND** 高度低于 400px 时 SHALL 限制为 400px

#### Scenario: 面板尺寸默认值
- **WHEN** 首次启动应用
- **THEN** 面板尺寸 SHALL 默认为 800×500px
