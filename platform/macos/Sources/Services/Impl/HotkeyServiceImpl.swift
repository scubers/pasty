import Combine
import KeyboardShortcuts

final class HotkeyServiceImpl: HotkeyService {
    func register(name: KeyboardShortcuts.Name) -> AnyPublisher<Void, Never> {
        let subject = PassthroughSubject<Void, Never>()
        
        KeyboardShortcuts.onKeyDown(for: name) {
            LoggerService.debug("Hotkey triggered: \(name)")
            subject.send()
        }
        
        return subject.eraseToAnyPublisher()
    }
    
    func unregister() {
    }
}
