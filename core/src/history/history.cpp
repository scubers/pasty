// Pasty2 - Copyright (c) 2026. MIT License.

#include <pasty/history/history.h>

#include <chrono>
#include <cstdint>
#include <iomanip>
#include <iostream>
#include <sstream>

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

void logHistoryMessage(const std::string& message) {
    std::cerr << "[core.history] " << message << std::endl;
}

}

namespace pasty {

ClipboardHistory::ClipboardHistory(std::unique_ptr<ClipboardHistoryStore> store)
    : m_store(std::move(store))
    , m_initialized(false) {
}

ClipboardHistory::~ClipboardHistory() {
    if (m_initialized) {
        shutdown();
    }
}

bool ClipboardHistory::initialize(const std::string& baseDirectory) {
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
    return true;
}

void ClipboardHistory::shutdown() {
    if (!m_initialized || !m_store) {
        return;
    }

    m_store->close();
    m_initialized = false;
}

bool ClipboardHistory::isInitialized() const {
    return m_initialized;
}

bool ClipboardHistory::ingest(const ClipboardHistoryIngestEvent& event) {
    if (!m_initialized || !m_store) {
        return false;
    }

    if (event.flags.isFileOrFolderReference || event.flags.isTransient || event.flags.isConcealed) {
        logHistoryMessage("skipped clipboard item due to privacy or file-reference flags");
        return true;
    }

    ClipboardHistoryItem item;
    const std::int64_t eventTimeMs = event.timestampMs > 0
        ? event.timestampMs
        : currentTimeMs();

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
        const std::string id = m_store->upsertImageItem(item, event.image.bytes);
        const bool ok = !id.empty();
        if (ok) {
            m_store->enforceRetention(1000);
        }
        logHistoryMessage(ok ? "stored image item" : "failed to store image item");
        return ok;
    }

    item.contentHash = computeTextHash(event.text);
    item.id = makeItemId(item.lastCopyTimeMs, item.sourceAppId, item.contentHash);
    const std::string id = m_store->upsertTextItem(item);
    const bool ok = !id.empty();
    if (ok) {
        m_store->enforceRetention(1000);
    }
    logHistoryMessage(ok ? "stored text item" : "failed to store text item");
    return ok;
}

ClipboardHistoryListResult ClipboardHistory::list(std::int32_t limit, const std::string& cursor) const {
    if (!m_initialized || !m_store) {
        return ClipboardHistoryListResult{};
    }

    return m_store->listItems(limit, cursor);
}

std::vector<ClipboardHistoryItem> ClipboardHistory::search(const SearchOptions& options) {
    if (!m_initialized || !m_store) {
        return {};
    }

    return m_store->search(options);
}

std::optional<ClipboardHistoryItem> ClipboardHistory::getById(const std::string& id) {
    if (!m_initialized || !m_store) {
        return std::nullopt;
    }

    return m_store->getItem(id);
}

bool ClipboardHistory::deleteById(const std::string& id) {
    if (!m_initialized || !m_store) {
        return false;
    }

    return m_store->deleteItem(id);
}

}
