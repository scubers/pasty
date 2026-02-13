import Foundation
import PastyCore

final class SettingsStore {
    private let coordinator: AppCoordinator

    private var fileMonitor: DispatchSourceFileSystemObject?
    private var pendingReloadWorkItem: DispatchWorkItem?
    private var pendingSaveWorkItem: DispatchWorkItem?
    private let currentSettingsVersion = 1
    private var didInitializeCoreSettings = false

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator

        resolveAndValidateSettingsDirectory()
        loadSettings()
        setupFileMonitor()
    }

    var settingsFileURL: URL {
        coordinator.clipboardData.appendingPathComponent("settings.json")
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

            if loadedSettings != coordinator.settings {
                coordinator.setSettings(loadedSettings)
                syncToCore()
            }
            if needsWriteBack {
                saveSettings()
            }
        } catch {
            let backupURL = coordinator.clipboardData.appendingPathComponent("settings.json.corrupted")
            let fileManager = FileManager.default
            try? fileManager.removeItem(at: backupURL)
            try? fileManager.moveItem(at: url, to: backupURL)

            let message = "设置文件读取失败，已重置为默认值（损坏文件已备份为 settings.json.corrupted）。"
            coordinator.setWarningMessage(message)
            coordinator.dispatch(.settingsWarning(message))
            coordinator.setSettings(.default)
            saveSettings()
        }
    }

    func saveSettings() {
        let url = settingsFileURL
        do {
            try FileManager.default.createDirectory(at: coordinator.clipboardData, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(coordinator.settings)

            try data.write(to: url, options: .atomic)
            syncToCore()
        } catch {
            LoggerService.error("Failed to save settings: \(error)")
        }
    }

    func updateSettings(_ update: (inout PastySettings) -> Void) {
        coordinator.updateSettings(update)
        syncToCore()
        scheduleSave()
    }

    func replaceSettings(_ settings: PastySettings) {
        coordinator.setSettings(settings)
        syncToCore()
        scheduleSave()
    }

    func syncCurrentSettingsToCore() {
        syncToCore()
    }

    private func setupFileMonitor() {
        fileMonitor?.cancel()
        fileMonitor = nil

        let url = settingsFileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor != -1 else {
            return
        }

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

    private func scheduleSave() {
        pendingSaveWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.saveSettings()
        }
        pendingSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private static func defaultClipboardDataDirectory(appData: URL) -> URL {
        appData.appendingPathComponent("ClipboardData")
    }

    private func resolveAndValidateSettingsDirectory() {
        let defaultDir = Self.defaultClipboardDataDirectory(appData: coordinator.appData)
        coordinator.setClipboardData(defaultDir)
        _ = validateDirectory(defaultDir)
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
        guard let runtime = coordinator.coreRuntime else {
            return
        }

        if !didInitializeCoreSettings {
            pasty_settings_initialize(runtime, Int32(coordinator.settings.history.maxCount))
            didInitializeCoreSettings = true
        } else {
            let maxCountStr = String(coordinator.settings.history.maxCount)
            maxCountStr.withCString { ptr in
                pasty_settings_update(runtime, "history.maxCount", ptr)
            }
        }

        let cloudSync = coordinator.settings.cloudSync
        let cloudSyncEnabled = cloudSync.enabled ? "true" : "false"
        cloudSyncEnabled.withCString { ptr in
            pasty_settings_update(runtime, "cloudSync.enabled", ptr)
        }

        cloudSync.rootPath.withCString { ptr in
            pasty_settings_update(runtime, "cloudSync.rootPath", ptr)
        }

        let includeSensitive = cloudSync.includeSensitive ? "true" : "false"
        includeSensitive.withCString { ptr in
            pasty_settings_update(runtime, "cloudSync.includeSensitive", ptr)
        }
    }
}
