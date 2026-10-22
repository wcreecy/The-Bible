import SwiftUI

struct HomeLayoutEditorView: View {
    @Binding var order: [HomeCardID]
    @Binding var hiddenSet: Set<HomeCardID>
    /// The iPad dashboard's three columns; edited instead of `order` when `usesDashboard`.
    @Binding var columns: HomeColumnLayout
    /// iPad arranges cards in three columns, with the Today's Reading panel atop one of them.
    let usesDashboard: Bool
    var onDone: () -> Void

    var onSaveFavorite: () -> Void
    var onResetToFavorite: () -> Void
    var hasFavorite: Bool

    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @AppStorage("homeCustomizeButtonVisible") private var customizeButtonVisible = true
    @AppStorage("homeQuickSearchVisible") private var quickSearchVisible = true
    @AppStorage("homeBibleReaderVisible") private var bibleReaderVisible = HomeLayoutStore.defaultBibleReaderVisible
    @AppStorage(HomeLayoutStore.keyBibleReaderColumn) private var bibleReaderColumn = HomeLayoutStore.defaultBibleReaderColumn
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
        quickSearchVisible = true
        bibleReaderVisible = HomeLayoutStore.defaultBibleReaderVisible
        bibleReaderColumn = HomeLayoutStore.defaultBibleReaderColumn
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

    private func apply(_ preset: HomeLayoutPreset) {
        let orderedCards = preset.orderedCards()
        let visibleCards = preset.visibleCards(usesDashboard: usesDashboard)
        let hiddenCards = Set(HomeCardID.allCases).subtracting(visibleCards)
        let readerVisible = preset.showsTodayReadingPanel
        let readerColumn: HomeColumn? = readerVisible ? HomeLayoutStore.defaultBibleReaderColumn : nil

        withAnimation(.snappy) {
            order = orderedCards
            hiddenSet = hiddenCards
            bibleReaderVisible = readerVisible
            bibleReaderColumn = HomeLayoutStore.defaultBibleReaderColumn
            columns = usesDashboard
                ? preset.dashboardColumns
                : HomeColumnLayout.seeded(
                    from: orderedCards,
                    hidden: hiddenCards,
                    readerColumn: readerColumn
                )
            highlightedCards = visibleCards
            reorderConfirmation = "\(preset.title) layout applied"
        }

        onDone()
        Haptics.success()
        AccessibilityNotification.Announcement("\(preset.title) layout applied. You can customize it below.").post()
        scheduleReorderFeedbackReset()
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

    /// Moves a card to the neighboring column: -1 is left, +1 is right.
    private func moveAcross(_ id: HomeCardID, by offset: Int) {
        guard let destination = columns.column(of: id)?.neighbor(by: offset) else { return }
        changeColumns(highlighting: [id], confirmation: "\(id.title) moved to the \(destination.title.lowercased())") {
            $0.moveAcross(id, by: offset)
        }
    }

    private func moveInColumn(_ id: HomeCardID, by offset: Int) {
        guard let column = columns.column(of: id),
              case let cards = columns.stackedCards(in: column),
              let row = cards.firstIndex(of: id),
              cards.indices.contains(row + offset) else { return }
        let swappedCard = cards[row + offset]
        changeColumns(highlighting: [id, swappedCard], confirmation: "\(id.title) moved to position \(row + offset + 1)") {
            $0.move(id, by: offset)
        }
    }

    private func moveInColumn(_ column: HomeColumn, fromOffsets source: IndexSet, toOffset destination: Int) {
        let cards = columns.stackedCards(in: column)
        let moved = source.map { cards[$0] }
        changeColumns(highlighting: Set(moved), confirmation: nil) {
            $0.moveStacked(in: column, fromOffsets: source, toOffset: destination)
        }
    }

    // MARK: - Verse of the Day width

    private var verseOfDayColumnCount: Binding<Int> {
        Binding {
            columns.verseOfDayWidth.columnCount
        } set: { count in
            let title = HomeCardWidthOption(columnCount: count).title.lowercased()
            changeColumns(highlighting: [.verseOfDay], confirmation: "Verse of the Day set to \(title)") {
                $0.setVerseOfDayColumnCount(count, readerColumn: bibleReaderVisible ? bibleReaderColumn : nil)
            }
        }
    }

    private var verseOfDayTwoColumnSide: Binding<HomeCardWidth> {
        Binding {
            columns.verseOfDayWidth
        } set: { width in
            changeColumns(highlighting: [.verseOfDay], confirmation: "Verse of the Day moved") {
                $0.verseOfDayWidth = width
            }
        }
    }

    private var verseOfDaySection: some View {
        Section {
            Picker("Width", selection: verseOfDayColumnCount) {
                ForEach(HomeCardWidthOption.allCases) { option in
                    Text(option.shortTitle).tag(option.columnCount)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Verse of the Day width")

            if columns.verseOfDayWidth.columnCount == 2 {
                Picker("Columns", selection: verseOfDayTwoColumnSide) {
                    Text("Left & Middle").tag(HomeCardWidth.leftTwoColumns)
                    Text("Middle & Right").tag(HomeCardWidth.rightTwoColumns)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Verse of the Day columns")
            }

            if columns.isSpanning(.verseOfDay) {
                HStack {
                    Image(systemName: HomeCardID.verseOfDay.systemImage)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    Text(HomeCardID.verseOfDay.title)
                        .foregroundStyle(isVisible(.verseOfDay) ? .primary : .secondary)
                    Spacer()
                    visibilityButton(for: .verseOfDay)
                }
                .padding(.vertical, 4)
                .background(
                    highlightedCards.contains(.verseOfDay) ? Color.accentColor.opacity(0.14) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            }
        } header: {
            Label("Verse of the Day", systemImage: HomeCardID.verseOfDay.systemImage)
        } footer: {
            Text(columns.isSpanning(.verseOfDay)
                ? "Verse of the Day sits across the top of the columns it covers, and the cards in those columns continue below it. Set it back to one column to return it to its place in a column."
                : "Widen Verse of the Day to sit across the top of two columns or the whole dashboard.")
        }
    }

    private func visibilityButton(for id: HomeCardID) -> some View {
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

    private func columnRow(for id: HomeCardID, in column: HomeColumn, position: Int) -> some View {
        let leftColumn = column.neighbor(by: -1)
        let rightColumn = column.neighbor(by: 1)
        return HStack {
            Image(systemName: id.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(id.title)
                .foregroundStyle(isVisible(id) ? .primary : .secondary)

            Spacer()

            visibilityButton(for: id)

            HStack(spacing: 2) {
                Button {
                    moveAcross(id, by: -1)
                } label: {
                    Image(systemName: "arrow.left.circle")
                        .font(.title3)
                        .frame(width: 32, height: 32)
                }
                .disabled(leftColumn == nil)
                .accessibilityLabel("Move \(id.title) left")

                Button {
                    moveAcross(id, by: 1)
                } label: {
                    Image(systemName: "arrow.right.circle")
                        .font(.title3)
                        .frame(width: 32, height: 32)
                }
                .disabled(rightColumn == nil)
                .accessibilityLabel("Move \(id.title) right")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        }
        .padding(.vertical, 4)
        .background(
            highlightedCards.contains(id) ? Color.accentColor.opacity(0.14) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .swipeActions(edge: .leading) {
            if let leftColumn {
                Button("Move to \(leftColumn.title)", systemImage: "arrow.left") {
                    moveAcross(id, by: -1)
                }
                .tint(.accentColor)
            }
        }
        .swipeActions(edge: .trailing) {
            if let rightColumn {
                Button("Move to \(rightColumn.title)", systemImage: "arrow.right") {
                    moveAcross(id, by: 1)
                }
                .tint(.accentColor)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(column.title), position \(position) of \(columns.stackedCards(in: column).count), \(isVisible(id) ? "shown" : "hidden")")
        .accessibilityActions {
            if columns.canMove(id, by: -1) {
                Button("Move up") { moveInColumn(id, by: -1) }
            }
            if columns.canMove(id, by: 1) {
                Button("Move down") { moveInColumn(id, by: 1) }
            }
            if let leftColumn {
                Button("Move to \(leftColumn.title)") { moveAcross(id, by: -1) }
            }
            if let rightColumn {
                Button("Move to \(rightColumn.title)") { moveAcross(id, by: 1) }
            }
            Button(isVisible(id) ? "Hide" : "Show") { toggleVisibility(id) }
        }
    }

    private func columnSymbol(_ column: HomeColumn) -> String {
        switch column {
        case .left: return "rectangle.leadingthird.inset.filled"
        case .middle: return "rectangle.center.inset.filled"
        case .right: return "rectangle.trailingthird.inset.filled"
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

            Picker("Column", selection: $bibleReaderColumn) {
                ForEach(HomeColumn.allCases, id: \.self) { column in
                    Text(column.shortTitle).tag(column)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!bibleReaderVisible)
            .accessibilityLabel("Today's Reading column")
        } header: {
            Label("Today's Reading Panel", systemImage: "book.pages")
        } footer: {
            Text("A full-height reading panel at the top of its column; any cards in that column appear below it. It shows your bookmark, or the Verse of the Day in its chapter.")
        }

        verseOfDaySection

        ForEach(HomeColumn.allCases, id: \.self) { column in
            Section {
                // A wide Verse of the Day heads the columns it covers, the reader panel included.
                if isVisible(.verseOfDay), columns.verseOfDayWidth.coveredColumns.contains(column) {
                    Label("Below Verse of the Day", systemImage: "arrow.up.to.line")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if bibleReaderVisible && bibleReaderColumn == column {
                    Label("Today's Reading panel", systemImage: "book.pages")
                        .foregroundStyle(.secondary)
                        .accessibilityHint("Choose its column in Today's Reading Panel above")
                }

                ForEach(Array(columns.stackedCards(in: column).enumerated()), id: \.element) { index, id in
                    columnRow(for: id, in: column, position: index + 1)
                }
                .onMove { source, destination in
                    moveInColumn(column, fromOffsets: source, toOffset: destination)
                }

                if columns.stackedCards(in: column).isEmpty {
                    Text("No cards. Use the arrows on a card to move it here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label(column.title, systemImage: columnSymbol(column))
            } footer: {
                if column == HomeColumn.allCases.last {
                    Text("Drag cards to reorder them within a column, and use the arrows to move a card to the next column. You can also tap Edit Home on the Home screen to arrange cards in place.")
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
                        ? "Use the eye buttons to show or hide cards, drag to reorder, and the arrows to move cards between the three columns."
                        : "Use the eye buttons to show or hide cards, and the arrows to reorder them.",
                    systemImage: "rectangle.grid.1x2"
                )
                .listRowSeparator(.hidden)
            }

            HomeLayoutPresetSection(
                usesDashboard: usesDashboard,
                onApply: apply,
                onRestoreDefault: resetToDefault
            )

            Section {
                Toggle(isOn: $quickSearchVisible) {
                    Label("Show Quick Search on Home", systemImage: "magnifyingglass")
                }
                .toggleStyle(StatusColorToggleStyle())
            } header: {
                Label("Home Shortcuts", systemImage: "bolt")
            } footer: {
                Text("Quick Search lets you find words, phrases, and Bible references directly from Home.")
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

private struct HomeLayoutPresetSection: View {
    let usesDashboard: Bool
    let onApply: (HomeLayoutPreset) -> Void
    let onRestoreDefault: () -> Void

    var body: some View {
        Section {
            ForEach(HomeLayoutPreset.allCases) { preset in
                Button {
                    onApply(preset)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: preset.systemImage)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.tint)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(preset.title)
                                .font(.body.weight(.semibold))

                            Text(detail(for: preset))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Applies this layout. You can customize it below.")
            }

            Button("Restore Default Layout", systemImage: "arrow.counterclockwise", action: onRestoreDefault)
        } header: {
            Label("Home Layout Presets", systemImage: "rectangle.3.group")
        } footer: {
            Text("A preset changes your card visibility and order. You can customize any layout below.")
        }
    }

    private func detail(for preset: HomeLayoutPreset) -> String {
        if preset == .minimal && !usesDashboard {
            return "Continue Reading and Search Scripture only."
        }

        return preset.detail
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
