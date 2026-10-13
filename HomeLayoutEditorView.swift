import SwiftUI

struct HomeLayoutEditorView: View {
    @Binding var order: [HomeCardID]
    @Binding var hiddenSet: Set<HomeCardID>
    /// The iPad dashboard pins Verse of the Day above the card grid, so it is toggled separately.
    let usesDashboard: Bool
    var onDone: () -> Void

    var onSaveFavorite: () -> Void
    var onResetToFavorite: () -> Void
    var hasFavorite: Bool

    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @AppStorage("homeCustomizeButtonVisible") private var customizeButtonVisible = true
    @AppStorage("homeBibleReaderVisible") private var bibleReaderVisible = HomeLayoutStore.defaultBibleReaderVisible
    @State private var highlightedCards: Set<HomeCardID> = []
    @State private var reorderConfirmation: String?
    @State private var reorderFeedbackTask: Task<Void, Never>?
    @State private var isShowingReplaceSavedLayoutConfirmation = false

    /// The cards listed for reordering, in Home order.
    private var listedCards: [HomeCardID] {
        usesDashboard ? order.filter { $0 != .verseOfDay } : order
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
        order = HomeLayoutStore.baselineOrder
        hiddenSet = HomeLayoutStore.baselineHidden
        customizeButtonVisible = true
        bibleReaderVisible = HomeLayoutStore.defaultBibleReaderVisible
        onDone()
    }

    private func showAll() {
        hiddenSet.removeAll()
        bibleReaderVisible = true
        onDone()
    }

    private func hideAllCards() {
        hiddenSet = Set(HomeCardID.allCases)
        bibleReaderVisible = false
        onDone()
    }

    private var isMinimalHome: Bool {
        hiddenSet.isSuperset(of: Set(HomeCardID.allCases)) && !bibleReaderVisible
    }

    private func useMinimalHome() {
        hiddenSet = Set(HomeCardID.allCases)
        bibleReaderVisible = false
        onDone()
    }

    private func moveCard(_ id: HomeCardID, by offset: Int) {
        var cards = listedCards
        guard let index = cards.firstIndex(of: id) else { return }
        let destination = index + offset
        guard cards.indices.contains(destination) else { return }
        let swappedCard = cards[destination]
        cards.swapAt(index, destination)
        // The dashboard keeps Verse of the Day first; it is not part of the reorderable list there.
        withAnimation(.snappy) {
            order = usesDashboard ? [.verseOfDay] + cards : cards
            highlightedCards = [id, swappedCard]
            reorderConfirmation = "\(id.title) moved to position \(destination + 1)"
        }
        onDone()
        Haptics.selection()
        scheduleReorderFeedbackReset()
    }

    private func canMoveUp(_ id: HomeCardID) -> Bool {
        listedCards.firstIndex(of: id).map { $0 > 0 } == true
    }

    private func canMoveDown(_ id: HomeCardID) -> Bool {
        listedCards.firstIndex(of: id).map { $0 < listedCards.count - 1 } == true
    }

    private func scheduleReorderFeedbackReset() {
        reorderFeedbackTask?.cancel()
        reorderFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                highlightedCards.removeAll()
                reorderConfirmation = nil
            }
        }
    }

    private func layoutRow(for id: HomeCardID, position: Int) -> some View {
        HStack {
            Text(position, format: .number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.tint)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.12), in: Circle())

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

            HStack(spacing: 4) {
                Button {
                    moveCard(id, by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(width: 28, height: 32)
                }
                .disabled(!canMoveUp(id))
                .accessibilityLabel("Move \(id.title) up")

                Button {
                    moveCard(id, by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: 28, height: 32)
                }
                .disabled(!canMoveDown(id))
                .accessibilityLabel("Move \(id.title) down")
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .background(
            highlightedCards.contains(id) ? Color.accentColor.opacity(0.14) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityValue("Position \(position) of \(listedCards.count)")
    }

    @ViewBuilder
    private func footerButton(title: String, systemImage: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .center)
                .lineLimit(2)
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
                    id: "home.layoutEditor",
                    title: "Make Home yours",
                    message: "Use the eye buttons to show or hide cards, and the arrows to reorder them.",
                    systemImage: "rectangle.grid.1x2"
                )
                .listRowSeparator(.hidden)
            }

            if usesDashboard {
                Section {
                    Toggle(
                        "Verse of the Day",
                        systemImage: "sun.max",
                        isOn: Binding(
                            get: { isVisible(.verseOfDay) },
                            set: { _ in toggleVisibility(.verseOfDay) }
                        )
                    )

                    Toggle(
                        "Today's Reading",
                        systemImage: "book.pages",
                        isOn: $bibleReaderVisible
                    )
                } header: {
                    Label("iPad Card Visibility", systemImage: "eye")
                } footer: {
                    Text("Choose whether Verse of the Day and the Today's Reading panel appear on the iPad Home dashboard. Today's Reading shows your bookmark or the Verse of the Day in its chapter.")
                }
            }

            Section {
                if let reorderConfirmation {
                    Label(reorderConfirmation, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.vertical, 4)
                }

                ForEach(Array(listedCards.enumerated()), id: \.element) { index, id in
                    layoutRow(for: id, position: index + 1)
                }

                // iPad keeps Customize Home in the toolbar; iPhone shows it below the cards.
                if !usesDashboard {
                    Toggle(isOn: $customizeButtonVisible) {
                        Label("Show ‘Customize Home’ on Home", systemImage: customizeButtonVisible ? "eye" : "eye.slash")
                    }
                    .toggleStyle(StatusColorToggleStyle())
                }
            } header: {
                Label("Home Cards", systemImage: "house")
            } footer: {
                Text("Shown cards appear on Home. Use the arrows to choose their order.")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    footerButton(title: "Show All Cards", systemImage: "eye") {
                        showAll()
                    }
                    footerButton(title: "Hide All Cards", systemImage: "eye.slash", disabled: isMinimalHome) {
                        hideAllCards()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } header: {
                Label("Card Visibility", systemImage: "eye")
            } footer: {
                Text("Show or hide every Home card at once. You can still adjust individual cards above.")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    if usesDashboard {
                        footerButton(
                            title: "Use Minimal Home",
                            systemImage: "rectangle.3.group",
                            disabled: isMinimalHome
                        ) {
                            useMinimalHome()
                        }
                    }
                    footerButton(title: "Restore Default Layout", systemImage: "arrow.counterclockwise") {
                        resetToDefault()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } header: {
                Label("Layout Presets", systemImage: "rectangle.3.group")
            } footer: {
                Text(usesDashboard ? "Minimal Home replaces dashboard cards with Read, Continue Reading, and Search actions." : "Restore the original Home card arrangement and visibility.")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    footerButton(
                        title: "Save Layout",
                        systemImage: hasFavorite ? "arrow.triangle.2.circlepath" : "square.and.arrow.down"
                    ) {
                        if hasFavorite {
                            isShowingReplaceSavedLayoutConfirmation = true
                        } else {
                            onSaveFavorite()
                        }
                    }
                    footerButton(title: "Apply Saved Layout", systemImage: "arrow.clockwise", disabled: !hasFavorite) {
                        onResetToFavorite()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } header: {
                Label("Saved Layout", systemImage: "bookmark")
            } footer: {
                Text("Save this arrangement to restore it later.")
            }

        }
        .navigationTitle("Home Layout")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Replace Saved Layout?",
            isPresented: $isShowingReplaceSavedLayoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Replace Saved Layout", role: .destructive, action: onSaveFavorite)
        } message: {
            Text("Your previous saved layout will be replaced with the current arrangement.")
        }
    }
}

private struct StatusColorToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                configuration.isOn.toggle()
            }
        } label: {
            HStack {
                configuration.label

                Spacer()

                Capsule()
                    .fill(configuration.isOn ? Color.green : Color.red)
                    .frame(width: 51, height: 31)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(.white)
                            .padding(2)
                            .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
                    }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
