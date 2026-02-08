// Pasty2 - Copyright (c) 2026. MIT License.

import Foundation

struct HistoryItemViewModel: Decodable {
    let id: String
    let type: String
    let content: String
    let imagePath: String
    let imageWidth: Int
    let imageHeight: Int
    let imageFormat: String
    let createTimeMs: Int64
    let updateTimeMs: Int64
    let lastCopyTimeMs: Int64
    let sourceAppId: String

    var titleText: String {
        if type == "image" {
            return "Image[\(imageWidth)x\(imageHeight)]"
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "(empty text)"
        }
        return String(trimmed.prefix(80))
    }

    var subtitleText: String {
        let source = sourceAppId.isEmpty ? "unknown" : sourceAppId
        return "id=\(id) source=\(source) lastCopy=\(lastCopyTimeMs)"
    }
}
