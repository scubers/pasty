import Foundation
import SwiftUI
import Combine

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

    func binding<Value>(_ keyPath: WritableKeyPath<PastySettings, Value>) -> Binding<Value> {
        Binding(
            get: { self.coordinator.settings[keyPath: keyPath] },
            set: { [weak self] newValue in
                self?.settingsStore.updateSettings { $0[keyPath: keyPath] = newValue }
            }
        )
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
