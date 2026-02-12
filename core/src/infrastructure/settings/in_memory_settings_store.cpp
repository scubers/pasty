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

} // namespace pasty
