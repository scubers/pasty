## 1. Core 层设置 API

- [ ] 1.1 创建 `core/include/pasty/settings/settings_api.h` - 定义 C API 接口
- [ ] 1.2 创建 `core/src/settings/settings_api.cpp` - 实现 C API
- [ ] 1.3 实现 `pasty_settings_initialize()` - 初始化 Core 层设置
- [ ] 1.4 实现 `pasty_settings_update()` - 更新 Core 层设置
- [ ] 1.5 添加单元测试 `core/tests/settings_api_test.cpp`
- [ ] 1.6 修改 `core/CMakeLists.txt` 包含新模块
- [ ] 1.7 运行 `./scripts/core-build.sh` 验证编译

## 2. Core 层历史记录使用设置

- [ ] 2.1 修改 `history.cpp` 使用 `maxHistoryCount` 配置值
- [ ] 2.2 实现动态更新历史记录限制（设置变更时触发 retention）
- [ ] 2.3 添加相关单元测试
- [ ] 2.4 验证 `./scripts/core-build.sh` 编译通过

## 3. Platform 层设置管理器

- [ ] 3.1 创建 `platform/macos/Sources/Settings/SettingsManager.swift`
- [ ] 3.2 实现设置目录路径管理（UserDefaults 存路径）
- [ ] 3.3 实现 settings.json 读取/写入
- [ ] 3.4 实现版本检测和迁移逻辑
- [ ] 3.5 实现文件系统监视（外部变更检测）
- [ ] 3.6 实现原子写入（临时文件+重命名）
- [ ] 3.7 添加错误处理（损坏文件恢复）

## 4. 设置目录功能

- [ ] 4.1 创建 `platform/macos/Sources/Settings/SettingsDirectoryView.swift`
- [ ] 4.2 实现显示当前设置目录路径
- [ ] 4.3 实现"更改目录"按钮和文件选择器
- [ ] 4.4 实现目录迁移（复制数据，保留原数据）
- [ ] 4.5 实现"在 Finder 中打开"功能
- [ ] 4.6 实现目录验证（可读写检查）
- [ ] 4.7 实现更改后提示重启

## 5. 剪贴板设置

- [ ] 5.1 创建 `platform/macos/Sources/Settings/ClipboardSettingsView.swift`
- [ ] 5.2 实现轮询周期滑块（100ms - 2000ms）
- [ ] 5.3 实现最大内容大小输入（1KB - 100MB）
- [ ] 5.4 实现最大历史记录输入（50 - 5000）
- [ ] 5.5 添加输入验证和错误提示
- [ ] 5.6 修改 `ClipboardWatcher.swift` 读取轮询周期设置
- [ ] 5.7 修改 `ClipboardWatcher.swift` 读取最大内容大小设置
- [ ] 5.8 实现设置变更实时生效（轮询周期）

## 6. OCR 设置

- [ ] 6.1 创建 `platform/macos/Sources/Settings/OCRSettingsView.swift`
- [ ] 6.2 实现 OCR 启用/禁用开关
- [ ] 6.3 实现语言多选（zh-Hans, zh-Hant, en, ko, ja）
- [ ] 6.4 实现置信度阈值滑块（0.1 - 1.0）
- [ ] 6.5 实现识别级别选择（Fast/Accurate）
- [ ] 6.6 实现"搜索时包含 OCR 结果"开关
- [ ] 6.7 修改 `OCRService.swift` 读取所有 OCR 设置
- [ ] 6.8 实现设置变更实时生效

## 7. 外观设置

- [ ] 7.1 创建 `platform/macos/Sources/Settings/AppearanceSettingsView.swift`
- [ ] 7.2 实现主题色选择器（System + 7 种颜色）
- [ ] 7.3 实现背景模糊程度滑块（0% - 100%）
- [ ] 7.4 实现面板尺寸设置（宽度/高度）
- [ ] 7.5 修改 `MainPanelTokens.swift` 使用动态主题色
- [ ] 7.6 修改 `MainPanelView.swift` 使用模糊设置
- [ ] 7.7 修改 `MainPanelWindowController.swift` 使用面板尺寸设置
- [ ] 7.8 实现设置变更实时生效

## 8. 通用设置

- [ ] 8.1 创建 `platform/macos/Sources/Settings/GeneralSettingsView.swift`
- [ ] 8.2 实现"启动时运行"开关
- [ ] 8.3 集成 SMAppService API（注册/注销）
- [ ] 8.4 实现授权请求（用户开启时请求）
- [ ] 8.5 实现全局快捷键配置
- [ ] 8.6 实现"恢复默认"按钮
- [ ] 8.7 修改 `HotkeyService.swift` 支持动态更新快捷键
- [ ] 8.8 实现"重置所有设置"功能

## 9. 设置面板 UI 框架

- [ ] 9.1 创建 `platform/macos/Sources/Settings/SettingsView.swift`
- [ ] 9.2 实现左侧分组导航栏
- [ ] 9.3 实现右侧设置内容区域
- [ ] 9.4 实现分组切换逻辑
- [ ] 9.5 实现选中分组高亮
- [ ] 9.6 创建 `SettingsWindowController.swift`
- [ ] 9.7 实现单例窗口逻辑
- [ ] 9.8 实现关闭窗口销毁逻辑

## 10. 菜单栏集成

- [ ] 10.1 修改 `App.swift` 添加"偏好设置..."菜单项
- [ ] 10.2 实现 ⌘, 快捷键打开设置
- [ ] 10.3 确保菜单栏入口正常工作
- [ ] 10.4 测试窗口单例行为

## 11. 数据迁移和初始化

- [ ] 11.1 实现首次启动默认设置初始化
- [ ] 11.2 实现从旧版本数据迁移
- [ ] 11.3 实现设置目录自动创建
- [ ] 11.4 实现数据库和图片目录迁移
- [ ] 11.5 测试首次启动流程

## 12. 测试和验证

- [ ] 12.1 运行 `./scripts/core-build.sh` 验证 Core 编译
- [ ] 12.2 运行 `./scripts/platform-build-macos.sh Debug` 验证 macOS 编译
- [ ] 12.3 测试所有设置项的读写
- [ ] 12.4 测试设置变更实时生效
- [ ] 12.5 测试设置目录更改流程
- [ ] 12.6 测试设置文件版本升级
- [ ] 12.7 测试设置文件损坏恢复
- [ ] 12.8 测试云同步场景（手动复制设置目录）
