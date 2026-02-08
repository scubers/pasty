## ADDED Requirements

### Requirement: 数据库 Schema 扩展
Core 层 SHALL 扩展 items 表，添加 OCR 相关字段。

#### Scenario: 新增 OCR 字段
- **WHEN** 执行数据库迁移 `0004-add-ocr-support.sql`
- **THEN** SHALL 添加字段 `ocr_text` (TEXT 类型，可为 NULL)
- **AND** SHALL 添加字段 `ocr_status` (INTEGER 类型，默认值为 0)
- **AND** SHALL 添加字段 `ocr_retry_count` (INTEGER 类型，默认值为 0)
- **AND** SHALL 添加字段 `ocr_next_retry_at` (INTEGER 类型，默认值为 0)

#### Scenario: ocr_status 状态值定义
- **GIVEN** ocr_status 字段
- **THEN** SHALL 定义以下状态值：
  - `0` = pending（待识别）
  - `1` = processing（识别中）
  - `2` = completed（已完成）
  - `3` = failed（识别失败，超过最大重试次数）

---

### Requirement: 创建 OCR 相关索引
Core 层 SHALL 创建索引优化 OCR 查询性能。

#### Scenario: 创建状态查询索引
- **WHEN** 数据库迁移时
- **THEN** SHALL 创建索引 `idx_items_ocr_status` ON items(ocr_status, last_copy_time_ms DESC)
- **AND** 该索引 SHALL 支持按状态筛选并按最后复制时间排序

#### Scenario: 创建重试时间索引
- **WHEN** 数据库迁移时
- **THEN** SHALL 创建索引 `idx_items_ocr_retry` ON items(ocr_status, ocr_next_retry_at) WHERE ocr_status = 0
- **AND** 该索引 SHALL 支持查询已到重试时间的 pending 记录

---

### Requirement: Core 层 OCR 查询接口
Core 层 SHALL 提供 API 供 Platform 层查询和管理 OCR 状态。

#### Scenario: 获取待处理图片列表
- **WHEN** 调用 `pasty_history_get_pending_ocr_images(limit, out_json)`
- **THEN** SHALL 返回 ocr_status = 0 且 ocr_next_retry_at <= 当前时间的记录
- **AND** SHALL 按 last_copy_time_ms 降序排序（最新的优先）
- **AND** SHALL 返回 JSON 数组，包含：id, image_path, last_copy_time_ms

#### Scenario: 获取下一条待处理记录
- **WHEN** 调用 `pasty_history_get_next_ocr_task(out_json)`
- **THEN** SHALL 查询第一条满足条件的记录：
  - ocr_status = 0（pending）
  - ocr_next_retry_at <= 当前时间（到达重试时间）
- **AND** SHALL 按 last_copy_time_ms 降序排序
- **AND** SHALL 返回 JSON 对象，包含：id, image_path, retry_count

#### Scenario: 标记记录为处理中
- **WHEN** 调用 `pasty_history_ocr_mark_processing(id)`
- **THEN** SHALL 将指定记录的 ocr_status 更新为 1（processing）
- **AND** SHALL 返回布尔值表示是否成功

#### Scenario: 报告 OCR 成功
- **WHEN** 调用 `pasty_history_ocr_success(id, ocr_text)`
- **THEN** SHALL 将指定记录的 ocr_text 更新为传入值
- **AND** SHALL 将 ocr_status 更新为 2（completed）
- **AND** SHALL 将 ocr_retry_count 重置为 0
- **AND** SHALL 返回布尔值表示是否成功

#### Scenario: 报告 OCR 失败（首次）
- **GIVEN** 记录的 ocr_retry_count = 0
- **WHEN** 调用 `pasty_history_ocr_failed(id)`
- **THEN** SHALL 将 ocr_retry_count 增加为 1
- **AND** SHALL 将 ocr_next_retry_at 设置为当前时间 + 5 秒
- **AND** SHALL 将 ocr_status 保持为 0（pending）
- **AND** SHALL 返回布尔值表示是否成功

#### Scenario: 报告 OCR 失败（第二次）
- **GIVEN** 记录的 ocr_retry_count = 1
- **WHEN** 调用 `pasty_history_ocr_failed(id)`
- **THEN** SHALL 将 ocr_retry_count 增加为 2
- **AND** SHALL 将 ocr_next_retry_at 设置为当前时间 + 30 秒
- **AND** SHALL 将 ocr_status 保持为 0（pending）
- **AND** SHALL 返回布尔值表示是否成功

#### Scenario: 报告 OCR 失败（第三次，最终失败）
- **GIVEN** 记录的 ocr_retry_count = 2
- **WHEN** 调用 `pasty_history_ocr_failed(id)`
- **THEN** SHALL 将 ocr_retry_count 增加为 3
- **AND** SHALL 将 ocr_status 更新为 3（failed）
- **AND** SHALL 不再自动重试该记录
- **AND** SHALL 返回布尔值表示是否成功

#### Scenario: 获取 OCR 状态
- **WHEN** 调用 `pasty_history_get_ocr_status(id, out_json)`
- **THEN** SHALL 返回指定记录的 OCR 状态
- **AND** SHALL 返回 JSON 对象，包含：ocr_status, ocr_text（如果有）

---

### Requirement: 向后兼容
Core 层 SHALL 确保 schema 变更向后兼容。

#### Scenario: 已有数据迁移
- **GIVEN** 已存在的 items 表记录
- **WHEN** 执行迁移添加 OCR 字段
- **THEN** 已有记录的 ocr_status SHALL 默认为 0（pending）
- **AND** 已有记录的 ocr_text SHALL 默认为 NULL
- **AND** 已有记录的 ocr_retry_count SHALL 默认为 0
- **AND** 已有记录的 ocr_next_retry_at SHALL 默认为 0

#### Scenario: Core API 兼容性
- **GIVEN** 现有的 Core API（如 list、search）
- **WHEN** 添加 OCR 字段后
- **THEN** 现有 API SHALL 正常工作，不破坏已有功能
