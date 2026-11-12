import SwiftUI

struct HomeLayoutEditorView: View {
    @Binding var order: [HomeCardID]
    @Binding var hiddenSet: Set<HomeCardID>
    /// The iPad dashboard's three columns; edited instead of `order` when `usesDashboard`.
    @Binding var columns: HomeColumnLayout
    /// iPad arranges cards in three columns, with the Today's Reading panel atop one of them.
    let usesDashboard: Bool
    var onDone: () -> Void

    /// Saves the current arrangement as "My Layout".
    var onSaveFavorite: () -> Void
    /// Replaces the current arrangement with "My Layout".
    var onResetToFavorite: () -> Void

    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @AppStorage("homeCustomizeButtonVisible") private var customizeButtonVisible = true
    @AppStorage("homeQuickSearchVisible") private var quickSearchVisible = true
    @AppStorage("homeBibleReaderVisible") private var bibleReaderVisible = HomeLayoutStore.defaultBibleReaderVisible
    @AppStorage(HomeLayoutStore.keyBibleReaderColumn) private var bibleReaderColumn = HomeLayoutStore.defaultBibleReaderColumn
    @State private var highlightedCards: Set<HomeCardID> = []
    @State private var confirmation: String?
    @State private var reorderFeedbackTask: Task<Void, Never>?
    @State private var isShowingReplaceSavedLayoutConfirmation = false
    @State private var isShowingRevertConfirmation = false
    @State private var hasFavorite = false
    @State private var favoriteSavedAt: Date?

    /// The cards listed for reordering on iPhone, in Home order.
    private var listedCards: [HomeCardID] { order }
    private var visibleListedCards: [HomeCardID] { listedCards.filter(isVisible) }
    private var hiddenListedCards: [HomeCardID] { listedCards.filter { !isVisible($0) } }

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
        confirm("Default layout restored")
    }

    private func showAll() {
        hiddenSet.removeAll()
        bibleReaderVisible = true
        onDone()
        confirm("All cards shown")
    }

    private func hideAllCards() {
        hiddenSet = Set(HomeCardID.allCases)
        bibleReaderVisible = false
        onDone()
        confirm("All cards hidden")
    }

    // MARK: - My Layout

    private func refreshFavorite() {
        let store = HomeLayoutStore()
        hasFavorite = store.hasFavorite
        favoriteSavedAt = store.favoriteSavedAt
    }

    private func saveMyLayout() {
        onSaveFavorite()
        refreshFavorite()
        confirm("Saved as My Layout")
    }

    private func revertToMyLayout() {
        onResetToFavorite()
        refreshFavorite()
        confirm("Reverted to My Layout")
    }

    private var myLayoutStatus: String {
        guard hasFavorite else { return "No saved layout yet" }
        guard let favoriteSavedAt else { return "My Layout is saved" }
        return "My Layout saved \(favoriteSavedAt.formatted(.dateTime.month(.abbreviated).day()))"
    }

    /// Shows the floating confirmation, with a haptic and a VoiceOver announcement.
    private func confirm(_ message: String) {
        withAnimation(.snappy) {
            confirmation = message
        }
        Haptics.success()
        AccessibilityNotification.Announcement(message).post()
        scheduleReorderFeedbackReset()
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
            if preset == .minimal {
                quickSearchVisible = false
            }
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
        }

        onDone()
        confirm("\(preset.title) layout applied")
    }

    private func moveCard(_ id: HomeCardID, by offset: Int) {
        var cards = listedCards
        let visibleIndices = cards.indices.filter { isVisible(cards[$0]) }
        guard let currentIndex = visibleIndices.firstIndex(where: { cards[$0] == id }) else { return }
        let destinationIndex = currentIndex + offset
        guard visibleIndices.indices.contains(destinationIndex) else { return }

        let source = visibleIndices[currentIndex]
        let destination = visibleIndices[destinationIndex]
        let swappedCard = cards[destination]
        cards.swapAt(source, destination)

        withAnimation(.snappy) {
            order = cards
            highlightedCards = [id, swappedCard]
            confirmation = "\(id.title) moved to position \(destinationIndex + 1)"
        }
        onDone()
        Haptics.selection()
        scheduleReorderFeedbackReset()
    }

    private func canMoveUp(_ id: HomeCardID) -> Bool {
        visibleListedCards.firstIndex(of: id).map { $0 > 0 } == true
    }

    private func canMoveDown(_ id: HomeCardID) -> Bool {
        visibleListedCards.firstIndex(of: id).map { $0 < visibleListedCards.count - 1 } == true
    }

    // MARK: - iPad columns

    /// Applies a column change, keeps the narrow-width order in step, and confirms it.
    /// Drag moves pass no confirmation, so a toast doesn't appear on every drop.
    private func changeColumns(highlighting ids: Set<HomeCardID>, confirmation message: String?, _ change: (inout HomeColumnLayout) -> Void) {
        withAnimation(.snappy) {
            change(&columns)
            order = columns.flatOrder
            highlightedCards = ids
            if let message {
                confirmation = message
            }
        }
        if let message {
            AccessibilityNotification.Announcement(message).post()
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

    private func move(_ id: HomeCardID, to destination: HomeColumn) {
        guard columns.column(of: id) != destination else { return }
        changeColumns(highlighting: [id], confirmation: "\(id.title) moved to \(destination.title.lowercased())") {
            $0.move(id, to: destination)
        }
    }

    private func moveInColumn(_ column: HomeColumn, fromOffsets source: IndexSet, toOffset destination: Int) {
        let cards = columns.stackedCards(in: column)
        let moved = source.map { cards[$0] }
        changeColumns(highlighting: Set(moved), confirmation: nil) {
            $0.moveStacked(in: column, fromOffsets: source, toOffset: destination)
        }
    }

    private func moveVisibleInColumn(_ column: HomeColumn, fromOffsets source: IndexSet, toOffset destination: Int) {
        let cards = columns.stackedCards(in: column)
        var visibleCards = cards.filter(isVisible)
        let moved = source.compactMap { visibleCards.indices.contains($0) ? visibleCards[$0] : nil }
        guard !moved.isEmpty else { return }

        visibleCards.move(fromOffsets: source, toOffset: destination)
        changeColumns(highlighting: Set(moved), confirmation: nil) {
            let originalCards = $0[column]
            var visibleIndex = 0
            for index in originalCards.indices where isVisible(originalCards[index]) && !$0.isSpanning(originalCards[index]) {
                $0[column][index] = visibleCards[visibleIndex]
                visibleIndex += 1
            }
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

    private func destinationColumns(excluding column: HomeColumn) -> [HomeColumn] {
        HomeColumn.allCases.filter { $0 != column }
    }

    private func columnRow(for id: HomeCardID, in column: HomeColumn, position: Int) -> some View {
        return HStack {
            Image(systemName: id.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(id.title)
                .foregroundStyle(isVisible(id) ? .primary : .secondary)

            Spacer()

            visibilityButton(for: id)

            Menu {
                ForEach(destinationColumns(excluding: column), id: \.self) { destination in
                    Button("Move to \(destination.shortTitle)", systemImage: columnSymbol(destination)) {
                        move(id, to: destination)
                    }
                }
            } label: {
                Image(systemName: "arrow.left.and.right.circle")
                    .font(.title3)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .accessibilityLabel("Move \(id.title) to another column")

            HStack(spacing: 2) {
                Button {
                    moveInColumn(id, by: -1)
                } label: {
                    Image(systemName: "arrow.up.circle")
                        .font(.title3)
                        .frame(width: 32, height: 32)
                }
                .disabled(!columns.canMove(id, by: -1))
                .accessibilityLabel("Move \(id.title) up")

                Button {
                    moveInColumn(id, by: 1)
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                        .frame(width: 32, height: 32)
                }
                .disabled(!columns.canMove(id, by: 1))
                .accessibilityLabel("Move \(id.title) down")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
        }
        .padding(.vertical, 4)
        .background(
            highlightedCards.contains(id) ? Color.accentColor.opacity(0.14) : Color.clear,
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(column.title), position \(position) of \(columns.stackedCards(in: column).count), \(isVisible(id) ? "shown" : "hidden")")
        .accessibilityActions {
            if columns.canMove(id, by: -1) {
                Button("Move up") { moveInColumn(id, by: -1) }
            }
            if columns.canMove(id, by: 1) {
                Button("Move down") { moveInColumn(id, by: 1) }
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

    /// iPad-only panel settings, shown after the card arrangement controls.
    @ViewBuilder
    private var dashboardOptionSections: some View {
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
    }

    @ViewBuilder
    private var dashboardSections: some View {
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

                ForEach(Array(columns.stackedCards(in: column).filter(isVisible).enumerated()), id: \.element) { index, id in
                    columnRow(for: id, in: column, position: index + 1)
                }
                .onMove { source, destination in
                    moveVisibleInColumn(column, fromOffsets: source, toOffset: destination)
                }

                if columns.stackedCards(in: column).filter(isVisible).isEmpty {
                    Text("No cards in this column.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label(column.title, systemImage: columnSymbol(column))
            } footer: {
                if column == HomeColumn.allCases.last {
                    Text("Drag cards or use the arrows to reorder them within a column. Use the move menu to send a card to another column.")
                }
            }
        }

        if !hiddenListedCards.isEmpty {
            Section {
                ForEach(hiddenListedCards) { id in
                    hiddenLayoutRow(for: id)
                }
            } header: {
                Label("Hidden Cards", systemImage: "eye.slash")
            } footer: {
                Text("These cards are hidden from Home. Show a card to make it available there.")
            }
        }
    }

    private func scheduleReorderFeedbackReset() {
        reorderFeedbackTask?.cancel()
        reorderFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.8))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                highlightedCards.removeAll()
                confirmation = nil
            }
        }
    }

    private func hiddenLayoutRow(for id: HomeCardID) -> some View {
        HStack {
            Image(systemName: id.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(id.title)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                toggleVisibility(id)
            } label: {
                Label("Show", systemImage: "eye")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show \(id.title)")
            .accessibilityHint("Makes this card available on Home")
        }
        .padding(.vertical, 4)
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

    private var quickSearchSection: some View {
        Section {
            Toggle(isOn: $quickSearchVisible) {
                Label("Show Quick Search on Home", systemImage: "magnifyingglass")
            }
            .toggleStyle(StatusColorToggleStyle())

        } header: {
            Label("Quick Search", systemImage: "magnifyingglass")
        } footer: {
            Text("Quick Search lets you find words, phrases, and Bible references directly from Home.")
        }
    }

    private var homeOptionsSection: some View {
        Section {
            if !usesDashboard {
                Toggle(isOn: $customizeButtonVisible) {
                    Label("Show ‘Customize Home’ on Home", systemImage: customizeButtonVisible ? "eye" : "eye.slash")
                }
                .toggleStyle(StatusColorToggleStyle())
            }
        } header: {
            Label("Home Options", systemImage: "slider.horizontal.3")
        }
    }

    /// One place for every "change many cards at once" action.
    private var startFromSection: some View {
        Section {
            Menu {
                Section("Layouts") {
                    ForEach(HomeLayoutPreset.allCases) { preset in
                        Button(preset.title, systemImage: preset.systemImage) {
                            apply(preset)
                        }
                    }
                }
                Section("Visibility") {
                    Button("Show All Cards", systemImage: "eye", action: showAll)
                    Button("Hide All Cards", systemImage: "eye.slash", action: hideAllCards)
                        .disabled(isMinimalHome)
                }
                Section {
                    Button("Restore Default Layout", systemImage: "arrow.counterclockwise", action: resetToDefault)
                }
            } label: {
                HStack {
                    Label("Choose a Setup", systemImage: "rectangle.3.group")
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
        } header: {
            Label("Quick Setups", systemImage: "wand.and.stars")
        } footer: {
            Text("Replaces your card order and visibility in one step. You can still adjust any card above.")
        }
    }

    private var myLayoutSection: some View {
        Section {
            Button(
                "Save as My Layout",
                systemImage: hasFavorite ? "arrow.triangle.2.circlepath" : "square.and.arrow.down"
            ) {
                if hasFavorite {
                    isShowingReplaceSavedLayoutConfirmation = true
                } else {
                    saveMyLayout()
                }
            }
            .confirmationDialog(
                "Replace My Layout?",
                isPresented: $isShowingReplaceSavedLayoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Replace My Layout", role: .destructive, action: saveMyLayout)
            } message: {
                Text("Your previous saved layout will be replaced with the current arrangement.")
            }

            Button("Revert to My Layout", systemImage: "arrow.uturn.backward") {
                isShowingRevertConfirmation = true
            }
            .disabled(!hasFavorite)
            .confirmationDialog(
                "Revert to My Layout?",
                isPresented: $isShowingRevertConfirmation,
                titleVisibility: .visible
            ) {
                Button("Revert to My Layout", role: .destructive, action: revertToMyLayout)
            } message: {
                Text("Home will switch back to the layout you saved. Your current arrangement will be lost.")
            }
        } header: {
            Label("My Layout", systemImage: "bookmark")
        } footer: {
            Text("\(myLayoutStatus). Changes you make here apply to Home right away; save a copy to come back to it later.")
        }
    }

    var body: some View {
        List {
            if contextualTipsEnabled {
                ContextualTipView(
                    id: "home.layoutEditor",
                    title: "Make Home yours",
                    message: usesDashboard
                        ? "Use the eye buttons to show or hide cards, drag or use the arrows to reorder, and use the move menu to choose a column."
                        : "Use the eye buttons to show or hide cards, and the arrows to reorder them.",
                    systemImage: "rectangle.grid.1x2"
                )
                .listRowSeparator(.hidden)
            }

            if usesDashboard {
                quickSearchSection
                verseOfDaySection
                dashboardSections
            } else {
                quickSearchSection

                Section {
                    ForEach(Array(visibleListedCards.enumerated()), id: \.element) { index, id in
                        layoutRow(for: id, position: index + 1)
                    }
                } header: {
                    Label("Visible Cards", systemImage: "eye")
                } footer: {
                    Text("These cards appear on Home. Use the arrows to choose their order.")
                }

                homeOptionsSection

                if !hiddenListedCards.isEmpty {
                    Section {
                        ForEach(hiddenListedCards) { id in
                            hiddenLayoutRow(for: id)
                        }
                    } header: {
                        Label("Hidden Cards", systemImage: "eye.slash")
                    } footer: {
                        Text("These cards are hidden from Home. Show a card to make it available there.")
                    }
                }
            }

            if usesDashboard {
                dashboardOptionSections
            }

            startFromSection
            myLayoutSection
        }
        // The confirmation floats over the list so rows don't shift under the next tap.
        .overlay(alignment: .bottom) {
            if let confirmation {
                AppToast(symbol: "checkmark.circle.fill", text: confirmation, tint: .green)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .navigationTitle("Home Layout")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refreshFavorite)
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
