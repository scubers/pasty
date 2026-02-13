#pragma once

#include "ports/settings_store.h"

#include <mutex>
#include <string>

namespace pasty {

class InMemorySettingsStore final : public SettingsStore {
public:
    explicit InMemorySettingsStore(int defaultMaxHistoryCount);

    int getMaxHistoryCount() const override;
    bool setMaxHistoryCount(int maxHistoryCount) override;

    // Sync settings
    bool isSyncEnabled() const override;
    bool setSyncEnabled(bool enabled) override;

    std::string getSyncRootPath() const override;
    bool setSyncRootPath(const std::string& path) override;

    bool isSyncIncludeSensitive() const override;
    bool setSyncIncludeSensitive(bool include) override;

    std::string getDeviceId() const override;

private:
    mutable std::mutex m_mutex;
    int m_maxHistoryCount;

    bool m_syncEnabled = false;
    std::string m_syncRootPath;
    bool m_syncIncludeSensitive = false;
    std::string m_deviceId = "in-memory-device";
};

} // namespace pasty
