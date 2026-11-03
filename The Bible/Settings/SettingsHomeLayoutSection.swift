import SwiftUI
import UIKit

struct SettingsHomeLayoutSection: View {
    // Local UI state
    @State private var layoutOrder: [HomeCardID] = HomeLayoutStore.baselineOrder
    @State private var hiddenSet: Set<HomeCardID> = HomeLayoutStore.baselineHidden
    @State private var columns: HomeColumnLayout = HomeLayoutStore.baselineColumns
    @AppStorage("homeBibleReaderVisible") private var bibleReaderVisible = HomeLayoutStore.defaultBibleReaderVisible

    private let layoutStore = HomeLayoutStore()

    private var hasFavoriteLayout: Bool { layoutStore.hasFavorite }

    private func loadHomeLayout() {
        let loaded = layoutStore.load()
        layoutOrder = loaded.order
        hiddenSet = loaded.hidden
        columns = loaded.columns
    }

    private func saveHomeLayout() {
        layoutStore.save(order: layoutOrder, hidden: hiddenSet, columns: columns)
    }

    private func saveFavoriteLayout() {
        layoutStore.saveFavorite(
            order: layoutOrder,
            hidden: hiddenSet,
            columns: columns,
            bibleReaderVisible: bibleReaderVisible
        )
    }

    private func applyFavoriteLayout() {
        layoutStore.applyFavoriteIfAvailable()
        loadHomeLayout()
    }

    var body: some View {
        HomeLayoutEditorView(
            order: $layoutOrder,
            hiddenSet: $hiddenSet,
            columns: $columns,
            usesDashboard: UIDevice.current.userInterfaceIdiom == .pad,
            onDone: saveHomeLayout,
            onSaveFavorite: saveFavoriteLayout,
            onResetToFavorite: applyFavoriteLayout,
            hasFavorite: hasFavoriteLayout
        )
        .onAppear(perform: loadHomeLayout)
    }
}
