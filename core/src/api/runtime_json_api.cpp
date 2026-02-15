// Pasty - Copyright (c) 2026. MIT License.

#include "runtime_json_api.h"

#include "../common/logger.h"
#include "../runtime/core_runtime.h"
#include "../utils/runtime_json_utils.h"

#include <mutex>
#include <optional>
#include <string>
#include <cstring>

#include "../thirdparty/nlohmann/json.hpp"

#include <sodium.h>

namespace {

struct PastyRuntime {
    mutable std::mutex mutex;
    pasty::CoreRuntimeConfig config;
    std::unique_ptr<pasty::CoreRuntime> runtime;

    PastyRuntime()
        : config()
        , runtime(nullptr) {
    }
};

PastyRuntime* castRuntime(pasty_runtime_ref runtime_ref) {
    return reinterpret_cast<PastyRuntime*>(runtime_ref);
}

pasty::ClipboardService* clipboardService(PastyRuntime* runtime) {
    if (runtime == nullptr || !runtime->runtime || !runtime->runtime->isStarted()) {
        return nullptr;
    }
    return runtime->runtime->clipboardService();
}

bool parseBoolSetting(const std::string& value, bool* parsed) {
    if (parsed == nullptr) {
        return false;
    }

    if (value == "1" || value == "true" || value == "TRUE" || value == "yes" || value == "YES") {
        *parsed = true;
        return true;
    }
    if (value == "0" || value == "false" || value == "FALSE" || value == "no" || value == "NO") {
        *parsed = false;
        return true;
    }
    return false;
}

std::string serializeCloudSyncStatus(const pasty::CloudSyncStatus& status) {
    using Json = nlohmann::json;

    Json json;
    json["enabled"] = status.enabled;
    json["rootPath"] = status.rootPath;
    json["includeSensitive"] = status.includeSensitive;
    json["deviceId"] = status.deviceId;
    json["stateFileErrorCount"] = status.stateFileErrorCount;
    json["e2eeEnabled"] = status.e2eeEnabled;
    json["e2eeKeyId"] = status.e2eeKeyId;

    Json lastImport;
    lastImport["eventsProcessed"] = status.lastImport.eventsProcessed;
    lastImport["eventsApplied"] = status.lastImport.eventsApplied;
    lastImport["eventsSkipped"] = status.lastImport.eventsSkipped;
    lastImport["errors"] = status.lastImport.errors;
    lastImport["success"] = status.lastImport.success;
    json["lastImport"] = lastImport;

    return json.dump();
}

} // namespace

extern "C" {

pasty_runtime_ref pasty_runtime_create(void) {
    return reinterpret_cast<pasty_runtime_ref>(new PastyRuntime());
}

void pasty_runtime_destroy(pasty_runtime_ref runtime_ref) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr) {
        return;
    }

    {
        std::lock_guard<std::mutex> lock(runtime->mutex);
        if (runtime->runtime) {
            runtime->runtime->stop();
            runtime->runtime.reset();
        }
    }

    delete runtime;
}

bool pasty_runtime_start(
    pasty_runtime_ref runtime_ref,
    const char* storage_directory,
    const char* migration_directory,
    int default_max_history_count
) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || storage_directory == nullptr || default_max_history_count <= 0) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);

    runtime->config.storageDirectory = storage_directory;
    runtime->config.migrationDirectory = pasty::runtime_json_utils::fromCString(migration_directory);
    runtime->config.defaultMaxHistoryCount = default_max_history_count;

    if (runtime->runtime) {
        runtime->runtime->stop();
        runtime->runtime.reset();
    }

    runtime->runtime = std::make_unique<pasty::CoreRuntime>(runtime->config);
    if (!runtime->runtime->start()) {
        runtime->runtime.reset();
        return false;
    }

    return true;
}

void pasty_runtime_stop(pasty_runtime_ref runtime_ref) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr) {
        return;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    if (!runtime->runtime) {
        return;
    }

    runtime->runtime->stop();
    runtime->runtime.reset();
}

bool pasty_runtime_is_started(pasty_runtime_ref runtime_ref) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    return runtime->runtime && runtime->runtime->isStarted();
}

bool pasty_runtime_set_max_history_count(pasty_runtime_ref runtime_ref, int max_count) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || max_count <= 0) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    runtime->config.defaultMaxHistoryCount = max_count;

    if (!runtime->runtime) {
        return true;
    }

    return runtime->runtime->setMaxHistoryCount(max_count);
}

int pasty_runtime_get_max_history_count(pasty_runtime_ref runtime_ref) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr) {
        return 0;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    if (!runtime->runtime) {
        return runtime->config.defaultMaxHistoryCount;
    }

    return runtime->runtime->getMaxHistoryCount();
}

void pasty_settings_initialize(pasty_runtime_ref runtime_ref, int max_history_count) {
    if (runtime_ref == nullptr) {
        return;
    }
    pasty_runtime_set_max_history_count(runtime_ref, max_history_count);
}

void pasty_settings_update(pasty_runtime_ref runtime_ref, const char* key, const char* value) {
    if (runtime_ref == nullptr || key == nullptr || value == nullptr) {
        return;
    }

    const std::string keyValue(key);
    const std::string rawValue(value);
    if (keyValue == "history.maxCount") {
        try {
            const int count = std::stoi(rawValue);
            pasty_runtime_set_max_history_count(runtime_ref, count);
        } catch (...) {
        }
        return;
    }

    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr) {
        return;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);

    if (keyValue == "cloudSync.enabled") {
        bool enabled = false;
        if (!parseBoolSetting(rawValue, &enabled)) {
            return;
        }
        runtime->config.cloudSyncEnabled = enabled;
        if (runtime->runtime) {
            runtime->runtime->setCloudSyncEnabled(enabled);
        }
        return;
    }

    if (keyValue == "cloudSync.rootPath") {
        runtime->config.cloudSyncRootPath = rawValue;
        if (runtime->runtime) {
            runtime->runtime->setCloudSyncRootPath(rawValue);
        }
        return;
    }

    if (keyValue == "cloudSync.includeSensitive") {
        bool includeSensitive = false;
        if (!parseBoolSetting(rawValue, &includeSensitive)) {
            return;
        }
        runtime->config.cloudSyncIncludeSensitive = includeSensitive;
        if (runtime->runtime) {
            runtime->runtime->setCloudSyncIncludeSensitive(includeSensitive);
        }
    }

    if (keyValue == "cloudSync.includeSourceAppId") {
        bool includeSourceAppId = false;
        if (!parseBoolSetting(rawValue, &includeSourceAppId)) {
            return;
        }
        runtime->config.cloudSyncIncludeSourceAppId = includeSourceAppId;
        if (runtime->runtime) {
            runtime->runtime->setCloudSyncIncludeSourceAppId(includeSourceAppId);
        }
    }
}

int pasty_settings_get_max_history_count(pasty_runtime_ref runtime_ref) {
    if (runtime_ref == nullptr) {
        return 0;
    }
    return pasty_runtime_get_max_history_count(runtime_ref);
}

bool pasty_cloud_sync_import_now(pasty_runtime_ref runtime_ref) {
    PASTY_LOG_DEBUG("Core.CAPI", "pasty_cloud_sync_import_now() called");
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    if (!runtime->runtime) {
        return false;
    }

    return runtime->runtime->runCloudSyncImport();
}

bool pasty_cloud_sync_get_status_json(pasty_runtime_ref runtime_ref, char** out_json) {
    PASTY_LOG_DEBUG("Core.CAPI", "pasty_cloud_sync_get_status_json() called");
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || out_json == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    if (!runtime->runtime) {
        pasty::CloudSyncStatus status;
        status.enabled = runtime->config.cloudSyncEnabled;
        status.rootPath = runtime->config.cloudSyncRootPath;
        status.includeSensitive = runtime->config.cloudSyncIncludeSensitive;
        *out_json = pasty::runtime_json_utils::copyString(serializeCloudSyncStatus(status));
        return true;
    }

    *out_json = pasty::runtime_json_utils::copyString(
        serializeCloudSyncStatus(runtime->runtime->cloudSyncStatus())
    );
    return true;
}

bool pasty_cloud_sync_e2ee_initialize(pasty_runtime_ref runtime_ref, const char* passphrase) {
    PASTY_LOG_DEBUG("Core.CAPI", "pasty_cloud_sync_e2ee_initialize() called, passphrase length: %zu",
        passphrase ? strlen(passphrase) : 0);
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || passphrase == nullptr || passphrase[0] == '\0') {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    if (!runtime->runtime || !runtime->runtime->isStarted()) {
        return false;
    }

    std::string passphraseBuffer(passphrase);
    if (passphraseBuffer.empty()) {
        return false;
    }

    const bool initialized = runtime->runtime->initializeCloudSyncE2ee(passphraseBuffer);
    sodium_memzero(passphraseBuffer.data(), passphraseBuffer.size());
    return initialized;
}

void pasty_cloud_sync_e2ee_clear(pasty_runtime_ref runtime_ref) {
    PASTY_LOG_DEBUG("Core.CAPI", "pasty_cloud_sync_e2ee_clear() called");
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr) {
        return;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    if (!runtime->runtime) {
        return;
    }

    runtime->runtime->clearCloudSyncE2eeKey();
}

bool pasty_history_ingest_text(pasty_runtime_ref runtime_ref, const char* text, const char* source_app_id) {
    return pasty_history_ingest_text_with_result(runtime_ref, text, source_app_id, nullptr);
}

bool pasty_history_ingest_text_with_result(
    pasty_runtime_ref runtime_ref,
    const char* text,
    const char* source_app_id,
    bool* out_inserted
) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    auto* service = clipboardService(runtime);
    if (service == nullptr) {
        return false;
    }

    pasty::ClipboardHistoryIngestEvent event;
    event.timestampMs = pasty::runtime_json_utils::nowMs();
    event.sourceAppId = pasty::runtime_json_utils::fromCString(source_app_id);
    event.itemType = pasty::ClipboardItemType::Text;
    event.text = pasty::runtime_json_utils::fromCString(text);
    const pasty::ClipboardIngestResult result = service->ingestWithResult(event);
    if (runtime->runtime) {
        runtime->runtime->exportLocalTextIngest(event, result.inserted);
    }
    if (out_inserted != nullptr) {
        *out_inserted = result.inserted;
    }
    return result.ok;
}

bool pasty_history_ingest_image(
    pasty_runtime_ref runtime_ref,
    const unsigned char* bytes,
    unsigned long byte_count,
    int width,
    int height,
    const char* format_hint,
    const char* source_app_id
) {
    return pasty_history_ingest_image_with_result(
        runtime_ref,
        bytes,
        byte_count,
        width,
        height,
        format_hint,
        source_app_id,
        nullptr
    );
}

bool pasty_history_ingest_image_with_result(
    pasty_runtime_ref runtime_ref,
    const unsigned char* bytes,
    unsigned long byte_count,
    int width,
    int height,
    const char* format_hint,
    const char* source_app_id,
    bool* out_inserted
) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || bytes == nullptr || byte_count == 0) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    auto* service = clipboardService(runtime);
    if (service == nullptr) {
        return false;
    }

    pasty::ClipboardHistoryIngestEvent event;
    event.timestampMs = pasty::runtime_json_utils::nowMs();
    event.sourceAppId = pasty::runtime_json_utils::fromCString(source_app_id);
    event.itemType = pasty::ClipboardItemType::Image;
    event.image.width = width;
    event.image.height = height;
    event.image.formatHint = pasty::runtime_json_utils::fromCString(format_hint);
    event.image.bytes.assign(bytes, bytes + byte_count);
    const pasty::ClipboardIngestResult result = service->ingestWithResult(event);
    if (runtime->runtime) {
        runtime->runtime->exportLocalImageIngest(event, result.inserted);
    }
    if (out_inserted != nullptr) {
        *out_inserted = result.inserted;
    }
    return result.ok;
}

bool pasty_history_list_json(pasty_runtime_ref runtime_ref, int limit, char** out_json) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || out_json == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    auto* service = clipboardService(runtime);
    if (service == nullptr) {
        return false;
    }

    const auto result = service->list(limit, std::string());
    *out_json = pasty::runtime_json_utils::copyString(
        pasty::runtime_json_utils::serializeItemsToJson(result.items)
    );
    return true;
}

bool pasty_history_search(
    pasty_runtime_ref runtime_ref,
    const char* query,
    int limit,
    int preview_length,
    const char* content_type,
    bool include_ocr,
    char** out_json
) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || out_json == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    auto* service = clipboardService(runtime);
    if (service == nullptr) {
        return false;
    }

    pasty::SearchOptions options;
    options.query = pasty::runtime_json_utils::fromCString(query);
    options.limit = limit > 0 ? limit : 100;
    options.previewLength = preview_length > 0 ? static_cast<std::size_t>(preview_length) : 200;
    const std::string requestedContentType = pasty::runtime_json_utils::fromCString(content_type);
    options.contentType = (requestedContentType == "text" || requestedContentType == "image") ? requestedContentType : std::string();
    options.includeOcr = include_ocr;

    const std::vector<pasty::ClipboardHistoryItem> items = service->search(options);
    *out_json = pasty::runtime_json_utils::copyString(
        pasty::runtime_json_utils::serializeItemsToJson(items)
    );
    return true;
}

bool pasty_history_get_pending_ocr_images(pasty_runtime_ref runtime_ref, int limit, char** out_json) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || out_json == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    auto* service = clipboardService(runtime);
    if (service == nullptr) {
        return false;
    }

    const std::vector<pasty::OcrTask> tasks = service->getPendingOcrImages(limit);
    *out_json = pasty::runtime_json_utils::copyString(
        pasty::runtime_json_utils::serializeOcrTasks(tasks)
    );
    return true;
}

bool pasty_history_get_next_ocr_task(pasty_runtime_ref runtime_ref, char** out_json) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || out_json == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    auto* service = clipboardService(runtime);
    if (service == nullptr) {
        return false;
    }

    const std::optional<pasty::OcrTask> task = service->getNextOcrTask();
    if (!task) {
        *out_json = nullptr;
        return true;
    }

    *out_json = pasty::runtime_json_utils::copyString(
        pasty::runtime_json_utils::serializeOcrTask(*task)
    );
    return true;
}

bool pasty_history_ocr_mark_processing(pasty_runtime_ref runtime_ref, const char* id) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || id == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    auto* service = clipboardService(runtime);
    if (service == nullptr) {
        return false;
    }

    return service->markOcrProcessing(pasty::runtime_json_utils::fromCString(id));
}

bool pasty_history_ocr_success(pasty_runtime_ref runtime_ref, const char* id, const char* ocr_text) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || id == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    auto* service = clipboardService(runtime);
    if (service == nullptr) {
        return false;
    }

    return service->updateOcrSuccess(
        pasty::runtime_json_utils::fromCString(id),
        pasty::runtime_json_utils::fromCString(ocr_text)
    );
}

bool pasty_history_ocr_failed(pasty_runtime_ref runtime_ref, const char* id) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || id == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    auto* service = clipboardService(runtime);
    if (service == nullptr) {
        return false;
    }

    return service->updateOcrFailed(pasty::runtime_json_utils::fromCString(id));
}

bool pasty_history_get_ocr_status(pasty_runtime_ref runtime_ref, const char* id, char** out_json) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || id == nullptr || out_json == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    auto* service = clipboardService(runtime);
    if (service == nullptr) {
        return false;
    }

    const std::optional<pasty::OcrTaskStatus> status = service->getOcrStatus(pasty::runtime_json_utils::fromCString(id));
    if (!status) {
        *out_json = nullptr;
        return true;
    }

    *out_json = pasty::runtime_json_utils::copyString(
        pasty::runtime_json_utils::serializeOcrStatus(*status)
    );
    return true;
}

bool pasty_history_get_json(pasty_runtime_ref runtime_ref, const char* id, char** out_json) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || id == nullptr || out_json == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    auto* service = clipboardService(runtime);
    if (service == nullptr) {
        return false;
    }

    const auto item = service->getById(pasty::runtime_json_utils::fromCString(id));
    if (!item) {
        *out_json = nullptr;
        return true;
    }

    *out_json = pasty::runtime_json_utils::copyString(
        pasty::runtime_json_utils::serializeItemToJson(*item)
    );
    return true;
}

bool pasty_history_get_tags(pasty_runtime_ref runtime_ref, const char* id, char** out_json) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || id == nullptr || out_json == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    auto* service = clipboardService(runtime);
    if (service == nullptr) {
        return false;
    }

    const std::vector<std::string> tags = service->getTags(pasty::runtime_json_utils::fromCString(id));

    using Json = nlohmann::json;
    Json json = tags;
    *out_json = pasty::runtime_json_utils::copyString(json.dump());
    return true;
}

bool pasty_history_set_tags(pasty_runtime_ref runtime_ref, const char* id, const char* tags_json) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || id == nullptr || tags_json == nullptr) {
        return false;
    }

    std::vector<std::string> tags;
    try {
        using Json = nlohmann::json;
        const Json json = Json::parse(tags_json);
        if (json.is_array()) {
            for (const auto& tag : json) {
                if (tag.is_string()) {
                    tags.push_back(tag.get<std::string>());
                }
            }
        }
    } catch (...) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    auto* service = clipboardService(runtime);
    if (service == nullptr) {
        return false;
    }

    const std::string itemId = pasty::runtime_json_utils::fromCString(id);
    const bool success = service->setTags(itemId, tags);

    if (success && runtime->runtime) {
        auto item = service->getById(itemId);
        if (item.has_value()) {
            runtime->runtime->exportLocalTags(*item, tags);
        }
    }

    return success;
}

bool pasty_history_set_pinned(pasty_runtime_ref runtime_ref, const char* id, bool pinned) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || id == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    auto* service = clipboardService(runtime);
    if (service == nullptr) {
        return false;
    }

    const std::string itemId = pasty::runtime_json_utils::fromCString(id);
    const bool success = service->setPinned(itemId, pinned);

    if (success && runtime->runtime) {
        auto item = service->getById(itemId);
        if (item.has_value()) {
            runtime->runtime->exportLocalPinned(*item, pinned);
        }
    }

    return success;
}

void pasty_free_string(char* str) {
    delete[] str;
}

bool pasty_history_delete(pasty_runtime_ref runtime_ref, const char* id) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr || id == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    auto* service = clipboardService(runtime);
    if (service == nullptr) {
        return false;
    }

    const std::optional<pasty::ClipboardHistoryItem> existingItem = service->getById(std::string(id));
    const bool deleted = service->deleteById(std::string(id));
    if (deleted && existingItem.has_value() && runtime->runtime) {
        runtime->runtime->exportLocalDelete(*existingItem, deleted);
    }
    return deleted;
}

bool pasty_history_enforce_retention(pasty_runtime_ref runtime_ref, int maxCount) {
    PastyRuntime* runtime = castRuntime(runtime_ref);
    if (runtime == nullptr) {
        return false;
    }

    std::lock_guard<std::mutex> lock(runtime->mutex);
    auto* service = clipboardService(runtime);
    if (service == nullptr) {
        return false;
    }

    return service->enforceRetention(maxCount);
}

} // extern "C"
