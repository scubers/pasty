import Foundation

struct PastySettings: Codable, Equatable {
    var version: Int = 1
    var clipboard: ClipboardSettings = .default
    var history: HistorySettings = .default
    var ocr: OCRSettings = .default
    var appearance: AppearanceSettings = .default
    var general: GeneralSettings = .default
    var cloudSync: CloudSyncSettings = .default

    static let `default` = PastySettings()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        clipboard = try container.decodeIfPresent(ClipboardSettings.self, forKey: .clipboard) ?? .default
        history = try container.decodeIfPresent(HistorySettings.self, forKey: .history) ?? .default
        ocr = try container.decodeIfPresent(OCRSettings.self, forKey: .ocr) ?? .default
        appearance = try container.decodeIfPresent(AppearanceSettings.self, forKey: .appearance) ?? .default
        general = try container.decodeIfPresent(GeneralSettings.self, forKey: .general) ?? .default
        cloudSync = try container.decodeIfPresent(CloudSyncSettings.self, forKey: .cloudSync) ?? .default
    }
}

struct CloudSyncSettings: Codable, Equatable {
    var enabled: Bool = false
    var rootPath: String = ""
    var includeSensitive: Bool = false
    var includeSourceAppId: Bool = true

    static let `default` = CloudSyncSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        rootPath = try container.decodeIfPresent(String.self, forKey: .rootPath) ?? ""
        includeSensitive = try container.decodeIfPresent(Bool.self, forKey: .includeSensitive) ?? false
        includeSourceAppId = try container.decodeIfPresent(Bool.self, forKey: .includeSourceAppId) ?? true
    }
}

struct ClipboardSettings: Codable, Equatable {
    var pollingIntervalMs: Int = 400
    var maxContentSizeBytes: Int = 10 * 1024 * 1024

    static let `default` = ClipboardSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pollingIntervalMs = try container.decodeIfPresent(Int.self, forKey: .pollingIntervalMs) ?? 400
        maxContentSizeBytes = try container.decodeIfPresent(Int.self, forKey: .maxContentSizeBytes) ?? 10 * 1024 * 1024
    }
}

struct HistorySettings: Codable, Equatable {
    var maxCount: Int = 1000

    static let `default` = HistorySettings()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        maxCount = try container.decodeIfPresent(Int.self, forKey: .maxCount) ?? 1000
    }
}

struct OCRSettings: Codable, Equatable {
    var enabled: Bool = true
    var languages: [String] = ["en", "zh-Hans"]
    var confidenceThreshold: Float = 0.7
    var recognitionLevel: String = "accurate"
    var includeInSearch: Bool = true

    static let `default` = OCRSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        languages = try container.decodeIfPresent([String].self, forKey: .languages) ?? ["en", "zh-Hans"]
        confidenceThreshold = try container.decodeIfPresent(Float.self, forKey: .confidenceThreshold) ?? 0.7
        recognitionLevel = try container.decodeIfPresent(String.self, forKey: .recognitionLevel) ?? "accurate"
        includeInSearch = try container.decodeIfPresent(Bool.self, forKey: .includeInSearch) ?? true
    }
}

struct AppearanceSettings: Codable, Equatable {
    var themeColor: String = "system"
    var blurIntensity: Double = 0.9
    var panelWidth: Double = 800
    var panelHeight: Double = 500

    static let `default` = AppearanceSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        themeColor = try container.decodeIfPresent(String.self, forKey: .themeColor) ?? "system"
        blurIntensity = try container.decodeIfPresent(Double.self, forKey: .blurIntensity) ?? 0.9
        panelWidth = try container.decodeIfPresent(Double.self, forKey: .panelWidth) ?? 800
        panelHeight = try container.decodeIfPresent(Double.self, forKey: .panelHeight) ?? 500
    }
}

struct GeneralSettings: Codable, Equatable {
    var launchAtLogin: Bool = false
    var shortcut: String = "cmd+shift+v"

    static let `default` = GeneralSettings()

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        launchAtLogin = try container.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        shortcut = try container.decodeIfPresent(String.self, forKey: .shortcut) ?? "cmd+shift+v"
    }
}
