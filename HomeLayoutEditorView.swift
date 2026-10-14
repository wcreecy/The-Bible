import SwiftUI

struct HomeLayoutEditorView: View {
    @Binding var order: [HomeCardID]
    @Binding var hiddenSet: Set<HomeCardID>
    /// The iPad dashboard's two card columns; edited instead of `order` when `usesDashboard`.
    @Binding var columns: HomeColumnLayout
    /// iPad arranges cards in two columns beside the Today's Reading panel.
    let usesDashboard: Bool
    var onDone: () -> Void

    var onSaveFavorite: () -> Void
    var onResetToFavorite: () -> Void
    var hasFavorite: Bool

    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @AppStorage("homeCustomizeButtonVisible") private var customizeButtonVisible = true
    @AppStorage("homeBibleReaderVisible") private var bibleReaderVisible = HomeLayoutStore.defaultBibleReaderVisible
    @AppStorage(HomeLayoutStore.keyBibleReaderOnLeft) private var bibleReaderOnLeft = false
    @State private var highlightedCards: Set<HomeCardID> = []
    @State private var reorderConfirmation: String?
    @State private var reorderFeedbackTask: Task<Void, Never>?
    @State private var isShowingReplaceSavedLayoutConfirmation = false

    /// The cards listed for reordering on iPhone, in Home order.
    private var listedCards: [HomeCardID] { order }

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
        columns = HomeLayoutStore.baselineColumns
        customizeButtonVisible = true
        bibleReaderVisible = HomeLayoutStore.defaultBibleReaderVisible
        bibleReaderOnLeft = false
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
        withAnimation(.snappy) {
            order = cards
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

    // MARK: - iPad columns

    /// Applies a column change, keeps the narrow-width order in step, and confirms it.
    /// Drag moves pass no confirmation: showing it adds a section while the List is still
    /// finishing the row move, which the List can't reconcile.
    private func changeColumns(highlighting ids: Set<HomeCardID>, confirmation: String?, _ change: (inout HomeColumnLayout) -> Void) {
        withAnimation(.snappy) {
            change(&columns)
            order = columns.flatOrder
            highlightedCards = ids
            if let confirmation {
                reorderConfirmation = confirmation
            }
        }
        if let confirmation {
            AccessibilityNotification.Announcement(confirmation).post()
        }
        onDone()
        Haptics.selection()
        scheduleReorderFeedbackReset()
    }

    private func moveToOtherColumn(_ id: HomeCardID) {
        guard let column = columns.column(of: id) else { return }
        changeColumns(highlighting: [id], confirmation: "\(id.title) moved to the \(column.other.title.lowercased())") {
            $0.moveToOtherColumn(id)
        }
    }

    private func moveInColumn(_ id: HomeCardID, by offset: Int) {
        guard let column = columns.column(of: id),
              let row = columns[column].firstIndex(of: id),
              columns[column].indices.contains(row + offset) else { return }
        let swappedCard = columns[column][row + offset]
        changeColumns(highlighting: [id, swappedCard], confirmation: "\(id.title) moved to position \(row + offset + 1)") {
            $0.move(id, by: offset)
        }
    }

    private func moveInColumn(_ column: HomeColumn, fromOffsets source: IndexSet, toOffset destination: Int) {
        let moved = source.map { columns[column][$0] }
        changeColumns(highlighting: Set(moved), confirmation: nil) {
            $0[column].move(fromOffsets: source, toOffset: destination)
        }
    }

    private func columnRow(for id: HomeCardID, in column: HomeColumn, position: Int) -> some View {
        let otherColumn = column.other
        return HStack {
            Image(systemName: id.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(id.title)
                .foregroundStyle(isVisible(id) ? .primary : .secondary)

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

            Button {
                moveToOtherColumn(id)
            } label: {
                Image(systemName: otherColumn == .right ? "arrow.right.circle" : "arrow.left.circle")
                    .font(.title3)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .accessibilityLabel("Move \(id.title) to the \(otherColumn.title.lowercased())")
        }
        .padding(.vertical, 4)
        .background(
            highlightedCards.contains(id) ? Color.accentColor.opacity(0.14) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .swipeActions(edge: otherColumn == .right ? .trailing : .leading) {
            Button("Move to \(otherColumn.title)", systemImage: otherColumn == .right ? "arrow.right" : "arrow.left") {
                moveToOtherColumn(id)
            }
            .tint(.accentColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(column.title), position \(position) of \(columns[column].count), \(isVisible(id) ? "shown" : "hidden")")
        .accessibilityActions {
            if columns.canMove(id, by: -1) {
                Button("Move up") { moveInColumn(id, by: -1) }
            }
            if columns.canMove(id, by: 1) {
                Button("Move down") { moveInColumn(id, by: 1) }
            }
            Button("Move to \(otherColumn.title)") { moveToOtherColumn(id) }
            Button(isVisible(id) ? "Hide" : "Show") { toggleVisibility(id) }
        }
    }

    @ViewBuilder
    private var dashboardSections: some View {
        Section {
            Toggle(
                "Today's Reading",
                systemImage: "book.pages",
                isOn: $bibleReaderVisible
            )

            Picker("Side", selection: $bibleReaderOnLeft) {
                Text("Left").tag(true)
                Text("Right").tag(false)
            }
            .pickerStyle(.segmented)
            .disabled(!bibleReaderVisible)
            .accessibilityLabel("Today's Reading side")
        } header: {
            Label("Today's Reading Panel", systemImage: "book.pages")
        } footer: {
            Text("A full-height reading panel beside your cards. It shows your bookmark, or the Verse of the Day in its chapter.")
        }

        ForEach(HomeColumn.allCases, id: \.self) { column in
            Section {
                ForEach(Array(columns[column].enumerated()), id: \.element) { index, id in
                    columnRow(for: id, in: column, position: index + 1)
                }
                .onMove { source, destination in
                    moveInColumn(column, fromOffsets: source, toOffset: destination)
                }

                if columns[column].isEmpty {
                    Text("No cards. Use the arrow on a card to move it here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label(column.title, systemImage: column == .left ? "rectangle.lefthalf.filled" : "rectangle.righthalf.filled")
            } footer: {
                if column == .right {
                    Text("Drag cards to reorder them within a column, and use the arrows to move a card to the other column. You can also tap Edit Home on the Home screen to arrange cards in place.")
                }
            }
        }
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
                    message: usesDashboard
                        ? "Use the eye buttons to show or hide cards, drag to reorder, and the arrows to move cards between columns."
                        : "Use the eye buttons to show or hide cards, and the arrows to reorder them.",
                    systemImage: "rectangle.grid.1x2"
                )
                .listRowSeparator(.hidden)
            }

            if usesDashboard {
                dashboardSections
            } else {
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
                    Toggle(isOn: $customizeButtonVisible) {
                        Label("Show ‘Customize Home’ on Home", systemImage: customizeButtonVisible ? "eye" : "eye.slash")
                    }
                    .toggleStyle(StatusColorToggleStyle())
                } header: {
                    Label("Home Cards", systemImage: "house")
                } footer: {
                    Text("Shown cards appear on Home. Use the arrows to choose their order.")
                }
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
        // On iPad the confirmation floats over the list so rows don't shift under the next tap.
        .overlay(alignment: .bottom) {
            if usesDashboard, let reorderConfirmation {
                Label(reorderConfirmation, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
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
