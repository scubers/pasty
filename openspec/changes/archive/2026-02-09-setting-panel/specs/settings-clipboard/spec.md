## ADDED Requirements

### Requirement: 剪贴板轮询周期配置
系统 SHALL 允许用户配置剪贴板监听轮询周期。

#### Scenario: 修改轮询周期
- **WHEN** 用户将轮询周期设置为 800ms
- **THEN** ClipboardWatcher SHALL 立即更新轮询间隔为 800ms
- **AND** SHALL 无需重启应用即生效

#### Scenario: 轮询周期边界值
- **WHEN** 用户尝试设置轮询周期低于 100ms
- **THEN** 系统 SHALL 拒绝该值
- **AND** SHALL 显示验证错误提示
- **AND** SHALL 保持原设置值不变

#### Scenario: 轮询周期默认值
- **WHEN** 首次启动应用
- **THEN** 轮询周期 SHALL 默认为 400ms

### Requirement: 最大内容大小配置
系统 SHALL 允许用户设置剪贴板内容的最大捕获大小。

#### Scenario: 设置内容大小限制
- **WHEN** 用户将最大内容大小设置为 5MB
- **THEN** 超过 5MB 的内容 SHALL 被忽略不记录
- **AND** 系统 SHALL 记录日志 "skip_large_content"

#### Scenario: 内容大小上限限制
- **WHEN** 用户尝试设置最大内容大小超过 100MB
- **THEN** 系统 SHALL 自动限制为 100MB

#### Scenario: 内容大小下限限制
- **WHEN** 用户尝试设置最大内容大小低于 1KB
- **THEN** 系统 SHALL 自动限制为 1KB

### Requirement: 最大历史记录数量配置
系统 SHALL 允许用户配置历史记录的最大保留数量。

#### Scenario: 设置历史记录上限
- **WHEN** 用户将最大历史记录设置为 500条
- **THEN** 历史记录数量超过 500条时
- **THEN** 系统 SHALL 自动删除最旧的记录

#### Scenario: 历史记录数量上限限制
- **WHEN** 用户尝试设置最大历史记录超过 5000条
- **THEN** 系统 SHALL 自动限制为 5000条

#### Scenario: 历史记录数量下限限制
- **WHEN** 用户尝试设置最大历史记录低于 50条
- **THEN** 系统 SHALL 自动限制为 50条

#### Scenario: 通过 Core API 传递设置
- **WHEN** 用户修改最大历史记录数量
- **THEN** Platform 层 SHALL 通过 C API `pasty_settings_update` 同步到 Core 层
- **AND** Core 层 SHALL 在下次执行 retention 时应用新值
