// Pasty2 - Copyright (c) 2026. MIT License.

#include <pasty/history/store.h>

#include <cstddef>
#include <cstdio>
#include <cerrno>
#include <fstream>
#include <iostream>
#include <sstream>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include <sqlite3.h>

namespace pasty {

namespace {

bool ensureDirectoryExists(const std::string& path) {
    if (path.empty()) {
        return false;
    }
    if (::mkdir(path.c_str(), 0755) == 0) {
        return true;
    }
    return errno == EEXIST;
}

void logStoreMessage(const std::string& message) {
    std::cerr << "[core.store] " << message << std::endl;
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
            close();
            return recreateFromCorruption();
        }

        if (migrateSchema()) {
            logStoreMessage("open + migrate succeeded");
            return true;
        }

        close();
        return recreateFromCorruption();
    }

    void close() override {
        if (m_db != nullptr) {
            sqlite3_close(m_db);
            m_db = nullptr;
        }
    }

    std::string upsertTextItem(const ClipboardHistoryItem& item) override {
        if (m_db == nullptr || item.id.empty()) {
            return std::string();
        }

        sqlite3_stmt* statement = nullptr;
        const char* sql =
            "INSERT INTO items ("
            "id, type, content, image_path, image_width, image_height, image_format, "
            "create_time_ms, update_time_ms, last_copy_time_ms, source_app_id, content_hash"
            ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) "
            "ON CONFLICT(type, content_hash) DO UPDATE SET "
            "content=excluded.content, "
            "update_time_ms=excluded.update_time_ms, "
            "last_copy_time_ms=excluded.last_copy_time_ms, "
            "source_app_id=excluded.source_app_id;";

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

        enforceRetention(m_itemsLimit);
        logStoreMessage("upsert text succeeded");
        return item.id;
    }

    std::string upsertImageItem(const ClipboardHistoryItem& item, const std::vector<std::uint8_t>& imageBytes) override {
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
                        "SET update_time_ms = ?1, last_copy_time_ms = ?2, source_app_id = ?3 "
                        "WHERE id = ?4;";
                    if (sqlite3_prepare_v2(m_db, updateSql, -1, &update, nullptr) != SQLITE_OK) {
                        logStoreMessage("upsert image dedupe update prepare failed");
                        return std::string();
                    }
                    sqlite3_bind_int64(update, 1, item.updateTimeMs);
                    sqlite3_bind_int64(update, 2, item.lastCopyTimeMs);
                    sqlite3_bind_text(update, 3, item.sourceAppId.c_str(), -1, SQLITE_TRANSIENT);
                    sqlite3_bind_text(update, 4, existingId.c_str(), -1, SQLITE_TRANSIENT);
                    const bool updated = sqlite3_step(update) == SQLITE_DONE;
                    sqlite3_finalize(update);
                    if (!updated) {
                        logStoreMessage("upsert image dedupe update failed");
                        return std::string();
                    }
                    enforceRetention(m_itemsLimit);
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
            "create_time_ms, update_time_ms, last_copy_time_ms, source_app_id, content_hash"
            ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);";

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

        enforceRetention(m_itemsLimit);
        logStoreMessage("upsert image inserted");
        return item.id;
    }

    ClipboardHistoryListResult listItems(std::int32_t limit, const std::string& cursor) override {
        ClipboardHistoryListResult result;
        if (m_db == nullptr) {
            return result;
        }

        const std::int32_t safeLimit = limit <= 0 ? 200 : (limit > 1000 ? 1000 : limit);
        const std::int64_t cursorTime = parseCursor(cursor);

        sqlite3_stmt* statement = nullptr;
        const char* sql =
            "SELECT id, type, content, image_path, image_width, image_height, image_format, "
            "create_time_ms, update_time_ms, last_copy_time_ms, source_app_id, content_hash "
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
            result.items.push_back(item);
        }

        sqlite3_finalize(statement);

        if (!result.items.empty()) {
            const auto& last = result.items.back();
            result.nextCursor = std::to_string(last.lastCopyTimeMs);
        }

        return result;
    }

    bool deleteItem(const std::string& id) override {
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

    bool enforceRetention(std::int32_t maxItems) override {
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
            ok = deleteItem(id) && ok;
        }
        return ok;
    }

private:
    bool migrateSchema() {
        static const char* kSchemaSql =
            "CREATE TABLE IF NOT EXISTS items ("
            "id TEXT PRIMARY KEY,"
            "type TEXT NOT NULL,"
            "content TEXT,"
            "image_path TEXT,"
            "image_width INTEGER,"
            "image_height INTEGER,"
            "image_format TEXT,"
            "create_time_ms INTEGER NOT NULL,"
            "update_time_ms INTEGER NOT NULL,"
            "last_copy_time_ms INTEGER NOT NULL,"
            "source_app_id TEXT NOT NULL DEFAULT '',"
            "content_hash TEXT NOT NULL DEFAULT ''"
            ");"
            "CREATE INDEX IF NOT EXISTS idx_items_last_copy_time ON items(last_copy_time_ms DESC);"
            "CREATE INDEX IF NOT EXISTS idx_items_type ON items(type);"
            "CREATE UNIQUE INDEX IF NOT EXISTS idx_items_type_hash ON items(type, content_hash);"
            "PRAGMA user_version = 1;";

        sqlite3_exec(m_db, "ALTER TABLE items ADD COLUMN source_app_id TEXT NOT NULL DEFAULT '';", nullptr, nullptr, nullptr);
        sqlite3_exec(m_db, "ALTER TABLE items ADD COLUMN content_hash TEXT NOT NULL DEFAULT '';", nullptr, nullptr, nullptr);

        char* error = nullptr;
        const int rc = sqlite3_exec(m_db, kSchemaSql, nullptr, nullptr, &error);
        if (error != nullptr) {
            sqlite3_free(error);
        }
        if (rc != SQLITE_OK) {
            logStoreMessage("schema migration failed");
        }
        return rc == SQLITE_OK;
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
            close();
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
};

}

std::unique_ptr<ClipboardHistoryStore> createClipboardHistoryStore() {
    return std::make_unique<SQLiteClipboardHistoryStore>();
}

}
