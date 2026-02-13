// Pasty - Copyright (c) 2026. MIT License.

#include "infrastructure/sync/cloud_drive_sync_pruner.h"
#include <common/logger.h>

#include <algorithm>
#include <chrono>
#include <fstream>
#include <filesystem>
#include <map>
#include <set>
#include <utility>

#include <nlohmann/json.hpp>

namespace pasty {

namespace {

constexpr int kSchemaVersion = 1;

} // namespace

CloudDriveSyncPruner::PruneResult CloudDriveSyncPruner::prune(const std::string& syncRootPath, std::int64_t nowMs,
                                                                   std::int64_t retentionMs,
                                                                   int maxEventsPerDevice) {
    PruneResult result;
    result.success = false;

    std::error_code ec;
    if (!std::filesystem::exists(syncRootPath, ec) || ec) {
        result.errorMessage = "Sync root path does not exist: " + syncRootPath;
        PASTY_LOG_ERROR("Core.SyncPruner", "%s", result.errorMessage.c_str());
        return result;
    }

    const std::string logsPath = syncRootPath + "/logs";
    const std::string assetsPath = syncRootPath + "/assets";
    const std::int64_t cutoffMs = nowMs - retentionMs;

    std::set<std::string> allReferencedAssets;

    std::vector<std::string> deviceDirectories;
    if (std::filesystem::exists(logsPath, ec) && !ec) {
        for (const auto& entry : std::filesystem::directory_iterator(logsPath, ec)) {
            if (ec) {
                break;
            }
            if (entry.is_directory(ec) && !ec) {
                deviceDirectories.push_back(entry.path().string());
            }
        }
    }

    for (const auto& deviceDir : deviceDirectories) {
        DeviceEventSummary summary;
        summary.deviceId = std::filesystem::path(deviceDir).filename().string();
        summary.logFiles = enumerateDeviceLogFiles(deviceDir);

        if (!collectDeviceEvents(deviceDir, summary, cutoffMs, allReferencedAssets)) {
            PASTY_LOG_WARN("Core.SyncPruner", "Failed to collect events for device: %s", summary.deviceId.c_str());
            continue;
        }

        int eventsRetained = 0;
        int eventsPruned = 0;
        std::vector<FileAction> actions = determinePruningActions(summary, cutoffMs, maxEventsPerDevice,
                                                                           eventsRetained, eventsPruned);

        for (const auto& action : actions) {
            if (action.lineNumbersToKeep.empty()) {
                std::error_code deleteEc;
                if (std::filesystem::remove(action.filePath, deleteEc)) {
                    result.logFilesDeleted++;
                    PASTY_LOG_INFO("Core.SyncPruner", "Deleted log file: %s", action.filePath.c_str());
                } else {
                    PASTY_LOG_ERROR("Core.SyncPruner", "Failed to delete log file: %s, error: %s",
                                   action.filePath.c_str(), deleteEc.message().c_str());
                }
            } else {
                int linesWritten = 0;
                if (rewriteBoundaryFile(action.filePath, action.lineNumbersToKeep, linesWritten)) {
                    PASTY_LOG_INFO("Core.SyncPruner", "Rewrote log file: %s, kept %d lines",
                                   action.filePath.c_str(), linesWritten);
                } else {
                    PASTY_LOG_ERROR("Core.SyncPruner", "Failed to rewrite log file: %s", action.filePath.c_str());
                }
            }

            for (const auto& assetKey : action.assetKeysToKeep) {
                allReferencedAssets.insert(assetKey);
            }
        }

        result.eventsRetained += eventsRetained;
        result.eventsPruned += eventsPruned;
        result.devicesProcessed++;
    }

    result.assetsDeleted = pruneUnreferencedAssets(assetsPath, allReferencedAssets, cutoffMs);

    result.success = true;
    PASTY_LOG_INFO("Core.SyncPruner", "Prune complete: devices=%d, files_deleted=%d, assets_deleted=%d, events_retained=%d, events_pruned=%d",
                   result.devicesProcessed, result.logFilesDeleted, result.assetsDeleted,
                   result.eventsRetained, result.eventsPruned);

    return result;
}

bool CloudDriveSyncPruner::collectDeviceEvents(const std::string& deviceLogsPath, DeviceEventSummary& summary,
                                                 std::int64_t cutoffMs, std::set<std::string>& allReferencedAssets) {
    (void)deviceLogsPath;
    (void)cutoffMs;

    for (const auto& logFile : summary.logFiles) {
        if (!parseJsonlFileForMetadata(logFile, summary.events)) {
            PASTY_LOG_WARN("Core.SyncPruner", "Failed to parse log file: %s", logFile.c_str());
            continue;
        }
    }

    std::sort(summary.events.begin(), summary.events.end(),
              [](const EventInfo& a, const EventInfo& b) {
                  if (a.tsMs != b.tsMs) return a.tsMs < b.tsMs;
                  return a.seq < b.seq;
              });

    return true;
}

std::vector<CloudDriveSyncPruner::FileAction> CloudDriveSyncPruner::determinePruningActions(const DeviceEventSummary& summary,
                                                                        std::int64_t cutoffMs,
                                                                        int maxEvents,
                                                                        int& eventsRetained,
                                                                        int& eventsPruned) {
    std::vector<FileAction> actions;

    if (summary.events.empty()) {
        eventsRetained = 0;
        eventsPruned = 0;
        return actions;
    }

    int countWithinWindow = 0;
    for (const auto& event : summary.events) {
        if (event.tsMs >= cutoffMs) {
            countWithinWindow++;
        }
    }

    int targetCount = std::min(countWithinWindow, maxEvents);
    if (static_cast<int>(summary.events.size()) <= targetCount) {
        eventsRetained = static_cast<int>(summary.events.size());
        eventsPruned = 0;
        return actions;
    }

    std::set<std::string> filesToKeep;
    std::map<std::string, std::set<int>> fileLinesToKeep;
    std::map<std::string, std::set<std::string>> fileAssetKeysToKeep;

    int keepFromEnd = targetCount;
    for (int i = static_cast<int>(summary.events.size()) - 1; i >= 0 && keepFromEnd > 0; --i) {
        const EventInfo& event = summary.events[i];
        filesToKeep.insert(event.filePath);
        fileLinesToKeep[event.filePath].insert(event.lineNumber);
        if (!event.assetKey.empty()) {
            fileAssetKeysToKeep[event.filePath].insert(event.assetKey);
        }
        keepFromEnd--;
    }

    for (const auto& logFile : summary.logFiles) {
        if (filesToKeep.find(logFile) == filesToKeep.end()) {
            FileAction action;
            action.filePath = logFile;
            action.lineNumbersToKeep.clear();
            action.assetKeysToKeep.clear();
            actions.push_back(action);
        } else {
            FileAction action;
            action.filePath = logFile;
            action.lineNumbersToKeep = fileLinesToKeep[logFile];
            action.assetKeysToKeep = fileAssetKeysToKeep[logFile];
            actions.push_back(action);
        }
    }

    eventsRetained = targetCount;
    eventsPruned = static_cast<int>(summary.events.size()) - targetCount;

    return actions;
}

bool CloudDriveSyncPruner::parseJsonlFileForMetadata(const std::string& filePath,
                                                        std::vector<EventInfo>& events) {
    std::ifstream file(filePath, std::ios::binary);
    if (!file.is_open()) {
        PASTY_LOG_ERROR("Core.SyncPruner", "Cannot open file: %s", filePath.c_str());
        return false;
    }

    std::string line;
    int lineNumber = 1;

    while (std::getline(file, line)) {
        if (line.empty()) {
            lineNumber++;
            continue;
        }

        using Json = nlohmann::json;
        Json json;

        try {
            json = Json::parse(line, nullptr, false);
            if (json.is_discarded()) {
                PASTY_LOG_ERROR("Core.SyncPruner", "Invalid JSON at line %d in %s",
                                lineNumber, filePath.c_str());
                lineNumber++;
                continue;
            }
        } catch (...) {
            PASTY_LOG_ERROR("Core.SyncPruner", "JSON parse exception at line %d in %s",
                           lineNumber, filePath.c_str());
            lineNumber++;
            continue;
        }

        if (!json.is_object()) {
            lineNumber++;
            continue;
        }

        const int schemaVersion = json.value("schema_version", 0);
        if (schemaVersion != kSchemaVersion) {
            lineNumber++;
            continue;
        }

        if (!json.contains("seq") || !json.contains("ts_ms") || !json.contains("op") ||
            !json.contains("content_hash")) {
            lineNumber++;
            continue;
        }

        EventInfo eventInfo;
        eventInfo.filePath = filePath;
        eventInfo.lineNumber = lineNumber;
        eventInfo.seq = json["seq"].get<std::uint64_t>();
        eventInfo.tsMs = json["ts_ms"].get<std::int64_t>();
        eventInfo.assetKey.clear();

        std::string contentHash = json["content_hash"].get<std::string>();
        if (!validateContentHash(contentHash)) {
            lineNumber++;
            continue;
        }

        std::string op = json["op"].get<std::string>();
        if (op == "upsert_image" && json.contains("asset_key")) {
            eventInfo.assetKey = json["asset_key"].get<std::string>();
        } else if (op != "upsert_text" && op != "delete") {
            lineNumber++;
            continue;
        }

        events.push_back(eventInfo);
        lineNumber++;
    }

    return true;
}

bool CloudDriveSyncPruner::rewriteBoundaryFile(const std::string& filePath, const std::set<int>& lineNumbersToKeep, int& linesWritten) {
    std::ifstream inFile(filePath, std::ios::binary);
    if (!inFile.is_open()) {
        PASTY_LOG_ERROR("Core.SyncPruner", "Cannot open file for rewrite: %s", filePath.c_str());
        return false;
    }

    const std::string tmpPath = filePath + ".tmp";
    std::ofstream outFile(tmpPath, std::ios::binary);
    if (!outFile.is_open()) {
        PASTY_LOG_ERROR("Core.SyncPruner", "Cannot create temp file for rewrite: %s", tmpPath.c_str());
        inFile.close();
        return false;
    }

    std::string line;
    int lineNumber = 1;
    linesWritten = 0;

    while (std::getline(inFile, line)) {
        if (lineNumbersToKeep.find(lineNumber) != lineNumbersToKeep.end()) {
            outFile << line << "\n";
            linesWritten++;
        }
        lineNumber++;
    }

    inFile.close();
    outFile.close();

    std::error_code ec;
    std::filesystem::rename(tmpPath, filePath, ec);
    if (ec) {
        PASTY_LOG_ERROR("Core.SyncPruner", "Failed to rename temp file: %s -> %s, error: %s",
                       tmpPath.c_str(), filePath.c_str(), ec.message().c_str());
        std::filesystem::remove(tmpPath, ec);
        return false;
    }

    return true;
}

int CloudDriveSyncPruner::pruneUnreferencedAssets(const std::string& assetsPath,
                                                      const std::set<std::string>& allReferencedAssets,
                                                      std::int64_t cutoffMs) {
    int deletedCount = 0;

    std::error_code ec;
    if (!std::filesystem::exists(assetsPath, ec) || ec) {
        return 0;
    }

    auto cutoffSys = std::chrono::system_clock::time_point(std::chrono::milliseconds(cutoffMs));
    auto cutoffFile = std::filesystem::file_time_type::clock::now() +
                     (cutoffSys - std::chrono::system_clock::now());

    for (const auto& entry : std::filesystem::directory_iterator(assetsPath, ec)) {
        if (ec) {
            break;
        }

        if (entry.is_regular_file(ec) && !ec) {
            const std::string assetKey = entry.path().filename().string();

            if (allReferencedAssets.find(assetKey) != allReferencedAssets.end()) {
                continue;
            }

            std::error_code timeEc;
            auto ftime = std::filesystem::last_write_time(entry.path(), timeEc);
            if (timeEc) {
                continue;
            }

            if (ftime >= cutoffFile) {
                continue;
            }

            std::error_code deleteEc;
            if (std::filesystem::remove(entry.path(), deleteEc)) {
                deletedCount++;
                PASTY_LOG_INFO("Core.SyncPruner", "Deleted unreferenced asset: %s", assetKey.c_str());
            } else {
                PASTY_LOG_ERROR("Core.SyncPruner", "Failed to delete asset: %s, error: %s",
                               assetKey.c_str(), deleteEc.message().c_str());
            }
        }
    }

    return deletedCount;
}

std::vector<std::string> CloudDriveSyncPruner::enumerateDeviceLogFiles(const std::string& deviceLogsPath) const {
    std::vector<std::string> files;

    std::error_code ec;
    if (!std::filesystem::exists(deviceLogsPath, ec) || ec) {
        return files;
    }

    for (const auto& entry : std::filesystem::directory_iterator(deviceLogsPath, ec)) {
        if (ec) {
            break;
        }

        if (entry.is_regular_file(ec) && !ec) {
            const std::string filename = entry.path().filename().string();
            if (isEventsJsonlFile(filename)) {
                files.push_back(entry.path().string());
            }
        }
    }

    std::sort(files.begin(), files.end());
    return files;
}

bool CloudDriveSyncPruner::isEventsJsonlFile(const std::string& filename) const {
    if (filename.size() < 12) {
        return false;
    }

    if (filename.substr(filename.size() - 6) != ".jsonl") {
        return false;
    }

    if (filename.substr(0, 7) != "events-") {
        return false;
    }

    std::string numPart = filename.substr(7, filename.size() - 12);
    if (numPart.size() != 4) {
        return false;
    }

    for (char c : numPart) {
        if (c < '0' || c > '9') {
            return false;
        }
    }

    return true;
}

bool CloudDriveSyncPruner::validateContentHash(const std::string& hash) const {
    if (hash.size() != 16) {
        return false;
    }
    for (char c : hash) {
        if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f'))) {
            return false;
        }
    }
    return true;
}

int CloudDriveSyncPruner::DeviceEventSummary::countEventsOlderThan(std::int64_t cutoffMs) const {
    int count = 0;
    for (const auto& event : events) {
        if (event.tsMs < cutoffMs) {
            count++;
        }
    }
    return count;
}

} // namespace pasty
