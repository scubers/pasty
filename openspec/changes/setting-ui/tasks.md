## 1. 基础设施与设计系统 (Infrastructure & Design System)

- [ ] 1.1 创建 `DesignSystem` 模块，提取 `MainPanel` 和 `SettingsPanel` 共用的颜色、字体和材质 Token。
- [ ] 1.2 创建 `GlassPanel` 基础容器组件，封装 `VisualEffectView` 并应用全局材质。
- [ ] 1.3 实现 `PastyToggle` 自定义开关组件。
- [ ] 1.4 实现 `PastyPicker` 自定义下拉选择组件。
- [ ] 1.5 实现 `PastySlider` 自定义滑块组件。
- [ ] 1.6 实现 `DangerButton` 和通用按钮样式。

## 2. 窗口与布局框架 (Window & Layout Framework)

- [ ] 2.1 修改 `SettingsWindowController.swift`，配置 `fullSizeContentView` 和无标题栏样式。
- [ ] 2.2 实现 `SettingsSidebarView`，包含导航项列表和选中状态逻辑。
- [ ] 2.3 实现 `SettingsContentContainer`，处理页面切换动画和背景。
- [ ] 2.4 重构 `SettingsView.swift`，整合 Sidebar 和 Content 布局。

## 3. 页面功能实现 (Page Implementation)

- [ ] 3.1 实现 `GeneralSettingsView` (启动项、菜单栏图标)。
- [ ] 3.2 实现 `ClipboardSettingsView` (历史记录、性能、清除数据)。
- [ ] 3.3 实现 `AppearanceSettingsView` (主题选择卡片、模糊滑块)。
- [ ] 3.4 实现 `OCRSettingsView` (语言列表、置信度、模型选择)。
- [ ] 3.5 实现 `ShortcutsSettingsView` (快捷键录制、列表展示)。
- [ ] 3.6 实现 `AboutSettingsView` (Logo、版本、链接)。

## 4. 集成与验证 (Integration & Verification)

- [ ] 4.1 绑定所有页面 UI 控件到现有的 `SettingsManager` 或 UserDefaults。
- [ ] 4.2 验证窗口拖拽、关闭、最小化行为是否正常。
- [ ] 4.3 验证所有自定义控件的交互反馈（Hover, Click, Focus）。
- [ ] 4.4 执行全流程测试，确保所有设置项修改后生效。
