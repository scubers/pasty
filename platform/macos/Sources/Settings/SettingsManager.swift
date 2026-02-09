import Foundation
import Combine
import PastyCore

struct PastySettings: Codable, Equatable {
    var version: Int = 1
    var clipboard: ClipboardSettings = .default
    var history: HistorySettings = .default
    var ocr: OCRSettings = .default
    var appearance: AppearanceSettings = .default
    var general: GeneralSettings = .default
    
    static let `default` = PastySettings()
}

struct ClipboardSettings: Codable, Equatable {
    var pollingIntervalMs: Int = 400
    var maxContentSizeBytes: Int = 10 * 1024 * 1024
    
    static let `default` = ClipboardSettings()
}

struct HistorySettings: Codable, Equatable {
    var maxCount: Int = 1000
    
    static let `default` = HistorySettings()
}

struct OCRSettings: Codable, Equatable {
    var enabled: Bool = true
    var languages: [String] = ["en", "zh-Hans"]
    var confidenceThreshold: Float = 0.7
    var recognitionLevel: String = "accurate"
    var includeInSearch: Bool = true
    
    static let `default` = OCRSettings()
}

struct AppearanceSettings: Codable, Equatable {
    var themeColor: String = "system"
    var blurIntensity: Double = 0.9
    var panelWidth: Double = 800
    var panelHeight: Double = 500
    
    static let `default` = AppearanceSettings()
}

struct GeneralSettings: Codable, Equatable {
    var launchAtLogin: Bool = false
    var shortcut: String = "cmd+shift+v"
    
    static let `default` = GeneralSettings()
}

class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    @Published var settings: PastySettings = .default
    
    private let userDefaults = UserDefaults.standard
    private let settingsDirectoryKey = "PastySettingsDirectory"
    private var fileMonitor: DispatchSourceFileSystemObject?
    private var cancellables = Set<AnyCancellable>()
    
    var settingsDirectory: URL {
        if let path = userDefaults.string(forKey: settingsDirectoryKey) {
            return URL(fileURLWithPath: path)
        }
        let defaultPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Pasty2")
        return defaultPath
    }
    
    var settingsFileURL: URL {
        settingsDirectory.appendingPathComponent("settings.json")
    }
    
    private init() {
        try? FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        
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
            
            if loadedSettings.version < 1 {
                loadedSettings.version = 1
            }
            
            DispatchQueue.main.async {
                self.settings = loadedSettings
                self.syncToCore()
            }
        } catch {
            print("Failed to load settings: \(error)")
            let backupURL = url.appendingPathExtension("corrupted")
            try? FileManager.default.moveItem(at: url, to: backupURL)
            self.settings = .default
            saveSettings()
        }
    }
    
    func saveSettings() {
        let url = settingsFileURL
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
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
        
        try? FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        setupFileMonitor()
        loadSettings()
    }
    
    private func setupFileMonitor() {
        fileMonitor?.cancel()
        fileMonitor = nil
        
        let url = settingsFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor != -1 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in
            self?.loadSettings()
        }
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
        fileMonitor = source
    }
    
    private func syncToCore() {
        let maxCountStr = String(settings.history.maxCount)
        maxCountStr.withCString { ptr in
            pasty_settings_update("history.maxCount", ptr)
        }
    }
}
