#pragma once

namespace pasty {

class SettingsStore {
public:
    virtual ~SettingsStore() = default;

    virtual int getMaxHistoryCount() const = 0;
    virtual bool setMaxHistoryCount(int maxHistoryCount) = 0;
};

} // namespace pasty
