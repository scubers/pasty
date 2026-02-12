// Pasty - Copyright (c) 2026. MIT License.

#include <pasty/pasty.h>
#include <pasty/history/history.h>
#include <pasty/history/store.h>

#include <chrono>
#include <cstdint>
#include <cstring>
#include <memory>
#include <optional>
#include <vector>

#include <nlohmann/json.hpp>

namespace pasty {

static const char* VERSION = "0.1.0";
static const char* APP_NAME = "Pasty";
static std::string HISTORY_STORAGE_DIRECTORY = "./build/history";
static std::unique_ptr<ClipboardHistory> HISTORY_SUBSYSTEM;

static std::int64_t nowMs() {
    const auto now = std::chrono::system_clock::now();
    return static_cast<std::int64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count());
}

static std::string fromCString(const char* text) {
    return text == nullptr ? std::string() : std::string(text);
}

static const char* ocrStatusToString(pasty::OcrStatus status) {
    switch (status) {
        case pasty::OcrStatus::Pending: return "pending";
        case pasty::OcrStatus::Processing: return "processing";
        case pasty::OcrStatus::Completed: return "completed";
        case pasty::OcrStatus::Failed: return "failed";
    }
    return "pending";
}

using Json = nlohmann::json;

static Json itemToJson(const ClipboardHistoryItem& item) {
    Json value = {
        {"id", item.id},
        {"type", item.type == pasty::ClipboardItemType::Image ? "image" : "text"},
        {"content", item.content},
        {"imagePath", item.imagePath},
        {"imageWidth", item.imageWidth},
        {"imageHeight", item.imageHeight},
        {"imageFormat", item.imageFormat},
        {"createTimeMs", item.createTimeMs},
        {"updateTimeMs", item.updateTimeMs},
        {"lastCopyTimeMs", item.lastCopyTimeMs},
        {"sourceAppId", item.sourceAppId},
        {"contentHash", item.contentHash},
        {"metadata", item.metadata},
        {"ocrStatus", nullptr},
        {"ocrText", nullptr},
    };

    if (item.type == pasty::ClipboardItemType::Image) {
        value["ocrStatus"] = ocrStatusToString(item.ocrStatus);
        if (!item.ocrText.empty()) {
            value["ocrText"] = item.ocrText;
        }
    }

    return value;
}

static std::string serializeItemsToJson(const std::vector<ClipboardHistoryItem>& items) {
    Json payload = Json::array();
    for (const auto& item : items) {
        payload.push_back(itemToJson(item));
    }
    return payload.dump();
}

static std::string serializeOcrTask(const pasty::OcrTask& task) {
    Json value = {
        {"id", task.id},
        {"imagePath", task.imagePath},
        {"retryCount", task.retryCount},
        {"lastCopyTimeMs", task.lastCopyTimeMs},
    };
    return value.dump();
}

static std::string serializeOcrTasks(const std::vector<pasty::OcrTask>& tasks) {
    Json payload = Json::array();
    for (const auto& task : tasks) {
        payload.push_back(Json{
            {"id", task.id},
            {"imagePath", task.imagePath},
            {"retryCount", task.retryCount},
            {"lastCopyTimeMs", task.lastCopyTimeMs},
        });
    }
    return payload.dump();
}

static std::string serializeOcrStatus(const pasty::OcrTaskStatus& status) {
    Json value = {
        {"ocrStatus", ocrStatusToString(status.status)},
        {"ocrText", status.text.empty() ? Json(nullptr) : Json(status.text)},
    };
    return value.dump();
}

static char* copyString(const std::string& str) {
    char* buffer = new char[str.size() + 1];
    std::memcpy(buffer, str.c_str(), str.size() + 1);
    return buffer;
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
    payload = pasty::serializeItemsToJson(result.items);
    return payload.c_str();
}

bool pasty_history_search(const char* query, int limit, int preview_length, const char* content_type, bool include_ocr, char** out_json) {
    if (!pasty::HISTORY_SUBSYSTEM || out_json == nullptr) {
        return false;
    }

    pasty::SearchOptions options;
    options.query = pasty::fromCString(query);
    options.limit = limit > 0 ? limit : 100;
    options.previewLength = preview_length > 0 ? static_cast<std::size_t>(preview_length) : 200;
    const std::string requestedContentType = pasty::fromCString(content_type);
    const std::string sanitizedContentType = (requestedContentType == "text" || requestedContentType == "image") ? requestedContentType : std::string();
    options.contentType = sanitizedContentType;
    options.includeOcr = include_ocr;

    std::vector<pasty::ClipboardHistoryItem> items = pasty::HISTORY_SUBSYSTEM->search(options);
    std::string json = pasty::serializeItemsToJson(items);

    *out_json = pasty::copyString(json);
    return true;
}

bool pasty_history_get_pending_ocr_images(int limit, char** out_json) {
    if (!pasty::HISTORY_SUBSYSTEM || out_json == nullptr) {
        return false;
    }

    const std::vector<pasty::OcrTask> tasks = pasty::HISTORY_SUBSYSTEM->getPendingOcrImages(limit);
    *out_json = pasty::copyString(pasty::serializeOcrTasks(tasks));
    return true;
}

bool pasty_history_get_next_ocr_task(char** out_json) {
    if (!pasty::HISTORY_SUBSYSTEM || out_json == nullptr) {
        return false;
    }

    const std::optional<pasty::OcrTask> task = pasty::HISTORY_SUBSYSTEM->getNextOcrTask();
    if (!task) {
        *out_json = nullptr;
        return true;
    }

    *out_json = pasty::copyString(pasty::serializeOcrTask(*task));
    return true;
}

bool pasty_history_ocr_mark_processing(const char* id) {
    if (!pasty::HISTORY_SUBSYSTEM || id == nullptr) {
        return false;
    }

    return pasty::HISTORY_SUBSYSTEM->markOcrProcessing(pasty::fromCString(id));
}

bool pasty_history_ocr_success(const char* id, const char* ocr_text) {
    if (!pasty::HISTORY_SUBSYSTEM || id == nullptr) {
        return false;
    }

    return pasty::HISTORY_SUBSYSTEM->updateOcrSuccess(pasty::fromCString(id), pasty::fromCString(ocr_text));
}

bool pasty_history_ocr_failed(const char* id) {
    if (!pasty::HISTORY_SUBSYSTEM || id == nullptr) {
        return false;
    }

    return pasty::HISTORY_SUBSYSTEM->updateOcrFailed(pasty::fromCString(id));
}

bool pasty_history_get_ocr_status(const char* id, char** out_json) {
    if (!pasty::HISTORY_SUBSYSTEM || id == nullptr || out_json == nullptr) {
        return false;
    }

    const std::optional<pasty::OcrTaskStatus> status = pasty::HISTORY_SUBSYSTEM->getOcrStatus(pasty::fromCString(id));
    if (!status) {
        *out_json = nullptr;
        return true;
    }

    *out_json = pasty::copyString(pasty::serializeOcrStatus(*status));
    return true;
}

char* pasty_history_get_json(const char* id) {
    if (!pasty::HISTORY_SUBSYSTEM || id == nullptr) {
        return nullptr;
    }

    auto item = pasty::HISTORY_SUBSYSTEM->getById(pasty::fromCString(id));
    if (!item) {
        return nullptr;
    }

    return pasty::copyString(pasty::itemToJson(*item).dump());
}

void pasty_free_string(char* str) {
    delete[] str;
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

bool pasty_history_enforce_retention(int maxCount) {
    if (!pasty::HISTORY_SUBSYSTEM) {
        return false;
    }
    return pasty::HISTORY_SUBSYSTEM->enforceRetention(maxCount);
}
