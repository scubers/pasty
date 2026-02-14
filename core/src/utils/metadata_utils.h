// Pasty - Copyright (c) 2026. MIT License.

#pragma once

#include <string>
#include <vector>

namespace pasty::metadata_utils {

/**
 * Tags storage utility functions
 * 
 * Tags are stored in ClipboardHistoryItem.metadata as a JSON string.
 * The metadata JSON format is: {"tags": ["tag1", "tag2", ...]}
 * 
 * Design decisions:
 * - Tags are case-sensitive ("Work" != "work")
 * - Empty strings are filtered out
 * - Duplicates are removed while preserving order
 * - Serialization is stable (sorted keys for deterministic output)
 */

/**
 * Parse tags from metadata JSON string
 * 
 * @param metadata The metadata JSON string (may be empty or invalid JSON)
 * @return Vector of tags (empty if metadata is empty, invalid, or has no tags field)
 */
std::vector<std::string> parseTags(const std::string& metadata);

/**
 * Serialize tags to metadata JSON string
 * 
 * - Filters out empty strings
 * - Removes duplicates while preserving order
 * - Returns stable JSON with sorted keys
 * - Returns empty string if tags is empty after filtering
 * 
 * @param tags Vector of tags to serialize
 * @return JSON string like {"tags": ["tag1", "tag2"]} or empty string
 */
std::string serializeTags(const std::vector<std::string>& tags);

/**
 * Normalize tags: filter empty strings and remove duplicates
 * 
 * @param tags Input tags
 * @return Normalized tags (order preserved, empty removed, duplicates removed)
 */
std::vector<std::string> normalizeTags(const std::vector<std::string>& tags);

/**
 * Check if two tag lists are equal (after normalization)
 * 
 * @param tags1 First tag list
 * @param tags2 Second tag list
 * @return true if both normalize to the same tags
 */
bool tagsEqual(const std::vector<std::string>& tags1, const std::vector<std::string>& tags2);

} // namespace pasty::metadata_utils
