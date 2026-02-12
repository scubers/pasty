import Foundation

struct MainPanelListStore {
    func removingItem(withID itemID: String, from items: [ClipboardItemRow]) -> [ClipboardItemRow] {
        items.filter { $0.id != itemID }
    }

    func replacingItem(_ item: ClipboardItemRow, in items: [ClipboardItemRow]) -> [ClipboardItemRow] {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else {
            return items
        }
        var updated = items
        updated[index] = item
        return updated
    }
}
