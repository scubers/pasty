// Pasty2 - Copyright (c) 2026. MIT License.

#include <pasty/history/store.h>

#include <cstddef>
#include <chrono>
#include <cstdio>
#include <cerrno>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iostream>
#include <algorithm>
#include <sstream>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <optional>
#include <mutex>
#include <sqlite3.h>

namespace pasty {

namespace {

bool ensureDirectoryExists(const std::string& path) {
    if (path.empty()) {
        return false;
    }
    std::error_code ec;
    std::filesystem::create_directories(path, ec);
    return !ec;
}

void logStoreMessage(const std::string& message) {
    std::cerr << "[core.store] " << message << std::endl;
}

std::string truncateUtf8(const std::string& value, std::size_t maxCodePoints) {
    if (maxCodePoints == 0 || value.empty()) {
        return std::string();
    }

    std::size_t index = 0;
    std::size_t codePoints = 0;
    while (index < value.size() && codePoints < maxCodePoints) {
        const unsigned char lead = static_cast<unsigned char>(value[index]);
        std::size_t charLength = 1;
        if ((lead & 0x80) == 0x00) {
            charLength = 1;
        } else if ((lead & 0xE0) == 0xC0) {
            charLength = 2;
        } else if ((lead & 0xF0) == 0xE0) {
            charLength = 3;
        } else if ((lead & 0xF8) == 0xF0) {
            charLength = 4;
        }

        if (index + charLength > value.size()) {
            break;
        }

        index += charLength;
        ++codePoints;
    }

    return value.substr(0, index);
}

OcrStatus ocrStatusFromInt(int value) {
    switch (value) {
        case 1: return OcrStatus::Processing;
        case 2: return OcrStatus::Completed;
        case 3: return OcrStatus::Failed;
        default: return OcrStatus::Pending;
    }
}

int ocrStatusToInt(OcrStatus status) {
    return static_cast<int>(status);
}

class SQLiteClipboardHistoryStore final : public ClipboardHistoryStore {
public:
    SQLiteClipboardHistoryStore()
        : m_db(nullptr)
        , m_itemsLimit(1000) {
    }

    ~SQLiteClipboardHistoryStore() override {
        close();
    }

    bool open(const std::string& baseDirectory) override {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_db != nullptr) {
            return true;
        }

        m_baseDirectory = baseDirectory;
        m_assetsDirectory = m_baseDirectory + "/images";
        m_dbPath = m_baseDirectory + "/history.sqlite3";

        if (!ensureDirectoryExists(m_baseDirectory)) {
            logStoreMessage("failed to ensure base directory");
            return false;
        }
        if (!ensureDirectoryExists(m_assetsDirectory)) {
            logStoreMessage("failed to ensure assets directory");
            return false;
        }

        const int openResult = sqlite3_open_v2(
            m_dbPath.c_str(),
            &m_db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
            nullptr
        );
        if (openResult != SQLITE_OK || m_db == nullptr) {
            closeUnlocked();
            return recreateFromCorruption();
        }

        if (migrateSchema()) {
            logStoreMessage("open + migrate succeeded");
            return true;
        }

        closeUnlocked();
        return recreateFromCorruption();
    }

    void close() override {
        std::lock_guard<std::mutex> lock(m_mutex);
        closeUnlocked();
    }

    std::string upsertTextItem(const ClipboardHistoryItem& item) override {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_db == nullptr || item.id.empty()) {
            return std::string();
        }

        sqlite3_stmt* statement = nullptr;
        const char* sql =
            "INSERT INTO items ("
            "id, type, content, image_path, image_width, image_height, image_format, "
            "create_time_ms, update_time_ms, last_copy_time_ms, source_app_id, content_hash, metadata, "
            "ocr_status, ocr_text, ocr_retry_count, ocr_next_retry_at"
            ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
            "ON CONFLICT(type, content_hash) DO UPDATE SET "
            "content=excluded.content, "
            "update_time_ms=excluded.update_time_ms, "
            "last_copy_time_ms=excluded.last_copy_time_ms, "
            "source_app_id=excluded.source_app_id,"
            "metadata=excluded.metadata;";

        if (sqlite3_prepare_v2(m_db, sql, -1, &statement, nullptr) != SQLITE_OK) {
            return std::string();
        }

        bindCommonItemFields(statement, item, false);

        const bool ok = sqlite3_step(statement) == SQLITE_DONE;
        sqlite3_finalize(statement);

        if (!ok) {
            logStoreMessage("upsert text failed");
            return std::string();
        }

        enforceRetentionUnlocked(m_itemsLimit);
        logStoreMessage("upsert text succeeded");
        return item.id;
    }

    std::string upsertImageItem(const ClipboardHistoryItem& item, const std::vector<std::uint8_t>& imageBytes) override {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_db == nullptr || item.id.empty() || imageBytes.empty()) {
            return std::string();
        }

        {
            sqlite3_stmt* existing = nullptr;
            const char* existingSql = "SELECT id FROM items WHERE type='image' AND content_hash = ?1 LIMIT 1;";
            if (sqlite3_prepare_v2(m_db, existingSql, -1, &existing, nullptr) == SQLITE_OK) {
                sqlite3_bind_text(existing, 1, item.contentHash.c_str(), -1, SQLITE_TRANSIENT);
                if (sqlite3_step(existing) == SQLITE_ROW) {
                    const std::string existingId = readTextColumn(existing, 0);
                    sqlite3_finalize(existing);

                    sqlite3_stmt* update = nullptr;
                    const char* updateSql =
                        "UPDATE items "
                        "SET update_time_ms = ?1, last_copy_time_ms = ?2, source_app_id = ?3, metadata = ?5 "
                        "WHERE id = ?4;";
                    if (sqlite3_prepare_v2(m_db, updateSql, -1, &update, nullptr) != SQLITE_OK) {
                        logStoreMessage("upsert image dedupe update prepare failed");
                        return std::string();
                    }
                    sqlite3_bind_int64(update, 1, item.updateTimeMs);
                    sqlite3_bind_int64(update, 2, item.lastCopyTimeMs);
                    sqlite3_bind_text(update, 3, item.sourceAppId.c_str(), -1, SQLITE_TRANSIENT);
                    sqlite3_bind_text(update, 4, existingId.c_str(), -1, SQLITE_TRANSIENT);
                    sqlite3_bind_text(update, 5, item.metadata.c_str(), -1, SQLITE_TRANSIENT);
                    const bool updated = sqlite3_step(update) == SQLITE_DONE;
                    sqlite3_finalize(update);
                    if (!updated) {
                        logStoreMessage("upsert image dedupe update failed");
                        return std::string();
                    }
                    enforceRetentionUnlocked(m_itemsLimit);
                    logStoreMessage("upsert image dedupe hit");
                    return existingId;
                }
                sqlite3_finalize(existing);
            }
        }

        const std::string extension = normalizeImageExtension(item.imageFormat);
        const std::string relativePath = writeAssetAtomically(item.id, extension, imageBytes);
        if (relativePath.empty()) {
            return std::string();
        }

        sqlite3_stmt* statement = nullptr;
        const char* sql =
            "INSERT INTO items ("
            "id, type, content, image_path, image_width, image_height, image_format, "
            "create_time_ms, update_time_ms, last_copy_time_ms, source_app_id, content_hash, metadata, "
            "ocr_status, ocr_text, ocr_retry_count, ocr_next_retry_at"
            ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);";

        if (sqlite3_prepare_v2(m_db, sql, -1, &statement, nullptr) != SQLITE_OK) {
            deleteAsset(relativePath);
            return std::string();
        }

        bindCommonItemFields(statement, item, true, relativePath);

        const bool ok = sqlite3_step(statement) == SQLITE_DONE;
        sqlite3_finalize(statement);

        if (!ok) {
            deleteAsset(relativePath);
            logStoreMessage("upsert image insert failed");
            return std::string();
        }

        enforceRetentionUnlocked(m_itemsLimit);
        logStoreMessage("upsert image inserted");
        return item.id;
    }

    std::optional<ClipboardHistoryItem> getItem(const std::string& id) override {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_db == nullptr || id.empty()) {
            return std::nullopt;
        }

        sqlite3_stmt* statement = nullptr;
        const char* sql =
            "SELECT id, type, content, image_path, image_width, image_height, image_format, "
            "create_time_ms, update_time_ms, last_copy_time_ms, source_app_id, content_hash, metadata, "
            "ocr_status, ocr_text, ocr_retry_count, ocr_next_retry_at "
            "FROM items "
            "WHERE id = ?1;";

        if (sqlite3_prepare_v2(m_db, sql, -1, &statement, nullptr) != SQLITE_OK) {
            return std::nullopt;
        }

        sqlite3_bind_text(statement, 1, id.c_str(), -1, SQLITE_TRANSIENT);

        std::optional<ClipboardHistoryItem> result;
        if (sqlite3_step(statement) == SQLITE_ROW) {
            ClipboardHistoryItem item;
            item.id = readTextColumn(statement, 0);
            item.type = readTextColumn(statement, 1) == "image" ? ClipboardItemType::Image : ClipboardItemType::Text;
            item.content = readTextColumn(statement, 2);
            item.imagePath = readTextColumn(statement, 3);
            item.imageWidth = sqlite3_column_int(statement, 4);
            item.imageHeight = sqlite3_column_int(statement, 5);
            item.imageFormat = readTextColumn(statement, 6);
            item.createTimeMs = sqlite3_column_int64(statement, 7);
            item.updateTimeMs = sqlite3_column_int64(statement, 8);
            item.lastCopyTimeMs = sqlite3_column_int64(statement, 9);
            item.sourceAppId = readTextColumn(statement, 10);
            item.contentHash = readTextColumn(statement, 11);
            item.metadata = readTextColumn(statement, 12);
            item.ocrStatus = ocrStatusFromInt(sqlite3_column_int(statement, 13));
            item.ocrText = readTextColumn(statement, 14);
            item.ocrRetryCount = sqlite3_column_int(statement, 15);
            item.ocrNextRetryAtMs = sqlite3_column_int64(statement, 16);
            result = item;
        }

        sqlite3_finalize(statement);
        return result;
    }

    ClipboardHistoryListResult listItems(std::int32_t limit, const std::string& cursor) override {
        std::lock_guard<std::mutex> lock(m_mutex);
        ClipboardHistoryListResult result;
        if (m_db == nullptr) {
            return result;
        }

        const std::int32_t safeLimit = limit <= 0 ? 200 : (limit > 1000 ? 1000 : limit);
        const std::int64_t cursorTime = parseCursor(cursor);

        sqlite3_stmt* statement = nullptr;
        const char* sql =
            "SELECT id, type, content, image_path, image_width, image_height, image_format, "
            "create_time_ms, update_time_ms, last_copy_time_ms, source_app_id, content_hash, metadata, "
            "ocr_status, ocr_text, ocr_retry_count, ocr_next_retry_at "
            "FROM items "
            "WHERE (?1 = 0 OR last_copy_time_ms < ?1) "
            "ORDER BY last_copy_time_ms DESC "
            "LIMIT ?2;";

        if (sqlite3_prepare_v2(m_db, sql, -1, &statement, nullptr) != SQLITE_OK) {
            return result;
        }

        sqlite3_bind_int64(statement, 1, cursorTime);
        sqlite3_bind_int(statement, 2, safeLimit);

        while (sqlite3_step(statement) == SQLITE_ROW) {
            ClipboardHistoryItem item;
            item.id = readTextColumn(statement, 0);
            item.type = readTextColumn(statement, 1) == "image" ? ClipboardItemType::Image : ClipboardItemType::Text;
            item.content = readTextColumn(statement, 2);
            item.imagePath = readTextColumn(statement, 3);
            item.imageWidth = sqlite3_column_int(statement, 4);
            item.imageHeight = sqlite3_column_int(statement, 5);
            item.imageFormat = readTextColumn(statement, 6);
            item.createTimeMs = sqlite3_column_int64(statement, 7);
            item.updateTimeMs = sqlite3_column_int64(statement, 8);
            item.lastCopyTimeMs = sqlite3_column_int64(statement, 9);
            item.sourceAppId = readTextColumn(statement, 10);
            item.contentHash = readTextColumn(statement, 11);
            item.metadata = readTextColumn(statement, 12);
            item.ocrStatus = ocrStatusFromInt(sqlite3_column_int(statement, 13));
            item.ocrText = readTextColumn(statement, 14);
            item.ocrRetryCount = sqlite3_column_int(statement, 15);
            item.ocrNextRetryAtMs = sqlite3_column_int64(statement, 16);
            result.items.push_back(item);
        }

        sqlite3_finalize(statement);

        if (!result.items.empty()) {
            const auto& last = result.items.back();
            result.nextCursor = std::to_string(last.lastCopyTimeMs);
        }

        return result;
    }

    std::vector<ClipboardHistoryItem> search(const SearchOptions& options) override {
        std::lock_guard<std::mutex> lock(m_mutex);
        std::vector<ClipboardHistoryItem> results;
        if (m_db == nullptr) {
            return results;
        }

        std::string sql =
            "SELECT id, type, content, image_path, image_width, image_height, image_format, "
            "create_time_ms, update_time_ms, last_copy_time_ms, source_app_id, content_hash, metadata, "
            "ocr_status, ocr_text, ocr_retry_count, ocr_next_retry_at "
            "FROM items "
            "WHERE (COALESCE(content, '') LIKE ?1 OR COALESCE(ocr_text, '') LIKE ?1) ";

        if (!options.contentType.empty()) {
            sql += "AND type = ?3 ";
        }

        sql += "ORDER BY last_copy_time_ms DESC LIMIT ?2;";

        sqlite3_stmt* statement = nullptr;
        if (sqlite3_prepare_v2(m_db, sql.c_str(), -1, &statement, nullptr) != SQLITE_OK) {
            return results;
        }

        std::string pattern = "%" + options.query + "%";
        sqlite3_bind_text(statement, 1, pattern.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int(statement, 2, static_cast<int>(options.limit));

        if (!options.contentType.empty()) {
            sqlite3_bind_text(statement, 3, options.contentType.c_str(), -1, SQLITE_TRANSIENT);
        }

        const std::size_t previewLength = options.previewLength == 0 ? 200 : options.previewLength;
        while (sqlite3_step(statement) == SQLITE_ROW) {
            ClipboardHistoryItem item;
            item.id = readTextColumn(statement, 0);
            item.type = readTextColumn(statement, 1) == "image" ? ClipboardItemType::Image : ClipboardItemType::Text;
            item.content = readTextColumn(statement, 2);
            item.imagePath = readTextColumn(statement, 3);
            item.imageWidth = sqlite3_column_int(statement, 4);
            item.imageHeight = sqlite3_column_int(statement, 5);
            item.imageFormat = readTextColumn(statement, 6);
            item.createTimeMs = sqlite3_column_int64(statement, 7);
            item.updateTimeMs = sqlite3_column_int64(statement, 8);
            item.lastCopyTimeMs = sqlite3_column_int64(statement, 9);
            item.sourceAppId = readTextColumn(statement, 10);
            item.contentHash = readTextColumn(statement, 11);
            item.metadata = readTextColumn(statement, 12);
            item.ocrStatus = ocrStatusFromInt(sqlite3_column_int(statement, 13));
            item.ocrText = readTextColumn(statement, 14);
            item.ocrRetryCount = sqlite3_column_int(statement, 15);
            item.ocrNextRetryAtMs = sqlite3_column_int64(statement, 16);
            if (item.type == ClipboardItemType::Text && !item.content.empty()) {
                item.content = truncateUtf8(item.content, previewLength);
            }
            results.push_back(item);
        }

        sqlite3_finalize(statement);
        return results;
    }

    std::vector<OcrTask> getPendingOcrImages(std::int32_t limit, HistoryTimestampMs nowMs) override {
        std::lock_guard<std::mutex> lock(m_mutex);
        std::vector<OcrTask> results;
        if (m_db == nullptr) {
            return results;
        }

        const std::int32_t safeLimit = limit <= 0 ? 50 : (limit > 500 ? 500 : limit);
        sqlite3_stmt* statement = nullptr;
        const char* sql =
            "SELECT id, image_path, ocr_retry_count, last_copy_time_ms "
            "FROM items "
            "WHERE type = 'image' AND ocr_status = 0 AND ocr_next_retry_at <= ?1 "
            "ORDER BY last_copy_time_ms DESC LIMIT ?2;";

        if (sqlite3_prepare_v2(m_db, sql, -1, &statement, nullptr) != SQLITE_OK) {
            return results;
        }

        sqlite3_bind_int64(statement, 1, nowMs);
        sqlite3_bind_int(statement, 2, safeLimit);

        while (sqlite3_step(statement) == SQLITE_ROW) {
            OcrTask task;
            task.id = readTextColumn(statement, 0);
            task.imagePath = readTextColumn(statement, 1);
            task.retryCount = sqlite3_column_int(statement, 2);
            task.lastCopyTimeMs = sqlite3_column_int64(statement, 3);
            results.push_back(task);
        }

        sqlite3_finalize(statement);
        return results;
    }

    std::optional<OcrTask> getNextOcrTask(HistoryTimestampMs nowMs) override {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_db == nullptr) {
            return std::nullopt;
        }

        sqlite3_stmt* statement = nullptr;
        const char* sql =
            "SELECT id, image_path, ocr_retry_count, last_copy_time_ms "
            "FROM items "
            "WHERE type = 'image' AND ocr_status = 0 AND ocr_next_retry_at <= ?1 "
            "ORDER BY last_copy_time_ms DESC LIMIT 1;";

        if (sqlite3_prepare_v2(m_db, sql, -1, &statement, nullptr) != SQLITE_OK) {
            return std::nullopt;
        }

        sqlite3_bind_int64(statement, 1, nowMs);

        std::optional<OcrTask> result;
        if (sqlite3_step(statement) == SQLITE_ROW) {
            OcrTask task;
            task.id = readTextColumn(statement, 0);
            task.imagePath = readTextColumn(statement, 1);
            task.retryCount = sqlite3_column_int(statement, 2);
            task.lastCopyTimeMs = sqlite3_column_int64(statement, 3);
            result = task;
        }
        sqlite3_finalize(statement);
        return result;
    }

    bool markOcrProcessing(const std::string& id) override {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_db == nullptr || id.empty()) {
            return false;
        }

        sqlite3_stmt* statement = nullptr;
        const char* sql =
            "UPDATE items SET ocr_status = 1 "
            "WHERE id = ?1 AND type = 'image';";

        if (sqlite3_prepare_v2(m_db, sql, -1, &statement, nullptr) != SQLITE_OK) {
            return false;
        }

        sqlite3_bind_text(statement, 1, id.c_str(), -1, SQLITE_TRANSIENT);
        const bool ok = sqlite3_step(statement) == SQLITE_DONE && sqlite3_changes(m_db) > 0;
        sqlite3_finalize(statement);
        return ok;
    }

    bool updateOcrSuccess(const std::string& id, const std::string& ocrText) override {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_db == nullptr || id.empty()) {
            return false;
        }

        sqlite3_stmt* statement = nullptr;
        const char* sql =
            "UPDATE items "
            "SET ocr_text = ?1, ocr_status = 2, ocr_retry_count = 0, ocr_next_retry_at = 0 "
            "WHERE id = ?2 AND type = 'image';";

        if (sqlite3_prepare_v2(m_db, sql, -1, &statement, nullptr) != SQLITE_OK) {
            return false;
        }

        if (ocrText.empty()) {
            sqlite3_bind_null(statement, 1);
        } else {
            sqlite3_bind_text(statement, 1, ocrText.c_str(), -1, SQLITE_TRANSIENT);
        }
        sqlite3_bind_text(statement, 2, id.c_str(), -1, SQLITE_TRANSIENT);
        const bool ok = sqlite3_step(statement) == SQLITE_DONE && sqlite3_changes(m_db) > 0;
        sqlite3_finalize(statement);
        return ok;
    }

    bool updateOcrFailed(const std::string& id, HistoryTimestampMs nowMs) override {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_db == nullptr || id.empty()) {
            return false;
        }

        sqlite3_stmt* lookup = nullptr;
        const char* lookupSql =
            "SELECT ocr_retry_count FROM items WHERE id = ?1 AND type = 'image' LIMIT 1;";
        if (sqlite3_prepare_v2(m_db, lookupSql, -1, &lookup, nullptr) != SQLITE_OK) {
            return false;
        }

        sqlite3_bind_text(lookup, 1, id.c_str(), -1, SQLITE_TRANSIENT);
        if (sqlite3_step(lookup) != SQLITE_ROW) {
            sqlite3_finalize(lookup);
            return false;
        }
        const int retryCount = sqlite3_column_int(lookup, 0);
        sqlite3_finalize(lookup);

        const int nextRetryCount = retryCount + 1;
        int nextStatus = 0;
        HistoryTimestampMs nextRetryAt = nowMs;
        if (nextRetryCount == 1) {
            nextRetryAt = nowMs + 5000;
        } else if (nextRetryCount == 2) {
            nextRetryAt = nowMs + 30000;
        } else {
            nextStatus = 3;
            nextRetryAt = 0;
        }

        sqlite3_stmt* update = nullptr;
        const char* updateSql =
            "UPDATE items "
            "SET ocr_retry_count = ?1, ocr_status = ?2, ocr_next_retry_at = ?3 "
            "WHERE id = ?4 AND type = 'image';";
        if (sqlite3_prepare_v2(m_db, updateSql, -1, &update, nullptr) != SQLITE_OK) {
            return false;
        }

        sqlite3_bind_int(update, 1, nextRetryCount);
        sqlite3_bind_int(update, 2, nextStatus);
        sqlite3_bind_int64(update, 3, nextRetryAt);
        sqlite3_bind_text(update, 4, id.c_str(), -1, SQLITE_TRANSIENT);
        const bool ok = sqlite3_step(update) == SQLITE_DONE && sqlite3_changes(m_db) > 0;
        sqlite3_finalize(update);
        return ok;
    }

    std::optional<OcrTaskStatus> getOcrStatus(const std::string& id) override {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (m_db == nullptr || id.empty()) {
            return std::nullopt;
        }

        sqlite3_stmt* statement = nullptr;
        const char* sql =
            "SELECT ocr_status, ocr_text FROM items WHERE id = ?1 AND type = 'image' LIMIT 1;";
        if (sqlite3_prepare_v2(m_db, sql, -1, &statement, nullptr) != SQLITE_OK) {
            return std::nullopt;
        }

        sqlite3_bind_text(statement, 1, id.c_str(), -1, SQLITE_TRANSIENT);
        std::optional<OcrTaskStatus> status;
        if (sqlite3_step(statement) == SQLITE_ROW) {
            OcrTaskStatus value;
            value.status = ocrStatusFromInt(sqlite3_column_int(statement, 0));
            value.text = readTextColumn(statement, 1);
            status = value;
        }
        sqlite3_finalize(statement);
        return status;
    }

    bool deleteItem(const std::string& id) override {
        std::lock_guard<std::mutex> lock(m_mutex);
        return deleteItemUnlocked(id);
    }

    bool enforceRetention(std::int32_t maxItems) override {
        std::lock_guard<std::mutex> lock(m_mutex);
        return enforceRetentionUnlocked(maxItems);
    }

private:
    void closeUnlocked() {
        if (m_db != nullptr) {
            sqlite3_close(m_db);
            m_db = nullptr;
        }
    }

    bool deleteItemUnlocked(const std::string& id) {
        if (m_db == nullptr || id.empty()) {
            return false;
        }

        std::string imagePath;
        {
            sqlite3_stmt* lookup = nullptr;
            const char* lookupSql = "SELECT image_path FROM items WHERE id = ?1;";
            if (sqlite3_prepare_v2(m_db, lookupSql, -1, &lookup, nullptr) != SQLITE_OK) {
                return false;
            }
            sqlite3_bind_text(lookup, 1, id.c_str(), -1, SQLITE_TRANSIENT);
            if (sqlite3_step(lookup) == SQLITE_ROW) {
                imagePath = readTextColumn(lookup, 0);
            }
            sqlite3_finalize(lookup);
        }

        sqlite3_stmt* statement = nullptr;
        const char* sql = "DELETE FROM items WHERE id = ?1;";
        if (sqlite3_prepare_v2(m_db, sql, -1, &statement, nullptr) != SQLITE_OK) {
            return false;
        }

        sqlite3_bind_text(statement, 1, id.c_str(), -1, SQLITE_TRANSIENT);
        const bool ok = sqlite3_step(statement) == SQLITE_DONE;
        sqlite3_finalize(statement);

        if (!ok) {
            logStoreMessage("delete item failed");
            return false;
        }

        if (!imagePath.empty()) {
            deleteAsset(imagePath);
        }

        return true;
    }

    bool enforceRetentionUnlocked(std::int32_t maxItems) {
        if (m_db == nullptr || maxItems <= 0) {
            return false;
        }

        m_itemsLimit = maxItems;

        sqlite3_stmt* statement = nullptr;
        const char* sql =
            "SELECT id FROM items "
            "ORDER BY last_copy_time_ms DESC "
            "LIMIT -1 OFFSET ?1;";

        if (sqlite3_prepare_v2(m_db, sql, -1, &statement, nullptr) != SQLITE_OK) {
            return false;
        }

        sqlite3_bind_int(statement, 1, maxItems);
        std::vector<std::string> toDelete;
        while (sqlite3_step(statement) == SQLITE_ROW) {
            toDelete.push_back(readTextColumn(statement, 0));
        }
        sqlite3_finalize(statement);

        bool ok = true;
        for (const auto& id : toDelete) {
            ok = deleteItemUnlocked(id) && ok;
        }
        return ok;
    }

private:
    bool migrateSchema() {
        int currentVersion = 0;
        sqlite3_stmt* stmt = nullptr;
        if (sqlite3_prepare_v2(m_db, "PRAGMA user_version;", -1, &stmt, nullptr) == SQLITE_OK) {
            if (sqlite3_step(stmt) == SQLITE_ROW) {
                currentVersion = sqlite3_column_int(stmt, 0);
            }
            sqlite3_finalize(stmt);
        }

        const std::vector<std::function<bool()>> migrations = {
            [&]() { return applyMigration(1, "0001-initial-schema.sql"); },
            [&]() { return applyMigration(2, "0002-add-search-index.sql"); },
            [&]() { return applyMigration(3, "0003-add-metadata.sql"); },
            [&]() { return applyMigration(4, "0004-add-ocr-support.sql"); },
        };

        for (size_t i = currentVersion; i < migrations.size(); ++i) {
            if (!migrations[i]()) {
                logStoreMessage("migration failed at version " + std::to_string(i + 1));
                return false;
            }
        }

        return true;
    }

    bool applyMigration(int /*targetVersion*/, const std::string& migrationFile) {
        std::vector<std::string> searchPaths = {
            m_baseDirectory + "/migrations/" + migrationFile,
            m_baseDirectory + "/../migrations/" + migrationFile,
            "migrations/" + migrationFile,
            "core/migrations/" + migrationFile,
            "../../core/migrations/" + migrationFile
        };

        std::string sql;
        bool found = false;

        for (const auto& path : searchPaths) {
            std::ifstream file(path);
            if (file.is_open()) {
                sql = std::string((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
                found = true;
                break;
            }
        }

        if (!found) {
             logStoreMessage("migration file not found: " + migrationFile);
             return false;
        }

        char* error = nullptr;
        if (sqlite3_exec(m_db, "BEGIN TRANSACTION;", nullptr, nullptr, &error) != SQLITE_OK) {
             sqlite3_free(error);
             return false;
        }

        if (sqlite3_exec(m_db, sql.c_str(), nullptr, nullptr, &error) != SQLITE_OK) {
            logStoreMessage("migration SQL error: " + std::string(error ? error : "unknown"));
            sqlite3_free(error);
            sqlite3_exec(m_db, "ROLLBACK;", nullptr, nullptr, nullptr);
            return false;
        }

        if (sqlite3_exec(m_db, "COMMIT;", nullptr, nullptr, &error) != SQLITE_OK) {
            sqlite3_free(error);
            return false;
        }

        return true;
    }

    bool recreateFromCorruption() {
        logStoreMessage("attempting sqlite recreation after open/migrate failure");

        const std::string brokenPath = m_dbPath + ".broken";
        std::remove(brokenPath.c_str());
        std::rename(m_dbPath.c_str(), brokenPath.c_str());

        const int openResult = sqlite3_open_v2(
            m_dbPath.c_str(),
            &m_db,
            SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
            nullptr
        );
        if (openResult != SQLITE_OK || m_db == nullptr) {
            closeUnlocked();
            logStoreMessage("sqlite recreation failed");
            return false;
        }

        const bool migrated = migrateSchema();
        logStoreMessage(migrated ? "sqlite recreation succeeded" : "sqlite recreation migrate failed");
        return migrated;
    }

    void bindCommonItemFields(sqlite3_stmt* statement, const ClipboardHistoryItem& item, bool isImage, const std::string& imagePath = std::string()) {
        sqlite3_bind_text(statement, 1, item.id.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(statement, 2, isImage ? "image" : "text", -1, SQLITE_TRANSIENT);

        if (item.content.empty()) {
            sqlite3_bind_null(statement, 3);
        } else {
            sqlite3_bind_text(statement, 3, item.content.c_str(), -1, SQLITE_TRANSIENT);
        }

        if (imagePath.empty()) {
            sqlite3_bind_null(statement, 4);
        } else {
            sqlite3_bind_text(statement, 4, imagePath.c_str(), -1, SQLITE_TRANSIENT);
        }

        sqlite3_bind_int(statement, 5, item.imageWidth);
        sqlite3_bind_int(statement, 6, item.imageHeight);

        if (item.imageFormat.empty()) {
            sqlite3_bind_null(statement, 7);
        } else {
            sqlite3_bind_text(statement, 7, item.imageFormat.c_str(), -1, SQLITE_TRANSIENT);
        }

        sqlite3_bind_int64(statement, 8, item.createTimeMs);
        sqlite3_bind_int64(statement, 9, item.updateTimeMs);
        sqlite3_bind_int64(statement, 10, item.lastCopyTimeMs);
        sqlite3_bind_text(statement, 11, item.sourceAppId.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(statement, 12, item.contentHash.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_text(statement, 13, item.metadata.c_str(), -1, SQLITE_TRANSIENT);
        sqlite3_bind_int(statement, 14, ocrStatusToInt(item.ocrStatus));
        if (item.ocrText.empty()) {
            sqlite3_bind_null(statement, 15);
        } else {
            sqlite3_bind_text(statement, 15, item.ocrText.c_str(), -1, SQLITE_TRANSIENT);
        }
        sqlite3_bind_int(statement, 16, item.ocrRetryCount);
        sqlite3_bind_int64(statement, 17, item.ocrNextRetryAtMs);
    }

    static std::string readTextColumn(sqlite3_stmt* statement, int column) {
        const unsigned char* text = sqlite3_column_text(statement, column);
        if (text == nullptr) {
            return std::string();
        }
        return reinterpret_cast<const char*>(text);
    }

    static std::int64_t parseCursor(const std::string& cursor) {
        if (cursor.empty()) {
            return 0;
        }
        std::istringstream stream(cursor);
        std::int64_t value = 0;
        stream >> value;
        return stream.fail() ? 0 : value;
    }

    std::string writeAssetAtomically(const std::string& id, const std::string& extension, const std::vector<std::uint8_t>& bytes) {
        const std::string relativePath = std::string("images/") + id + "." + extension;
        const std::string targetPath = m_baseDirectory + "/" + relativePath;
        const std::string tempPath = targetPath + ".tmp";

        std::ofstream output(tempPath, std::ios::binary | std::ios::trunc);
        if (!output.is_open()) {
            return std::string();
        }

        output.write(reinterpret_cast<const char*>(bytes.data()), static_cast<std::streamsize>(bytes.size()));
        output.flush();
        output.close();

        if (std::rename(tempPath.c_str(), targetPath.c_str()) != 0) {
            std::remove(tempPath.c_str());
            return std::string();
        }

        return relativePath;
    }

    bool deleteAsset(const std::string& relativePath) {
        std::remove((m_baseDirectory + "/" + relativePath).c_str());
        return true;
    }

    static std::string normalizeImageExtension(const std::string& formatHint) {
        if (formatHint.empty()) {
            return "png";
        }
        std::string normalized = formatHint;
        for (char& character : normalized) {
            if (character >= 'A' && character <= 'Z') {
                character = static_cast<char>(character - 'A' + 'a');
            }
        }
        if (normalized == "jpg") {
            return "jpeg";
        }
        return normalized;
    }

    sqlite3* m_db;
    std::string m_baseDirectory;
    std::string m_assetsDirectory;
    std::string m_dbPath;
    std::int32_t m_itemsLimit;
    std::mutex m_mutex;
};

}

std::unique_ptr<ClipboardHistoryStore> createClipboardHistoryStore() {
    return std::make_unique<SQLiteClipboardHistoryStore>();
}

}
