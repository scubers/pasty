# Settings Panel Blur

## Purpose
允许用户调整设置面板的毛玻璃背景模糊程度。

## ADDED Requirements

### Requirement: 设置面板背景应用毛玻璃效果
系统必须在设置面板背景中使用毛玻璃模糊效果。

#### Scenario: 设置面板显示毛玻璃背景
- **WHEN** 用户打开设置面板
- **THEN** 设置面板背景显示毛玻璃模糊效果
- **AND** 模糊效果使用系统默认的 hudWindow material

### Requirement: 用户可以调整毛玻璃模糊程度
系统必须在 Appearance 设置中提供滑块控件，允许用户调整设置面板的毛玻璃模糊程度。

#### Scenario: 调整毛玻璃模糊程度
- **WHEN** 用户在 Appearance 设置中调整"Window Blur"滑块
- **THEN** 滑块范围从 0 到 100
- **AND** 0 表示无模糊效果（显示纯背景色）
- **AND** 100 表示最大模糊效果（完全显示毛玻璃）

### Requirement: 毛玻璃模糊程度实时生效
系统必须在用户调整毛玻璃模糊程度时立即更新设置面板的视觉效果。

#### Scenario: 调整滑块后设置面板立即更新
- **WHEN** 用户调整"Window Blur"滑块到 50%
- **THEN** 设置面板背景的毛玻璃效果立即更新为中等模糊程度
- **AND** 无需重启应用

### Requirement: 毛玻璃模糊程度设置持久化
系统必须将用户设置的毛玻璃模糊程度保存到设置文件中，并在下次启动时恢复。

#### Scenario: 毛玻璃模糊程度持久化
- **WHEN** 用户设置"Window Blur"为 80%
- **THEN** 系统将 0.8 保存到设置文件的 appearance.blurIntensity 字段
- **WHEN** 用户重启应用并打开设置面板
- **THEN** 设置面板背景显示 80% 的毛玻璃模糊效果

### Requirement: 毛玻璃效果通过叠加半透明层控制
系统必须通过在毛玻璃效果上叠加半透明背景色层来控制视觉模糊强度。

#### Scenario: 叠加层透明度控制模糊效果
- **WHEN** 用户的 blurIntensity 设置为 0
- **THEN** 叠加层完全不透明（opacity = 1.0）
- **AND** 毛玻璃效果完全被遮挡，显示纯背景色

#### Scenario: 叠加层半透明显示模糊效果
- **WHEN** 用户的 blurIntensity 设置为 1.0
- **THEN** 叠加层几乎完全透明（opacity ≈ 0.2）
- **AND** 毛玻璃效果清晰可见

#### Scenario: 中等模糊程度
- **WHEN** 用户的 blurIntensity 设置为 0.5
- **THEN** 叠加层半透明（opacity ≈ 0.6）
- **AND** 毛玻璃效果中等程度可见
