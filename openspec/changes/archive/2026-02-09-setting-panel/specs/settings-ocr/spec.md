## ADDED Requirements

### Requirement: OCR 启用/禁用开关
系统 SHALL 允许用户启用或禁用 OCR 功能。

#### Scenario: 禁用 OCR
- **WHEN** 用户在设置中关闭 OCR
- **THEN** OCRService SHALL 立即停止处理新图片
- **AND** 已完成的 OCR 结果 SHALL 仍保留可搜索

#### Scenario: 启用 OCR
- **WHEN** 用户在设置中开启 OCR
- **THEN** OCRService SHALL 开始处理待处理的图片
- **AND** SHALL 使用当前配置的 OCR 参数

#### Scenario: OCR 默认状态
- **WHEN** 首次启动应用
- **THEN** OCR SHALL 默认为启用状态

### Requirement: OCR 语言选择
系统 SHALL 允许用户选择 OCR 识别的语言。

#### Scenario: 选择识别语言
- **WHEN** 用户选择 ["zh-Hans", "en", "ja"] 作为 OCR 语言
- **THEN** OCRService SHALL 使用这些语言进行文字识别
- **AND** 至少一种语言必须被选中

#### Scenario: OCR 默认语言
- **WHEN** 首次启动应用
- **THEN** OCR 语言 SHALL 默认为 ["zh-Hans", "zh-Hant", "en", "ko", "ja"]

#### Scenario: 清空所有语言
- **WHEN** 用户尝试取消所有 OCR 语言选择
- **THEN** 系统 SHALL 阻止该操作
- **AND** SHALL 保持至少一种语言被选中

### Requirement: OCR 置信度阈值
系统 SHALL 允许用户配置 OCR 结果的最小置信度阈值。

#### Scenario: 设置置信度阈值
- **WHEN** 用户将置信度阈值设置为 0.8
- **THEN** 置信度低于 0.8 的 OCR 结果 SHALL 被丢弃不保存

#### Scenario: 置信度上限限制
- **WHEN** 用户尝试设置置信度超过 1.0
- **THEN** 系统 SHALL 自动限制为 1.0

#### Scenario: 置信度下限限制
- **WHEN** 用户尝试设置置信度低于 0.1
- **THEN** 系统 SHALL 自动限制为 0.1

#### Scenario: 置信度默认值
- **WHEN** 首次启动应用
- **THEN** 置信度阈值 SHALL 默认为 0.7

### Requirement: OCR 识别级别
系统 SHALL 允许用户选择 OCR 识别级别（速度 vs 准确度）。

#### Scenario: 选择快速识别
- **WHEN** 用户选择 "Fast" 识别级别
- **THEN** OCRService SHALL 使用 `.fast` 识别级别
- **AND** 识别速度更快但准确度可能较低

#### Scenario: 选择准确识别
- **WHEN** 用户选择 "Accurate" 识别级别
- **THEN** OCRService SHALL 使用 `.accurate` 识别级别
- **AND** 识别更慢但更精确

#### Scenario: 识别级别默认值
- **WHEN** 首次启动应用
- **THEN** OCR 识别级别 SHALL 默认为 "Accurate"

### Requirement: OCR 搜索结果包含开关
系统 SHALL 允许用户选择是否在搜索时包含 OCR 结果。

#### Scenario: 排除 OCR 搜索结果
- **WHEN** 用户关闭 "搜索时包含 OCR 结果"
- **THEN** 搜索功能 SHALL 只查询 content 字段
- **AND** SHALL 不搜索 ocr_text 字段

#### Scenario: 包含 OCR 搜索结果
- **WHEN** 用户开启 "搜索时包含 OCR 结果"
- **THEN** 搜索功能 SHALL 同时查询 content 和 ocr_text 字段

#### Scenario: OCR 搜索默认状态
- **WHEN** 首次启动应用
- **THEN** "搜索时包含 OCR 结果" SHALL 默认为开启
