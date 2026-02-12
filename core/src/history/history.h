// Pasty - Copyright (c) 2026. MIT License.

#ifndef PASTY_HISTORY_HISTORY_H
#define PASTY_HISTORY_HISTORY_H

#include <history/store.h>
#include <history/types.h>

#include <vector>
#include <string>
#include <optional>

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
    std::vector<ClipboardHistoryItem> search(const SearchOptions& options);
    std::vector<OcrTask> getPendingOcrImages(std::int32_t limit) const;
    std::optional<OcrTask> getNextOcrTask() const;
    bool markOcrProcessing(const std::string& id);
    bool updateOcrSuccess(const std::string& id, const std::string& ocrText);
    bool updateOcrFailed(const std::string& id);
    std::optional<OcrTaskStatus> getOcrStatus(const std::string& id) const;
    std::optional<ClipboardHistoryItem> getById(const std::string& id);
    bool deleteById(const std::string& id);
    bool enforceRetention(std::int32_t maxCount);

private:
    std::unique_ptr<ClipboardHistoryStore> m_store;
    bool m_initialized;
};

}

#endif
