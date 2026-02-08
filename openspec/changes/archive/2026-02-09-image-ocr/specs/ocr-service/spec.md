## ADDED Requirements

### Requirement: Platform 层提供 OCR 识别能力
macOS Platform 层 SHALL 使用 Apple Vision 框架提供图片 OCR 识别能力。

#### Scenario: 正常识别图片中的文字
- **WHEN** OCR 服务获取到一张待识别的图片路径
- **THEN** Platform 层 SHALL 使用 VNRecognizeTextRequest 执行 OCR
- **AND** SHALL 支持语言：简体中文、繁体中文、英文、韩文、日文、阿拉伯文、拉丁文、俄文
- **AND** SHALL 返回识别出的文字内容（按行拼接，以换行符分隔）

#### Scenario: 识别置信度低于阈值
- **WHEN** OCR 识别结果的平均置信度低于 0.7
- **THEN** SHALL 返回空字符串（视为无有效文字）

#### Scenario: 图片加载失败
- **WHEN** 无法读取图片文件（文件不存在、格式错误、损坏）
- **THEN** SHALL 抛出/返回错误，视为识别失败

#### Scenario: OCR 超时
- **WHEN** 单张图片 OCR 处理时间超过 30 秒
- **THEN** SHALL 取消识别任务，视为识别失败

---

### Requirement: OCR 服务串行调度
OCRService SHALL 实现单队列串行处理机制，确保同一时间只处理一张图片。

#### Scenario: 启动 OCR 服务
- **WHEN** 应用启动后 5 秒
- **THEN** OCRService SHALL 自动启动
- **AND** SHALL 开始查询待处理的图片记录

#### Scenario: 获取下一条待处理记录
- **WHEN** OCRService 准备处理下一张图片
- **THEN** SHALL 调用 Core API `pasty_history_get_next_ocr_task` 获取记录
- **AND** SHALL 获取到记录后先调用 `pasty_history_ocr_mark_processing` 标记状态

#### Scenario: 成功完成 OCR
- **WHEN** 图片 OCR 成功完成并获取到文字
- **THEN** SHALL 调用 Core API `pasty_history_ocr_success` 保存结果
- **AND** SHALL 立即处理下一条记录

#### Scenario: OCR 失败
- **WHEN** 图片 OCR 失败（异常、超时、无文字）
- **THEN** SHALL 调用 Core API `pasty_history_ocr_failed` 报告失败
- **AND** SHALL 立即处理下一条记录

#### Scenario: 无待处理记录
- **WHEN** 没有待处理的图片记录
- **THEN** SHALL 等待 10 秒后再次查询
- **AND** SHALL 持续循环检查

#### Scenario: 新增图片记录触发处理
- **WHEN** 新增图片剪贴板记录
- **THEN** SHALL 收到通知后立即触发一次处理检查
- **AND** IF 当前没有正在处理的记录 THEN 立即开始处理新记录

---

### Requirement: 后台队列配置
OCRService SHALL 使用后台队列执行 OCR 任务，避免阻塞主线程。

#### Scenario: 队列优先级
- **GIVEN** OCR 服务正在运行
- **THEN** SHALL 使用 `DispatchQueue(label: "OCRService", qos: .background)`
- **AND** SHALL 确保不阻塞 UI 线程

#### Scenario: 并发控制
- **GIVEN** 同时有多个待处理记录
- **THEN** SHALL 同一时间只处理一张图片
- **AND** SHALL 等待当前处理完成后再处理下一张
