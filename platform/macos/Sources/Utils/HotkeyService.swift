import Combine
import KeyboardShortcuts

protocol HotkeyService {
    func register(name: KeyboardShortcuts.Name) -> AnyPublisher<Void, Never>
    func unregister()
}

extension KeyboardShortcuts.Name {
    static let togglePanel = Self("togglePanel", default: .init(.v, modifiers: [.command, .shift]))
}
