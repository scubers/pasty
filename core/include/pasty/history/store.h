// Pasty2 - Copyright (c) 2026. MIT License.

#ifndef PASTY_HISTORY_STORE_H
#define PASTY_HISTORY_STORE_H

#include <pasty/history/types.h>

#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace pasty {

class ClipboardHistoryStore {
public:
    virtual ~ClipboardHistoryStore() = default;

    virtual bool open(const std::string& baseDirectory) = 0;
    virtual void close() = 0;

    virtual std::string upsertTextItem(const ClipboardHistoryItem& item) = 0;
    virtual std::string upsertImageItem(const ClipboardHistoryItem& item, const std::vector<std::uint8_t>& imageBytes) = 0;
    virtual std::optional<ClipboardHistoryItem> getItem(const std::string& id) = 0;
    virtual ClipboardHistoryListResult listItems(std::int32_t limit, const std::string& cursor) = 0;
    virtual std::vector<ClipboardHistoryItem> search(const SearchOptions& options) = 0;
    virtual bool deleteItem(const std::string& id) = 0;
    virtual bool enforceRetention(std::int32_t maxItems) = 0;
};

std::unique_ptr<ClipboardHistoryStore> createClipboardHistoryStore();

}

#endif
