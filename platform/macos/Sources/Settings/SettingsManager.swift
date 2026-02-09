import Foundation
import Combine
import PastyCore

extension Notification.Name {
    static let pastySettingsWarning = Notification.Name("PastySettingsWarning")
}

struct PastySettings: Codable, Equatable {
    var version: Int = 1
    var clipboard: ClipboardSettings = .default
    var history: HistorySettings = .default
    var ocr: OCRSettings = .default
    var appearance: AppearanceSettings = .default
    var general: GeneralSettings = .default
    
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

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var settings: PastySettings = .default

    @Published private(set) var settingsDirectory: URL

    @Published private(set) var lastWarningMessage: String?
    
    private let userDefaults = UserDefaults.standard
    private let settingsDirectoryKey = "PastySettingsDirectory"
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var pendingReloadWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    private let currentSettingsVersion = 1
    private var didInitializeCoreSettings = false
    
    var settingsFileURL: URL {
        settingsDirectory.appendingPathComponent("settings.json")
    }

    private init() {
        self.settingsDirectory = SettingsManager.defaultSettingsDirectory()
        self.lastWarningMessage = nil

        resolveAndValidateSettingsDirectory()

        loadSettings()
        setupFileMonitor()
        
        $settings
            .dropFirst()
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &cancellables)
    }
    
    func loadSettings() {
        let url = settingsFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            saveSettings()
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            var loadedSettings = try decoder.decode(PastySettings.self, from: data)

            var needsWriteBack = false
            if loadedSettings.version < currentSettingsVersion {
                loadedSettings.version = currentSettingsVersion
                needsWriteBack = true
            }

            DispatchQueue.main.async {
                if loadedSettings != self.settings {
                    self.settings = loadedSettings
                    self.syncToCore()
                }
                if needsWriteBack {
                    self.saveSettings()
                }
            }
        } catch {
            let backupURL = settingsDirectory.appendingPathComponent("settings.json.corrupted")
            let fileManager = FileManager.default
            try? fileManager.removeItem(at: backupURL)
            try? fileManager.moveItem(at: url, to: backupURL)

            let message = "设置文件读取失败，已重置为默认值（损坏文件已备份为 settings.json.corrupted）。"
            DispatchQueue.main.async {
                self.lastWarningMessage = message
                NotificationCenter.default.post(name: .pastySettingsWarning, object: self, userInfo: ["message": message])
                self.settings = .default
                self.saveSettings()
            }
        }
    }
    
    func saveSettings() {
        let url = settingsFileURL
        do {
            try FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)

            try data.write(to: url, options: .atomic)
            
            syncToCore()
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    func updateSettings(_ update: (inout PastySettings) -> Void) {
        var newSettings = settings
        update(&newSettings)
        settings = newSettings
        saveSettings()
    }
    
    func setSettingsDirectory(_ url: URL) {
        userDefaults.set(url.path, forKey: settingsDirectoryKey)

        settingsDirectory = url
        resolveAndValidateSettingsDirectory()
        loadSettings()
        setupFileMonitor()
    }
    
    private func setupFileMonitor() {
        fileMonitor?.cancel()
        fileMonitor = nil

        let url = settingsFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor != -1 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.scheduleReloadFromDisk()
        }
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
        fileMonitor = source
    }

    private func scheduleReloadFromDisk() {
        pendingReloadWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.loadSettings()
        }
        pendingReloadWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    private static func defaultSettingsDirectory() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Pasty2")
    }

    private func resolveAndValidateSettingsDirectory() {
        let defaultDir = SettingsManager.defaultSettingsDirectory()
        if let path = userDefaults.string(forKey: settingsDirectoryKey) {
            settingsDirectory = URL(fileURLWithPath: path)
        } else {
            settingsDirectory = defaultDir
            userDefaults.set(defaultDir.path, forKey: settingsDirectoryKey)
        }

        if validateDirectory(settingsDirectory) {
            return
        }

        if settingsDirectory.path != defaultDir.path {
            let message = "设置目录不可访问，已回退到默认目录：\(defaultDir.path)"
            lastWarningMessage = message
            NotificationCenter.default.post(name: .pastySettingsWarning, object: self, userInfo: ["message": message])

            settingsDirectory = defaultDir
            userDefaults.set(defaultDir.path, forKey: settingsDirectoryKey)
            _ = validateDirectory(defaultDir)
        }
    }

    private func validateDirectory(_ url: URL) -> Bool {
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            return false
        }

        guard fileManager.isReadableFile(atPath: url.path),
              fileManager.isWritableFile(atPath: url.path) else {
            return false
        }

        let probeURL = url.appendingPathComponent(".pasty_write_probe_\(UUID().uuidString)")
        do {
            try Data("ok".utf8).write(to: probeURL, options: .atomic)
            try? fileManager.removeItem(at: probeURL)
            return true
        } catch {
            try? fileManager.removeItem(at: probeURL)
            return false
        }
    }
    
    private func syncToCore() {
        if !didInitializeCoreSettings {
            pasty_settings_initialize(Int32(settings.history.maxCount))
            didInitializeCoreSettings = true
        } else {
            let maxCountStr = String(settings.history.maxCount)
            maxCountStr.withCString { ptr in
                pasty_settings_update("history.maxCount", ptr)
            }
        }
    }
}
