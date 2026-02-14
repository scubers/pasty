// Pasty - Copyright (c) 2026. MIT License.

#include "utils/metadata_utils.h"

#include <nlohmann/json.hpp>

#include <algorithm>
#include <set>

namespace pasty::metadata_utils {

std::vector<std::string> parseTags(const std::string& metadata) {
    if (metadata.empty()) {
        return {};
    }

    try {
        auto json = nlohmann::json::parse(metadata, nullptr, false);
        if (json.is_discarded() || !json.is_object()) {
            return {};
        }

        if (!json.contains("tags") || !json["tags"].is_array()) {
            return {};
        }

        std::vector<std::string> tags;
        for (const auto& tag : json["tags"]) {
            if (tag.is_string()) {
                tags.push_back(tag.get<std::string>());
            }
        }

        return normalizeTags(tags);
    } catch (...) {
        return {};
    }
}

std::string serializeTags(const std::vector<std::string>& tags) {
    auto normalized = normalizeTags(tags);
    if (normalized.empty()) {
        return {};
    }

    nlohmann::json json;
    json["tags"] = normalized;

    return json.dump();
}

std::vector<std::string> normalizeTags(const std::vector<std::string>& tags) {
    std::vector<std::string> result;
    std::set<std::string> seen;

    for (const auto& tag : tags) {
        if (tag.empty()) {
            continue;
        }
        if (seen.find(tag) == seen.end()) {
            seen.insert(tag);
            result.push_back(tag);
        }
    }

    return result;
}

bool tagsEqual(const std::vector<std::string>& tags1, const std::vector<std::string>& tags2) {
    auto normalized1 = normalizeTags(tags1);
    auto normalized2 = normalizeTags(tags2);

    if (normalized1.size() != normalized2.size()) {
        return false;
    }

    for (std::size_t i = 0; i < normalized1.size(); ++i) {
        if (normalized1[i] != normalized2[i]) {
            return false;
        }
    }

    return true;
}

} // namespace pasty::metadata_utils
