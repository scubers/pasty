#include "infrastructure/settings/in_memory_settings_store.h"

namespace pasty {

namespace {
constexpr int kFallbackMaxHistoryCount = 1000;
}

InMemorySettingsStore::InMemorySettingsStore(int defaultMaxHistoryCount)
    : m_maxHistoryCount(defaultMaxHistoryCount > 0 ? defaultMaxHistoryCount : kFallbackMaxHistoryCount) {
}

int InMemorySettingsStore::getMaxHistoryCount() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_maxHistoryCount;
}

bool InMemorySettingsStore::setMaxHistoryCount(int maxHistoryCount) {
    if (maxHistoryCount <= 0) {
        return false;
    }

    std::lock_guard<std::mutex> lock(m_mutex);
    m_maxHistoryCount = maxHistoryCount;
    return true;
}

bool InMemorySettingsStore::isSyncEnabled() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_syncEnabled;
}

bool InMemorySettingsStore::setSyncEnabled(bool enabled) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_syncEnabled = enabled;
    return true;
}

std::string InMemorySettingsStore::getSyncRootPath() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_syncRootPath;
}

bool InMemorySettingsStore::setSyncRootPath(const std::string& path) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_syncRootPath = path;
    return true;
}

bool InMemorySettingsStore::isSyncIncludeSensitive() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_syncIncludeSensitive;
}

bool InMemorySettingsStore::setSyncIncludeSensitive(bool include) {
    std::lock_guard<std::mutex> lock(m_mutex);
    m_syncIncludeSensitive = include;
    return true;
}

std::string InMemorySettingsStore::getDeviceId() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_deviceId;
}

} // namespace pasty
