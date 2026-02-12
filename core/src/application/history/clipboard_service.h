#pragma once

#include "history/clipboard_history_store.h"
#include "ports/settings_store.h"

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
    bool deleteById(const std::string& id);

    bool applyRetentionFromSettings();
    bool enforceRetention(std::int32_t maxCount);

private:
    std::unique_ptr<ClipboardHistoryStore> m_store;
    SettingsStore& m_settingsStore;
    bool m_initialized;
};

} // namespace pasty
