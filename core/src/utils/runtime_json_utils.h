#pragma once

#include <history/clipboard_history_types.h>

#include <cstdint>
#include <string>
#include <vector>

namespace pasty::runtime_json_utils {

std::int64_t nowMs();
std::string fromCString(const char* text);
char* copyString(const std::string& str);
std::string serializeItemsToJson(const std::vector<ClipboardHistoryItem>& items);
std::string serializeOcrTask(const OcrTask& task);
std::string serializeOcrTasks(const std::vector<OcrTask>& tasks);
std::string serializeOcrStatus(const OcrTaskStatus& status);
std::string serializeItemToJson(const ClipboardHistoryItem& item);

} // namespace pasty::runtime_json_utils
