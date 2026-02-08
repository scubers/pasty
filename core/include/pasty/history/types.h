// Pasty2 - Copyright (c) 2026. MIT License.

#ifndef PASTY_HISTORY_TYPES_H
#define PASTY_HISTORY_TYPES_H

#include <cstdint>
#include <string>
#include <vector>

namespace pasty {

using HistoryTimestampMs = std::int64_t;
using HistoryItemId = std::string;

enum class ClipboardItemType {
    Text,
    Image,
};

struct ClipboardImagePayload {
    std::vector<std::uint8_t> bytes;
    std::int32_t width = 0;
    std::int32_t height = 0;
    std::string formatHint;
};

struct ClipboardEventFlags {
    bool isTransient = false;
    bool isConcealed = false;
    bool isFileOrFolderReference = false;
};

struct ClipboardHistoryIngestEvent {
    HistoryTimestampMs timestampMs = 0;
    std::string sourceAppId;
    ClipboardItemType itemType = ClipboardItemType::Text;
    std::string text;
    ClipboardImagePayload image;
    ClipboardEventFlags flags;
};

struct ClipboardHistoryItem {
    HistoryItemId id;
    ClipboardItemType type = ClipboardItemType::Text;
    std::string content;
    std::string imagePath;
    std::int32_t imageWidth = 0;
    std::int32_t imageHeight = 0;
    std::string imageFormat;
    HistoryTimestampMs createTimeMs = 0;
    HistoryTimestampMs updateTimeMs = 0;
    HistoryTimestampMs lastCopyTimeMs = 0;
    std::string sourceAppId;
    std::string contentHash;
    std::string metadata;
};

struct SearchOptions {
    std::string query;
    std::size_t limit = 100;
    std::size_t previewLength = 200;
    std::string contentType;
};

struct ClipboardHistoryListResult {
    std::vector<ClipboardHistoryItem> items;
    std::string nextCursor;
};

inline bool isValidHistoryTimestamp(HistoryTimestampMs timestampMs) {
    return timestampMs > 0;
}

}

#endif
