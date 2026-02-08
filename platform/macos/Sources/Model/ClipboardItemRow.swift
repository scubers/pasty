import Foundation

struct ClipboardItemRow: Identifiable, Equatable, Decodable {
    let id: String
    let type: ItemType
    let content: String
    let imagePath: String?
    let imageWidth: Int?
    let imageHeight: Int?
    let createTimeMs: Int64
    let sourceAppId: String
    
    var timestamp: Date {
        Date(timeIntervalSince1970: TimeInterval(createTimeMs) / 1000.0)
    }
    
    enum ItemType: String, Equatable, Decodable {
        case text
        case image
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case type
        case content
        case imagePath
        case imageWidth
        case imageHeight
        case createTimeMs
        case sourceAppId
    }
}
