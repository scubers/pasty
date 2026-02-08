## ADDED Requirements

### Requirement: 搜索支持 OCR 文本
Core 层 SHALL 扩展搜索功能，支持同时搜索文本内容和图片 OCR 结果。

#### Scenario: 搜索匹配 OCR 文本
- **GIVEN** 有一张图片记录的 ocr_text 为 "Hello World"
- **WHEN** 用户搜索关键词 "Hello"
- **THEN** SHALL 返回该图片记录
- **AND** 该记录 SHALL 出现在搜索结果中

#### Scenario: 搜索同时匹配 content 和 ocr_text
- **GIVEN** 有一条文本记录 content = "Hello"
- **AND** 有一张图片记录 ocr_text = "Hello"
- **WHEN** 用户搜索关键词 "Hello"
- **THEN** SHALL 同时返回两条记录
- **AND** 两条记录 SHALL 按 last_copy_time_ms 降序排序

#### Scenario: 搜索不匹配
- **GIVEN** 没有任何记录的 content 或 ocr_text 包含 "XYZ123"
- **WHEN** 用户搜索关键词 "XYZ123"
- **THEN** SHALL 返回空结果列表

#### Scenario: 图片记录没有 OCR 结果
- **GIVEN** 有一张图片记录的 ocr_text 为 NULL
- **AND** 没有文本记录包含关键词 "Special"
- **WHEN** 用户搜索关键词 "Special"
- **THEN** SHALL 不返回该图片记录

---

### Requirement: 搜索 SQL 实现
Core 层 SHALL 修改搜索 SQL 以支持 OCR 文本搜索。

#### Scenario: 基础搜索 SQL
- **WHEN** 执行搜索查询
- **THEN** SHALL 使用以下 WHERE 条件：
  ```sql
  WHERE (COALESCE(content, '') LIKE ?1 OR COALESCE(ocr_text, '') LIKE ?1)
  ```
- **AND** SHALL 保持原有排序：ORDER BY last_copy_time_ms DESC
- **AND** SHALL 保持原有分页限制

#### Scenario: 带类型过滤的搜索
- **WHEN** 搜索时指定了 contentType 过滤条件
- **THEN** SHALL 在 WHERE 条件中添加类型过滤
- **AND** SQL SHALL 为：
  ```sql
  WHERE (COALESCE(content, '') LIKE ?1 OR COALESCE(ocr_text, '') LIKE ?1)
    AND type = ?3
  ```

#### Scenario: 空搜索查询
- **GIVEN** 搜索关键词为空字符串
- **WHEN** 执行搜索
- **THEN** SHALL 使用 LIKE '%%' 匹配所有记录
- **AND** 返回结果 SHALL 包含所有记录（受 limit 限制）

---

### Requirement: 搜索结果包含 OCR 信息
Core 层 SHALL 在搜索结果中包含 OCR 相关信息。

#### Scenario: 返回 OCR 文本
- **WHEN** 返回搜索结果
- **THEN** 每个图片记录 SHALL 包含 ocr_text 字段（如果有）
- **AND** 返回的 JSON SHALL 包含 ocr_status 字段

#### Scenario: 文本记录的 OCR 字段
- **GIVEN** 搜索结果中的记录是文本类型
- **WHEN** 返回该记录
- **THEN** ocr_text SHALL 为 null 或空字符串
- **AND** ocr_status SHALL 为 null 或不返回（仅图片类型有意义）
