# macOS 目录结构重构任务清单

## 目标目录结构（参考）
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

## 1. 迁移前准备（Pre-Migration Preparation）

- [x] 1.1 通过创建 git 提交备份当前目录结构
- [x] 1.2 在迁移映射文件中记录所有当前文件路径
- [x] 1.3 创建 `platform/macos/project.yml` 的备份

## 2. 创建新目录结构（Create New Directory Structure）

- [x] 2.1 创建 `platform/macos/Sources/Features/` 目录
- [x] 2.2 创建 `platform/macos/Sources/Features/MainPanel/` 目录
- [x] 2.3 创建 `platform/macos/Sources/Features/MainPanel/Model/` 目录
- [x] 2.4 创建 `platform/macos/Sources/Features/MainPanel/ViewModel/` 目录
- [x] 2.5 创建 `platform/macos/Sources/Features/MainPanel/View/` 目录
- [x] 2.6 创建 `platform/macos/Sources/Features/Settings/` 目录
- [x] 2.7 创建 `platform/macos/Sources/Features/Settings/ViewModel/` 目录（如果不存在）
- [x] 2.8 创建 `platform/macos/Sources/Features/Settings/View/` 目录（如果不存在）
- [x] 2.9 创建 `platform/macos/Sources/Features/FutureModules/` 目录
- [x] 2.10 创建 `platform/macos/Sources/Services/` 目录
- [x] 2.11 创建 `platform/macos/Sources/Services/Interface/` 目录
- [x] 2.12 创建 `platform/macos/Sources/Services/Impl/` 目录
- [x] 2.13 创建 `platform/macos/Sources/Utilities/` 目录

## 3. 将文件移动到新位置（Move Files to New Locations）

### 3.1 主面板模块（MainPanel Module）
- [x] 3.1.1 将 `View/MainPanel/` 的内容移动到 `Features/MainPanel/View/`
- [x] 3.1.2 将 `ViewModel/MainPanelViewModel.swift` 移动到 `Features/MainPanel/ViewModel/`
- [x] 3.1.3 将 `Model/` 的内容移动到 `Features/MainPanel/Model/`
- [x] 3.1.4 验证所有主面板文件都在正确的位置

### 3.2 设置模块（Settings Module）
- [x] 3.2.1 将 `Settings/View/` 的内容移动到 `Features/Settings/View/`
- [x] 3.2.2 将 `Settings/Views/` 的内容移动到 `Features/Settings/View/`
- [x] 3.2.3 将 `Settings/ViewModel/` 的内容移动到 `Features/Settings/ViewModel/`
- [x] 3.2.4 将 `Settings/SettingsManager.swift` 移动到 `Services/Impl/SettingsManager.swift`
- [x] 3.2.5 验证所有设置文件都在正确的位置

### 3.3 服务迁移（Services Migration）
- [x] 3.3.1 将 `Utils/ClipboardHistoryService.swift` 移动到 `Services/Interface/`
- [x] 3.3.2 将 `Utils/ClipboardHistoryServiceImpl.swift` 移动到 `Services/Impl/`
- [x] 3.3.3 将 `Utils/HotkeyService.swift` 移动到 `Services/Interface/`
- [x] 3.3.4 将 `Utils/HotkeyServiceImpl.swift` 移动到 `Services/Impl/`
- [x] 3.3.5 将 `Utils/OCRService.swift` 移动到 `Services/Impl/`
- [x] 3.3.6 将 `Utils/ClipboardWatcher.swift` 移动到 `Services/Impl/`
- [x] 3.3.7 将 `Utils/MainPanelInteractionService.swift` 移动到 `Services/Impl/`
- [x] 3.3.8 识别并将任何其他服务接口移动到 `Services/Interface/`
- [x] 3.3.9 识别并将任何其他服务实现移动到 `Services/Impl/`

### 3.4 实用程序迁移（Utilities Migration）
- [x] 3.4.1 将 `Utils/AppPaths.swift` 移动到 `Utilities/`
- [x] 3.4.2 将 `Utils/CombineExtensions.swift` 移动到 `Utilities/`
- [x] 3.4.3 将 `Utils/DeleteConfirmationHotkeyOwner.swift` 移动到 `Utilities/`
- [x] 3.4.4 将 `Utils/InAppHotkeyPermissionManager.swift` 移动到 `Utilities/`
- [x] 3.4.5 将 `Utils/InAppHotkeyPermissionTypes.swift` 移动到 `Utilities/`
- [x] 3.4.6 将 `Utils/LoggerService.swift` 移动到 `Utilities/`
- [x] 3.4.7 验证所有纯实用程序文件都在 `Utilities/` 中

### 3.5 验证目录结构（Verify Directory Structure）
- [x] 3.5.1 验证 `Utils/` 目录为空或仅包含需要移动的服务/实用程序文件
- [x] 3.5.2 如果所有文件已移动，删除空的 `Utils/` 目录
- [x] 3.5.3 验证 `ViewModel/` 目录为空或仅包含需要移动的文件
- [x] 3.5.4 如果所有文件已移动，删除空的 `ViewModel/` 目录
- [x] 3.5.5 验证 `View/` 目录为空，所有视图已移至各自功能模块
- [x] 3.5.6 验证 `Model/` 目录为空，所有模型已移至各自功能模块
- [x] 3.5.7 如果所有文件已移动，删除空的 `Model/` 和 `View/` 目录
- [x] 3.5.8 验证 `Features/` 目录包含所有功能模块

## 4. 更新导入语句（Update Import Statements）

- [x] 4.1 更新主面板文件中的所有导入以反映新路径（添加 `Features/` 前缀）
- [x] 4.2 更新设置文件中的所有导入以反映新路径（添加 `Features/` 前缀）
- [x] 4.3 更新 SettingsManager 引用，指向新的 `Services/Impl/SettingsManager.swift` 路径
- [x] 4.4 更新服务引用（ClipboardWatcher、MainPanelInteractionService），指向新的 `Services/Impl/` 路径
- [x] 4.5 如果设计系统文件引用了移动的文件，更新其中的所有导入
- [x] 4.6 更新 `App.swift` 中的导入以反映新结构
- [x] 4.7 使用自动化工具（sed/rg）查找和替换导入模式
- [x] 4.8 手动验证所有文件中的导入

## 5. 更新 XcodeGen 配置（Update XcodeGen Configuration）

- [x] 5.1 更新 `platform/macos/project.yml` 添加 `Features/` 源路径
- [x] 5.2 更新 `platform/macos/project.yml` 中主面板的源路径为 `Features/MainPanel/`
- [x] 5.3 更新 `platform/macos/project.yml` 中设置的源路径为 `Features/Settings/`
- [x] 5.4 更新 `platform/macos/project.yml` 中服务的源路径
- [x] 5.5 更新 `platform/macos/project.yml` 中实用程序的源路径
- [x] 5.6 更新 `platform/macos/project.yml` 中设计系统的源路径
- [x] 5.7 验证所有目标都有正确的文件引用
- [x] 5.8 运行 `xcodegen generate` 重新生成 Xcode 项目

## 6. 构建和验证（Build and Verify）

- [x] 6.1 清理构建目录：`rm -rf build/macos/Build/`
- [x] 6.2 运行完整构建：`./scripts/platform-build-macos.sh Debug`
- [x] 6.3 验证构建完成无错误
- [x] 6.4 如果构建失败，修复错误并重新构建
- [x] 6.5 运行应用并验证基本功能
- [x] 6.6 测试主面板 UI 正确打开
- [x] 6.7 测试设置窗口正确打开
- [x] 6.8 验证所有功能与以前一样工作

## 7. 更新文档（Update Documentation）

- [x] 7.1 使用新目录结构更新 `docs/project-structure.md`
- [x] 7.2 更新 `docs/project-structure.md` 中所有引用的文件路径
- [x] 7.3 如果存在 `platform/macos/ARCHITECTURE.md`，进行更新
- [x] 7.4 验证所有文档引用都是准确的
- [x] 7.5 使用新结构更新任何 README 文件

## 8. 最终验证（Final Verification）

- [x] 8.1 运行 `git status` 验证所有文件更改
- [x] 8.2 审查 diff 以确保没有意外的更改
- [x] 8.3 验证没有临时或备份文件残留
- [x] 8.4 再次测试所有主要应用功能
- [x] 8.5 创建带有描述性消息的最终 git 提交
- [x] 8.6 运行 openspec verify 以确认实现与设计匹配
