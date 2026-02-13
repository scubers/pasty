import Foundation
import SwiftUI
import Combine
import PastyCore

private struct CloudSyncStatusPayload: Decodable {
    let deviceId: String?
    let stateFileErrorCount: Int?
    let e2eeEnabled: Bool?
    let e2eeKeyId: String?
}

@MainActor
final class SettingsViewModel: ObservableObject {
    private let coordinator: AppCoordinator
    private let settingsStore: SettingsStore
    private var cancellables = Set<AnyCancellable>()

    init(coordinator: AppCoordinator, settingsStore: SettingsStore) {
        self.coordinator = coordinator
        self.settingsStore = settingsStore

        coordinator.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        coordinator.$settings
            .map(\.cloudSync)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cloudSync in
                self?.updateCloudSyncDirectoryValidation(cloudSync)
            }
            .store(in: &cancellables)

        updateCloudSyncDirectoryValidation(coordinator.settings.cloudSync)
    }

    var settings: PastySettings {
        coordinator.settings
    }

    var clipboardData: URL {
        coordinator.clipboardData
    }

    var appData: URL {
        coordinator.appData
    }

    var blurIntensity: Double {
        settings.appearance.blurIntensity
    }

    @Published var cloudSyncIsDirectoryValid: Bool = true
    @Published var deviceId: String? = nil
    @Published var cloudSyncLastSync: Date? = nil
    @Published var cloudSyncErrorCount: Int = 0
    @Published var e2eeEnabled: Bool = false
    @Published var e2eeUnlocked: Bool = false
    @Published var e2eeKeyId: String? = nil

    func binding<Value>(_ keyPath: WritableKeyPath<PastySettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.coordinator.settings[keyPath: keyPath] },
            set: { [weak self] newValue in
                self?.settingsStore.updateSettings { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    func refreshCloudSyncStatus() {
        LoggerService.info("Refreshing cloud sync status")
        let canRunImport = updateCloudSyncDirectoryValidation() && settings.cloudSync.enabled
        let normalizedPath = settings.cloudSync.rootPath.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let runtime = coordinator.coreRuntime else {
            LoggerService.warn("Core runtime not available, skipping refresh")
            deviceId = nil
            cloudSyncErrorCount = 0
            e2eeEnabled = false
            e2eeUnlocked = false
            e2eeKeyId = nil
            return
        }
        let runtimeAddress = UInt(bitPattern: runtime)

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let runtime = UnsafeMutableRawPointer(bitPattern: runtimeAddress) else {
                return
            }

            var hasPassphrase = false
            if canRunImport && !normalizedPath.isEmpty {
                if let passphrase = KeychainService.getPassphrase(account: normalizedPath) {
                    pasty_cloud_sync_e2ee_initialize(runtime, passphrase)
                    hasPassphrase = true
                }
            }

            let importSucceeded = canRunImport ? pasty_cloud_sync_import_now(runtime) : false
            var statusDeviceId: String?
            var statusErrorCount = 0
            var statusE2eeEnabled = false
            var statusE2eeKeyId: String?

            var outJson: UnsafeMutablePointer<CChar>? = nil
            if pasty_cloud_sync_get_status_json(runtime, &outJson), let outJson {
                defer {
                    pasty_free_string(outJson)
                }

                let jsonString = String(cString: outJson)
                if let data = jsonString.data(using: .utf8),
                   let payload = try? JSONDecoder().decode(CloudSyncStatusPayload.self, from: data) {
                    statusDeviceId = payload.deviceId
                    statusErrorCount = payload.stateFileErrorCount ?? 0
                    statusE2eeEnabled = payload.e2eeEnabled ?? false
                    statusE2eeKeyId = payload.e2eeKeyId
                }
            }

            LoggerService.info("Cloud sync status refresh complete (e2eeEnabled: \(statusE2eeEnabled), importSucceeded: \(importSucceeded))")

            Task { @MainActor in
                guard let self else {
                    return
                }
                self.deviceId = statusDeviceId
                self.cloudSyncErrorCount = max(0, statusErrorCount)
                self.e2eeEnabled = statusE2eeEnabled
                self.e2eeUnlocked = hasPassphrase
                self.e2eeKeyId = statusE2eeKeyId
                if importSucceeded {
                    self.cloudSyncLastSync = Date()
                }
            }
        }
    }

    func savePassphrase(_ passphrase: String) {
        let normalizedPath = settings.cloudSync.rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPath.isEmpty else { return }

        LoggerService.info("Saving passphrase to Keychain for account: \(normalizedPath)")
        if KeychainService.setPassphrase(passphrase, account: normalizedPath) {
            LoggerService.debug("Successfully saved passphrase to Keychain")
            refreshCloudSyncStatus()
        } else {
            LoggerService.error("Failed to save passphrase to Keychain")
        }
    }

    func deletePassphrase() {
        let normalizedPath = settings.cloudSync.rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPath.isEmpty else { return }

        LoggerService.info("Deleting passphrase from Keychain for account: \(normalizedPath)")
        if KeychainService.deletePassphrase(account: normalizedPath) {
            LoggerService.debug("Successfully deleted passphrase from Keychain")
            if let runtime = coordinator.coreRuntime {
                pasty_cloud_sync_e2ee_clear(runtime)
            }
            refreshCloudSyncStatus()
        } else {
            LoggerService.error("Failed to delete passphrase from Keychain")
        }
    }

    @discardableResult
    private func updateCloudSyncDirectoryValidation(_ cloudSync: CloudSyncSettings? = nil) -> Bool {
        let targetSettings = cloudSync ?? settings.cloudSync
        let isValid = isCloudSyncDirectoryValid(targetSettings)
        cloudSyncIsDirectoryValid = isValid
        return isValid
    }

    private func isCloudSyncDirectoryValid(_ cloudSync: CloudSyncSettings) -> Bool {
        guard cloudSync.enabled else {
            return true
        }

        let normalizedPath = cloudSync.rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPath.isEmpty else {
            LoggerService.debug("Cloud sync directory path is empty")
            return false
        }

        let url = URL(fileURLWithPath: normalizedPath)
        let fileManager = FileManager.default
        
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        } catch {
            LoggerService.debug("Failed to create cloud sync directory: \(error.localizedDescription)")
            return false
        }

        let probeURL = url.appendingPathComponent("pasty_write_probe_\(UUID().uuidString).tmp")
        do {
            try Data("ok".utf8).write(to: probeURL)
            try? fileManager.removeItem(at: probeURL)
            LoggerService.debug("Cloud sync directory validation successful for path: \(normalizedPath)")
            return true
        } catch {
            try? fileManager.removeItem(at: probeURL)
            LoggerService.debug("Cloud sync directory write probe failed for path: \(normalizedPath), error: \(error.localizedDescription)")
            return false
        }
    }

    func selectCloudSyncDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a directory for cloud sync"

        if panel.runModal() == .OK {
            if let url = panel.url {
                LoggerService.info("User selected cloud sync directory: \(url.path)")
                updateSettings { settings in
                    settings.cloudSync.rootPath = url.path
                }
            }
        } else {
            LoggerService.info("User cancelled cloud sync directory selection")
        }
    }

    func updateSettings(_ update: (inout PastySettings) -> Void) {
        settingsStore.updateSettings(update)
    }

    func restoreDefaults() {
        settingsStore.replaceSettings(.default)
    }

    func setClipboardDataDirectory(_ url: URL) {
        settingsStore.setClipboardDataDirectory(url)
    }

    func restoreDefaultClipboardDataDirectory() {
        settingsStore.restoreDefaultClipboardDataDirectory()
    }

    func toggleOCRLanguage(_ code: String) {
        settingsStore.updateSettings { settings in
            var languages = settings.ocr.languages
            if let index = languages.firstIndex(of: code) {
                languages.remove(at: index)
            } else {
                languages.append(code)
            }
            settings.ocr.languages = languages
        }
    }
}
