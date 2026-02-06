// Pasty2 - Copyright (c) 2026. MIT License.

#include "../include/Pasty.h"

#include "../include/ClipboardHistory.h"
#include "../include/ClipboardHistoryStore.h"

#include <chrono>
#include <cstdint>
#include <memory>
#include <sstream>
#include <vector>

namespace pasty {

static const char* VERSION = "0.1.0";
static const char* APP_NAME = "Pasty2";
static std::string HISTORY_STORAGE_DIRECTORY = "./build/history";
static std::unique_ptr<ClipboardHistory> HISTORY_SUBSYSTEM;

static std::int64_t nowMs() {
    const auto now = std::chrono::system_clock::now();
    return static_cast<std::int64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count());
}

static std::string fromCString(const char* text) {
    return text == nullptr ? std::string() : std::string(text);
}

static std::string escapeJson(const std::string& value) {
    std::string escaped;
    escaped.reserve(value.size());
    for (char character : value) {
        switch (character) {
            case '\\': escaped += "\\\\"; break;
            case '"': escaped += "\\\""; break;
            case '\n': escaped += "\\n"; break;
            case '\r': escaped += "\\r"; break;
            case '\t': escaped += "\\t"; break;
            default: escaped.push_back(character); break;
        }
    }
    return escaped;
}

ClipboardManager::ClipboardManager()
    : m_initialized(false) {
}

ClipboardManager::~ClipboardManager() {
    if (m_initialized) {
        shutdown();
    }
}

std::string ClipboardManager::getVersion() {
    return std::string(VERSION);
}

std::string ClipboardManager::getAppName() {
    return std::string(APP_NAME);
}

bool ClipboardManager::initialize() {
    return initializeWithStorageDirectory(HISTORY_STORAGE_DIRECTORY);
}

bool ClipboardManager::initializeWithStorageDirectory(const std::string& baseDirectory) {
    if (m_initialized) {
        return true;
    }

    HISTORY_STORAGE_DIRECTORY = baseDirectory;
    HISTORY_SUBSYSTEM = std::make_unique<ClipboardHistory>(createClipboardHistoryStore());
    if (!HISTORY_SUBSYSTEM || !HISTORY_SUBSYSTEM->initialize(HISTORY_STORAGE_DIRECTORY)) {
        HISTORY_SUBSYSTEM.reset();
        return false;
    }

    m_initialized = true;
    return true;
}

void ClipboardManager::shutdown() {
    if (!m_initialized) {
        return;
    }
    
    if (HISTORY_SUBSYSTEM) {
        HISTORY_SUBSYSTEM->shutdown();
        HISTORY_SUBSYSTEM.reset();
    }

    m_initialized = false;
}

bool ClipboardManager::isInitialized() const {
    return m_initialized;
}

}

bool pasty_history_ingest_text(const char* text, const char* source_app_id) {
    if (!pasty::HISTORY_SUBSYSTEM) {
        return false;
    }

    pasty::ClipboardHistoryIngestEvent event;
    event.timestampMs = pasty::nowMs();
    event.sourceAppId = pasty::fromCString(source_app_id);
    event.itemType = pasty::ClipboardItemType::Text;
    event.text = pasty::fromCString(text);
    return pasty::HISTORY_SUBSYSTEM->ingest(event);
}

bool pasty_history_ingest_image(const unsigned char* bytes, unsigned long byte_count, int width, int height, const char* format_hint, const char* source_app_id) {
    if (!pasty::HISTORY_SUBSYSTEM || bytes == nullptr || byte_count == 0) {
        return false;
    }

    pasty::ClipboardHistoryIngestEvent event;
    event.timestampMs = pasty::nowMs();
    event.sourceAppId = pasty::fromCString(source_app_id);
    event.itemType = pasty::ClipboardItemType::Image;
    event.image.width = width;
    event.image.height = height;
    event.image.formatHint = pasty::fromCString(format_hint);
    event.image.bytes.assign(bytes, bytes + byte_count);
    return pasty::HISTORY_SUBSYSTEM->ingest(event);
}

const char* pasty_history_list_json(int limit) {
    static std::string payload;
    if (!pasty::HISTORY_SUBSYSTEM) {
        payload = "[]";
        return payload.c_str();
    }

    const auto result = pasty::HISTORY_SUBSYSTEM->list(limit, std::string());
    std::ostringstream stream;
    stream << "[";
    for (std::size_t index = 0; index < result.items.size(); ++index) {
        const auto& item = result.items[index];
        if (index > 0) {
            stream << ",";
        }
        stream << "{";
        stream << "\"id\":\"" << pasty::escapeJson(item.id) << "\",";
        stream << "\"type\":\"" << (item.type == pasty::ClipboardItemType::Image ? "image" : "text") << "\",";
        stream << "\"content\":\"" << pasty::escapeJson(item.content) << "\",";
        stream << "\"imagePath\":\"" << pasty::escapeJson(item.imagePath) << "\",";
        stream << "\"imageWidth\":" << item.imageWidth << ",";
        stream << "\"imageHeight\":" << item.imageHeight << ",";
        stream << "\"imageFormat\":\"" << pasty::escapeJson(item.imageFormat) << "\",";
        stream << "\"createTimeMs\":" << item.createTimeMs << ",";
        stream << "\"updateTimeMs\":" << item.updateTimeMs << ",";
        stream << "\"lastCopyTimeMs\":" << item.lastCopyTimeMs << ",";
        stream << "\"sourceAppId\":\"" << pasty::escapeJson(item.sourceAppId) << "\"";
        stream << "}";
    }
    stream << "]";
    payload = stream.str();
    return payload.c_str();
}

bool pasty_history_delete(const char* id) {
    if (!pasty::HISTORY_SUBSYSTEM || id == nullptr) {
        return false;
    }
    return pasty::HISTORY_SUBSYSTEM->deleteById(std::string(id));
}

void pasty_history_set_storage_directory(const char* path) {
    if (path == nullptr) {
        return;
    }
    pasty::HISTORY_STORAGE_DIRECTORY = std::string(path);
}
