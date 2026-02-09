## Context

当前应用使用基于侧边栏的设置界面，包含 General、Clipboard、Appearance、OCR、Shortcuts 和 About 六个部分。设置数据通过 `SettingsManager` 管理，序列化为 JSON 存储在用户应用支持目录中。

设计系统（`DesignSystem`）目前使用静态颜色定义，强调色硬编码为 Teal (#2DD4BF)。主看板（MainPanel）和设置页面使用独立的 UI 代码，但共享设计系统组件。

现有的 `SettingsDirectoryView.swift` 提供了存储目录更改功能，但未集成到主设置界面中。

## Goals / Non-Goals

**Goals:**
- 简化设置界面结构，移除不必要的选项
- 将主题颜色从静态硬编码改为动态配置
- 在多个位置一致地应用主题颜色
- 将毛玻璃程度设置动态应用到设置面板背景
- 为危险操作添加安全确认机制
- 集成存储目录管理到设置界面

**Non-Goals:**
- 不更改当前颜色方案或添加新的颜色选项
- 不修改设置文件的存储格式（仅移除不需要的字段）
- 不添加新的全局快捷键功能
- 不修改 Core 层的 API（除了移除不需要的 themeMode 相关调用）

## Decisions

### 1. 动态主题颜色实现方式

**Decision**: 将 `DesignSystem.Colors.accent` 改为基于 `@ObservedObject` 动态读取的扩展属性，而非静态属性

**Rationale**:
- Swift 静态属性无法响应 `@Published` 属性的变化
- 需要保持 `DesignSystem.Colors` 作为静态命名空间以支持现有调用模式
- 使用计算属性 + 环境对象（EnvironmentObject）方案比直接注入更符合 SwiftUI 最佳实践

**Alternative Considered**: 创建全局单例 `AccentColorManager`
- **Rejected**: 增加不必要的抽象层，与现有的 `SettingsManager` 重复

**Implementation**:
```swift
extension DesignSystem {
    struct Colors {
        // 静态 fallback，用于无法访问环境对象的上下文
        static let defaultAccent = Color(hex: "2DD4BF")

        // 动态读取需要通过 EnvironmentObject
        // 在需要动态颜色的 View 中使用：
        // @EnvironmentObject var settingsManager: SettingsManager
        // let accentColor = settingsManager.settings.appearance.themeColor.toColor()
    }
}

extension String {
    func toColor() -> Color {
        switch self {
        case "blue": return .blue
        case "purple": return .purple
        // ... 其他颜色映射
        default: return Color(hex: "2DD4BF") // system/teal
        }
    }
}
```

### 2. 主题模式移除策略

**Decision**: 从数据模型和 UI 中完全移除 `themeMode` 字段，更新 SettingsView 移除 `colorScheme` 绑定

**Rationale**:
- macOS 用户偏好深色模式，系统自动管理更符合平台惯例
- 减少设置选项复杂度
- 移除后简化 `SettingsView` 代码，无需监听主题模式变化

**Alternative Considered**: 保留 `themeMode` 但隐藏 UI 控件
- **Rejected**: 增加维护负担，隐藏的字段可能导致未来误用

**Implementation**:
- 从 `AppearanceSettings` 结构体移除 `themeMode` 属性
- 从 `AppearanceSettingsView.swift` 移除 Theme Mode section
- 从 `SettingsView.swift` 移除 `colorScheme` 计算属性和 `.preferredColorScheme()` 修饰符

### 3. 确认对话框 UI 模式

**Decision**: 使用 SwiftUI 原生 `.alert()` 修饰符实现确认对话框

**Rationale**:
- 符合 macOS 人机界面指南
- 零外部依赖，使用系统原生外观
- 实现简单，易于维护

**Alternative Considered**: 自定义 NSAlert sheet
- **Rejected**: 增加 AppKit/SwiftUI 混合的复杂度，原生 alert 已足够

**Implementation**:
```swift
// GeneralSettingsView
@State private var showingRestoreConfirm = false

SettingsRow(title: "Restore Default Settings", icon: "arrow.counterclockwise") {
    DangerButton(title: "Restore") {
        showingRestoreConfirm = true
    }
}
.alert("确认恢复默认设置？", isPresented: $showingRestoreConfirm) {
    Button("取消", role: .cancel) {}
    Button("恢复", role: .destructive) {
        settingsManager.settings = .default
        settingsManager.saveSettings()
    }
} message: {
    Text("此操作将重置所有设置为默认值，且无法撤销。")
}

// ClipboardSettingsView - 类似实现
```

### 4. 存储目录集成方式

**Decision**: 在 `GeneralSettingsView` 中内嵌 `SettingsDirectoryView` 的核心 UI，而非直接嵌入整个 View

**Rationale**:
- `SettingsDirectoryView` 使用 Form 布局，与现有设置页面的 ScrollView + SettingsSection 结构不匹配
- 重用现有的文件选择和验证逻辑，但适配到统一的视觉风格
- 保持代码职责分离（验证逻辑可以共享）

**Implementation**:
- 创建新的 `StorageLocationSettingsView.swift`，复用 `SettingsDirectoryView` 中的选择和迁移逻辑
- 使用 `SettingsSection` 和 `SettingsRow` 包装，保持视觉一致性
- 在 `GeneralSettingsView` 中添加新的 section：
```swift
SettingsSection(title: "Storage") {
    SettingsRow(title: "Data Location", icon: "folder") {
        Text(settingsManager.settingsDirectory.path)
            .font(.caption)
            .foregroundColor(DesignSystem.Colors.textSecondary)
            .textSelection(.enabled)
    }

    SettingsRow(title: "", icon: "") {
        HStack(spacing: 8) {
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: settingsManager.settingsDirectory.path)
            }
            Button("Change...") {
                // 复用选择逻辑
            }
        }
    }
}
```

### 5. 颜色应用策略

**Decision**: 通过传递计算属性而非直接引用 `DesignSystem.Colors.accent` 来应用动态颜色

**Rationale**:
- 避免在非 View 上下文（如 AppKit NSTableCellView）中访问环境对象
- 保持组件的可复用性和独立性
- 对于 AppKit 代码，使用 `NotificationCenter` 或闭包回调机制

**Implementation**:
- SwiftUI Views: 直接使用 `@EnvironmentObject var settingsManager`
- AppKit views: 使用 `Combine` 或通知监听设置变化，在 `configure` 方法中动态设置颜色

```swift
// MainPanelItemTableCellView 示例
private var cancellables = Set<AnyCancellable>()

func configure(item: ClipboardItemRow, selected: Bool, hovered: Bool, focused: Bool) {
    let themeColor = SettingsManager.shared.settings.appearance.themeColor.toColor()
    let nsColor = NSColor(themeColor)

    if selected {
        layer?.backgroundColor = nsColor.withAlphaComponent(0.12).cgColor
    }
    // ...
}

// 订阅设置变化以更新颜色
init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setupViews()
    subscribeToSettingsChanges()
}

private func subscribeToSettingsChanges() {
    SettingsManager.shared.$settings
        .map { $0.appearance.themeColor }
        .removeDuplicates()
        .sink { [weak self] _ in
            self?.needsDisplay = true
        }
        .store(in: &cancellables)
}
```

### 6. 设置面板毛玻璃程度应用

**Decision**: 在 `SettingsView` 中使用 `VisualEffectBlur` 组件，动态绑定 `blurIntensity` 设置值

**Rationale**:
- `VisualEffectBlur` 已经在主看板中使用，复用该组件保持一致性
- `blurIntensity` 已存在于 `AppearanceSettings` 中（0.0 - 1.0），直接应用无需新增数据模型
- SwiftUI 的 `material` 参数可以通过自定义实现或修改 `VisualEffectBlur` 支持动态模糊程度

**Alternative Considered**: 创建新的动态模糊组件
- **Rejected**: 增加 codebase 复杂度，现有 `VisualEffectBlur` 可扩展支持

**Implementation**:
```swift
// 在 SettingsView 中应用动态毛玻璃程度
// NSVisualEffectView 不直接支持动态模糊强度，通过叠加半透明背景色层模拟
ZStack {
    // 基础背景色
    DesignSystem.Colors.backgroundStart
        .ignoresSafeArea()

    // 毛玻璃效果
    VisualEffectBlur(
        material: .hudWindow,
        blendingMode: .behindWindow
    )

    // 半透明背景层控制模糊效果的"可见性"
    // blurIntensity: 1.0 = 完全模糊，0.0 = 无模糊
    DesignSystem.Colors.backgroundStart
        .opacity(1.0 - settingsManager.settings.appearance.blurIntensity * 0.8)
        .ignoresSafeArea()

    // 主内容
    // ... settings content
}
```

**Implementation Details**:
- `NSVisualEffectView` 的模糊程度由系统控制，无法直接调整
- 通过叠加半透明背景色层来控制模糊效果的视觉强度
- `blurIntensity` 越高，叠加层越透明，模糊效果越明显
- `blurIntensity` 为 0 时，叠加层完全遮挡模糊视图，显示纯背景色
```

## Risks / Trade-offs

### Risk 1: AppKit 代码中的动态颜色更新可能不及时

**Mitigation**: 使用 `Combine` 监听 `SettingsManager` 变化，在收到通知时调用 `needsDisplay()` 或重新配置视图

### Risk 2: 移除 themeMode 可能影响现有用户的设置迁移

**Mitigation**: 设置文件解码器继续接受 `themeMode` 字段但忽略其值，确保向后兼容性。版本号保持不变或仅小幅递增。

### Risk 3: 动态颜色计算可能影响性能

**Mitigation**: 颜色转换开销极小，且仅在设置变化时触发。使用缓存或懒加载进一步优化（仅在需要时转换）。

### Trade-off: 内联存储目录 UI 而非复用现有 View

**Trade-off**: 需要复制部分验证和迁移逻辑到新 View

**Mitigation**: 提取共享逻辑到独立的 helper class 或 extension，避免代码重复。

## Migration Plan

### 部署步骤

1. **Phase 1: 准备工作**
   - 提取 `SettingsDirectoryView` 的核心逻辑到共享的 `StorageLocationHelper`
   - 为 `DesignSystem.Colors` 添加颜色映射扩展

2. **Phase 2: 数据模型变更**
   - 从 `AppearanceSettings` 移除 `themeMode`
   - 更新 `AppearanceSettings` 的解码器，忽略 `themeMode` 字段

3. **Phase 3: UI 重构**
   - 更新 `AppearanceSettingsView` 移除 Theme Mode section
   - 更新 `ShortcutsSettingsView` 移除 In-App Shortcuts section
   - 更新 `GeneralSettingsView` 添加 Storage section 和 Global Shortcuts
   - 更新 `ClipboardSettingsView` 添加确认对话框

4. **Phase 4: 设计系统更新**
    - 修改 `DesignSystem.Colors` 添加颜色转换扩展
    - 更新 `PastySlider`、`PastyToggle` 使用动态颜色
    - 更新 `MainPanelItemTableCellView` 使用通知机制更新颜色
    - 更新 `SettingsSidebarView` 使用动态高亮颜色
    - 更新 `SettingsView` 应用动态毛玻璃程度到背景

5. **Phase 5: 清理**
   - 从 `SettingsView` 移除 `colorScheme` 逻辑
   - 删除不再使用的 `ThemePicker` 组件

### 回滚策略

- 所有变更通过 Git 管理，可随时回滚
- 设置文件向后兼容，回滚后用户数据不受影响
- 不涉及 Core 层 API 变更，无需回滚依赖该层的其他组件

## Open Questions

1. **Q**: 是否需要在清空历史记录时显示进度指示器？
   - **Status**: 不在本次变更范围内，待后续优化

2. **Q**: 存储目录迁移失败时是否提供保留旧数据的选项？
   - **Status**: 现有实现已处理此场景（失败提示用户，不修改目录），本次集成时保持该行为

3. **Q**: 动态颜色是否需要支持系统外观变化（Light/Dark）？
   - **Status**: 本次仅修改强调色，不涉及系统外观适配。如需支持可后续扩展。

4. **Q**: 是否需要为存储目录添加校验和检查，确保迁移成功？
   - **Status**: 现有验证逻辑（可写性测试）已足够，本次保持不变

5. **Q**: 设置面板毛玻璃效果是否需要与主看板使用相同的实现方式？
   - **Status**: 使用相同的 `VisualEffectBlur` 组件，通过叠加层控制效果强度
