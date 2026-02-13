#pragma once

#include <string>

namespace pasty {

class SettingsStore {
public:
    virtual ~SettingsStore() = default;

    virtual int getMaxHistoryCount() const = 0;
    virtual bool setMaxHistoryCount(int maxHistoryCount) = 0;

    // Sync settings
    virtual bool isSyncEnabled() const = 0;
    virtual bool setSyncEnabled(bool enabled) = 0;

    virtual std::string getSyncRootPath() const = 0;
    virtual bool setSyncRootPath(const std::string& path) = 0;

    virtual bool isSyncIncludeSensitive() const = 0;
    virtual bool setSyncIncludeSensitive(bool include) = 0;

    virtual std::string getDeviceId() const = 0;
};

} // namespace pasty
