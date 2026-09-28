import SwiftUI

struct SettingsHomeLayoutSection: View {
    // Local UI state
    @State private var layoutOrder: [HomeCardID] = HomeCardID.allCases
    @State private var hiddenSet: Set<HomeCardID> = []

    private let layoutStore = HomeLayoutStore()

    private var hasFavoriteLayout: Bool { layoutStore.hasFavorite }

    private func loadHomeLayout() {
        let loaded = layoutStore.load()
        layoutOrder = loaded.order
        hiddenSet = loaded.hidden
    }

    private func saveHomeLayout() {
        layoutStore.save(order: layoutOrder, hidden: hiddenSet)
    }

    private func saveFavoriteLayout() {
        layoutStore.saveFavorite(order: layoutOrder, hidden: hiddenSet)
    }

    private func applyFavoriteLayout() {
        layoutStore.applyFavoriteIfAvailable()
        let loaded = layoutStore.load()
        layoutOrder = loaded.order
        hiddenSet = loaded.hidden
    }

    var body: some View {
        Section(
            header: Text("Home Layout").foregroundStyle(.primary),
            footer: Text("Choose what appears directly on Home and what is available inside the collapsed Show More section.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        ) {

            NavigationLink {
                HomeLayoutEditorView(
                    order: $layoutOrder,
                    hiddenSet: $hiddenSet,
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
