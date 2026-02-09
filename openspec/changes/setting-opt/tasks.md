## 1. 准备工作

- [ ] 1.1 创建 `String+Color.swift` 扩展文件，实现 `toColor()` 方法，支持将颜色名称字符串转换为 SwiftUI Color
- [ ] 1.2 提取 `SettingsDirectoryView` 的文件选择和验证逻辑到 `StorageLocationHelper.swift`，以便复用

## 2. 数据模型变更

- [ ] 2.1 从 `AppearanceSettings` 结构体移除 `themeMode` 属性（文件：`SettingsManager.swift`）
- [ ] 2.2 更新 `AppearanceSettings` 的解码器（`init(from decoder:)`），忽略 `themeMode` 字段以保持向后兼容
- [ ] 2.3 测试设置文件解码，确认包含旧 `themeMode` 字段的设置文件仍能正确加载

## 3. UI 重构 - 设置页面

- [ ] 3.1 从 `AppearanceSettingsView.swift` 移除 Theme Mode section（包含 ThemePicker 组件）
- [ ] 3.2 从 `ShortcutsSettingsView.swift` 移除 In-App Shortcuts section
- [ ] 3.3 在 `ShortcutsSettingsView.swift` 移除 Global Shortcuts section（将移至 General）
- [ ] 3.4 创建 `StorageLocationSettingsView.swift`，使用 `SettingsSection` 和 `SettingsRow` 实现存储目录 UI
- [ ] 3.5 在 `GeneralSettingsView.swift` 添加 Storage section，嵌入 `StorageLocationSettingsView`
- [ ] 3.6 在 `GeneralSettingsView.swift` 添加 Global Shortcuts section（从 Shortcuts 移来）
- [ ] 3.7 在 `GeneralSettingsView.swift` 为"Restore Default Settings"按钮添加二次确认对话框（使用 `.alert()` 修饰符）
- [ ] 3.8 在 `ClipboardSettingsView.swift` 为"Clear All History"按钮添加二次确认对话框（使用 `.alert()` 修饰符）
- [ ] 3.9 实现"Clear All History"的实际清空逻辑（调用 ClipboardHistoryService）

## 4. UI 重构 - 设置导航

- [ ] 4.1 从 `SettingsView.swift` 移除 `colorScheme` 计算属性
- [ ] 4.2 从 `SettingsView.swift` 移除 `.preferredColorScheme(colorScheme)` 修饰符
- [ ] 4.3 更新 `SettingsNavigation.swift`，确认 Shortcuts tab 仍存在（仅移除 In-App Shortcuts）
- [ ] 4.4 删除不再使用的 `ThemePicker.swift` 组件

## 5. 设计系统更新 - 动态颜色

- [ ] 5.1 修改 `DesignSystem.Colors` 添加 `defaultAccent` 静态属性（Teal #2DD4BF）
- [ ] 5.2 更新 `PastySlider.swift`：接受 `@EnvironmentObject var settingsManager`，激活轨道颜色使用 `settingsManager.settings.appearance.themeColor.toColor()`
- [ ] 5.3 更新 `PastyToggle.swift`：接受 `@EnvironmentObject var settingsManager`，激活状态背景色使用 `settingsManager.settings.appearance.themeColor.toColor()`
- [ ] 5.4 更新 `SettingsSidebarView.swift`：接受 `@EnvironmentObject var settingsManager`，选中项背景高亮色使用 `settingsManager.settings.appearance.themeColor.toColor().opacity(0.1)`

## 6. 设计系统更新 - AppKit 代码

- [ ] 6.1 在 `MainPanelItemTableCellView.swift` 添加 Combine 订阅，监听 `SettingsManager.$settings` 变化
- [ ] 6.2 更新 `MainPanelItemTableCellView.swift` 的 `configure` 方法，选中背景色和标记条颜色使用 `SettingsManager.shared.settings.appearance.themeColor.toColor()`
- [ ] 6.3 更新 `MainPanelItemTableCellView.swift` 的 `configure` 方法，聚焦时边框颜色使用 `SettingsManager.shared.settings.appearance.themeColor.toColor().opacity(0.8)`
- [ ] 6.4 在设置变化时触发 `MainPanelItemTableCellView` 重新显示（调用 `needsDisplay = true`）

## 7. 设计系统更新 - 毛玻璃效果

- [ ] 7.1 更新 `SettingsView.swift`：接受 `@EnvironmentObject var settingsManager`
- [ ] 7.2 在 `SettingsView.swift` 中重构背景布局，使用 ZStack 实现动态毛玻璃效果
- [ ] 7.3 添加半透明背景色层，透明度根据 `settingsManager.settings.appearance.blurIntensity` 计算（公式：`1.0 - blurIntensity * 0.8`）
- [ ] 7.4 测试调整"Window Blur"滑块时，设置面板背景效果实时更新

## 8. 测试与验证

- [ ] 8.1 验证主题颜色切换时，主看板历史记录选中颜色立即更新
- [ ] 8.2 验证主题颜色切换时，设置页面滑块和开关颜色立即更新
- [ ] 8.3 验证主题颜色切换时，设置侧边栏选中项高亮颜色立即更新
- [ ] 8.4 验证毛玻璃程度调整时，设置面板背景效果实时更新
- [ ] 8.5 验证"恢复默认设置"确认对话框正常工作，取消和恢复按钮功能正确
- [ ] 8.6 验证"清空历史记录"确认对话框正常工作，取消和清空按钮功能正确
- [ ] 8.7 验证存储目录查看、在 Finder 中显示和更改功能正常工作
- [ ] 8.8 验证更改存储目录后应用重启提示正常
- [ ] 8.9 验证全局快捷键在 General 设置中正常显示和工作
- [ ] 8.10 验证包含旧 `themeMode` 字段的设置文件仍能正确加载
- [ ] 8.11 验证所有设置变更正确保存到文件并在重启后恢复
