## 1. Core 层 - 数据库 Schema 扩展

- [ ] 1.1 创建数据库迁移文件 `core/migrations/0004-add-ocr-support.sql`
- [ ] 1.2 添加字段：ocr_text, ocr_status, ocr_retry_count, ocr_next_retry_at
- [ ] 1.3 创建索引：idx_items_ocr_status, idx_items_ocr_retry
- [ ] 1.4 验证迁移文件可以正确执行

## 2. Core 层 - Store 接口扩展

- [ ] 2.1 在 `core/include/pasty/history/store.h` 添加 OCR 相关方法声明
- [ ] 2.2 实现 `getNextOcrTask()` 方法
- [ ] 2.3 实现 `markOcrProcessing()` 方法
- [ ] 2.4 实现 `updateOcrSuccess()` 方法
- [ ] 2.5 实现 `updateOcrFailed()` 方法（含重试逻辑）
- [ ] 2.6 实现 `getOcrStatus()` 方法
- [ ] 2.7 在 `store_sqlite.cpp` 中实现所有 OCR 方法

## 3. Core 层 - C API 接口

- [ ] 3.1 在 `core/include/pasty/api/history_api.h` 添加 OCR C API 声明
- [ ] 3.2 实现 `pasty_history_get_pending_ocr_images()`
- [ ] 3.3 实现 `pasty_history_get_next_ocr_task()`
- [ ] 3.4 实现 `pasty_history_ocr_mark_processing()`
- [ ] 3.5 实现 `pasty_history_ocr_success()`
- [ ] 3.6 实现 `pasty_history_ocr_failed()`
- [ ] 3.7 实现 `pasty_history_get_ocr_status()`
- [ ] 3.8 在 `core/src/pasty.cpp` 中实现所有 OCR C API

## 4. Core 层 - 搜索功能扩展

- [ ] 4.1 修改 `store_sqlite.cpp` 中的 `search()` 方法 SQL
- [ ] 4.2 添加 WHERE 条件：COALESCE(content, '') LIKE ? OR COALESCE(ocr_text, '') LIKE ?
- [ ] 4.3 确保搜索结果返回 ocr_status 和 ocr_text 字段
- [ ] 4.4 运行 Core 层构建验证：`./scripts/core-build.sh`

## 5. Platform 层 - OCRService 实现

- [ ] 5.1 创建 `platform/macos/Sources/Utils/OCRService.swift`
- [ ] 5.2 定义 OCRService 类，使用单例模式
- [ ] 5.3 实现 `start()` 方法（延迟 5 秒启动）
- [ ] 5.4 实现串行处理队列 `DispatchQueue(label: "OCRService", qos: .background)`
- [ ] 5.5 实现 `processNext()` 方法调用 Core API 获取任务
- [ ] 5.6 实现 `markProcessing(id:)` 调用 Core API
- [ ] 5.7 实现 `reportSuccess(id:text:)` 调用 Core API
- [ ] 5.8 实现 `reportFailure(id:)` 调用 Core API
- [ ] 5.9 实现 `scheduleNextCheck(after:)` 空闲轮询机制

## 6. Platform 层 - Vision 框架集成

- [ ] 6.1 导入 Vision 框架
- [ ] 6.2 实现 `performOCR(imagePath:completion:)` 方法
- [ ] 6.3 配置 VNRecognizeTextRequest，设置语言列表
- [ ] 6.4 实现置信度检查（< 0.7 返回空）
- [ ] 6.5 实现 30 秒超时机制
- [ ] 6.6 处理图片加载失败错误

## 7. Platform 层 - 新增图片触发

- [ ] 7.1 在 `ClipboardWatcher` 新增图片成功后发送通知
- [ ] 7.2 在 `OCRService` 监听通知并触发即时检查
- [ ] 7.3 确保空闲时立即处理新记录，忙时加入队列

## 8. UI 层 - 数据模型更新

- [ ] 8.1 在 `ClipboardItemRow.swift` 添加 `ocrStatus` 字段
- [ ] 8.2 在 `ClipboardItemRow.swift` 添加 `ocrText` 字段
- [ ] 8.3 定义 `OcrStatus` 枚举（pending, processing, completed, failed）
- [ ] 8.4 更新 `CodingKeys` 包含新字段
- [ ] 8.5 验证 JSON 解码正常工作

## 9. UI 层 - 预览面板 OCR 标识

- [ ] 9.1 在 `MainPanelPreviewPanel.swift` 添加 OCR 状态图标区域
- [ ] 9.2 实现已识别状态：SF Symbol `text.viewfinder`，强调色
- [ ] 9.3 实现识别中状态：SF Symbol `eye` 或 loading 动画
- [ ] 9.4 实现无文字状态：SF Symbol `eye.slash`，灰色
- [ ] 9.5 实现失败状态：SF Symbol `exclamationmark.triangle`，警告色
- [ ] 9.6 图标位置：图片预览区域右上角

## 10. UI 层 - OCR 文本预览

- [ ] 10.1 实现鼠标悬停图标显示 Tooltip（OCR 文本前 100 字符）
- [ ] 10.2 实现点击图标展开完整 OCR 文本面板
- [ ] 10.3 OCR 文本面板支持文本选择和复制
- [ ] 10.4 在列表视图显示 OCR 摘要（前 50 字符）

## 11. 集成与测试

- [ ] 11.1 在 `App.swift` 初始化并启动 OCRService
- [ ] 11.2 运行 macOS 构建：`./scripts/platform-build-macos.sh Debug`
- [ ] 11.3 测试新增图片后自动触发 OCR
- [ ] 11.4 测试 OCR 结果保存到数据库
- [ ] 11.5 测试搜索可以匹配 OCR 文本
- [ ] 11.6 测试 UI 正确显示 OCR 状态图标
- [ ] 11.7 测试重试机制（模拟失败场景）
- [ ] 11.8 测试串行处理（多张图片同时添加）

## 12. 回归测试

- [ ] 12.1 验证现有文本记录功能正常
- [ ] 12.2 验证现有图片记录功能正常（显示、复制、删除）
- [ ] 12.3 验证搜索功能正常（文本内容搜索）
- [ ] 12.4 验证数据库迁移后现有数据完整
- [ ] 12.5 验证 Core 层单元测试通过（如有）
