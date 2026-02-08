## ADDED Requirements

### Requirement: 实时搜索功能

系统 SHALL 提供实时的基于文本的搜索功能，用于查找剪贴板历史项。

#### Scenario: 搜索框输入

- **WHEN** 用户在搜索框中输入搜索内容
- **THEN** 系统 SHALL 实时触发搜索操作
- **THEN** 系统 SHALL 在输入后立即开始搜索（无需用户按下回车）

#### Scenario: LIKE 模式匹配

- **WHEN** 系统执行搜索
- **THEN** 系统 SHALL 使用 SQL LIKE 模式匹配搜索内容
- **THEN** 系统 SHALL 支持部分匹配（如搜索"hello"可匹配"helloworld"）
- **THEN** 系统 SHALL 不区分大小写（使用 COLLATE NOCASE）

### Requirement: 搜索结果限制

系统 SHALL 限制搜索结果的数量以保证性能。

#### Scenario: 默认结果数量限制

- **WHEN** 用户执行搜索
- **THEN** 系统 SHALL 默认返回最多 100 条搜索结果
- **THEN** 系统 SHALL 按时间戳降序排列结果（最新的在前）

#### Scenario: 结果数量可配置（可选）

- **WHEN** 用户在设置中配置最大结果数量（未来功能）
- **THEN** 系统 SHALL 使用用户配置的限制值
- **THEN** 系统 SHALL 确保限制值在合理范围内（如 1-1000）

### Requirement: 搜索结果显示

系统 SHALL 在左侧列表中显示搜索结果。

#### Scenario: 实时结果更新

- **WHEN** 搜索结果返回
- **THEN** 系统 SHALL 立即在左侧列表中更新显示
- **THEN** 系统 SHALL 清空之前的搜索结果
- **THEN** 系统 SHALL 显示新搜索结果

#### Scenario: 无结果提示

- **WHEN** 搜索未找到任何匹配项
- **THEN** 系统 SHALL 在列表中显示"未找到结果"提示
- **THEN** 系统 SHALL 保持搜索框可继续输入

### Requirement: 搜索性能要求

系统 SHALL 确保搜索操作在 100ms 内完成。

#### Scenario: 响应时间约束

- **WHEN** 用户输入搜索内容或执行搜索
- **THEN** 系统 SHALL 在 100ms 内返回搜索结果
- **THEN** 系统 SHALL 遵守 P2 性能响应原则

#### Scenario: 搜索性能优化

- **WHEN** 数据库中历史记录数量增长
- **THEN** 系统 SHALL 使用数据库索引优化查询性能
- **THEN** 系统 SHALL 确保 `content` 列有搜索索引（CREATE INDEX idx_items_content_search）

### Requirement: 空搜索处理

系统 SHALL 正确处理空搜索输入。

#### Scenario: 清空搜索框

- **WHEN** 用户清空搜索框内容
- **THEN** 系统 SHALL 显示所有剪贴板历史项（等同于无过滤）
- **THEN** 系统 SHALL 按时间戳降序排列

#### Scenario: 初始状态

- **WHEN** 主面板首次显示，搜索框为空
- **THEN** 系统 SHALL 显示最近的剪贴板历史项
- **THEN** 系统 SHALL 显示最多 100 条项

### Requirement: 搜索状态反馈

系统 SHALL 提供搜索状态反馈。

#### Scenario: 搜索中状态

- **WHEN** 搜索正在执行
- **THEN** 系统 SHALL 显示加载指示器（如旋转图标或进度条）
- **THEN** 系统 SHALL 防止用户重复触发搜索

#### Scenario: 搜索错误处理

- **WHEN** 搜索操作失败
- **THEN** 系统 SHALL 在搜索框附近显示错误提示
- **THEN** 系统 SHALL 记录错误日志供调试

### Requirement: 搜索历史记录（可选）

系统 SHALL 可选记录用户搜索历史（未来功能）。

#### Scenario: 搜索历史保存

- **WHEN** 用户执行搜索（未来功能）
- **THEN** 系统 SHALL 保存搜索内容到搜索历史
- **THEN** 系统 SHALL 支持通过搜索框自动补全重复搜索

#### Scenario: 搜索历史清除

- **WHEN** 用户选择清除搜索历史（未来功能）
- **THEN** 系统 SHALL 删除所有保存的搜索历史记录
- **THEN** 系统 SHALL 立即从自动补全中移除历史项

### Requirement: 搜索内容类型过滤（可选）

系统 SHALL 支持按内容类型过滤搜索结果（未来功能）。

#### Scenario: 按类型过滤

- **WHEN** 用户选择内容类型过滤器（如仅文本、仅图片）（未来功能）
- **THEN** 系统 SHALL 仅返回匹配类型和搜索内容的结果
- **THEN** 系统 SHALL 保持其他搜索行为不变
