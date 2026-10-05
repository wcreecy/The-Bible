import SwiftUI
import UIKit

struct SettingsHomeLayoutSection: View {
    // Local UI state
    @State private var layoutOrder: [HomeCardID] = HomeLayoutStore.baselineOrder
    @State private var hiddenSet: Set<HomeCardID> = HomeLayoutStore.baselineHidden
    @State private var mainSet: Set<HomeCardID> = HomeLayoutStore.baselineMain
    @State private var showMoreVisible = HomeLayoutStore.defaultShowMoreVisible
    @AppStorage("homeBibleReaderVisible") private var bibleReaderVisible = HomeLayoutStore.defaultBibleReaderVisible

    private let layoutStore = HomeLayoutStore()

    private var hasFavoriteLayout: Bool { layoutStore.hasFavorite }

    private func loadHomeLayout() {
        let loaded = layoutStore.load()
        layoutOrder = loaded.order
        hiddenSet = loaded.hidden
        mainSet = loaded.main
        showMoreVisible = loaded.showMoreVisible
    }

    private func saveHomeLayout() {
        layoutStore.save(
            order: layoutOrder,
            hidden: hiddenSet,
            main: mainSet,
            showMoreVisible: showMoreVisible
        )
    }

    private func saveFavoriteLayout() {
        layoutStore.saveFavorite(
            order: layoutOrder,
            hidden: hiddenSet,
            main: mainSet,
            showMoreVisible: showMoreVisible,
            bibleReaderVisible: bibleReaderVisible
        )
    }

    private func applyFavoriteLayout() {
        layoutStore.applyFavoriteIfAvailable()
        let loaded = layoutStore.load()
        layoutOrder = loaded.order
        hiddenSet = loaded.hidden
        mainSet = loaded.main
        showMoreVisible = loaded.showMoreVisible
    }

    var body: some View {
        HomeLayoutEditorView(
            order: $layoutOrder,
            hiddenSet: $hiddenSet,
            mainSet: $mainSet,
            showMoreVisible: $showMoreVisible,
            allowsShowMore: UIDevice.current.userInterfaceIdiom != .pad,
            onDone: saveHomeLayout,
            onSaveFavorite: saveFavoriteLayout,
            onResetToFavorite: applyFavoriteLayout,
            hasFavorite: hasFavoriteLayout
        )
        .onAppear(perform: loadHomeLayout)
    }
}
