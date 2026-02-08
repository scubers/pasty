import AppKit
import Combine

/// Node in the hotkey permission chain
private final class HotkeyPermissionNode {
    weak var owner: InAppHotkeyOwner?
    var prev: HotkeyPermissionNode?
    var next: HotkeyPermissionNode?
    var isResigned: Bool = false

    init(owner: InAppHotkeyOwner) {
        self.owner = owner
    }
}

/// Manages in-app hotkey permissions using a linked list structure.
/// Ensures only one owner can handle hotkeys at a time, with automatic fallback.
@MainActor
final class InAppHotkeyPermissionManager {
    static let shared = InAppHotkeyPermissionManager()

    private var head: HotkeyPermissionNode?
    private var tail: HotkeyPermissionNode?
    private var activeNode: HotkeyPermissionNode?

    private var isApplicationActive: Bool = false

    private init() {
        setupApplicationStateObservers()
    }

    private func setupApplicationStateObservers() {
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.setApplicationActive(true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)
            .sink { [weak self] _ in
                self?.setApplicationActive(false)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    func setApplicationActive(_ active: Bool) {
        isApplicationActive = active
    }

    func request(owner: InAppHotkeyOwner) -> InAppHotkeyPermissionToken {
        cleanupDeadNodes()

        let node = HotkeyPermissionNode(owner: owner)

        if tail == nil {
            head = node
            tail = node
        } else {
            tail?.next = node
            node.prev = tail
            tail = node
        }

        activeNode = node

        return HotkeyPermissionToken { [weak self] in
            self?.resignPermission(ownerID: owner.hotkeyOwnerID)
        }
    }

    func resignPermission(ownerID: String) {
        guard let node = findNode(ownerID: ownerID) else {
            return
        }

        node.isResigned = true

        if node === activeNode {
            activeNode = findNextActiveCandidate(from: node.prev)
        }

        cleanupDeadNodes()
    }

    func handle(event: NSEvent) -> Bool {
        guard isApplicationActive else {
            return false
        }

        cleanupDeadNodes()

        guard let currentNode = activeNode else {
            return false
        }

        return findAndHandleEvent(from: currentNode, event: event)
    }

    private func findAndHandleEvent(from node: HotkeyPermissionNode?, event: NSEvent) -> Bool {
        guard let node = node else {
            return false
        }

        if node.isResigned || node.owner == nil {
            return findAndHandleEvent(from: node.prev, event: event)
        }

        guard let owner = node.owner, owner.canHandleInAppHotkey() else {
            return findAndHandleEvent(from: node.prev, event: event)
        }

        if owner.handleInAppHotkey(event) {
            return true
        }

        return findAndHandleEvent(from: node.prev, event: event)
    }

    private func findNextActiveCandidate(from node: HotkeyPermissionNode?) -> HotkeyPermissionNode? {
        guard let node = node else {
            return nil
        }

        if node.isResigned || node.owner == nil {
            return findNextActiveCandidate(from: node.prev)
        }

        return node
    }

    private func findNode(ownerID: String) -> HotkeyPermissionNode? {
        var node: HotkeyPermissionNode? = tail

        while let n = node {
            if !n.isResigned, n.owner?.hotkeyOwnerID == ownerID {
                return n
            }
            node = n.prev
        }

        return nil
    }

    private func cleanupDeadNodes() {
        var node: HotkeyPermissionNode? = head

        while let n = node {
            if n.isResigned || n.owner == nil {
                removeNode(n)
            }
            node = n.next
        }
    }

    private func removeNode(_ node: HotkeyPermissionNode) {
        if let prev = node.prev {
            prev.next = node.next
        } else {
            head = node.next
        }

        if let next = node.next {
            next.prev = node.prev
        } else {
            tail = node.prev
        }

        if node === activeNode {
            activeNode = findNextActiveCandidate(from: node.prev)
        }
    }
}
