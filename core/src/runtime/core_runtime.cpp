#include "runtime/core_runtime.h"

#include "history/clipboard_history_store.h"
#include "infrastructure/settings/in_memory_settings_store.h"
#include "store/sqlite_clipboard_history_store.h"

namespace pasty {

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

    m_started = true;
    return true;
}

void CoreRuntime::stop() {
    if (!m_started) {
        return;
    }

    if (m_clipboardService) {
        m_clipboardService->shutdown();
        m_clipboardService.reset();
    }

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

} // namespace pasty
