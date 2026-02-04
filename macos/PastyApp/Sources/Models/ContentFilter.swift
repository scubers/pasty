import Foundation

/// Content filter options for clipboard entries
enum ContentFilter: String, CaseIterable {
    case all = "All"
    case text = "Text"
    case images = "Images"

    /// Display title
    var title: String {
        rawValue
    }
}
