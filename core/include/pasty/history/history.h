// Pasty2 - Copyright (c) 2026. MIT License.

#ifndef PASTY_HISTORY_HISTORY_H
#define PASTY_HISTORY_HISTORY_H

#include <pasty/history/store.h>
#include <pasty/history/types.h>

#include <memory>
#include <string>

namespace pasty {

class ClipboardHistory {
public:
    explicit ClipboardHistory(std::unique_ptr<ClipboardHistoryStore> store);
    ~ClipboardHistory();

    bool initialize(const std::string& baseDirectory);
    void shutdown();
    bool isInitialized() const;

    bool ingest(const ClipboardHistoryIngestEvent& event);
    ClipboardHistoryListResult list(std::int32_t limit, const std::string& cursor) const;
    bool deleteById(const std::string& id);

private:
    std::unique_ptr<ClipboardHistoryStore> m_store;
    bool m_initialized;
};

}

#endif
