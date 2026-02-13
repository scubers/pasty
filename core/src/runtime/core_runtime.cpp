#include "core_runtime.h"

#include "../history/clipboard_history_store.h"
#include "../infrastructure/settings/in_memory_settings_store.h"
#include "../infrastructure/sync/cloud_drive_sync_importer.h"
#include "../infrastructure/sync/cloud_drive_sync_protocol_info.h"
#include "../infrastructure/sync/cloud_drive_sync_state.h"
#include "../infrastructure/sync/cloud_drive_sync_pruner.h"
#include "../utils/runtime_json_utils.h"
#include "../store/sqlite_clipboard_history_store.h"

#include <algorithm>
#include <fstream>
#include <iomanip>
#include <sstream>

#include <sodium.h>

#include "../thirdparty/nlohmann/json.hpp"

namespace pasty {

namespace {

constexpr std::uint64_t kFnvOffset = 1469598103934665603ULL;
constexpr std::uint64_t kFnvPrime = 1099511628211ULL;

std::string normalizeTextForHash(const std::string& text) {
    std::string normalized;
    normalized.reserve(text.size());

    for (std::size_t i = 0; i < text.size(); ++i) {
        if (text[i] == '\r') {
            if (i + 1 < text.size() && text[i + 1] == '\n') {
                continue;
            }
            normalized.push_back('\n');
            continue;
        }
        normalized.push_back(text[i]);
    }

    return normalized;
}

std::uint64_t hashBytes(const std::uint8_t* bytes, std::size_t length) {
    std::uint64_t hash = kFnvOffset;
    for (std::size_t i = 0; i < length; ++i) {
        hash ^= static_cast<std::uint64_t>(bytes[i]);
        hash *= kFnvPrime;
    }
    return hash;
}

std::string toHex(std::uint64_t value) {
    std::ostringstream stream;
    stream << std::hex << std::setfill('0') << std::setw(16) << value;
    return stream.str();
}

std::string computeTextHash(const std::string& text) {
    const std::string normalized = normalizeTextForHash(text);
    return toHex(hashBytes(reinterpret_cast<const std::uint8_t*>(normalized.data()), normalized.size()));
}

std::string computeImageHash(const std::vector<std::uint8_t>& bytes) {
    if (bytes.empty()) {
        return std::string();
    }
    return toHex(hashBytes(bytes.data(), bytes.size()));
}

}

CoreRuntime::CoreRuntime(CoreRuntimeConfig config)
    : m_config(std::move(config))
    , m_started(false) {
}

bool CoreRuntime::start() {
    if (m_started) {
        return true;
    }

    if (!m_config.migrationDirectory.empty()) {
        setClipboardHistoryMigrationDirectory(m_config.migrationDirectory);
    }

    m_settingsStore = std::make_unique<InMemorySettingsStore>(m_config.defaultMaxHistoryCount);
    auto store = createClipboardHistoryStore();
    m_clipboardService = std::make_unique<ClipboardService>(std::move(store), *m_settingsStore);

    if (!m_clipboardService->initialize(m_config.storageDirectory)) {
        m_clipboardService.reset();
        m_settingsStore.reset();
        return false;
    }

    m_syncExporter.reset();
    m_syncDeviceId = loadSyncDeviceId();
    m_lastImportStatus.reset();

    m_started = true;
    return true;
}

void CoreRuntime::stop() {
    if (!m_started) {
        return;
    }

    clearCloudSyncE2eeKey();

    if (m_clipboardService) {
        m_clipboardService->shutdown();
        m_clipboardService.reset();
    }

    m_syncExporter.reset();
    m_settingsStore.reset();
    m_started = false;
}

bool CoreRuntime::isStarted() const {
    return m_started;
}

ClipboardService* CoreRuntime::clipboardService() {
    return m_clipboardService.get();
}

const ClipboardService* CoreRuntime::clipboardService() const {
    return m_clipboardService.get();
}

int CoreRuntime::getMaxHistoryCount() const {
    if (!m_settingsStore) {
        return m_config.defaultMaxHistoryCount;
    }
    return m_settingsStore->getMaxHistoryCount();
}

bool CoreRuntime::setMaxHistoryCount(int maxHistoryCount) {
    if (maxHistoryCount <= 0) {
        return false;
    }

    if (!m_settingsStore) {
        m_config.defaultMaxHistoryCount = maxHistoryCount;
        return true;
    }

    if (!m_settingsStore->setMaxHistoryCount(maxHistoryCount)) {
        return false;
    }

    if (!m_clipboardService) {
        return true;
    }

    return m_clipboardService->applyRetentionFromSettings();
}

bool CoreRuntime::setCloudSyncEnabled(bool enabled) {
    m_config.cloudSyncEnabled = enabled;
    if (!enabled) {
        m_syncExporter.reset();
    }
    return true;
}

bool CoreRuntime::setCloudSyncRootPath(const std::string& rootPath) {
    m_config.cloudSyncRootPath = rootPath;
    m_syncExporter.reset();
    return true;
}

bool CoreRuntime::setCloudSyncIncludeSensitive(bool includeSensitive) {
    m_config.cloudSyncIncludeSensitive = includeSensitive;
    return true;
}

bool CoreRuntime::syncExportConfigured() const {
    return m_started && m_clipboardService && m_config.cloudSyncEnabled && !m_config.cloudSyncRootPath.empty();
}

bool CoreRuntime::ensureCloudSyncExporter() {
    if (!syncExportConfigured()) {
        return false;
    }
    if (m_syncExporter.has_value()) {
        return true;
    }

    auto exporter = CloudDriveSyncExporter::Create(
        m_config.cloudSyncRootPath,
        m_config.storageDirectory,
        m_cloudSyncE2eeMasterKey,
        m_cloudSyncE2eeKeyId);
    if (!exporter.has_value()) {
        return false;
    }

    m_syncExporter = std::move(*exporter);
    return true;
}

void CoreRuntime::applyCloudSyncE2eeToExporter() {
    if (!m_syncExporter.has_value()) {
        return;
    }

    if (m_cloudSyncE2eeMasterKey.has_value() && !m_cloudSyncE2eeKeyId.empty()) {
        m_syncExporter->setE2eeKey(*m_cloudSyncE2eeMasterKey, m_cloudSyncE2eeKeyId);
        return;
    }

    m_syncExporter->clearE2eeKey();
}

bool CoreRuntime::runCloudSyncImport() {
    if (!m_started || !m_clipboardService || !m_config.cloudSyncEnabled || m_config.cloudSyncRootPath.empty()) {
        m_lastImportStatus = CloudSyncImportStatus{};
        return false;
    }

    auto importer = CloudDriveSyncImporter::Create(
        m_config.cloudSyncRootPath,
        m_config.storageDirectory,
        m_cloudSyncE2eeMasterKey,
        m_cloudSyncE2eeKeyId);
    if (!importer.has_value()) {
        m_lastImportStatus = CloudSyncImportStatus{};
        return false;
    }

    const CloudDriveSyncImporter::ImportResult importResult = importer->importChanges(*m_clipboardService);
    CloudSyncImportStatus status;
    status.eventsProcessed = importResult.eventsProcessed;
    status.eventsApplied = importResult.eventsApplied;
    status.eventsSkipped = importResult.eventsSkipped;
    status.errors = importResult.errors;
    status.success = importResult.success;
    m_lastImportStatus = status;

    if (m_syncDeviceId.empty()) {
        m_syncDeviceId = loadSyncDeviceId();
    }

    const std::int64_t nowMs = runtime_json_utils::nowMs();
    constexpr std::int64_t kPruneIntervalMs = 24LL * 60 * 60 * 1000;
    if (m_lastCloudSyncPruneMs == 0 || (nowMs - m_lastCloudSyncPruneMs) >= kPruneIntervalMs) {
        CloudDriveSyncPruner pruner;
        pruner.prune(m_config.cloudSyncRootPath, nowMs);
        m_lastCloudSyncPruneMs = nowMs;
    }

    return importResult.success;
}

bool CoreRuntime::initializeCloudSyncE2ee(const std::string& passphrase) {
    if (!m_started || !m_config.cloudSyncEnabled || m_config.cloudSyncRootPath.empty() || passphrase.empty()) {
        return false;
    }

    auto protocolInfo = CloudDriveSyncProtocolInfo::Load(m_config.cloudSyncRootPath);
    if (!protocolInfo.has_value()) {
        if (!CloudDriveSyncProtocolInfo::CreateE2EE(
                m_config.cloudSyncRootPath,
                crypto_pwhash_OPSLIMIT_INTERACTIVE,
                crypto_pwhash_MEMLIMIT_INTERACTIVE
            )) {
            return false;
        }
        protocolInfo = CloudDriveSyncProtocolInfo::Load(m_config.cloudSyncRootPath);
        if (!protocolInfo.has_value()) {
            return false;
        }
    }

    EncryptionManager::Key derivedKey{};
    if (!EncryptionManager::deriveMasterKey(
            passphrase,
            protocolInfo->kdfSalt,
            protocolInfo->kdfOpslimit,
            protocolInfo->kdfMemlimit,
            derivedKey
        )) {
        return false;
    }

    clearCloudSyncE2eeKey();
    m_cloudSyncE2eeMasterKey = derivedKey;
    m_cloudSyncE2eeKeyId = protocolInfo->keyId;
    applyCloudSyncE2eeToExporter();
    sodium_memzero(derivedKey.data(), derivedKey.size());
    return true;
}

void CoreRuntime::clearCloudSyncE2eeKey() {
    if (m_syncExporter.has_value()) {
        m_syncExporter->clearE2eeKey();
    }

    if (m_cloudSyncE2eeMasterKey.has_value()) {
        sodium_memzero(m_cloudSyncE2eeMasterKey->data(), m_cloudSyncE2eeMasterKey->size());
        m_cloudSyncE2eeMasterKey.reset();
    }
    m_cloudSyncE2eeKeyId.clear();
}

CloudSyncStatus CoreRuntime::cloudSyncStatus() const {
    CloudSyncStatus status;
    status.enabled = m_config.cloudSyncEnabled;
    status.rootPath = m_config.cloudSyncRootPath;
    status.includeSensitive = m_config.cloudSyncIncludeSensitive;
    status.deviceId = m_syncDeviceId.empty() ? loadSyncDeviceId() : m_syncDeviceId;
    if (m_lastImportStatus.has_value()) {
        status.lastImport = *m_lastImportStatus;
    }
    status.stateFileErrorCount = loadSyncFileErrorCount();

    if (status.enabled && !status.rootPath.empty()) {
        auto protocolInfo = CloudDriveSyncProtocolInfo::Load(status.rootPath);
        if (protocolInfo.has_value()) {
            status.e2eeEnabled = true;
            status.e2eeKeyId = protocolInfo->keyId;
        }
    }

    return status;
}

std::string CoreRuntime::computeContentHash(const ClipboardHistoryIngestEvent& event) {
    if (event.itemType == ClipboardItemType::Image) {
        return computeImageHash(event.image.bytes);
    }
    return computeTextHash(event.text);
}

bool CoreRuntime::exportLocalTextIngest(const ClipboardHistoryIngestEvent& event, bool inserted) {
    if (!inserted || !ensureCloudSyncExporter() || !m_syncExporter.has_value()) {
        return false;
    }

    ClipboardHistoryItem item;
    item.type = ClipboardItemType::Text;
    item.content = event.text;
    item.contentHash = computeContentHash(event);
    item.sourceAppId = event.sourceAppId;

    return m_syncExporter->exportTextItem(item) == CloudDriveSyncExporter::ExportResult::Success;
}

bool CoreRuntime::exportLocalImageIngest(const ClipboardHistoryIngestEvent& event, bool inserted) {
    if (!inserted || !ensureCloudSyncExporter() || !m_syncExporter.has_value()) {
        return false;
    }

    ClipboardHistoryItem item;
    item.type = ClipboardItemType::Image;
    item.imageWidth = event.image.width;
    item.imageHeight = event.image.height;
    item.imageFormat = event.image.formatHint;
    item.contentHash = computeContentHash(event);
    item.sourceAppId = event.sourceAppId;

    return m_syncExporter->exportImageItem(item, event.image.bytes) == CloudDriveSyncExporter::ExportResult::Success;
}

bool CoreRuntime::exportLocalDelete(const ClipboardHistoryItem& deletedItem, bool deleted) {
    if (!deleted || !ensureCloudSyncExporter() || !m_syncExporter.has_value()) {
        return false;
    }

    return m_syncExporter->exportDeleteTombstone(deletedItem.type, deletedItem.contentHash)
        == CloudDriveSyncExporter::ExportResult::Success;
}

std::string CoreRuntime::loadSyncDeviceId() const {
    auto state = CloudDriveSyncState::LoadOrCreate(m_config.storageDirectory);
    if (!state.has_value()) {
        return std::string();
    }
    return state->deviceId();
}

std::uint64_t CoreRuntime::loadSyncFileErrorCount() const {
    const std::string statePath = m_config.storageDirectory + "/sync_state.json";
    std::ifstream file(statePath);
    if (!file.is_open()) {
        return 0;
    }

    std::string content((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    if (content.empty()) {
        return 0;
    }

    using Json = nlohmann::json;
    Json json = Json::parse(content, nullptr, false);
    if (json.is_discarded() || !json.is_object() || !json.contains("files") || !json["files"].is_object()) {
        return 0;
    }

    std::uint64_t total = 0;
    for (const auto& [unusedPath, cursor] : json["files"].items()) {
        (void)unusedPath;
        if (!cursor.is_object()) {
            continue;
        }

        const int fileErrors = cursor.value("error_count", 0);
        if (fileErrors > 0) {
            total += static_cast<std::uint64_t>(fileErrors);
        }
    }

    return total;
}

} // namespace pasty
