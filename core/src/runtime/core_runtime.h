#pragma once

#include "application/history/clipboard_service.h"
#include "ports/settings_store.h"

#include <memory>
#include <string>

namespace pasty {

struct CoreRuntimeConfig {
    std::string storageDirectory = "./build/history";
    std::string migrationDirectory;
    int defaultMaxHistoryCount = 1000;
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

private:
    CoreRuntimeConfig m_config;
    std::unique_ptr<SettingsStore> m_settingsStore;
    std::unique_ptr<ClipboardService> m_clipboardService;
    bool m_started;
};

} // namespace pasty
