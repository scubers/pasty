## ADDED Requirements

### Requirement: 项预览显示

系统 SHALL 在右侧预览窗格中显示所选剪贴板项的内容。

#### Scenario: 选中项预览

- **WHEN** 用户在左侧结果列表中点击某个剪贴板项
- **THEN** 系统 SHALL 在右侧预览窗格中显示该项的内容
- **THEN** 系统 SHALL 更新预览区的标题和元数据信息

### Requirement: 文本内容预览

系统 SHALL 支持文本类型的剪贴板内容预览。

#### Scenario: 文本显示

- **WHEN** 所选项为文本类型
- **THEN** 系统 SHALL 在预览窗格中显示文本内容
- **THEN** 系统 SHALL 支持长文本的滚动显示
- **THEN** 系统 SHALL 保持原始格式（如换行、缩进）

#### Scenario: 文本长度限制

- **WHEN** 文本内容过长（如超过 10,000 字符）
- **THEN** 系统 SHALL 限制预览显示的最大字符数（如 5,000 字符）
- **THEN** 系统 SHALL 显示"内容已截断"提示
- **THEN** 系统 SHALL 提供完整内容的访问方式（如双击复制）

### Requirement: 图片内容预览

系统 SHALL 支持图片类型的剪贴板内容预览。

#### Scenario: 图片显示

- **WHEN** 所选项为图片类型
- **THEN** 系统 SHALL 在预览窗格中显示图片
- **THEN** 系统 SHALL 缩放图片以适应预览窗格尺寸
- **THEN** 系统 SHALL 保持图片的宽高比

#### Scenario: 图片尺寸限制

- **WHEN** 图片尺寸过大（如超过 4K 分辨率）
- **THEN** 系统 SHALL 限制预览显示的最大尺寸（如 1024x1024 像素）
- **THEN** 系统 SHALL 显示缩略图而非原始全尺寸图片
- **THEN** 系统 SHALL 提供完整图片的访问方式（如双击打开）

#### Scenario: 图片格式支持

- **WHEN** 所选项为不同图片格式（PNG、JPEG、GIF、等）
- **THEN** 系统 SHALL 支持显示常见图片格式
- **THEN** 系统 SHALL 正确解码图片数据

### Requirement: 元数据显示

系统 SHALL 在预览窗格中显示剪贴板项的元数据。

#### Scenario: 显示基本信息

- **WHEN** 预览剪贴板项
- **THEN** 系统 SHALL 显示以下元数据信息：
  - 来源应用名称
  - 复制时间（格式化显示，如"2小时前"、"2024-02-08 14:30"）
  - 内容类型（文本/图片）
  - 内容哈希（调试用途，可选）

#### Scenario: 时间格式化

- **WHEN** 显示复制时间
- **THEN** 系统 SHALL 使用用户友好的相对时间格式（如"刚刚"、"5分钟前"）
- **THEN** 系统 SHALL 对于较旧时间使用绝对时间格式（如"2024-01-15 10:30"）

### Requirement: 预览性能要求

系统 SHALL 确保预览操作在 100ms 内完成。

#### Scenario: 预览加载时间

- **WHEN** 用户选择剪贴板项
- **THEN** 系统 SHALL 在 100ms 内完成预览加载和显示
- **THEN** 系统 SHALL 遵守 P2 性能响应原则

#### Scenario: 异步加载

- **WHEN** 加载大型内容（如大图片、长文本）
- **THEN** 系统 SHALL 使用异步加载机制
- **THEN** 系统 SHALL 在加载期间显示占位符或加载指示器
- **THEN** 系统 SHALL 避免阻塞主线程

### Requirement: 预览空状态

系统 SHALL 处理未选择任何项时的预览状态。

#### Scenario: 无选择状态

- **WHEN** 用户未选择任何剪贴板项
- **THEN** 系统 SHALL 在预览窗格中显示"选择一项查看预览"提示
- **THEN** 系统 SHALL 显示友好的空状态图标或占位符

### Requirement: 预览交互

系统 SHALL 支持预览内容的用户交互。

#### Scenario: 复制预览内容

- **WHEN** 用户双击预览内容（未来功能）
- **THEN** 系统 SHALL 将内容复制到系统剪贴板
- **THEN** 系统 SHALL 显示复制成功的提示

#### Scenario: 打开完整内容（图片）

- **WHEN** 用户右键点击预览图片并选择"打开"（未来功能）
- **THEN** 系统 SHALL 使用默认图片查看器打开完整图片
- **THEN** 系统 SHALL 避免修改原始图片数据

### Requirement: 预览自适应布局

系统 SHALL 支持预览窗格的自适应布局。

#### Scenario: 垂直滚动支持

- **WHEN** 预览内容超过窗格高度
- **THEN** 系统 SHALL 提供垂直滚动功能
- **THEN** 系统 SHALL 保持水平滚动禁用（除非内容超宽）

#### Scenario: 预览窗格调整

- **WHEN** 用户调整主面板窗口大小
- **THEN** 系统 SHALL 自动调整预览窗格尺寸
- **THEN** 系统 SHALL 保持内容居中或顶部对齐

### Requirement: 预览错误处理

系统 SHALL 正确处理预览加载失败的情况。

#### Scenario: 内容加载失败

- **WHEN** 预览内容加载失败（如文件损坏、格式不支持）
- **THEN** 系统 SHALL 在预览窗格中显示"无法加载预览"错误提示
- **THEN** 系统 SHALL 记录错误日志供调试
- **THEN** 系统 SHALL 提供重试按钮（可选）

### Requirement: 预览缓存（可选）

系统 SHALL 可选缓存预览内容以提升性能（未来功能）。

#### Scenario: 最近项缓存

- **WHEN** 用户预览最近使用的剪贴板项（未来功能）
- **THEN** 系统 SHALL 从内存缓存加载预览内容
- **THEN** 系统 SHALL 减少磁盘 I/O 操作
- **THEN** 系统 SHALL 提升重复预览的响应速度
