// Pasty - Copyright (c) 2026. MIT License.

#ifndef PASTY_HISTORY_STORE_H
#define PASTY_HISTORY_STORE_H

#include <history/clipboard_history_types.h>

#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace pasty {

struct ClipboardHistoryUpsertResult {
    std::string id;
    bool inserted = false;
};

class ClipboardHistoryStore {
public:
    virtual ~ClipboardHistoryStore() = default;

    virtual bool open(const std::string& baseDirectory) = 0;
    virtual void close() = 0;

    virtual ClipboardHistoryUpsertResult upsertTextItem(const ClipboardHistoryItem& item) = 0;
    virtual ClipboardHistoryUpsertResult upsertImageItem(const ClipboardHistoryItem& item, const std::vector<std::uint8_t>& imageBytes) = 0;
    virtual std::optional<ClipboardHistoryItem> getItem(const std::string& id) = 0;
    virtual std::optional<ClipboardHistoryItem> getItemByTypeAndContentHash(ClipboardItemType type, const std::string& contentHash) = 0;
    virtual ClipboardHistoryListResult listItems(std::int32_t limit, const std::string& cursor) = 0;
    virtual std::vector<ClipboardHistoryItem> search(const SearchOptions& options) = 0;
    virtual std::vector<OcrTask> getPendingOcrImages(std::int32_t limit, HistoryTimestampMs nowMs) = 0;
    virtual std::optional<OcrTask> getNextOcrTask(HistoryTimestampMs nowMs) = 0;
    virtual bool markOcrProcessing(const std::string& id) = 0;
    virtual bool updateOcrSuccess(const std::string& id, const std::string& ocrText) = 0;
    virtual bool updateOcrFailed(const std::string& id, HistoryTimestampMs nowMs) = 0;
    virtual std::optional<OcrTaskStatus> getOcrStatus(const std::string& id) = 0;
    virtual bool deleteItem(const std::string& id) = 0;
    virtual int deleteByTypeAndContentHash(ClipboardItemType type, const std::string& contentHash) = 0;
    virtual bool enforceRetention(std::int32_t maxItems) = 0;

    virtual bool updateItemMetadata(const std::string& id, const std::string& metadata, HistoryTimestampMs updateTimeMs) = 0;
    virtual bool setPinnedById(const std::string& id, bool pinned, HistoryTimestampMs updateTimeMs) = 0;
    virtual std::optional<bool> getPinnedById(const std::string& id) = 0;
};

std::unique_ptr<ClipboardHistoryStore> createClipboardHistoryStore();

}

#endif
