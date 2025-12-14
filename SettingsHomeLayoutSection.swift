import SwiftUI

struct SettingsHomeLayoutSection: View {
    // Local UI state
    @State private var layoutOrder: [SettingsView.HomeCardID] = SettingsView.HomeCardID.allCases
    @State private var hiddenSet: Set<SettingsView.HomeCardID> = []

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
        Section(header: Text("Home Layout"), footer: Text("Reorder or hide sections on the Home page. The title card always stays at the top.").font(.footnote).foregroundStyle(.secondary)) {

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
                Label("Edit Order & Visibility", systemImage: "arrow.up.arrow.down")
            }
        }
        .headerProminence(.increased)
        .onAppear(perform: loadHomeLayout)
    }
}
