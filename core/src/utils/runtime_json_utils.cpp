#include "utils/runtime_json_utils.h"

#include <chrono>
#include <cstring>

#include <nlohmann/json.hpp>

namespace pasty::runtime_json_utils {

namespace {

const char* ocrStatusToString(OcrStatus status) {
    switch (status) {
        case OcrStatus::Pending: return "pending";
        case OcrStatus::Processing: return "processing";
        case OcrStatus::Completed: return "completed";
        case OcrStatus::Failed: return "failed";
    }
    return "pending";
}

using Json = nlohmann::json;

Json itemToJson(const ClipboardHistoryItem& item) {
    Json value = {
        {"id", item.id},
        {"type", item.type == ClipboardItemType::Image ? "image" : "text"},
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

    if (item.type == ClipboardItemType::Image) {
        value["ocrStatus"] = ocrStatusToString(item.ocrStatus);
        if (!item.ocrText.empty()) {
            value["ocrText"] = item.ocrText;
        }
    }

    return value;
}

} // namespace

std::int64_t nowMs() {
    const auto now = std::chrono::system_clock::now();
    return static_cast<std::int64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()).count());
}

std::string fromCString(const char* text) {
    return text == nullptr ? std::string() : std::string(text);
}

char* copyString(const std::string& str) {
    char* buffer = new char[str.size() + 1];
    std::memcpy(buffer, str.c_str(), str.size() + 1);
    return buffer;
}

std::string serializeItemsToJson(const std::vector<ClipboardHistoryItem>& items) {
    Json payload = Json::array();
    for (const auto& item : items) {
        payload.push_back(itemToJson(item));
    }
    return payload.dump();
}

std::string serializeOcrTask(const OcrTask& task) {
    Json value = {
        {"id", task.id},
        {"imagePath", task.imagePath},
        {"retryCount", task.retryCount},
        {"lastCopyTimeMs", task.lastCopyTimeMs},
    };
    return value.dump();
}

std::string serializeOcrTasks(const std::vector<OcrTask>& tasks) {
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

std::string serializeOcrStatus(const OcrTaskStatus& status) {
    Json value = {
        {"ocrStatus", ocrStatusToString(status.status)},
        {"ocrText", status.text.empty() ? Json(nullptr) : Json(status.text)},
    };
    return value.dump();
}

std::string serializeItemToJson(const ClipboardHistoryItem& item) {
    return itemToJson(item).dump();
}

} // namespace pasty::runtime_json_utils
