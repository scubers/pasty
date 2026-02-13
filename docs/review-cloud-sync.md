# 云同步代码 Review 报告

> Review Date: 2026-02-13
> Reviewer: AI Assistant
> Files Reviewed: `core/src/infrastructure/sync/*.cpp/.h`, `core/src/runtime/core_runtime.cpp`

---

## 一、整体架构梳理

```
┌─────────────────────────────────────────────────────────────────────┐
│                           CoreRuntime                                │
│  (协调者：管理配置、导入/导出触发、E2EE密钥管理)                          │
└───────────┬─────────────────────────────┬───────────────────────────┘
            │                             │
            ▼                             ▼
┌───────────────────────┐     ┌───────────────────────┐
│  CloudDriveSyncExporter│     │  CloudDriveSyncImporter│
│  (导出本地变更)          │     │  (导入远程变更)          │
│  - exportTextItem      │     │  - importChanges       │
│  - exportImageItem     │     │  - 确定性合并排序        │
│  - exportDeleteTombstone│    │  - Tombstone 防复活     │
└───────────┬───────────┘     └───────────┬───────────┘
            │                             │
            └──────────────┬──────────────┘
                           ▼
            ┌───────────────────────────────┐
            │    CloudDriveSyncState        │
            │    (本地状态持久化)             │
            │    - device_id, next_seq      │
            │    - remoteDevices (max_seq)  │
            │    - fileCursors (offset)     │
            │    - tombstones               │
            └───────────────────────────────┘
                           │
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
┌─────────────────┐ ┌───────────────┐ ┌───────────────────┐
│ ProtocolInfo    │ │ Pruner        │ │ 加密管理器         │
│ (E2EE配置)       │ │ (定期清理)     │ │ EncryptionManager │
└─────────────────┘ └───────────────┘ └───────────────────┘
```

### 核心组件职责

| 组件 | 文件 | 职责 |
|------|------|------|
| `CoreRuntime` | `core_runtime.cpp` | 协调者，管理配置、触发导入导出、E2EE密钥生命周期 |
| `CloudDriveSyncExporter` | `cloud_drive_sync_exporter.cpp` | 导出本地剪贴板变更到 JSONL 日志 |
| `CloudDriveSyncImporter` | `cloud_drive_sync_importer.cpp` | 导入远程变更，确定性合并，tombstone 检查 |
| `CloudDriveSyncState` | `cloud_drive_sync_state.cpp` | 本地状态持久化 (device_id, seq, cursors, tombstones) |
| `CloudDriveSyncPruner` | `cloud_drive_sync_pruner.cpp` | 定期清理旧日志和未引用资产 |
| `CloudDriveSyncProtocolInfo` | `cloud_drive_sync_protocol_info.cpp` | E2EE 协议配置 (KDF 参数、salt) |

### 数据流

| 操作 | 数据流 |
|------|--------|
| **导出** | 本地剪贴板 → `ClipboardService.ingest` → `CoreRuntime.export*` → `Exporter.writeJsonl` → `sync_root/logs/<device_id>/` |
| **导入** | `sync_root/logs/<remote_id>/` → `Importer.importChanges` → 确定性排序 → `ClipboardService.ingest` |
| **清理** | `Pruner.prune` → 删除旧日志 → 清理未引用资产 |

---

## 二、已正确实现的边界情况 ✅

| 边界情况 | 实现位置 | 说明 |
|----------|----------|------|
| **循环防护** | `Exporter:257`, `Importer:149` | `sourceAppId` 以 `pasty-sync:` 前缀跳过，防止无限循环 |
| **图片大小限制** | `Exporter:124`, `347` | 25 MiB 超限跳过，记录错误 |
| **事件行大小限制** | `Exporter:125`, `224` | 1 MiB 超限跳过，防止 JSON 过大 |
| **日志轮转** | `Exporter:126`, `165` | 10 MiB 触发轮转到 `events-NNNN.jsonl` |
| **原子写入** | `Exporter:194`, `State:180` | temp + rename 模式，防止写入中断导致损坏 |
| **Tombstone 防复活** | `State:355`, `Importer:588` | 删除事件记录 tombstone，阻止旧 upsert 复活内容 |
| **确定性合并** | `Importer:123`, `204` | 按 `(ts_ms, device_id, seq)` 排序，保证跨设备一致性 |
| **Offset 恢复** | `Importer:287` | offset > EOF 时重置为0，容错文件截断 |
| **JSON 错误处理** | `Importer:359` | 解析失败跳过，继续处理后续行 |
| **E2EE 加密** | `Exporter:289`, `Importer:413` | 文本/图片都支持端到端加密 |
| **Schema 版本检查** | `Importer:377` | 非 v1 schema 跳过，forward compatibility |
| **文件游标持久化** | `State:326` | 记录每个文件的读取位置，支持增量导入 |
| **状态损坏恢复** | `State:77` | 损坏文件备份为 `.corrupted.<timestamp>` 并重建 |
| **加密密钥清理** | `Exporter:80`, `Importer:127` | 使用 `sodium_memzero` 清理敏感数据 |

---

## 三、缺失或未完全实现的边界情况 ⚠️

### 1. **`is_concealed` / `includeSensitive` 未实现** 🔴 高优先级

**代码位置**:
```cpp
// cloud_drive_sync_exporter.cpp:286-287
json["is_concealed"] = false;  // 硬编码为 false
json["is_transient"] = false;  // 硬编码为 false
```

**问题**:
- `CoreRuntimeConfig.cloudSyncIncludeSensitive` 配置项存在但**从未使用**
- `ClipboardHistoryItem` 可能有 `isConcealed` 属性，但导出时未检查
- 敏感内容（如密码管理器复制的内容）可能被错误同步到云端

**建议修复**:
```cpp
// 在 exportTextItem/exportImageItem 开头添加检查
if (item.isConcealed && !m_includeSensitive) {
    PASTY_LOG_DEBUG("Core.SyncExporter", "Skipping concealed content");
    return ExportResult::SkippedConcealedContent;
}
```

**需要修改的文件**:
- `cloud_drive_sync_exporter.h`: 添加 `m_includeSensitive` 成员
- `cloud_drive_sync_exporter.cpp`: 构造函数接收配置，导出时检查
- `core_runtime.cpp`: 传递 `cloudSyncIncludeSensitive` 给 Exporter

---

### 2. **冲突副本文件未处理** 🟡 中优先级

**协议文档** (`cloud-drive-sync-protocol.md:528-532`) 提到:
> Detection: Filename contains "conflict", "copy", or timestamp suffix
> Treat as additional log file (read and parse)

**代码位置**: `cloud_drive_sync_importer.cpp:248-271`

**问题**: `enumerateJsonlFiles` 只检查 `.jsonl` 扩展名，没有过滤或特殊处理冲突文件

**当前代码**:
```cpp
// cloud_drive_sync_importer.cpp:263
if (filename.size() >= 6 && filename.substr(filename.size() - 6) == ".jsonl") {
    files.push_back(entry.path().string());
}
```

**建议修复**:
```cpp
// 方案 A: 跳过冲突文件（保守）
if (filename.find("(conflicted copy") != std::string::npos ||
    filename.find("-conflict-") != std::string::npos) {
    PASTY_LOG_WARN("Core.SyncImporter", "Skipping conflict file: %s", filename.c_str());
    continue;
}

// 方案 B: 处理冲突文件（按协议文档）
// 按文件名排序时，优先处理原始文件
```

---

### 3. **设备 ID 冲突无检测** 🟡 中优先级

**代码位置**: `cloud_drive_sync_state.cpp:68-71`

**问题**: 
- 如果两个设备意外共享相同的 `device_id`（如复制配置文件），会导致事件序列号冲突
- 事件 ID 将冲突，可能导致数据混乱

**当前代码**:
```cpp
std::string CloudDriveSyncState::generateDeviceId() {
    const auto bytes = generateRandomBytes(DEVICE_ID_BYTES);
    return hexEncode(bytes);  // 纯随机，无碰撞检测
}
```

**建议修复**:
```cpp
// 在首次同步或导入时检测
bool CloudDriveSyncExporter::detectDeviceIdConflict() {
    const std::string myDevicePath = m_deviceLogsPath;
    // 检查是否有非本设备写入的事件
    // 如果事件的 sourceAppId 不是 pasty-sync:<my_device> 但在同目录
    // 说明有冲突
}
```

---

### 4. **Tombstone 过期后的复活风险** 🟡 中优先级

**代码位置**: `cloud_drive_sync_state.cpp:396-403`

**问题**:
```cpp
// GC 删除过期 tombstone
auto it = std::remove_if(m_tombstones.begin(), m_tombstones.end(), 
    [cutoffMs](const Tombstone& t) {
        return t.ts_ms < cutoffMs;  // 删除旧于保留期的 tombstone
    });
```

如果 tombstone 被清理后，一个**延迟到达**的旧 upsert 事件（如离线设备同步）可能导致内容复活。

**风险评估**:
- 保留期默认 180 天，风险较低
- 但如果用户长期离线后恢复，可能出现

**建议修复**:
```cpp
// 方案 A: 延长 tombstone 保留期（简单）
// 将 tombstone 保留期设为 retentionMs * 2

// 方案 B: 保留永久 tombstone 索引（内存优化）
// 只保留 (item_type, content_hash) 哈希集合，不保留完整信息
std::set<std::pair<std::string, std::string>> m_permanentTombstoneKeys;
```

---

### 5. **Delete 操作无 E2EE 加密** 🟢 低优先级

**代码位置**: `cloud_drive_sync_exporter.cpp:469-499`

**问题**: Delete tombstone 事件没有加密逻辑，元数据明文暴露

**影响分析**:
- Delete 只包含 `item_type` + `content_hash`
- `content_hash` 是 64-bit FNV-1a，不可逆
- 暴露的是"删除了某个文本/图片"这一事实

**风险**: 低（无法知道具体内容，只能观察到删除行为）

**建议**: 可选地在 E2EE 模式下也加密 delete 事件

---

### 6. **`is_transient` 未实现** 🟢 低优先级

**问题**: 始终设置为 `false`，无法标记临时内容

**使用场景**:
- 密码管理器复制的密码（应标记为 transient，不同步）
- 一次性验证码

**建议**:
```cpp
// 在 ClipboardHistoryItem 中添加 isTransient 字段
// 或基于 sourceAppId 规则判断
bool isTransient = isTransientApp(item.sourceAppId);
```

---

### 7. **同步频率硬编码** 🟡 中优先级

**代码位置**: `core_runtime.cpp:251`

```cpp
constexpr std::int64_t kPruneIntervalMs = 24LL * 60 * 60 * 1000;  // 24小时
```

**问题**: 
- 轮询间隔没有配置项
- 平台层无法根据网络状况调整（如 WiFi vs 蜂窝）

**建议**: 添加配置项，见下文配置建议

---

### 8. **网络错误无重试机制** 🟡 中优先级

**问题**: 文件读写失败后直接返回错误，没有重试或退避策略

**场景**:
- 云盘同步进行中，文件被锁定
- 网络临时中断

**建议**:
```cpp
// 在 CoreRuntime 添加重试逻辑
struct SyncRetryPolicy {
    int maxRetries = 3;
    int baseDelayMs = 1000;
    float backoffMultiplier = 2.0f;
};
```

---

### 9. **event_id 前缀一致性检查缺失** 🟢 低优先级

**协议要求**: `event_id` 的 `<device_id>` 前缀必须等于 `device_id` 字段

**当前代码**: Importer 只检查 `event.deviceId != remoteDeviceId`（目录名），未检查 event_id 前缀

**建议**:
```cpp
// cloud_drive_sync_importer.cpp parseEvent 中添加
const std::string expectedPrefix = event.deviceId + ":";
if (event.eventId.compare(0, expectedPrefix.size(), expectedPrefix) != 0) {
    PASTY_LOG_WARN("Core.SyncImporter", "event_id prefix mismatch");
    return false;
}
```

---

## 四、可配置项建议 📋

### 当前配置（已有）

| 配置项 | 位置 | 当前值 | 是否生效 |
|--------|------|--------|----------|
| `cloudSyncEnabled` | `CoreRuntimeConfig` | `false` | ✅ |
| `cloudSyncRootPath` | `CoreRuntimeConfig` | 空 | ✅ |
| `cloudSyncIncludeSensitive` | `CoreRuntimeConfig` | `false` | ❌ 未使用 |

### 建议新增配置

| 配置项 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `syncPollingIntervalMs` | `int` | 10000 | 轮询间隔（毫秒），范围 5000-60000 |
| `retentionDays` | `int` | 180 | 事件保留天数 |
| `maxEventsPerDevice` | `int` | 5000 | 每设备最大事件数 |
| `maxImageSizeMB` | `int` | 25 | 最大图片大小（MB） |
| `maxTextSizeKB` | `int` | 1024 | 最大文本大小（KB） |
| `syncMode` | `enum` | `auto` | `auto` / `manual` / `wifiOnly` |
| `excludeAppIds` | `string[]` | `[]` | 不同步的应用 ID 列表 |
| `pruneIntervalHours` | `int` | 24 | 清理间隔（小时） |
| `e2eeEnabled` | `bool` | `false` | 是否启用 E2EE |

### 建议的配置结构

```cpp
struct CloudSyncConfig {
    // === 基础配置 ===
    bool enabled = false;
    std::string rootPath;
    
    // === 内容过滤 ===
    bool includeSensitive = false;
    std::vector<std::string> excludeAppIds;
    
    // === 大小限制 ===
    int maxImageSizeMB = 25;
    int maxTextSizeKB = 1024;
    
    // === 保留策略 ===
    int retentionDays = 180;
    int maxEventsPerDevice = 5000;
    
    // === 同步行为 ===
    int pollingIntervalMs = 10000;       // 10秒
    int pruneIntervalHours = 24;         // 24小时
    
    // === 网络限制 ===
    enum class SyncMode { Auto, Manual, WifiOnly };
    SyncMode syncMode = SyncMode::Auto;
    
    // === 安全 ===
    bool e2eeEnabled = false;
};
```

### 配置优先级建议

| 优先级 | 配置项 | 理由 |
|--------|--------|------|
| P0 | `includeSensitive` | 已存在但未生效，需要立即修复 |
| P1 | `pollingIntervalMs` | 用户体验，影响电池/流量 |
| P1 | `syncMode` | 用户控制同步时机 |
| P2 | `retentionDays` | 存储空间管理 |
| P2 | `excludeAppIds` | 隐私控制 |
| P3 | `maxImageSizeMB` | 高级调优 |

---

## 五、代码质量观察

### 优点 👍

1. **架构清晰**: Exporter/Importer/State/Pruner 职责分明，依赖方向正确
2. **错误处理健壮**: JSON 解析失败、文件错误等都优雅跳过，不崩溃
3. **协议设计良好**: 
   - 确定性合并保证跨设备一致性
   - Tombstone 防复活机制完善
   - Forward compatibility 考虑周全
4. **安全意识强**: 
   - E2EE 加密实现正确
   - 敏感数据清理 (`sodium_memzero`)
   - 密钥生命周期管理
5. **测试覆盖**: 有 E2EE、tombstone、offset 恢复等核心功能测试

### 改进建议 💡

| 问题 | 位置 | 建议 |
|------|------|------|
| 日志级别不一致 | 多处 `PASTY_LOG_ERROR` | 非关键失败改为 `WARN` |
| 常量重复定义 | `kLoopPrefix` 在 Exporter/Importer 重复 | 提取到公共头文件 |
| 接口命名不一致 | `SettingsStore.isSyncEnabled()` vs `CoreRuntime.cloudSyncEnabled` | 统一命名规范 |
| 硬编码常量 | `kMaxImageBytes = 26214400` | 考虑可配置化 |
| 缺少单元测试 | `CloudDriveSyncState` | 添加状态操作单元测试 |

---

## 六、行动项总结

### P0 - 立即修复

| 项目 | 工作量 | 文件 |
|------|--------|------|
| 实现 `includeSensitive` 配置 | 2h | `exporter.cpp`, `core_runtime.cpp` |

### P1 - 短期优化

| 项目 | 工作量 | 文件 |
|------|--------|------|
| 添加 `pollingIntervalMs` 配置 | 1h | `core_runtime.h`, `core_runtime.cpp` |
| 添加 `syncMode` 配置 | 2h | 新增枚举，API 扩展 |
| 冲突文件处理 | 2h | `importer.cpp` |

### P2 - 中期改进

| 项目 | 工作量 | 文件 |
|------|--------|------|
| Tombstone 保留策略优化 | 3h | `state.cpp`, `pruner.cpp` |
| 重试机制 | 3h | `core_runtime.cpp` |
| 设备 ID 冲突检测 | 2h | `exporter.cpp` |

### P3 - 长期优化

| 项目 | 工作量 | 文件 |
|------|--------|------|
| `excludeAppIds` 配置 | 2h | 配置系统扩展 |
| Delete 事件加密 | 1h | `exporter.cpp` |
| `is_transient` 支持 | 2h | 类型系统扩展 |

---

## 七、评分总结

| 维度 | 评分 | 说明 |
|------|------|------|
| **架构设计** | ⭐⭐⭐⭐⭐ | 清晰的分层，职责划分明确 |
| **边界处理** | ⭐⭐⭐⭐ | 核心场景覆盖，少数遗漏 |
| **安全性** | ⭐⭐⭐⭐ | E2EE 实现 good，敏感内容处理待完善 |
| **可配置性** | ⭐⭐⭐ | 基础配置有，高级配置缺失 |
| **测试覆盖** | ⭐⭐⭐⭐ | 核心功能有测试，边界可加强 |
| **代码质量** | ⭐⭐⭐⭐ | 整体良好，少量可优化点 |

**总体评价**: 这是一个设计良好、实现健壮的云同步系统。核心功能完整，错误处理得当。主要改进方向是完善配置项和少量边界情况处理。

---

## 附录：关键常量速查

```cpp
// 大小限制
kMaxImageBytes = 26,214,400        // 25 MiB
kMaxEventLineBytes = 1,048,576     // 1 MiB
kLogFileRotationBytes = 10,485,760 // 10 MiB
kMaxAssetBytes = 26,214,400        // 25 MiB

// 保留策略
kDefaultRetentionMs = 15,552,000,000  // 180 天
kDefaultMaxEventsPerDevice = 5000     // 5000 事件/设备

// 清理间隔
kPruneIntervalMs = 86,400,000  // 24 小时

// 协议版本
kSchemaVersion = 1

// 循环防护前缀
kLoopPrefix = "pasty-sync:"
```
