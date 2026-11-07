import Foundation
import Observation

/// Home's card arrangement: the narrow-width order, the hidden cards, and the iPad
/// dashboard columns, kept in step with HomeLayoutStore. Callers wrap changes in
/// `withAnimation` and play haptics; this type only owns the state and persistence.
@MainActor
@Observable
final class HomeLayoutModel {
    var order: [HomeCardID] = HomeLayoutStore.baselineOrder
    var hidden: Set<HomeCardID> = HomeLayoutStore.baselineHidden
    var columns: HomeColumnLayout = HomeLayoutStore.baselineColumns

    /// Every card is hidden, so only the reader panel (if shown) is left.
    var hidesEveryCard: Bool {
        hidden.isSuperset(of: HomeCardID.allCases)
    }

    var visibleOrder: [HomeCardID] {
        order.filter { !hidden.contains($0) }
    }

    func load() {
        let loaded = HomeLayoutStore().load()
        order = loaded.order
        hidden = loaded.hidden
        columns = loaded.columns
    }

    func save() {
        HomeLayoutStore().save(order: order, hidden: hidden, columns: columns)
    }

    /// Applies a column change from Edit Home and keeps the narrow-width order in step.
    func updateColumns(_ change: (inout HomeColumnLayout) -> Void) {
        change(&columns)
        order = columns.flatOrder
        save()
    }

    func toggleHidden(_ id: HomeCardID) {
        if hidden.contains(id) {
            hidden.remove(id)
        } else {
            hidden.insert(id)
        }
        save()
    }

    func saveFavorite(bibleReaderVisible: Bool) {
        HomeLayoutStore().saveFavorite(
            order: order,
            hidden: hidden,
            columns: columns,
            bibleReaderVisible: bibleReaderVisible
        )
    }

    func applyFavorite() {
        HomeLayoutStore().applyFavoriteIfAvailable()
        load()
    }
}
