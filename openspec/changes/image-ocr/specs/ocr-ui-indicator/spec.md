## ADDED Requirements

### Requirement: 数据模型包含 OCR 状态
macOS Platform 层 SHALL 在数据模型中暴露 OCR 状态。

#### Scenario: ClipboardItemRow 包含 OCR 字段
- **GIVEN** Core API 返回的 JSON 包含 ocr_status 和 ocr_text
- **WHEN** 解码为 ClipboardItemRow
- **THEN** ClipboardItemRow SHALL 包含以下字段：
  - `ocrStatus`: OcrStatus 枚举（pending, processing, completed, failed）
  - `ocrText`: String?（可选，识别出的文字）

#### Scenario: OcrStatus 枚举定义
- **GIVEN** OCR 状态需要在 UI 中展示
- **THEN** SHALL 定义 OcrStatus 枚举：
  ```swift
  enum OcrStatus: String, Equatable, Decodable {
      case pending       // 待识别
      case processing    // 识别中
      case completed     // 已完成
      case failed        // 识别失败
  }
  ```

---

### Requirement: 预览面板展示 OCR 状态
macOS Platform 层 SHALL 在图片预览面板中展示 OCR 状态标识。

#### Scenario: 已识别状态标识
- **GIVEN** 预览的图片记录 ocr_status = completed
- **AND** ocr_text 不为空
- **WHEN** 在预览面板展示该图片
- **THEN** SHALL 在图片预览区域右上角展示 "已识别" 图标
- **AND** SHALL 使用 SF Symbols: `text.viewfinder`
- **AND** 图标颜色 SHALL 为系统强调色（accent color）

#### Scenario: 识别中状态标识
- **GIVEN** 预览的图片记录 ocr_status = processing
- **WHEN** 在预览面板展示该图片
- **THEN** SHALL 展示 "识别中" 图标
- **AND** SHALL 使用 SF Symbols: `eye` 或 loading 动画

#### Scenario: 无文字或失败状态标识
- **GIVEN** 预览的图片记录 ocr_status = completed
- **AND** ocr_text 为空（没有识别出文字）
- **WHEN** 在预览面板展示该图片
- **THEN** SHALL 展示 "无文字" 图标
- **AND** SHALL 使用 SF Symbols: `eye.slash`
- **AND** 图标颜色 SHALL 为次要文字颜色（gray）

#### Scenario: 失败状态标识
- **GIVEN** 预览的图片记录 ocr_status = failed
- **WHEN** 在预览面板展示该图片
- **THEN** SHALL 展示 "识别失败" 图标
- **AND** SHALL 使用 SF Symbols: `exclamationmark.triangle`
- **AND** 图标颜色 SHALL 为警告色（orange/red）

---

### Requirement: OCR 文本预览
macOS Platform 层 SHALL 支持预览已识别的 OCR 文本。

#### Scenario: 鼠标悬停显示 OCR 文本
- **GIVEN** 预览的图片记录 ocr_status = completed
- **AND** ocr_text 不为空
- **WHEN** 用户鼠标悬停在已识别图标上
- **THEN** SHALL 显示 Tooltip 展示 OCR 文本片段（前 100 字符）

#### Scenario: 展开查看完整 OCR 文本
- **GIVEN** 预览的图片有 OCR 文本
- **WHEN** 用户点击已识别图标
- **THEN** SHALL 在预览面板下方或侧边展示完整的 OCR 文本
- **AND** SHALL 支持文本选择和复制

#### Scenario: 列表视图展示 OCR 摘要
- **GIVEN** 在列表视图中显示图片记录
- **WHEN** 该记录已完成 OCR 且 ocr_text 不为空
- **THEN** SHALL 在记录行展示 OCR 文本摘要（前 50 字符）
- **AND** 格式 SHALL 为：📝 "识别的文字摘要..."

---

### Requirement: 新增图片触发 OCR 通知
macOS Platform 层 SHALL 在新增图片记录时通知 OCR 服务。

#### Scenario: 新增图片时触发检查
- **GIVEN** ClipboardWatcher 检测到新的图片剪贴板内容
- **WHEN** 图片成功保存到 Core 层
- **THEN** SHALL 发送通知触发 OCRService 立即检查
- **AND** IF OCRService 当前空闲 THEN 立即开始处理新记录
