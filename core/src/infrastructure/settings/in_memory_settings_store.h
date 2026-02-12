#pragma once

#include "ports/settings_store.h"

#include <mutex>

namespace pasty {

class InMemorySettingsStore final : public SettingsStore {
public:
    explicit InMemorySettingsStore(int defaultMaxHistoryCount);

    int getMaxHistoryCount() const override;
    bool setMaxHistoryCount(int maxHistoryCount) override;

private:
    mutable std::mutex m_mutex;
    int m_maxHistoryCount;
};

} // namespace pasty
