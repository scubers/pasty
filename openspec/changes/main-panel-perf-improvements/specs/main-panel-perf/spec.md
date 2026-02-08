## ADDED Requirements

### Requirement: 搜索结果预览内容截断

核心层搜索 API SHALL 支持返回截断后的预览内容，以减少数据传输和 UI 渲染开销。

#### Scenario: 搜索剪贴板历史返回预览内容

- **WHEN** 用户在主面板中搜索剪贴板历史
- **THEN** 核心层搜索返回的文本内容 SHALL 被截断至前 200 个字符
- **THEN** 截断后的预览内容 SHALL 在列表中显示
- **THEN** 点击列表项时，完整内容 SHALL 在预览面板中显示
- **THEN** 数据传输大小 SHALL 显著减少（特别是对于长字符串内容）

#### Scenario: 搜索参数控制预览长度

- **WHEN** 平台层调用核心层搜索 API
- **THEN** API SHALL 支持 `previewLength` 参数（默认值：200）
- **THEN** 核心层 SHALL 根据此参数截断返回的文本内容
- **THEN** 参数值 SHALL 可配置以适应不同场景

### Requirement: 线程安全的数据库访问

核心层数据库访问 SHALL 被互斥锁保护，确保并发调用不会导致数据损坏或崩溃。

#### Scenario: 并发搜索查询

- **WHEN** 多个并发请求调用核心层搜索 API
- **THEN** 数据库访问 SHALL 被互斥锁保护
- **THEN** 每个请求 SHALL 按顺序或并发安全的方式执行
- **THEN** 不会出现数据损坏、崩溃或不可预测行为

#### Scenario: 数据库操作互斥

- **WHEN** 任何数据库操作（search, getItem, upsert 等）正在执行
- **THEN** 其他并发数据库操作 SHALL 等待当前操作完成
- **THEN** 互斥锁 SHALL 保护所有数据库访问点
- **THEN** 锁的持有时间 SHALL 尽可能短以最小化性能影响

### Requirement: 平台层查询结果缓存

平台层 SHALL 实现简单的 LRU 缓存机制，缓存最近的搜索结果以避免重复的 JSON 解码。

#### Scenario: 缓存命中

- **WHEN** 用户重复搜索相同的查询
- **THEN** 平台层 SHALL 从缓存中返回结果（如果未过期）
- **THEN** 不重复调用核心层搜索 API
- **THEN** UI 响应时间 SHALL 显著减少（目标：<50ms）

#### Scenario: 缓存失效

- **WHEN** 剪贴板内容变化导致新数据持久化
- **THEN** 相关的缓存条目 SHALL 被清除
- **THEN** 下次搜索 SHALL 返回最新数据
- **THEN** 缓存大小 SHALL 被限制（如 50 条目）以控制内存使用

#### Scenario: LRU 缓存策略

- **WHEN** 缓存达到大小限制
- **THEN** 最少使用的缓存条目 SHALL 被移除
- **THEN** 热门查询 SHALL 保持在缓存中
- **THEN** 缓存实现 SHALL 简单且高效（不使用复杂的依赖）

### Requirement: 性能目标

优化后的性能 SHALL 满足 constitution.md P2 要求：UI 操作 <100ms，内存 <200MB/10K条目。

#### Scenario: 点击长字符串项的响应时间

- **WHEN** 用户点击包含长字符串（如 10K+ 字符）的列表项
- **THEN** 预览面板 SHALL 在 <100ms 内显示内容
- **THEN** UI SHALL 保持响应，无卡顿或冻结
- **THEN** 主线程 SHALL 不被阻塞超过 100ms

#### Scenario: 列表渲染性能

- **WHEN** 主面板加载包含 100+ 条目的列表
- **THEN** 列表 SHALL 在 <500ms 内渲染完成
- **THEN** 每个列表项的预览 SHALL 显示截断后的内容
- **THEN** 内存使用 SHALL 保持在 <200MB/10K条目

#### Scenario: 性能监控

- **WHEN** 性能优化实现完成
- **THEN** SHALL 提供性能基准测试结果
- **THEN** SHALL 对比优化前后的响应时间和内存使用
- **THEN** SHALL 验证符合 constitution.md P2 目标
