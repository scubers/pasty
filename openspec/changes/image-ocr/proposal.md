## Why

用户需要能够搜索图片中的文字内容。当前应用只能搜索文本剪贴板历史，而图片内容无法被检索。通过对历史图片进行 OCR 文字识别，可以将图片中的文字内容纳入搜索范围，提升搜索体验和产品实用性。

## What Changes

- **新增后台 OCR 服务**：应用启动后自动启动后台任务，对历史图片记录进行 OCR 识别
- **新增 ocr_text 字段**：数据库记录新增字段存储 OCR 识别结果
- **OCR 串行处理**：从最新的记录（按 lastcopytime 降序）开始往前扫描，避免资源竞争
- **循环扫描机制**：完成一轮扫描后，再次查询最近复制的图片记录继续识别
- **搜索功能增强**：搜索时 query 同时匹配 content 或 ocr_text 字段（LIKE 查询）
- **预览标识**：预览图片时，若已完成 OCR，展示已识别图标
- **增量触发**：新增图片记录时自动触发 OCR 识别任务

## Capabilities

### New Capabilities
- `ocr-service`: 后台 OCR 服务，负责图片文字识别的调度与执行
- `ocr-database-schema`: 数据库 schema 扩展，新增 ocr_text 字段及相关索引
- `ocr-search-integration`: 搜索功能集成，支持搜索图片 OCR 文本
- `ocr-ui-indicator`: UI 层标识，展示图片 OCR 状态

### Modified Capabilities
- `clipboard-image-record`: 新增图片记录时触发 OCR 识别流程

## Impact

- **Core 层**: 新增 OCR 服务接口，数据库 schema 变更，搜索逻辑扩展
- **Database**: 新增 `ocr_text` 字段，可能需要添加索引优化搜索性能
- **Platform 层 (macOS)**: 后台任务调度，UI 预览状态展示
- **依赖**: 可能需要引入 OCR 库（如 Tesseract 或平台原生 OCR API）
