#include "application/history/clipboard_service.h"

#include <common/logger.h>

#include <chrono>
#include <cstdint>
#include <iomanip>
#include <sstream>

namespace pasty {

namespace {

constexpr std::uint64_t kFnvOffset = 1469598103934665603ULL;
constexpr std::uint64_t kFnvPrime = 1099511628211ULL;

std::string normalizeTextForHash(const std::string& text) {
    std::string normalized;
    normalized.reserve(text.size());

    for (std::size_t i = 0; i < text.size(); ++i) {
        if (text[i] == '\r') {
            if (i + 1 < text.size() && text[i + 1] == '\n') {
                continue;
            }
            normalized.push_back('\n');
            continue;
        }
        normalized.push_back(text[i]);
    }

    return normalized;
}

std::uint64_t hashBytes(const std::uint8_t* bytes, std::size_t length) {
    std::uint64_t hash = kFnvOffset;
    for (std::size_t i = 0; i < length; ++i) {
        hash ^= static_cast<std::uint64_t>(bytes[i]);
        hash *= kFnvPrime;
    }
    return hash;
}

std::string toHex(std::uint64_t value) {
    std::ostringstream stream;
    stream << std::hex << std::setfill('0') << std::setw(16) << value;
    return stream.str();
}

std::string computeTextHash(const std::string& text) {
    const std::string normalized = normalizeTextForHash(text);
    return toHex(hashBytes(reinterpret_cast<const std::uint8_t*>(normalized.data()), normalized.size()));
}

std::string computeImageHash(const std::vector<std::uint8_t>& bytes) {
    if (bytes.empty()) {
        return std::string();
    }
    return toHex(hashBytes(bytes.data(), bytes.size()));
}

std::int64_t currentTimeMs() {
    const auto now = std::chrono::system_clock::now();
    const auto value = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch());
    return static_cast<std::int64_t>(value.count());
}

std::string makeItemId(std::int64_t timestampMs, const std::string& sourceAppId, const std::string& contentHash) {
    const std::string seed = sourceAppId + ":" + contentHash + ":" + std::to_string(timestampMs);
    const std::uint64_t hashed = hashBytes(reinterpret_cast<const std::uint8_t*>(seed.data()), seed.size());
    return toHex(hashed);
}

} // namespace

ClipboardService::ClipboardService(std::unique_ptr<ClipboardHistoryStore> store, SettingsStore& settingsStore)
    : m_store(std::move(store))
    , m_settingsStore(settingsStore)
    , m_initialized(false) {
}

bool ClipboardService::initialize(const std::string& baseDirectory) {
    if (m_initialized) {
        return true;
    }

    if (!m_store) {
        return false;
    }

    if (!m_store->open(baseDirectory)) {
        return false;
    }

    m_initialized = true;
    return applyRetentionFromSettings();
}

void ClipboardService::shutdown() {
    if (!m_initialized || !m_store) {
        return;
    }

    m_store->close();
    m_initialized = false;
}

bool ClipboardService::isInitialized() const {
    return m_initialized;
}

bool ClipboardService::ingest(const ClipboardHistoryIngestEvent& event) {
    return ingestWithResult(event).ok;
}

ClipboardIngestResult ClipboardService::ingestWithResult(const ClipboardHistoryIngestEvent& event) {
    if (!m_initialized || !m_store) {
        return {};
    }

    if (event.flags.isFileOrFolderReference || event.flags.isTransient || event.flags.isConcealed) {
        PASTY_LOG_INFO("Core.History", "Skipped item. Flags: file=%d transient=%d concealed=%d",
            event.flags.isFileOrFolderReference, event.flags.isTransient, event.flags.isConcealed);
        return ClipboardIngestResult{true, false};
    }

    ClipboardHistoryItem item;
    const std::int64_t eventTimeMs = event.timestampMs > 0 ? event.timestampMs : currentTimeMs();

    item.type = event.itemType;
    item.content = event.text;
    item.imageWidth = event.image.width;
    item.imageHeight = event.image.height;
    item.imageFormat = event.image.formatHint;
    item.createTimeMs = eventTimeMs;
    item.updateTimeMs = eventTimeMs;
    item.lastCopyTimeMs = eventTimeMs;
    item.sourceAppId = event.sourceAppId;

    if (event.itemType == ClipboardItemType::Image) {
        item.contentHash = computeImageHash(event.image.bytes);
        item.id = makeItemId(item.lastCopyTimeMs, item.sourceAppId, item.contentHash);
        const ClipboardHistoryUpsertResult upsertResult = m_store->upsertImageItem(item, event.image.bytes);
        if (upsertResult.id.empty()) {
            return {};
        }
        const bool retentionOk = applyRetentionFromSettings();
        return ClipboardIngestResult{retentionOk, retentionOk && upsertResult.inserted};
    }

    item.contentHash = computeTextHash(event.text);
    item.id = makeItemId(item.lastCopyTimeMs, item.sourceAppId, item.contentHash);
    const ClipboardHistoryUpsertResult upsertResult = m_store->upsertTextItem(item);
    if (upsertResult.id.empty()) {
        return {};
    }

    const bool retentionOk = applyRetentionFromSettings();
    return ClipboardIngestResult{retentionOk, retentionOk && upsertResult.inserted};
}

ClipboardHistoryListResult ClipboardService::list(std::int32_t limit, const std::string& cursor) {
    if (!m_initialized || !m_store) {
        return ClipboardHistoryListResult{};
    }

    return m_store->listItems(limit, cursor);
}

std::vector<ClipboardHistoryItem> ClipboardService::search(const SearchOptions& options) {
    if (!m_initialized || !m_store) {
        return {};
    }

    return m_store->search(options);
}

std::vector<OcrTask> ClipboardService::getPendingOcrImages(std::int32_t limit) {
    if (!m_initialized || !m_store) {
        return {};
    }

    return m_store->getPendingOcrImages(limit, currentTimeMs());
}

std::optional<OcrTask> ClipboardService::getNextOcrTask() {
    if (!m_initialized || !m_store) {
        return std::nullopt;
    }

    return m_store->getNextOcrTask(currentTimeMs());
}

bool ClipboardService::markOcrProcessing(const std::string& id) {
    if (!m_initialized || !m_store) {
        return false;
    }

    return m_store->markOcrProcessing(id);
}

bool ClipboardService::updateOcrSuccess(const std::string& id, const std::string& ocrText) {
    if (!m_initialized || !m_store) {
        return false;
    }

    return m_store->updateOcrSuccess(id, ocrText);
}

bool ClipboardService::updateOcrFailed(const std::string& id) {
    if (!m_initialized || !m_store) {
        return false;
    }

    return m_store->updateOcrFailed(id, currentTimeMs());
}

std::optional<OcrTaskStatus> ClipboardService::getOcrStatus(const std::string& id) {
    if (!m_initialized || !m_store) {
        return std::nullopt;
    }

    return m_store->getOcrStatus(id);
}

std::optional<ClipboardHistoryItem> ClipboardService::getById(const std::string& id) {
    if (!m_initialized || !m_store) {
        return std::nullopt;
    }

    return m_store->getItem(id);
}

std::optional<ClipboardHistoryItem> ClipboardService::getByTypeAndContentHash(ClipboardItemType type, const std::string& contentHash) {
    if (!m_initialized || !m_store) {
        return std::nullopt;
    }

    return m_store->getItemByTypeAndContentHash(type, contentHash);
}

bool ClipboardService::deleteById(const std::string& id) {
    if (!m_initialized || !m_store) {
        return false;
    }

    return m_store->deleteItem(id);
}

int ClipboardService::deleteByTypeAndContentHash(ClipboardItemType type, const std::string& contentHash) {
    if (!m_initialized || !m_store) {
        return 0;
    }

    return m_store->deleteByTypeAndContentHash(type, contentHash);
}

std::vector<std::string> ClipboardService::getTags(const std::string& id) {
    if (!m_initialized || !m_store || id.empty()) {
        return {};
    }

    auto item = m_store->getItem(id);
    if (!item) {
        return {};
    }

    return metadata_utils::parseTags(item->metadata);
}

bool ClipboardService::setTags(const std::string& id, const std::vector<std::string>& tags) {
    if (!m_initialized || !m_store || id.empty()) {
        return false;
    }

    auto item = m_store->getItem(id);
    if (!item) {
        return false;
    }

    auto currentTags = metadata_utils::parseTags(item->metadata);
    if (metadata_utils::tagsEqual(currentTags, tags)) {
        return true;
    }

    std::string newMetadata = metadata_utils::serializeTags(tags);
    HistoryTimestampMs updateTimeMs = currentTimeMs();

    return m_store->updateItemMetadata(id, newMetadata, updateTimeMs);
}

bool ClipboardService::applyRetentionFromSettings() {
    return enforceRetention(m_settingsStore.getMaxHistoryCount());
}

bool ClipboardService::enforceRetention(std::int32_t maxCount) {
    if (!m_initialized || !m_store) {
        return false;
    }

    return m_store->enforceRetention(maxCount);
}

} // namespace pasty
