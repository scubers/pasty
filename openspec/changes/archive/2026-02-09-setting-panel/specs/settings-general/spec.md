## ADDED Requirements

### Requirement: 启动时运行配置
系统 SHALL 允许用户配置应用是否在系统登录时自动启动。

#### Scenario: 启用启动时运行
- **WHEN** 用户在设置中开启"启动时运行"
- **THEN** 系统 SHALL 请求用户授权
- **AND** 授权通过后 SHALL 注册 SMAppService
- **AND** 下次系统登录时 SHALL 自动启动应用

#### Scenario: 禁用启动时运行
- **WHEN** 用户在设置中关闭"启动时运行"
- **THEN** 系统 SHALL 注销 SMAppService
- **AND** 下次系统登录时 SHALL 不再自动启动

#### Scenario: 启动时运行默认值
- **WHEN** 首次启动应用
- **THEN** "启动时运行" SHALL 默认为关闭

#### Scenario: 拒绝授权处理
- **WHEN** 用户开启"启动时运行"但拒绝授权
- **THEN** 系统 SHALL 保持设置开关为关闭状态
- **AND** SHALL 显示提示信息说明需要授权

### Requirement: 全局快捷键配置
系统 SHALL 允许用户自定义打开面板的全局快捷键。

#### Scenario: 修改快捷键
- **WHEN** 用户将快捷键从 ⌘⇧V 修改为 ⌥⌘V
- **THEN** 系统 SHALL 立即更新全局快捷键
- **AND** 旧快捷键 SHALL 失效
- **AND** 新快捷键 SHALL 触发面板打开

#### Scenario: 快捷键恢复默认
- **WHEN** 用户点击"恢复默认"按钮
- **THEN** 快捷键 SHALL 恢复为 ⌘⇧V

#### Scenario: 快捷键默认值
- **WHEN** 首次启动应用
- **THEN** 全局快捷键 SHALL 默认为 ⌘⇧V

### Requirement: 设置面板快捷键
系统 SHALL 支持使用标准快捷键打开设置面板。

#### Scenario: 使用标准快捷键打开设置
- **WHEN** 用户按下 ⌘,（Command + 逗号）
- **THEN** 设置面板 SHALL 打开
- **AND** 此快捷键 SHALL 与 macOS 标准一致

### Requirement: 重置所有设置
系统 SHALL 允许用户将所有设置恢复为默认值。

#### Scenario: 重置所有设置
- **WHEN** 用户点击"重置所有设置"并确认
- **THEN** 所有设置项 SHALL 恢复为默认值
- **AND** SHALL 立即生效（需要重启的设置提示用户）
- **AND** SHALL 保留设置目录路径不变
