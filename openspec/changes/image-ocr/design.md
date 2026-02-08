## Context

Pasty2 是一个跨平台剪贴板管理应用，采用 **C++ Core + 平台 Shell** 架构：

- **C++ Core**：位于 `core/` 目录，包含可移植的业务逻辑和数据存储
  - 数据存储使用 SQLite，通过迁移文件管理 schema 变更
  - 当前 items 表结构包含 id, type, content, image_path, image_width, image_height, image_format, create_time_ms, update_time_ms, last_copy_time_ms, source_app_id, content_hash 等字段
  - 搜索目前仅支持 content 字段的 LIKE 查询

- **Platform Shell (macOS)**：位于 `platform/macos/` 目录
  - Swift 代码通过 C API 与 Core 层交互
  - `ClipboardHistoryServiceImpl` 使用 Combine 封装 Core API 调用
  - `ClipboardItemRow` 作为 UI 数据模型
  - 图片预览已支持展示图片尺寸信息

当前图片记录无法被搜索，因为图片的文字内容没有被提取和存储。

## Goals / Non-Goals

**Goals:**
- 设计一个可扩展的 OCR 服务架构，支持图片文字识别
- 确保 OCR 处理不会阻塞主线程或影响用户体验
- 实现增量 OCR：优先处理最新记录，支持后台持续扫描
- 搜索时同时匹配文本内容和 OCR 结果
- UI 层展示 OCR 状态标识

**Non-Goals:**
- 不实现实时 OCR（复制图片时立即识别）—— 改为后台异步处理
- 不存储图片中文字的位置信息（bounding box）—— 仅存储纯文本
- 不支持 OCR 结果的手动编辑
- 不处理非图片类型的文件 OCR（如 PDF）

## Decisions

### 1. OCR 引擎选择：使用 Apple Vision 框架

**选择**: macOS 平台使用原生 `VNRecognizeTextRequest` API

**理由**:
- 无需引入外部依赖（如 Tesseract），减少包体积和复杂度
- Apple Vision 针对 Apple Silicon 优化，性能和准确性较好
- 支持多种语言识别：中文、英文、韩文、日文、阿拉伯文、拉丁文、俄文
- 平台原生 API 更稳定，维护成本低

**语言配置**:
```swift
let request = VNRecognizeTextRequest()
request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en", "ko", "ja", "ar", "la", "ru"]
request.usesLanguageCorrection = true
```

**替代方案**: Tesseract OCR
- 跨平台优势，但目前仅需支持 macOS
- 需要额外依赖和配置，增加复杂度
- 选择 Vision 是基于"最小变更"原则

### 2. 架构分层：OCR 服务放在 Platform 层

**选择**: OCR 核心逻辑放在 `platform/macos/` 层，而非 Core 层

**理由**:
- Vision 框架是 macOS 平台特有，Core 层需要保持可移植性
- OCR 识别是纯计算任务，不需要持久化逻辑
- Core 层暴露接口供 Platform 层调用更新 OCR 结果

**Core 层新增接口**:

```cpp
// 查询待 OCR 的图片记录（按 last_copy_time_ms 降序，状态为 pending）
// 返回 JSON 数组，包含：id, image_path, last_copy_time_ms
bool pasty_history_get_pending_ocr_images(int limit, char** out_json);

// 获取下一条待 OCR 的图片（串行处理用，状态为 pending 且到达重试时间）
// 返回 JSON 对象，包含：id, image_path, retry_count
bool pasty_history_get_next_ocr_task(char** out_json);

// 更新记录的 OCR 结果（识别成功）
bool pasty_history_ocr_success(const char* id, const char* ocr_text);

// 报告 OCR 失败（Platform 层调用，Core 自动更新重试计数和下次重试时间）
bool pasty_history_ocr_failed(const char* id);

// 标记记录为 OCR 处理中（防止多个 worker 同时处理）
bool pasty_history_ocr_mark_processing(const char* id);

// 获取记录的 OCR 状态（用于 UI 展示）
// 返回 JSON 对象，包含：ocr_status, ocr_text（如果有）
bool pasty_history_get_ocr_status(const char* id, char** out_json);
```

### 3. 串行处理：单队列顺序执行（Platform 层调度）

**选择**: OCR 任务调度逻辑放在 `platform/macos/` 层，使用单队列串行处理

**理由**:
- 避免并发导致的内存压力（Vision 识别可能占用较多资源）
- 串行逻辑简单，易于调试和维护
- 按 last_copy_time_ms 降序处理确保用户体验（最新记录优先）
- Platform 层可灵活控制调度策略，响应系统资源变化

**Platform 层调度策略**:
```swift
class OCRService {
    private let queue = DispatchQueue(label: "OCRService", qos: .background)
    private var isProcessing = false
    private let maxRetries = 3
    private let retryIntervals: [TimeInterval] = [5, 30, 300]  // 5秒、30秒、5分钟
    
    func start() {
        // 延迟启动：应用启动后5秒
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.processNext()
        }
    }
    
    private func processNext() {
        queue.async { [weak self] in
            guard let self = self, !self.isProcessing else { return }
            
            // 从 Core 获取下一条待处理记录
            guard let task = self.getNextTask() else {
                // 无任务，10秒后再次检查
                self.scheduleNextCheck(after: 10)
                return
            }
            
            self.isProcessing = true
            
            // 标记为 processing 状态
            self.markProcessing(id: task.id)
            
            // 执行 OCR
            self.performOCR(task: task) { [weak self] result in
                switch result {
                case .success(let text):
                    // 报告成功
                    self?.reportSuccess(id: task.id, text: text)
                case .failure(let error):
                    // 报告失败（Core 层自动处理重试计数）
                    self?.reportFailure(id: task.id)
                }
                
                self?.isProcessing = false
                // 继续处理下一条
                self?.processNext()
            }
        }
    }
    
    private func scheduleNextCheck(after interval: TimeInterval) {
        queue.asyncAfter(deadline: .now() + interval) { [weak self] in
            self?.processNext()
        }
    }
}
```

**调度流程**:
1. 应用启动后延迟 5 秒启动 OCR 服务
2. 查询 Core 层获取下一条待处理记录（`pasty_history_get_next_ocr_task`）
3. 标记记录为 processing 状态（`pasty_history_ocr_mark_processing`）
4. 使用 Vision 框架执行 OCR
5. 报告结果：成功（`pasty_history_ocr_success`）或失败（`pasty_history_ocr_failed`）
6. 立即处理下一条，无任务时 10 秒后再次检查
7. 新增图片记录时触发即时检查（通过通知机制）

### 4. 数据库 Schema 变更

**新增字段**:
```sql
ALTER TABLE items ADD COLUMN ocr_text TEXT;
ALTER TABLE items ADD COLUMN ocr_status INTEGER DEFAULT 0;  -- 0:pending, 1:processing, 2:completed, 3:failed
ALTER TABLE items ADD COLUMN ocr_retry_count INTEGER DEFAULT 0;  -- 重试次数
ALTER TABLE items ADD COLUMN ocr_next_retry_at INTEGER DEFAULT 0;  -- 下次重试时间戳（毫秒）
```

**ocr_status 枚举**:
- `0`: pending（待识别）
- `1`: processing（识别中）
- `2`: completed（已完成）
- `3`: failed（识别失败，超过最大重试次数）

**索引**:
```sql
CREATE INDEX idx_items_ocr_status ON items(ocr_status, last_copy_time_ms DESC);
CREATE INDEX idx_items_ocr_text ON items(ocr_text) WHERE ocr_text IS NOT NULL;
```

### 5. 搜索集成策略

**SQL 变更**:
```sql
-- 原查询
WHERE COALESCE(content, '') LIKE ?1

-- 新查询
WHERE (COALESCE(content, '') LIKE ?1 OR COALESCE(ocr_text, '') LIKE ?1)
```

**考虑**:
- OR 查询可能导致索引失效，但由于数据量不大（默认 1000 条），性能可接受
- 如有性能问题，后续可添加全文搜索（FTS5）扩展

### 6. UI 状态标识

**方案**: 在 `ClipboardItemRow` 新增 `ocrStatus` 字段

**预览面板**:
- 图片预览区域右上角展示小型图标
- 使用 SF Symbols：`text.viewfinder`（已识别）、`eye.slash`（无文字）
- 鼠标悬停显示识别出的文字片段（tooltip）

## Risks / Trade-offs

**[风险] OCR 处理可能占用较多 CPU/内存**
→ **缓解措施**: 
- 后台队列使用 `.background` QoS
- 串行处理避免并发资源竞争
- 单张图片识别超时机制（30 秒）

**[风险] 大量历史图片首次启动时 OCR 可能导致启动慢**
→ **缓解措施**:
- OCR 服务延迟启动（应用启动后 5 秒）
- 分批处理，避免阻塞其他操作
- 暂时不提供关闭 OCR 的开关（后续根据用户反馈决定）

**[风险] OCR 准确性问题**
→ **缓解措施**:
- OCR 是辅助功能，不作为主要搜索依赖
- 失败记录自动重试，最多重试 3 次
- 重试间隔：失败后 5 秒、30 秒、5 分钟
- 3 次失败后标记为永久失败，不再自动重试
- 不存储低置信度结果（置信度 < 0.7 不保存）

**[风险] 数据库 schema 变更后降级困难**
→ **缓解措施**:
- 新增字段允许 NULL，保持向后兼容
- 使用迁移文件管理 schema 版本

## Migration Plan

### 数据库迁移
1. 新增 migration 文件 `0004-add-ocr-support.sql`
2. 添加字段：ocr_text, ocr_status, ocr_retry_count, ocr_next_retry_at
3. 创建必要的索引

### 代码部署
1. **Core 层**: 新增 OCR 相关 C API 和 Store 方法
2. **Platform 层**: 实现 OCRService，集成到 App 生命周期
3. **UI 层**: 更新预览面板，添加 OCR 状态图标

### 回滚策略
- 删除字段：ocr_text, ocr_status, ocr_retry_count, ocr_next_retry_at（可选）
- 移除 OCR 服务代码
- 回滚搜索 SQL 到原版本

## Open Questions

已解决：

1. ✅ **OCR 语言支持**: 支持中文（简/繁）、英文、韩文、日文、阿拉伯文、拉丁文、俄文
2. ✅ **失败重试策略**: 自动重试 3 次，间隔分别为 5 秒、30 秒、5 分钟
3. ✅ **OCR 开关**: 暂时不需要，保持功能始终开启
4. ✅ **隐私考量**: OCR 结果与普通文本内容等同处理，无需特殊逻辑
