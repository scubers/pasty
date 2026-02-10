## 背景与现状

Pasty 当前存在多处硬编码配置，分散在各个模块中：

| 配置项 | 当前值 | 位置 | 生效层级 |
|--------|--------|------|----------|
| 剪贴板轮询间隔 | 0.4s | `ClipboardWatcher.start(interval: 0.4)` | Platform |
| 最大内容大小 | 10MB | `ClipboardWatcher.maxPayloadBytes` | Platform |
| 最大历史记录 | 1000条 | `history.cpp enforceRetention(1000)` | Core |
| OCR 识别语言 | 7种语言 | `OCRService.performOCR()` 硬编码 | Platform |
| OCR 置信度阈值 | 0.7 | `OCRService` 硬编码 | Platform |
| 面板尺寸 | 800×500 | `MainPanelWindowController` 初始化 | Platform |
| 快捷键 | ⌘⇧V | `HotkeyService` 默认值 | Platform |

**分层说明**：
- **Core 层设置**：影响业务逻辑（如最大历史数量）
- **Platform 层设置**：影响平台特定行为（如轮询间隔、OCR 参数、UI 外观）

所有设置统一由 Platform 层管理存储，通过 C API 将 Core 层需要的设置同步到 Core。

## 约束条件

- **架构约束**：必须遵循 C++ Core + Platform Shell 架构
- **跨平台约束**：Core 层代码必须是纯 C++17，禁止平台头文件
- **依赖方向**：Platform → Core（单向依赖）
- **测试约束**：Core 层必须可独立测试，不依赖 OS
- **无新依赖**：不使用新的第三方库
- **云同步友好**：设置使用 JSON 文件存储，便于用户通过云盘同步

## 目标

1. **统一配置管理**：Platform 层统一管理所有设置，Core 层通过 C API 获取所需设置
2. **云同步支持**：设置以 JSON 文件形式存储在用户指定目录，支持云盘同步
3. **实时生效**：设置变更尽可能实时生效，无需重启
4. **合理默认值**：首次启动提供开箱即用的配置
5. **向后兼容**：升级后现有用户数据不受影响

## 非目标

- 不实现云端同步功能（但支持用户自行使用云盘同步设置目录）
- 不支持多配置文件切换
- 不实现设置导入/导出（设置文件本身可手动复制）
- **不实现应用黑名单（本期不做）**

## 决策 1：设置目录结构

**选择**：引入"设置目录"概念，用户可自定义配置存储位置

**存储策略**：

| 设置项 | 存储位置 | 说明 |
|--------|----------|------|
| **设置目录路径** | UserDefaults | 唯一存 UserDefaults 的项，用于找到设置目录 |
| **其他所有设置** | `{设置目录}/settings.json` | 以 JSON 文件存储，便于云同步 |
| **历史数据库** | `{设置目录}/history.sqlite3` | 原有数据库移至设置目录 |
| **图片资源** | `{设置目录}/images/` | 原有图片目录移至设置目录 |

**默认设置目录**：
- macOS: `~/Library/Application Support/Pasty/`

**架构图**：

```
┌─────────────────────────────────────────────────────────────────┐
│                        Platform 层（macOS）                      │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    SettingsManager                        │   │
│  │                   （设置统一管理）                         │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  职责：                                                    │   │
│  │  • 管理设置目录路径（存 UserDefaults）                      │   │
│  │  • 读写 settings.json                                      │   │
│  │  • 通知各模块设置变更                                       │   │
│  │  • 通过 C API 同步 Core 层设置                              │   │
│  └────────────┬────────────────────────────────────────────┘   │
│               │                                                  │
│     ┌─────────┼─────────┬──────────────┬──────────────┐         │
│     │         │         │              │              │         │
│     ▼         ▼         ▼              ▼              ▼         │
│ ┌────────┐ ┌────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│ │Clipboa │ │  OCR   │ │  Hotkey  │ │   UI     │ │   Core   │  │
│ │Watcher │ │Service │ │ Service  │ │ Settings │ │  (C API) │  │
│ └────────┘ └────────┘ └──────────┘ └──────────┘ └──────────┘  │
└─────────────────────────────────────────────────────────────────┘
                               │
                               │ C API
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Core 层（C++）                            │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Settings Store（内存缓存）                    │   │
│  │         仅存储 Core 层业务逻辑需要的设置                   │   │
│  │              （如 maxHistoryCount）                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    使用设置的模块                         │   │
│  │              • History Store（最大历史数量）               │   │
│  │              • ...                                        │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

**设置目录变更流程**：
1. 用户选择新目录
2. 将当前设置、数据库、图片**复制**到新目录（**保留原目录数据**）
3. 验证新目录可读写
4. 更新 UserDefaults 中的目录路径
5. 重启应用（必须，因为数据库路径变更）
6. 应用重启后从新的设置目录加载

## 决策 2：持久化方案（JSON 文件）

**选择**：使用 JSON 文件存储设置，而非 UserDefaults

**理由**：
- JSON 文件便于用户通过云盘（iCloud Drive、Dropbox 等）同步设置
- 用户可手动编辑配置文件
- 跨平台迁移时只需复制文件
- 符合"设置目录"整体云同步的理念

**文件格式示例**：
```json
{
  "version": 1,
  "clipboard": {
    "pollingIntervalMs": 400,
    "maxContentSizeBytes": 10485760
  },
  "history": {
    "maxCount": 1000
  },
  "ocr": {
    "enabled": true,
    "languages": ["zh-Hans", "en"],
    "confidenceThreshold": 0.7,
    "recognitionLevel": "accurate",
    "includeInSearch": true
  },
  "appearance": {
    "themeColor": "system",
    "blurIntensity": 0.9
  },
  "general": {
    "launchAtLogin": false,
    "shortcut": "cmd+shift+v"
  }
}
```

**备选方案**：UserDefaults
- **拒绝原因**：不易于用户手动备份和云同步

## 决策 3：设置分层管理

**核心原则**：所有设置由 Platform 层统一管理，Core 层只获取自己需要的

| 设置类别 | 所属层级 | 说明 |
|----------|----------|------|
| 剪贴板轮询间隔 | Platform | 纯 macOS 行为 |
| 最大内容大小 | Platform | ClipboardWatcher 在 Platform 层过滤 |
| 最大历史数量 | Core | 影响 History Store 业务逻辑 |
| OCR 参数 | Platform | OCRService 在 Platform 层实现 |
| 外观/快捷键 | Platform | 纯 UI 行为 |
| 启动时运行 | Platform | 纯系统集成 |

**Core 层设置同步**：
- Platform 层启动时读取 settings.json
- 将 Core 需要的设置通过 C API 传递给 Core
- Core 层缓存在内存中，供业务逻辑使用
- 设置变更时，Platform 层通过 C API 更新 Core

**C API 设计**：
```cpp
// 初始化时传递 Core 层需要的设置
void pasty_settings_initialize(
    int maxHistoryCount,
    // ... 其他 Core 层设置
);

// 设置变更时更新
void pasty_settings_update(
    const char* key,
    const char* jsonValue
);
```

## 决策 4：设置变更生效时机

**分类处理**：

| 设置类型 | 生效时机 | 示例 |
|----------|----------|------|
| 即时生效 | 保存后立即 | 轮询间隔、外观主题、OCR开关 |
| 下次生效 | 下一次操作时 | 最大历史数量（清理在下次写入时触发） |
| 需重启 | 应用重启后 | 设置目录路径（数据库位置变更） |

## 决策 5：启动时运行实现

**选择**：使用 SMAppService（macOS 13+ 现代方式）

**实现要点**：
- 使用 `SMAppService.mainApp.register()` API
- 在通用设置中提供开关
- **用户在设置中开启"启动时运行"时才请求授权**，应用启动时不主动请求
- 用户关闭设置时自动注销

**备选方案**：LaunchAgent
- **拒绝原因**：SMAppService 是 Apple 推荐的新方式

## [风险] 设置目录不可访问

**缓解措施**：
- 启动时验证设置目录可读写
- 如不可访问，回退到默认目录
- 向用户显示警告通知

## [风险] 设置文件损坏

**缓解措施**：
- 写入时先写临时文件，再原子重命名
- 读取失败时自动重置为默认值
- 保留损坏文件备份（`settings.json.corrupted`）

## [风险] 多设备同步冲突

**缓解措施**：
- 使用文件系统通知监视设置文件变更
- 检测到外部变更时重新加载
- 冲突时以最后写入为准（简单策略）

## 决策 6：设置文件版本升级

**选择**：在 settings.json 中包含版本号，支持平滑升级

**升级策略**：
```
读取 settings.json
    │
    ▼
检查 version 字段
    │
    ├── 版本匹配 ──▶ 正常使用
    │
    └── 版本较低 ──▶ 执行迁移
                         │
                         ▼
                    按新增设置补充默认值
                         │
                         ▼
                    写入新版本 settings.json
```

**版本号管理**：
- settings.json 中 `"version": 1` 表示当前版本
- 后续新增设置项时递增版本号
- Platform 层启动时检查版本，自动执行迁移

**向后兼容**：
- 新版本应用读取旧版本设置时，缺失字段使用默认值
- 旧版本应用读取新版本设置时，忽略不识别的字段

## 迁移计划

**Phase 1 - Core 层设置支持**（1-2 天）
- 添加 C API 接收 Core 层设置
- 修改 History Store 使用配置值
- 单元测试

**Phase 2 - Platform 层设置管理**（2-3 天）
- 实现 SettingsManager（统一管理）
- 实现 JSON 文件读写
- 实现设置目录管理
- 迁移现有数据到设置目录

**Phase 3 - 集成现有模块**（2 天）
- 修改 ClipboardWatcher 读取设置
- 修改 OCRService 读取设置
- 修改 UI 组件读取外观设置

**Phase 4 - UI 开发**（2-3 天）
- 创建设置目录选择界面
- 创建各分类设置页面
- 菜单栏添加入口
- 实现 ⌘+, 快捷键

**Phase 5 - 测试验收**（1-2 天）
- 编译验证
- 设置云同步测试
- 功能测试

## 文件结构变更

```
core/
├── include/pasty/settings/
│   └── settings_api.h       # C API：接收 Core 层设置
├── src/settings/
│   └── settings_api.cpp     # C API 实现
└── tests/settings_test.cpp  # 单元测试

platform/macos/Sources/
├── Settings/                    # 新增目录
│   ├── SettingsManager.swift         # 统一管理设置目录和 JSON
│   ├── SettingsView.swift            # 设置主视图
│   ├── SettingsWindowController.swift
│   ├── GeneralSettingsView.swift     # 通用（启动时运行、快捷键）
│   ├── ClipboardSettingsView.swift   # 剪贴板（轮询、大小限制）
│   ├── OCRSettingsView.swift         # OCR 相关
│   ├── AppearanceSettingsView.swift  # 外观主题
│   └── SettingsDirectoryView.swift   # 设置目录选择
├── App.swift                    # 修改：添加设置入口
├── ClipboardWatcher.swift       # 修改：读取设置
├── OCRService.swift            # 修改：读取设置
└── AppPaths.swift              # 修改：支持自定义设置目录
```

## 决策 7：设置面板窗口行为

**选择**：单例窗口，关闭时销毁，重新打开时重新创建

**行为定义**：
- 同一时间只能打开一个设置窗口
- 用户关闭窗口时（点击红色关闭按钮或按 Esc）完全销毁窗口
- 用户再次打开设置（菜单栏或 ⌘+,）时重新创建窗口
- 不保持窗口状态，每次重新初始化

**理由**：
- 实现简单，无需管理窗口隐藏/显示状态
- 内存友好，不使用时立即释放资源
- 每次打开都从磁盘读取最新设置，避免状态同步问题

## 待解决问题

无（所有问题已解决）

---

**设计确认后，将进入 Spec 阶段，详细定义每个设置项的行为规范。**
