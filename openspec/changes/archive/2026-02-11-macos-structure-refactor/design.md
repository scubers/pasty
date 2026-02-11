## 背景（Context）

macOS 应用当前具有扁平的源结构，关注点混合：
- `Utils/` 包含业务服务（ClipboardHistoryService、HotkeyService、OCRService）
- `View/` 包含与其他视图混合的 MainPanel 视图
- `ViewModel/` 位于根级别
- `Model/` 组织松散

随着应用扩展到包含多个功能模块（主面板、设置和未来模块），这种结构无法扩展。功能团队需要清晰的边界和隔离的开发环境。

约束条件：
- 不能引入新依赖
- 迁移后必须构建成功
- 代码行为必须保持不变
- 必须支持未来模块的添加而无需重组

## 目标 / 非目标（Goals / Non-Goals）

**目标：**
- 启用具有清晰模块边界的独立功能开发
- 为未来模块提供可扩展的结构
- 提高代码可发现性和导航性
- 使功能组织与 SwiftUI 的 MVVM 模式对齐
- 将基础设施（Services、DesignSystem）与功能分离

**非目标：**
- 不进行代码逻辑更改
- 除了目录结构外，不引入新的架构模式
- 不更改 Core 层（C++ Core 保持不变）
- 不更改用户行为

## 决策（Decisions）

### 1. 基于功能的目录结构

**决策：** 使用统一的 `Features/` 目录管理所有功能模块，每个功能包含 Model/、View/ 和 ViewModel/ 子目录。

**理由：**
- `Features/` 统一管理所有功能，边界清晰
- 每个功能拥有自己的 Model/ 符合领域驱动设计（DDD）原则
- 相关文件位于同一位置，提高可发现性
- 与 SwiftUI 的自然 MVVM 组织对齐
- 使功能的添加/删除变得简单

**考虑的替代方案：**
- *所有功能直接在 Sources/ 下*：根目录会变得庞大，功能边界不清晰
- *所有 Views/、所有 ViewModels/ 方法*：更适合跨功能代码重用，但更难导航，所有权不太清晰

### 2. 使用 Interface/Impl 模式的服务

**决策：** 将业务服务从 Utils/ 移动到 Services/，包含 Interface/ 和 Impl/ 子目录。

**理由：**
- 遵循现有的 Core 层可移植性模式（C++ Core 使用接口）
- 通过模拟实现启用可测试性
- 提供合约和实现之间的清晰分离
- 为潜在的未来服务抽象做准备

**考虑的替代方案：**
- *保持 Utils/ 不变*：Utils 名称对业务服务具有误导性
- *扁平 Services/ 目录*：没有合约/实现分离，更难测试

### 3. Utilities 与 Services 分离

**决策：** 创建 Utilities/ 用于纯实用程序函数（扩展、助手），创建 Services/ 用于业务逻辑。

**理由：**
- 纯实用程序不依赖于应用状态或业务逻辑
- 业务服务可能需要接口、依赖和状态管理
- 清晰的区别有助于代码组织和思维模型

**考虑的替代方案：**
- *所有都在 Services/ 中，没有 Utilities/*：对纯函数来说过于复杂
- *将 Utils/ 用于所有内容*：模糊了实用程序和业务逻辑之间的界限

### 4. 共享基础设施层

**决策：** 将 DesignSystem/、Services/、Utilities/ 保持在顶层作为共享基础设施。

**理由：**
- 这些被多个功能使用
- 功能代码和共享代码之间的清晰区别
- 遵循常见的应用架构模式（UI 工具包、服务层、实用程序）
- 每个功能有自己的 Model/，减少跨功能的模型耦合

**考虑的替代方案：**
- *将共享 Model/ 保持在顶层*：导致功能间的模型耦合，违反 DDD 原则
- *将共享代码放在每个功能内*：代码重复，更难维护

### 5. 迁移方法

**决策：** 单个原子迁移，在一个更改中进行所有文件移动和导入更新。

**理由：**
- 比增量迁移更快
- 没有中间损坏状态
- 可能进行清晰的迁移前后比较

**考虑的替代方案：**
- *增量逐功能迁移*：更安全但需要更长时间，管理更复杂

## 风险 / 权衡（Risks / Trade-offs）

| 风险 | 缓解措施 |
|------|------------|
| 导入更新可能会被遗漏导致构建失败 | 使用自动化工具（sed/rg）查找和替换导入，通过构建验证 |
| XcodeGen project.yml 路径更新可能会破坏构建 | 迁移后立即测试构建，保留原始 project.yml 备份 |
| 某些文件的模块边界可能不清晰 | 记录文件放置决策的指南，使用示例 |
| 过渡期间团队混淆 | 提供迁移指南、清晰的文件映射和验证清单 |

**权衡：**
- *功能隔离与代码共享*：功能有自己的目录，但共享代码需要仔细的放置决策
- *原子迁移与增量迁移*：原子迁移更快但需要彻底测试；增量迁移更安全但需要更长时间

## 迁移计划（Migration Plan）

### 步骤

1. **创建新的目录结构**
   - 在 `platform/macos/Sources/` 下创建 `Features/` 目录
   - 在 `Features/` 下创建 `MainPanel/`、`Settings/`、`FutureModules/` 目录
   - 为每个功能创建 Model/、ViewModel/、View/ 子目录
   - 确保正确权限

2. **将文件移动到新位置**
   - 移动 Utils/ → Services/Impl/ 和 Utilities/
   - 移动 View/MainPanel/ → Features/MainPanel/View/
   - 移动 ViewModel/ → Features/MainPanel/ViewModel/
   - 移动 Model/ → Features/MainPanel/Model/
   - 移动 Settings/View/ → Features/Settings/View/
   - 将 SettingsManager 移动到 Services/Impl/
   - 将 ClipboardWatcher 和 MainPanelInteractionService 移动到 Services/Impl/
   - 保持 DesignSystem/ 不变
   - 保持 App.swift 不变

3. **更新导入**
   - 更新所有导入语句以反映新路径（Features/ 前缀）
   - 验证没有损坏的引用

4. **更新 XcodeGen project.yml**
   - 更新 project.yml 中的源路径（Features/ 路径）
   - 验证目标配置

5. **构建和验证**
   - 运行清理构建
   - 修复任何构建错误
   - 运行测试（如果有）

6. **更新文档**
   - 使用新结构更新 docs/project-structure.md
   - 更新任何引用旧路径的内联注释

7. **归档更改**
   - 运行 openspec verify 以确认实现与设计匹配
   - 归档更改

### 回滚策略

- 在迁移期间保留原始目录结构作为备份
- 迁移前的 Git 提供干净的回滚点
- 如果构建彻底失败：`git checkout HEAD -- platform/macos/Sources`

## 未解决的问题（Open Questions）

无 - 目录结构已由用户需求完全指定。
