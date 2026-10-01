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

    @State private var editMode: EditMode = .active
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

    private func moveShowMoreCards(from offsets: IndexSet, to destination: Int) {
        var reorderedCards = showMoreCards
        reorderedCards.move(fromOffsets: offsets, toOffset: destination)
        order = mainCards + reorderedCards
        onDone()
    }

    private func moveMainCards(from offsets: IndexSet, to destination: Int) {
        var reorderedCards = mainCards
        reorderedCards.move(fromOffsets: offsets, toOffset: destination)
        order = reorderedCards + showMoreCards
        onDone()
    }

    private func moveAllCards(from offsets: IndexSet, to destination: Int) {
        order.move(fromOffsets: offsets, toOffset: destination)
        onDone()
    }

    private func moveToOtherSection(_ id: HomeCardID) {
        if mainSet.contains(id) {
            mainSet.remove(id)
        } else {
            mainSet.insert(id)
        }
        order = mainCards + showMoreCards
        onDone()
    }

    private func layoutRow(for id: HomeCardID) -> some View {
        HStack {
            Image(systemName: id.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(id.title)

            Spacer()

            if allowsShowMore {
                Button {
                    moveToOtherSection(id)
                } label: {
                    Label(
                        mainSet.contains(id) ? "Move to Show More" : "Move to Main Home",
                        systemImage: mainSet.contains(id) ? "arrow.down.square" : "arrow.up.square"
                    )
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mainSet.contains(id) ? "Move to Show More" : "Move to Main Home")
            }

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
                        ? "Use the arrow buttons to move cards between Main Home and Show More. Drag to reorder cards."
                        : "Use the eye buttons to show or hide cards, and drag to reorder them.",
                    systemImage: "rectangle.grid.1x2"
                )
                .listRowSeparator(.hidden)
            }

            Section {
                ForEach(allowsShowMore ? mainCards : order) { id in
                    layoutRow(for: id)
                        .moveDisabled(id == .verseOfDay)
                }
                .onMove(perform: allowsShowMore ? moveMainCards : moveAllCards)
            } header: {
                Label(allowsShowMore ? "Main Home" : "Home Cards", systemImage: "house")
            } footer: {
                Text(allowsShowMore
                    ? "Shown cards appear directly on Home. Use the arrow button to move a card to Show More."
                    : "Shown cards appear on Home. Drag to choose their order.")
            }

            if allowsShowMore {
                Section {
                    ForEach(showMoreCards) { id in
                        layoutRow(for: id)
                            .moveDisabled(id == .verseOfDay)
                    }
                    .onMove(perform: moveShowMoreCards)
                } header: {
                    Label("Inside Show More", systemImage: "square.grid.2x2")
                } footer: {
                    Text("Shown cards become visible only after Show More is expanded. Use the arrow button to move a card to Main Home.")
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
