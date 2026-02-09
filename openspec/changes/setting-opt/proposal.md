# 设置优化 (Settings Optimization)

## Why

当前设置界面存在以下问题：外观设置中的主题模式（Theme Mode）概念不必要；快捷键分类不合理；存储目录设置功能未集成到设置界面中；危险操作（恢复默认设置、清空历史）缺乏确认机制；主题颜色未统一应用到所有界面元素。此次优化旨在简化设置结构，提升用户体验，并确保主题颜色的一致性应用。

## What Changes

### 移除和重组
- **BREAKING**: 移除 Appearance 中的 Theme Mode（主题模式）选项及相关代码
- **BREAKING**: 移除 Shortcuts 中的 In-App Shortcuts（应用内快捷键）展示部分
- 移动 Global Shortcuts（全局快捷键）从 Shortcuts 分组移至 General 分组

### 新增功能
- 在 General 分组中添加存储目录设置界面
- 为 Restore Default Settings 按钮添加二次确认对话框
- 为 Clear All History 按钮添加二次确认对话框

### 视觉优化
- 将 Appearance 中设置的主题颜色（Accent Color）应用到以下元素：
  - 主看板的历史记录选中背景色和边框色
  - 主看板的标记条（marker）颜色
  - 设置页面中滑块（PastySlider）的激活轨道颜色
  - 设置页面中开关（PastyToggle）的激活状态颜色
  - 侧边栏选中项的背景高亮颜色
- 将 Appearance 中设置的毛玻璃程度（Window Blur）应用到设置面板背景

## Capabilities

### New Capabilities
- `settings-storage-directory`: 存储目录设置功能，允许用户查看、在 Finder 中显示以及更改设置和数据的存储位置
- `dangerous-action-confirmation`: 危险操作的二次确认机制，包括恢复默认设置和清空历史记录
- `theme-color-application`: 主题颜色在整个应用中的一致性应用
- `settings-panel-blur`: 设置面板背景毛玻璃程度的动态应用

### Modified Capabilities
- `settings-ui`: 重构设置界面的布局结构，移除不必要的选项并重新组织快捷键设置
- `settings-ui-refresh`: 更新设计系统的颜色应用逻辑，使其支持动态主题颜色

## Impact

### 代码变更
- `platform/macos/Sources/Settings/AppearanceSettingsView.swift`: 移除 Theme Mode 代码段
- `platform/macos/Sources/Settings/ShortcutsSettingsView.swift`: 移除 In-App Shortcuts section
- `platform/macos/Sources/Settings/GeneralSettingsView.swift`: 添加 Global Shortcuts section，添加 Restore 确认对话框
- `platform/macos/Sources/Settings/ClipboardSettingsView.swift`: 添加 Clear All 确认对话框，集成清空历史逻辑
- `platform/macos/Sources/Settings/SettingsManager.swift`: 修改 AppearanceSettings 结构，移除 themeMode 属性
- `platform/macos/Sources/DesignSystem/DesignSystem.swift`: 修改 accent 颜色为动态属性，支持从设置中读取
- `platform/macos/Sources/View/MainPanel/AppKit/MainPanelItemTableCellView.swift`: 更新选中颜色逻辑，使用动态主题颜色
- `platform/macos/Sources/DesignSystem/Components/PastySlider.swift`: 使用动态主题颜色
- `platform/macos/Sources/DesignSystem/Components/PastyToggle.swift`: 使用动态主题颜色
- `platform/macos/Sources/Settings/Views/SettingsSidebarView.swift`: 使用动态主题颜色
- `platform/macos/Sources/Settings/SettingsView.swift`: 更新 colorScheme 逻辑，移除 themeMode 依赖，应用动态毛玻璃程度

### API 变更
- 移除 `AppearanceSettings.themeMode` 属性
- 新增 `DesignSystem.Colors.accent` 动态计算属性

### 数据持久化
- 现有设置文件向后兼容（themeMode 字段将被忽略）
- 版本号可能需要递增以触发设置迁移

### 用户体验
- 设置界面更简洁直观
- 危险操作更安全，防止误操作
- 主题颜色在整个应用中保持一致，视觉体验更统一
