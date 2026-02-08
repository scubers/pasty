## ADDED Requirements

### Requirement: 设置目录管理
系统 SHALL 支持用户自定义设置目录路径。

#### Scenario: 首次启动使用默认目录
- **WHEN** 应用首次启动
- **THEN** 设置目录 SHALL 默认为 `~/Library/Application Support/Pasty2/`
- **AND** 目录路径 SHALL 存入 UserDefaults

#### Scenario: 更改设置目录
- **WHEN** 用户选择新的设置目录
- **THEN** 系统 SHALL 将现有设置、数据库、图片复制到新目录
- **AND** SHALL 保留原目录数据不删除
- **AND** SHALL 更新 UserDefaults 中的目录路径
- **AND** SHALL 提示用户重启应用生效

#### Scenario: 启动时验证设置目录
- **WHEN** 应用启动时
- **THEN** 系统 SHALL 验证设置目录可读写
- **IF** 目录不可访问
- **THEN** SHALL 回退到默认目录
- **AND** SHALL 向用户显示警告通知

### Requirement: 设置文件版本管理
系统 SHALL 在 settings.json 中包含版本号字段。

#### Scenario: 新版本读取旧设置文件
- **WHEN** 应用启动读取 settings.json
- **AND** 文件中的 version 字段低于当前版本
- **THEN** 系统 SHALL 自动执行迁移
- **AND** SHALL 为新增设置项填充默认值
- **AND** SHALL 写入新版本的 settings.json

#### Scenario: 旧版本读取新设置文件
- **WHEN** 旧版本应用读取新版本的 settings.json
- **THEN** 系统 SHALL 忽略不识别的字段
- **AND** SHALL 正常启动使用识别到的设置

### Requirement: 设置文件原子写入
系统 SHALL 确保设置文件写入的原子性，防止文件损坏。

#### Scenario: 正常保存设置
- **WHEN** 用户修改设置并保存
- **THEN** 系统 SHALL 先写入临时文件
- **AND** SHALL 原子重命名为 settings.json

#### Scenario: 设置文件损坏恢复
- **WHEN** 读取 settings.json 失败
- **THEN** 系统 SHALL 备份损坏文件为 settings.json.corrupted
- **AND** SHALL 重置为默认设置
- **AND** SHALL 向用户显示警告

### Requirement: 多设备同步支持
系统 SHALL 支持设置文件被外部修改时自动重新加载。

#### Scenario: 检测到外部设置变更
- **WHEN** 用户使用云盘同步导致 settings.json 被外部修改
- **THEN** 系统 SHALL 检测到文件变更
- **AND** SHALL 自动重新加载设置
- **AND** SHALL 应用新设置（实时生效的设置立即生效）
