import Foundation
import Combine

final class AppCoordinator: ObservableObject {
    enum Event {
        case settingsWarning(String)
        case clipboardImageCaptured
    }

    @Published private(set) var settings: PastySettings = .default
    @Published private(set) var appData: URL = AppPaths.appDataDirectory()
    @Published private(set) var clipboardData: URL = AppPaths.appDataDirectory().appendingPathComponent("ClipboardData")
    @Published private(set) var lastWarningMessage: String?

    let events = PassthroughSubject<Event, Never>()

    func setSettings(_ value: PastySettings) {
        settings = value
    }

    func updateSettings(_ update: (inout PastySettings) -> Void) {
        var next = settings
        update(&next)
        settings = next
    }

    func setClipboardData(_ value: URL) {
        clipboardData = value
    }

    func setWarningMessage(_ value: String?) {
        lastWarningMessage = value
    }

    func dispatch(_ event: Event) {
        events.send(event)
    }
}
