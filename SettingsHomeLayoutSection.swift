import SwiftUI
import UIKit

struct SettingsHomeLayoutSection: View {
    // Local UI state
    @State private var layoutOrder: [HomeCardID] = HomeCardID.allCases
    @State private var hiddenSet: Set<HomeCardID> = []
    @State private var mainSet: Set<HomeCardID> = HomeLayoutStore.baselineMain

    private let layoutStore = HomeLayoutStore()

    private var hasFavoriteLayout: Bool { layoutStore.hasFavorite }

    private func loadHomeLayout() {
        let loaded = layoutStore.load()
        layoutOrder = loaded.order
        hiddenSet = loaded.hidden
        mainSet = loaded.main
    }

    private func saveHomeLayout() {
        layoutStore.save(order: layoutOrder, hidden: hiddenSet, main: mainSet)
    }

    private func saveFavoriteLayout() {
        layoutStore.saveFavorite(order: layoutOrder, hidden: hiddenSet, main: mainSet)
    }

    private func applyFavoriteLayout() {
        layoutStore.applyFavoriteIfAvailable()
        let loaded = layoutStore.load()
        layoutOrder = loaded.order
        hiddenSet = loaded.hidden
        mainSet = loaded.main
    }

    var body: some View {
        Section(
            header: Text("Home Layout").foregroundStyle(.primary),
            footer: Text(UIDevice.current.userInterfaceIdiom == .pad
                ? "Choose which cards appear on Home and arrange their order."
                : "Choose what appears directly on Home and what is available inside the collapsed Show More section.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        ) {

            NavigationLink {
                HomeLayoutEditorView(
                    order: $layoutOrder,
                    hiddenSet: $hiddenSet,
                    mainSet: $mainSet,
                    allowsShowMore: UIDevice.current.userInterfaceIdiom != .pad,
                    onDone: { saveHomeLayout() },
                    onSaveFavorite: { saveFavoriteLayout() },
                    onResetToFavorite: { applyFavoriteLayout() },
                    hasFavorite: hasFavoriteLayout
                )
            } label: {
                Label("Customize Home Content", systemImage: "slider.horizontal.3")
            }
        }
        .headerProminence(.increased)
        .onAppear(perform: loadHomeLayout)
    }
}
