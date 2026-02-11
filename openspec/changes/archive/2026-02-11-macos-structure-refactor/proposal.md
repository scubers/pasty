## 为什么（Why）

当前 `platform/macos/Sources` 目录结构采用扁平化组织，将功能代码与共享关注点混合在一起（Utils/ 中包含服务，View/ 中包含 MainPanel，Model/ 组织混乱）。随着应用超越主面板和设置，扩展到多个功能模块，这种结构无法扩展。需要采用基于功能的架构，以实现模块的独立开发和清晰的边界。

## 变更内容（What Changes）

**新的目录结构**
- 在 `Sources/` 下引入基于功能的组织
- 将 Utils/ 重组为 `Services/`，包含 Interface/ 和 Impl/ 子目录
- 将功能特定代码移动到专用功能目录
- 创建 `Utilities/` 用于真正的共享实用程序代码

**模块组织**
- `Features/` - 统一管理所有功能模块的目录
  - `MainPanel/` - 主面板功能（Model/、ViewModel/、View/）
  - `Settings/` - 设置功能（ViewModel/、View/）
  - `FutureModules/` - 未来功能的占位符
- 每个功能都是自包含的，拥有自己的 Model、View 和 ViewModel

**共享基础设施**
- `DesignSystem/` - UI 组件（位置不变，只是作为共享层的一部分）
- `Services/` - 具有 Interface/ 和 Impl/ 模式的业务服务
- `Utilities/` - 纯实用程序函数和扩展

**重新组织后的完整目录结构**
```
platform/macos/Sources/
├── App.swift                          # 应用入口
│
├── DesignSystem/                      # 设计系统（共享）
│   ├── DesignSystem.swift
│   ├── DesignSystem+Modifiers.swift
│   ├── String+Color.swift
│   └── Components/
│       ├── DangerButton.swift
│       ├── PastySlider.swift
│       ├── PastyToggle.swift
│       └── VisualEffectBlur.swift
│
├── Services/                          # 业务服务层（共享）
│   ├── Interface/                      # 服务接口定义
│   │   ├── ClipboardHistoryService.swift
│   │   └── HotkeyService.swift
│   └── Impl/                          # 服务实现
│       ├── ClipboardHistoryServiceImpl.swift
│       ├── HotkeyServiceImpl.swift
│       ├── ClipboardWatcher.swift
│       ├── MainPanelInteractionService.swift
│       ├── SettingsManager.swift
│       └── OCRService.swift
│
├── Utilities/                         # 纯实用程序（共享）
│   ├── AppPaths.swift
│   ├── CombineExtensions.swift
│   ├── DeleteConfirmationHotkeyOwner.swift
│   ├── InAppHotkeyPermissionManager.swift
│   ├── InAppHotkeyPermissionTypes.swift
│   └── LoggerService.swift
│
└── Features/                          # 所有功能模块
    ├── MainPanel/                     # 主面板功能模块
    │   ├── Model/
    │   │   ├── ClipboardItemRow.swift
    │   │   └── ClipboardSourceAttribution.swift
    │   ├── ViewModel/
    │   │   └── MainPanelViewModel.swift
    │   └── View/
    │       ├── MainPanelView.swift
    │       ├── MainPanelWindowController.swift
    │       ├── MainPanelContent.swift
    │       ├── MainPanelFooterView.swift
    │       ├── MainPanelSearchBar.swift
    │       ├── MainPanelPreviewPanel.swift
    │       ├── MainPanelMaterials.swift
    │       ├── MainPanelImageLoader.swift
    │       ├── MainPanelTokens.swift
    │       ├── AppKit/
    │       │   ├── MainPanelItemTableView.swift
    │       │   ├── MainPanelItemTableCellView.swift
    │       │   ├── MainPanelItemTableRepresentable.swift
    │       │   ├── MainPanelLongTextView.swift
    │       │   └── MainPanelLongTextRepresentable.swift
    │       ├── HistoryViewController.swift
    │       └── HistoryWindowController.swift
    │
    ├── Settings/                      # 设置功能模块
    │   ├── ViewModel/
    │   │   └── [未来可能的 SettingsViewModel.swift]
    │   └── View/
    │       ├── SettingsView.swift
    │       ├── SettingsWindowController.swift
    │       ├── SettingsDirectoryView.swift
    │       ├── StorageLocationHelper.swift
    │       ├── StorageLocationSettingsView.swift
    │       ├── GeneralSettingsView.swift
    │       ├── AppearanceSettingsView.swift
    │       ├── ClipboardSettingsView.swift
    │       ├── OCRSettingsView.swift
    │       ├── ShortcutsSettingsView.swift
    │       ├── AboutSettingsView.swift
    │       └── Views/
    │           ├── SettingsContentContainer.swift
    │           ├── SettingsNavigation.swift
    │           ├── SettingsSection.swift
    │           └── SettingsSidebarView.swift
    │
    └── FutureModules/                 # 未来功能模块占位符
        └── [按需添加新功能模块]
```

**文件迁移**
- 所有现有文件将移动到新位置
- 导入语句将更新以反映新结构
- 不会更改代码行为，仅组织文件

## 功能能力（Capabilities）

### 新增功能能力
- `macos-feature-architecture`：macOS 应用的基于功能的模块组织，定义目录结构、模块边界和独立功能开发的组织原则

### 修改的功能能力
- `settings-ui`：设置模块的文件路径将更改为新结构
- `design-system-core`：规范中的目录路径引用需要更新

## 影响（Impact）

**受影响的代码**
- `platform/macos/Sources/` 中的所有 Swift 文件将移动到新位置
- 跨文件的导入语句需要更新
- XcodeGen `project.yml` 需要路径更新

**受影响的依赖**
- 无（未引入新依赖）

**构建系统**
- `platform/macos/project.yml` 需要更新源路径以反映新结构
- 构建脚本保持不变

**无功能中断性更改**
- 这纯粹是结构性重构
- 用户行为保持不变
