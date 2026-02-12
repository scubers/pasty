import Foundation

struct MainPanelSelectionStore {
    func defaultSelectionID(in items: [ClipboardItemRow]) -> String? {
        items.first?.id
    }

    func movedSelection(
        currentSelectionID: String?,
        in items: [ClipboardItemRow],
        delta: Int
    ) -> String? {
        guard !items.isEmpty else {
            return nil
        }
        guard let currentSelectionID,
              let currentIndex = items.firstIndex(where: { $0.id == currentSelectionID }) else {
            return defaultSelectionID(in: items)
        }

        let nextIndex = currentIndex + delta
        guard nextIndex >= 0, nextIndex < items.count else {
            return currentSelectionID
        }

        return items[nextIndex].id
    }

    func selectionAfterDeletion(
        deletedID: String,
        previousItems: [ClipboardItemRow],
        updatedItems: [ClipboardItemRow],
        currentSelectionID: String?
    ) -> String? {
        guard !updatedItems.isEmpty else {
            return nil
        }

        guard let deletedIndex = previousItems.firstIndex(where: { $0.id == deletedID }) else {
            if let currentSelectionID,
               updatedItems.contains(where: { $0.id == currentSelectionID }) {
                return currentSelectionID
            }
            return defaultSelectionID(in: updatedItems)
        }

        let preferredIndex = min(deletedIndex, updatedItems.count - 1)
        return updatedItems[preferredIndex].id
    }
}
