#pragma once

#include "history/clipboard_history_store.h"
#include "ports/settings_store.h"
#include "utils/metadata_utils.h"

#include <memory>
#include <optional>
#include <string>
#include <vector>

namespace pasty {

struct ClipboardIngestResult {
    bool ok = false;
    bool inserted = false;
};

class ClipboardService {
public:
    ClipboardService(std::unique_ptr<ClipboardHistoryStore> store, SettingsStore& settingsStore);

    bool initialize(const std::string& baseDirectory);
    void shutdown();
    bool isInitialized() const;

    bool ingest(const ClipboardHistoryIngestEvent& event);
    ClipboardIngestResult ingestWithResult(const ClipboardHistoryIngestEvent& event);
    ClipboardHistoryListResult list(std::int32_t limit, const std::string& cursor);
    std::vector<ClipboardHistoryItem> search(const SearchOptions& options);
    std::vector<OcrTask> getPendingOcrImages(std::int32_t limit);
    std::optional<OcrTask> getNextOcrTask();
    bool markOcrProcessing(const std::string& id);
    bool updateOcrSuccess(const std::string& id, const std::string& ocrText);
    bool updateOcrFailed(const std::string& id);
    std::optional<OcrTaskStatus> getOcrStatus(const std::string& id);
    std::optional<ClipboardHistoryItem> getById(const std::string& id);
    std::optional<ClipboardHistoryItem> getByTypeAndContentHash(ClipboardItemType type, const std::string& contentHash);
    bool deleteById(const std::string& id);
    int deleteByTypeAndContentHash(ClipboardItemType type, const std::string& contentHash);

    std::vector<std::string> getTags(const std::string& id);
    bool setTags(const std::string& id, const std::vector<std::string>& tags);

    bool applyRetentionFromSettings();
    bool enforceRetention(std::int32_t maxCount);

    bool setPinned(const std::string& id, bool pinned);
    bool setPinned(const std::string& id, bool pinned, HistoryTimestampMs pinnedUpdateTimeMs);
    std::optional<bool> getPinned(const std::string& id);
    bool deleteItem(const std::string& id);

private:
    std::unique_ptr<ClipboardHistoryStore> m_store;
    SettingsStore& m_settingsStore;
    bool m_initialized;
};

} // namespace pasty
