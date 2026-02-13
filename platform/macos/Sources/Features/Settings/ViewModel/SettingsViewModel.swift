import Foundation
import SwiftUI
import Combine
import PastyCore

private struct CloudSyncStatusPayload: Decodable {
    let deviceId: String?
    let stateFileErrorCount: Int?
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
            .sink { [weak self] _ in
                self?.updateCloudSyncDirectoryValidation()
            }
            .store(in: &cancellables)

        updateCloudSyncDirectoryValidation()
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

    func binding<Value>(_ keyPath: WritableKeyPath<PastySettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.coordinator.settings[keyPath: keyPath] },
            set: { [weak self] newValue in
                self?.settingsStore.updateSettings { $0[keyPath: keyPath] = newValue }
            }
        )
    }

    func refreshCloudSyncStatus() {
        let canRunImport = updateCloudSyncDirectoryValidation() && settings.cloudSync.enabled

        guard let runtime = coordinator.coreRuntime else {
            deviceId = nil
            cloudSyncErrorCount = 0
            return
        }
        let runtimeAddress = UInt(bitPattern: runtime)

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let runtime = UnsafeMutableRawPointer(bitPattern: runtimeAddress) else {
                return
            }
            let importSucceeded = canRunImport ? pasty_cloud_sync_import_now(runtime) : false
            var statusDeviceId: String?
            var statusErrorCount = 0

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
                }
            }

            Task { @MainActor in
                guard let self else {
                    return
                }
                self.deviceId = statusDeviceId
                self.cloudSyncErrorCount = max(0, statusErrorCount)
                if importSucceeded {
                    self.cloudSyncLastSync = Date()
                }
            }
        }
    }

    @discardableResult
    private func updateCloudSyncDirectoryValidation() -> Bool {
        let isValid = isCloudSyncDirectoryValid(settings.cloudSync)
        cloudSyncIsDirectoryValid = isValid
        return isValid
    }

    private func isCloudSyncDirectoryValid(_ cloudSync: CloudSyncSettings) -> Bool {
        guard cloudSync.enabled else {
            return true
        }

        let normalizedPath = cloudSync.rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedPath.isEmpty else {
            return false
        }

        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: normalizedPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            return false
        }

        return fileManager.isReadableFile(atPath: normalizedPath)
            && fileManager.isWritableFile(atPath: normalizedPath)
    }

    func selectCloudSyncDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a directory for cloud sync"

        if panel.runModal() == .OK {
            if let url = panel.url {
                updateSettings { settings in
                    settings.cloudSync.rootPath = url.path
                }
            }
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
