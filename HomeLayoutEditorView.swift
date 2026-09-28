import SwiftUI

struct HomeLayoutEditorView: View {
    @Binding var order: [HomeCardID]
    @Binding var hiddenSet: Set<HomeCardID>
    var onDone: () -> Void

    var onSaveFavorite: () -> Void
    var onResetToFavorite: () -> Void
    var hasFavorite: Bool

    @State private var editMode: EditMode = .active

    private let mainCards: [HomeCardID] = [.verseOfDay, .resumeReading]

    private var showMoreCards: [HomeCardID] {
        order.filter { !mainCards.contains($0) }
    }

    private func isVisible(_ id: HomeCardID) -> Bool {
        !hiddenSet.contains(id)
    }

    private func toggleVisibility(_ id: HomeCardID) {
        if hiddenSet.contains(id) {
            hiddenSet.remove(id)
        } else {
            hiddenSet.insert(id)
        }
        onDone()
    }

    private func resetToDefault() {
        order = HomeCardID.allCases
        hiddenSet = HomeLayoutStore.baselineHidden
        onDone()
    }

    private func showAll() {
        hiddenSet.removeAll()
        onDone()
    }

    private func moveShowMoreCards(from offsets: IndexSet, to destination: Int) {
        var reorderedCards = showMoreCards
        reorderedCards.move(fromOffsets: offsets, toOffset: destination)
        order = mainCards + reorderedCards
        onDone()
    }

    private func layoutRow(for id: HomeCardID) -> some View {
        HStack {
            Image(systemName: id.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(id.title)

            Spacer()

            Button {
                toggleVisibility(id)
            } label: {
                Label(
                    isVisible(id) ? "Shown" : "Hidden",
                    systemImage: isVisible(id) ? "eye" : "eye.slash"
                )
                .font(.subheadline)
                .foregroundStyle(isVisible(id) ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(isVisible(id) ? "Hide" : "Show") \(id.title)")
            .accessibilityHint("Changes whether this card is available on Home")
        }
    }

    @ViewBuilder
    private func footerButton(title: String, systemImage: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 12))
        .tint(.accentColor)
        .controlSize(.large)
        .font(.subheadline)
        .disabled(disabled)
    }

    var body: some View {
        List {
            Section {
                ForEach(mainCards) { id in
                    layoutRow(for: id)
                }
            } header: {
                Label("Main Home", systemImage: "house")
            } footer: {
                Text("Shown cards appear directly on Home. These are not part of the collapsed Show More section.")
            }

            Section {
                ForEach(showMoreCards) { id in
                    layoutRow(for: id)
                }
                .onMove(perform: moveShowMoreCards)
            } header: {
                Label("Inside Show More", systemImage: "square.grid.2x2")
            } footer: {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Shown cards become visible only after Show More is expanded. Drag to choose their order.")

                    footerButton(title: "Reset Layout", systemImage: "arrow.counterclockwise") {
                        resetToDefault()
                    }
                    footerButton(title: "Show All Cards", systemImage: "eye") {
                        showAll()
                    }
                    footerButton(title: "Apply Favorite", systemImage: "star", disabled: !hasFavorite) {
                        onResetToFavorite()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("Home Layout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save as Favorite") {
                    onSaveFavorite()
                }
            }
        }
    }
}
