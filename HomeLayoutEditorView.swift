import SwiftUI

struct HomeLayoutEditorView: View {
    @Binding var order: [HomeCardID]
    @Binding var hiddenSet: Set<HomeCardID>
    @Binding var mainSet: Set<HomeCardID>
    let allowsShowMore: Bool
    var onDone: () -> Void

    var onSaveFavorite: () -> Void
    var onResetToFavorite: () -> Void
    var hasFavorite: Bool

    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false

    private var mainCards: [HomeCardID] {
        order.filter { mainSet.contains($0) }
    }

    private var showMoreCards: [HomeCardID] {
        order.filter { !mainSet.contains($0) }
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
        mainSet = HomeLayoutStore.baselineMain
        onDone()
    }

    private func showAll() {
        hiddenSet.removeAll()
        onDone()
    }

    private func moveDroppedCards(_ rawIDs: [String], before target: HomeCardID?, inMain: Bool) -> Bool {
        let movedCards = rawIDs.compactMap(HomeCardID.init(rawValue:)).filter { $0 != .verseOfDay }
        guard !movedCards.isEmpty else { return false }

        var destinationCards = inMain ? mainCards : showMoreCards
        destinationCards.removeAll { movedCards.contains($0) }

        let insertionIndex = target.flatMap { destinationCards.firstIndex(of: $0) } ?? destinationCards.endIndex
        destinationCards.insert(contentsOf: movedCards, at: insertionIndex)

        if inMain {
            mainSet.formUnion(movedCards)
        } else {
            mainSet.subtract(movedCards)
        }

        let reorderedMain = inMain ? destinationCards : mainCards
        let reorderedShowMore = inMain ? showMoreCards : destinationCards
        order = reorderedMain + reorderedShowMore
        onDone()
        return true
    }

    @ViewBuilder
    private func reorderableRow(for id: HomeCardID, inMain: Bool) -> some View {
        if id == .verseOfDay {
            layoutRow(for: id)
                .dropDestination(for: String.self) { rawIDs, _ in
                    _ = moveDroppedCards(rawIDs, before: id, inMain: inMain)
                }
        } else {
            layoutRow(for: id)
                .draggable(id.rawValue)
                .dropDestination(for: String.self) { rawIDs, _ in
                    _ = moveDroppedCards(rawIDs, before: id, inMain: inMain)
                }
        }
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
        .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
        .controlSize(.large)
        .font(.subheadline)
        .disabled(disabled)
    }

    var body: some View {
        List {
            if contextualTipsEnabled {
                ContextualTipView(
                    title: "Make Home yours",
                    message: allowsShowMore
                        ? "Drag cards to reorder them or move them between Main Home and Show More."
                        : "Use the eye buttons to show or hide cards, and drag to reorder them.",
                    systemImage: "rectangle.grid.1x2"
                )
                .listRowSeparator(.hidden)
            }

            Section {
                ForEach(allowsShowMore ? mainCards : order) { id in
                    reorderableRow(for: id, inMain: true)
                }
            } header: {
                Label(allowsShowMore ? "Main Home" : "Home Cards", systemImage: "house")
            } footer: {
                Text(allowsShowMore
                    ? "Shown cards appear directly on Home. Drag a card here to move it from Show More."
                    : "Shown cards appear on Home. Drag to choose their order.")
            }

            if allowsShowMore {
                Section {
                    if showMoreCards.isEmpty {
                        Label("Drag cards here", systemImage: "square.and.arrow.down")
                            .foregroundStyle(.secondary)
                            .dropDestination(for: String.self) { rawIDs, _ in
                                _ = moveDroppedCards(rawIDs, before: nil, inMain: false)
                            }
                    }
                    ForEach(showMoreCards) { id in
                        reorderableRow(for: id, inMain: false)
                    }
                } header: {
                    Label("Inside Show More", systemImage: "square.grid.2x2")
                } footer: {
                    Text("Shown cards become visible only after Show More is expanded. Drag a card here to move it from Main Home.")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
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

            HomeBackgroundSection()
        }
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

private struct HomeBackgroundSection: View {
    var body: some View {
        Section {
            BackgroundEditor(tab: .home, showsApplyToAllPages: false)
        } header: {
            Label("Home Background", systemImage: "photo.on.rectangle")
        } footer: {
            Text("Choose the default background, a photo, or a custom color for Home.")
        }
    }
}
