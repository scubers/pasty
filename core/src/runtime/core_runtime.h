#pragma once

#include "../application/history/clipboard_service.h"
#include "../infrastructure/sync/cloud_drive_sync_exporter.h"
#include "../ports/settings_store.h"

#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace pasty {

struct CoreRuntimeConfig {
    std::string storageDirectory = "./build/history";
    std::string migrationDirectory;
    int defaultMaxHistoryCount = 1000;
    bool cloudSyncEnabled = false;
    std::string cloudSyncRootPath;
    bool cloudSyncIncludeSensitive = false;
};

struct CloudSyncImportStatus {
    int eventsProcessed = 0;
    int eventsApplied = 0;
    int eventsSkipped = 0;
    int errors = 0;
    bool success = false;
};

struct CloudSyncStatus {
    bool enabled = false;
    std::string rootPath;
    bool includeSensitive = false;
    std::string deviceId;
    CloudSyncImportStatus lastImport;
    std::uint64_t stateFileErrorCount = 0;
};

class CoreRuntime {
public:
    explicit CoreRuntime(CoreRuntimeConfig config);

    bool start();
    void stop();
    bool isStarted() const;

    ClipboardService* clipboardService();
    const ClipboardService* clipboardService() const;

    int getMaxHistoryCount() const;
    bool setMaxHistoryCount(int maxHistoryCount);

    bool setCloudSyncEnabled(bool enabled);
    bool setCloudSyncRootPath(const std::string& rootPath);
    bool setCloudSyncIncludeSensitive(bool includeSensitive);

    bool runCloudSyncImport();
    CloudSyncStatus cloudSyncStatus() const;

    bool exportLocalTextIngest(const ClipboardHistoryIngestEvent& event, bool inserted);
    bool exportLocalImageIngest(const ClipboardHistoryIngestEvent& event, bool inserted);
    bool exportLocalDelete(const ClipboardHistoryItem& deletedItem, bool deleted);

private:
    bool syncExportConfigured() const;
    bool ensureCloudSyncExporter();
    std::string loadSyncDeviceId() const;
    std::uint64_t loadSyncFileErrorCount() const;
    static std::string computeContentHash(const ClipboardHistoryIngestEvent& event);

    CoreRuntimeConfig m_config;
    std::unique_ptr<SettingsStore> m_settingsStore;
    std::unique_ptr<ClipboardService> m_clipboardService;
    std::optional<CloudSyncImportStatus> m_lastImportStatus;
    std::string m_syncDeviceId;

    std::optional<CloudDriveSyncExporter> m_syncExporter;

    bool m_started;
};

} // namespace pasty
