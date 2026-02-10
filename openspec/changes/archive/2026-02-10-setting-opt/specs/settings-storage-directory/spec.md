# Settings Storage Directory

## Purpose
提供用户管理和查看设置与数据存储目录的功能。

## ADDED Requirements

### Requirement: 用户可以查看当前存储目录
系统必须在 General 设置中显示当前设置和数据的存储路径。

#### Scenario: 查看存储目录路径
- **WHEN** 用户打开 General 设置页面
- **THEN** 系统显示当前存储目录的完整路径
- **AND** 路径文本支持复制操作

### Requirement: 用户可以在 Finder 中显示存储目录
系统必须允许用户通过点击按钮在 Finder 中打开当前存储目录。

#### Scenario: 在 Finder 中打开目录
- **WHEN** 用户点击"Show in Finder"按钮
- **THEN** 系统在 Finder 中选中并显示存储目录

### Requirement: 用户可以更改存储目录
系统必须允许用户选择新的存储目录，并自动迁移现有设置和数据。

#### Scenario: 更改存储目录成功
- **WHEN** 用户点击"Change..."按钮并选择有效的目录
- **THEN** 系统验证目录可写性
- **AND** 系统迁移 settings.json 文件到新目录
- **AND** 系统迁移 history.sqlite3 文件到新目录
- **AND** 系统迁移 images 文件夹到新目录
- **AND** 系统更新设置管理器的目录路径
- **AND** 系统提示用户需要重启应用

#### Scenario: 更改存储目录失败（目录不可写）
- **WHEN** 用户选择不可写的目录
- **THEN** 系统显示错误消息"所选目录不可写入"
- **AND** 系统保持原存储目录不变

#### Scenario: 更改存储目录失败（迁移错误）
- **WHEN** 迁移过程中发生错误
- **THEN** 系统显示包含错误详情的警告对话框
- **AND** 系统保持原存储目录不变

### Requirement: 更改存储目录需要重启应用
系统必须在更改存储目录后提示用户重启应用，新的目录才能生效。

#### Scenario: 更改目录后提示重启
- **WHEN** 用户成功更改存储目录
- **THEN** 系统显示重启确认对话框
- **AND** 用户可以选择"立即重启"或"稍后重启"
- **WHEN** 用户点击"立即重启"
- **THEN** 系统重新启动应用
- **WHEN** 用户点击"稍后重启"
- **THEN** 系统关闭对话框，应用继续运行

### Requirement: 系统自动回退到默认存储目录
系统必须在当前存储目录无效时自动回退到默认目录。

#### Scenario: 存储目录无效时回退
- **WHEN** 系统检测到当前存储目录不可访问或不可写
- **THEN** 系统自动切换到默认存储目录（~/Library/Application Support/Pasty）
- **AND** 系统显示警告消息，说明已回退到默认目录
- **AND** 系统将默认目录路径保存到用户偏好设置中
