# macOS Feature Architecture

## Purpose
定义 macOS 应用的基于功能的模块架构，确保可扩展性、清晰的模块边界和独立开发能力。

## Requirements

### Requirement: 功能模块组织
系统必须采用基于功能的目录结构，所有功能模块统一管理在 `Features/` 目录下，每个功能模块自包含 Model/、ViewModel/ 和 View/。

#### Scenario: 主面板模块结构
- **WHEN** 查看主面板模块的目录结构
- **THEN** 它位于 `Features/MainPanel/` 下
- **AND** 它包含 `Model/`、`ViewModel/` 和 `View/` 子目录
- **AND** 所有与主面板相关的文件都位于这些子目录中

#### Scenario: 设置模块结构
- **WHEN** 查看设置模块的目录结构
- **THEN** 它位于 `Features/Settings/` 下
- **AND** 它包含 `ViewModel/` 和 `View/` 子目录
- **AND** 所有与设置 UI 和业务逻辑相关的文件都位于这些子目录中

#### Scenario: 未来功能模块
- **WHEN** 添加新的功能模块
- **THEN** 系统在 `Features/` 下创建新的功能目录
- **AND** 新目录包含 `Model/`、`ViewModel/` 和 `View/` 的子目录结构

### Requirement: 共享基础设施层
系统必须将共享的基础设施代码与功能代码分开，放在专用的顶级目录中。

#### Scenario: 设计系统组织
- **WHEN** 访问设计系统组件
- **THEN** 所有共享的 UI 组件位于顶级 `DesignSystem/` 目录中
- **AND** 任何功能模块都可以导入和使用这些组件

#### Scenario: 服务层组织
- **WHEN** 访问业务服务
- **THEN** 服务定义位于顶级 `Services/Interface/` 中
- **AND** 服务实现位于顶级 `Services/Impl/` 中
- **AND** 服务遵循接口/实现分离模式

#### Scenario: 工具组织
- **WHEN** 访问纯实用函数
- **THEN** 纯实用函数和扩展位于顶级 `Utilities/` 目录中
- **AND** 这些工具不依赖应用状态或业务逻辑

### Requirement: 模块边界清晰性
系统必须确保每个功能模块有明确的边界，并最小化跨模块依赖。

#### Scenario: 功能自包含性
- **WHEN** 开发主面板功能
- **THEN** 主面板的所有模型、视图模型和视图都在 `Features/MainPanel/` 中
- **AND** 主面板有自己专属的 Model/ 子目录
- **AND** 开发者可以在该目录内完成工作，无需频繁切换到其他模块

#### Scenario: 最小跨模块依赖
- **WHEN** 功能模块需要访问共享代码
- **THEN** 模块只从顶级 `DesignSystem/`、`Services/` 或 `Utilities/` 导入
- **AND** 模块不直接从其他功能模块导入（除非有明确的共享需求）
- **AND** 每个功能使用自己的 Model/，不依赖其他功能的模型

### Requirement: 可扩展性
系统架构必须支持在无需重组现有代码的情况下轻松添加新功能模块。

#### Scenario: 添加新功能
- **WHEN** 团队决定添加新功能（例如编辑器）
- **THEN** 在 `Features/` 下创建新的 `Editor/` 目录
- **AND** 在 `Editor/` 下创建 `Model/`、`ViewModel/` 和 `View/` 子目录
- **AND** 现有的主面板、设置等模块无需更改

### Requirement: Swift 导入一致性
系统必须在重组后确保所有 Swift 导入语句与新的目录结构一致。

#### Scenario: 功能模块导入
- **WHEN** 主面板模块中的文件导入其视图模型
- **THEN** 它使用相对导入或正确的模块路径，如 `import MainPanel`（如果使用模块）
- **OR** 它使用正确的文件路径引用，包含 `Features/` 前缀

#### Scenario: 共享基础设施导入
- **WHEN** 功能模块导入共享代码
- **THEN** 它从顶级 `DesignSystem`、`Services` 或 `Utilities` 导入
- **AND** 导入路径反映新的目录组织

### Requirement: XcodeGen 项目配置兼容性
系统必须更新 XcodeGen 配置以反映新的目录结构。

#### Scenario: 源路径更新
- **WHEN** 生成 Xcode 项目
- **THEN** `project.yml` 文件包含正确指向新目录结构的源路径
- **AND** 包含 `Features/` 路径引用
- **AND** 所有目标都包含正确的文件引用

#### Scenario: 构建成功
- **WHEN** 使用新的目录结构构建应用
- **THEN** Xcode 构建成功完成
- **AND** 所有文件都正确包含在目标中
