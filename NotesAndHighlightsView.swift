import SwiftData
import SwiftUI

@MainActor
struct NotesAndHighlightsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VerseNote.updatedAt, order: .reverse) private var scriptureNotes: [VerseNote]
    @Query(sort: \UserNote.updatedAt, order: .reverse) private var userNotes: [UserNote]

    @AppStorage("notesTabSortField") private var sortFieldRawValue = NotesTabSort.modified.rawValue
    @AppStorage("notesTabSortAscending") private var sortAscending = NotesTabSort.modified.defaultAscending
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @State private var selectedFilter = NotesFilter.all
    @State private var highlightFilter = NotesHighlightFilter.all
    @State private var selectedCustomTag: String?
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var selectedScriptureNote: VerseNote?
    @State private var selectedUserNote: UserNote?
    @State private var isCreatingNote = false
    @State private var isEditingSelection = false
    @State private var isShowingCompactDetail = false
    @State private var deletedNoteSnapshot: DeletedNoteSnapshot?
    @State private var isShowingDeleteUndo = false
    @State private var deleteUndoText = ""

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactContent
            } else {
                regularContent
            }
        }
        .background(AppBackgroundView(tab: .notes))
        .navigationTitle("Notes")
        .navigationDestination(isPresented: $isShowingCompactDetail) {
            NoteDetailCard(
                scriptureNote: selectedScriptureNote,
                userNote: selectedUserNote,
                editAction: {
                    isShowingCompactDetail = false
                    DispatchQueue.main.async {
                        isEditingSelection = true
                    }
                }
            )
            .padding()
            .background(AppBackgroundView(tab: .notes))
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
        }
        .searchable(
            text: $searchText,
            isPresented: $isSearchPresented,
            prompt: "Search all notes"
        )
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NotesViewOptionsMenu(
                    sortField: sortFieldBinding,
                    sortAscending: $sortAscending,
                    highlightFilter: $highlightFilter
                )

                Button {
                    isCreatingNote = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create note")
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .fullScreenCover(isPresented: $isCreatingNote) {
            NavigationStack {
                UserNoteEditorView(
                    existingNote: nil,
                    defaultCategory: selectedFilter.noteCategory ?? .personal
                )
            }
        }
        .fullScreenCover(isPresented: $isEditingSelection) {
            NavigationStack {
                if let selectedScriptureNote {
                    VerseNoteEditorView(
                        verse: VerseActionReference(
                            bookName: selectedScriptureNote.bookName,
                            chapterNumber: selectedScriptureNote.chapterNumber,
                            verseNumber: selectedScriptureNote.verseNumber,
                            verseText: selectedScriptureNote.verseText
                        ),
                        existingNote: selectedScriptureNote,
                        preservesHighlightWhenRemovingNote: true
                    )
                } else if let selectedUserNote {
                    UserNoteEditorView(existingNote: selectedUserNote)
                }
            }
        }
        .background {
            ZStack {
                keyboardShortcutControls
                NotesKeyboardCommandResponder(
                    isEnabled: !isSearchPresented && !isCreatingNote && !isEditingSelection,
                    moveSelection: moveSelection,
                    requestDeletion: requestSelectedNoteDeletion
                )
            }
        }
        .appToast(
            isPresented: $isShowingDeleteUndo,
            symbol: "trash",
            text: deleteUndoText,
            tint: .red,
            actionTitle: "Undo",
            action: undoLastDeletion
        )
        .onAppear(perform: selectFirstVisibleNoteIfNeeded)
        .onChange(of: selectedFilter) { _, _ in selectFirstVisibleNoteIfNeeded() }
        .onChange(of: highlightFilter) { _, _ in selectFirstVisibleNoteIfNeeded() }
        .onChange(of: selectedCustomTag) { _, _ in selectFirstVisibleNoteIfNeeded() }
        .onChange(of: customTags) { _, newTags in
            if let selectedCustomTag, !newTags.contains(selectedCustomTag) {
                self.selectedCustomTag = nil
            }
        }
        .onChange(of: sortFieldRawValue) { _, _ in selectFirstVisibleNoteIfNeeded() }
        .onChange(of: sortAscending) { _, _ in selectFirstVisibleNoteIfNeeded() }
        .onChange(of: searchText) { _, _ in selectFirstVisibleNoteIfNeeded() }
    }

    private var keyboardShortcutControls: some View {
        Group {
            Button("Search Notes") {
                isSearchPresented = true
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("Edit Selected Note") {
                editSelectedNote()
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(selectedScriptureNote == nil && selectedUserNote == nil)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private var compactContent: some View {
        VStack(spacing: 12) {
            NotesCategoryStrip(
                selection: $selectedFilter,
                highlightFilter: $highlightFilter,
                selectedCustomTag: $selectedCustomTag,
                customTags: customTags
            )
            contextualTip

            notesList(
                newNoteAction: nil,
                selectAction: { item in
                    select(item)
                    isShowingCompactDetail = true
                }
            )
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private var regularContent: some View {
        VStack(spacing: 12) {
            NotesCategoryStrip(
                selection: $selectedFilter,
                highlightFilter: $highlightFilter,
                selectedCustomTag: $selectedCustomTag,
                customTags: customTags
            )
            contextualTip

            ResizableNotesColumns {
                notesList(
                    newNoteAction: { isCreatingNote = true },
                    selectAction: select
                )
                .padding(.horizontal, 2)
                .padding(.vertical, 12)
            } detail: {
                VStack(spacing: 12) {
                    if selectedNoteIsExcludedFromVisibleNotes {
                        Label(
                            "This note isn’t included in the active filter or search.",
                            systemImage: "line.3.horizontal.decrease.circle"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Color.orange.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityLabel("The open note is not included in the active filter or search.")
                    }

                    NoteDetailCard(
                        scriptureNote: selectedScriptureNote,
                        userNote: selectedUserNote,
                        editAction: { isEditingSelection = true }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    @ViewBuilder
    private var contextualTip: some View {
        if contextualTipsEnabled {
            ContextualTipView(
                id: "notes.quickActions",
                title: "Browse and manage notes",
                message: "Tap #Custom to reveal custom tags, or filter by category and highlight color. Select a note to follow links without editing, or swipe or press and hold it for quick actions.",
                systemImage: "hand.point.up.left"
            )
        }
    }

    private func notesList(
        newNoteAction: (() -> Void)?,
        selectAction: @escaping (NotesListItem) -> Void
    ) -> some View {
        NotesListCard(
            notes: visibleNotes,
            selectedID: selectedItem?.id,
            filter: selectedFilter,
            hasAnyNotes: !scriptureNotes.isEmpty || !userNotes.isEmpty,
            showsClearFiltersAction: hasActiveFilters,
            clearFiltersAction: clearFilters,
            newNoteAction: newNoteAction,
            createFirstNoteAction: { isCreatingNote = true },
            selectAction: selectAction,
            editAction: { item in
                select(item)
                isEditingSelection = true
            },
            deleteAction: delete
        )
    }

    private var customTags: [String] {
        let allNoteText = scriptureNotes.map(\.content) + userNotes.map(\.content)
        return Array(Set(allNoteText.flatMap { NoteCustomTags.tags(in: $0) })).sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    /// Notes matching the active category, custom tag, highlight filter, and search. Favorites are
    /// pinned above the rest but are still subject to every filter.
    private var visibleNotes: [NotesListItem] {
        let allNotes = scriptureNotes.map(NotesListItem.scripture) + userNotes.map(NotesListItem.user)
        let matchingNotes = allNotes.filter { note in
            matchesSelectedCategory(note.categoryRawValue) &&
                matchesCustomTag(note) &&
                matchesHighlight(note.highlightColor) &&
                note.matchesSearch(searchText)
        }
        return sort(matchingNotes.filter(\.isFavorite)) + sort(matchingNotes.filter { !$0.isFavorite })
    }

    private var sortField: NotesTabSort {
        NotesTabSort(rawValue: sortFieldRawValue) ?? .modified
    }

    /// Picking a new sort field resets the direction to that field's natural order.
    private var sortFieldBinding: Binding<NotesTabSort> {
        Binding(
            get: { sortField },
            set: { newValue in
                guard newValue != sortField else { return }
                sortFieldRawValue = newValue.rawValue
                sortAscending = newValue.defaultAscending
            }
        )
    }

    private var hasActiveFilters: Bool {
        selectedFilter != .all ||
            highlightFilter != .all ||
            selectedCustomTag != nil ||
            !searchText.isEmpty
    }

    private func clearFilters() {
        withAnimation(.snappy) {
            selectedFilter = .all
            highlightFilter = .all
            selectedCustomTag = nil
            searchText = ""
        }
    }

    private func matchesSelectedCategory(_ rawValue: String) -> Bool {
        selectedFilter == .all || rawValue == selectedFilter.rawValue
    }

    private func matchesCustomTag(_ note: NotesListItem) -> Bool {
        guard let selectedCustomTag else { return true }
        return note.customTags.contains(selectedCustomTag)
    }

    private func matchesHighlight(_ rawValue: String) -> Bool {
        switch highlightFilter {
        case .all: true
        case .none: rawValue.isEmpty
        default: rawValue == highlightFilter.rawValue
        }
    }

    private func sort(_ notes: [NotesListItem]) -> [NotesListItem] {
        let field = sortField
        let ascending = sortAscending
        return notes.sorted { lhs, rhs in
            let order = Self.compare(lhs, rhs, by: field)
            if order != .orderedSame {
                return order == (ascending ? .orderedAscending : .orderedDescending)
            }
            // Ties always fall back to title A–Z so the order is stable and predictable.
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private static func compare(
        _ lhs: NotesListItem,
        _ rhs: NotesListItem,
        by field: NotesTabSort
    ) -> ComparisonResult {
        switch field {
        case .modified:
            return (lhs.updatedAt ?? .distantPast).compare(rhs.updatedAt ?? .distantPast)
        case .created:
            return (lhs.createdAt ?? .distantPast).compare(rhs.createdAt ?? .distantPast)
        case .title:
            return lhs.title.localizedStandardCompare(rhs.title)
        case .tag:
            return lhs.categoryRawValue.localizedStandardCompare(rhs.categoryRawValue)
        case .color:
            // Follow the highlight picker's color order; notes without a highlight sort last.
            let left = colorPosition(lhs.highlightColor)
            let right = colorPosition(rhs.highlightColor)
            return left == right ? .orderedSame : (left < right ? .orderedAscending : .orderedDescending)
        }
    }

    private static func colorPosition(_ rawValue: String) -> Int {
        VerseHighlightColor.allCases.firstIndex { $0.rawValue == rawValue } ?? VerseHighlightColor.allCases.count
    }

    private var selectedNoteIsExcludedFromVisibleNotes: Bool {
        if let selectedScriptureNote {
            return !visibleNotes.contains {
                if case .scripture(let note) = $0 { return note === selectedScriptureNote }
                return false
            }
        }

        if let selectedUserNote {
            return !visibleNotes.contains {
                if case .user(let note) = $0 { return note === selectedUserNote }
                return false
            }
        }

        return false
    }

    private func selectFirstVisibleNoteIfNeeded() {
        guard selectedScriptureNote == nil, selectedUserNote == nil else { return }
        selectFirstVisibleNote()
    }

    private func moveSelection(by offset: Int) {
        guard !visibleNotes.isEmpty else { return }

        let selectedID: NotesListItem.ID? = if let selectedScriptureNote {
            .scripture(selectedScriptureNote.persistentModelID)
        } else if let selectedUserNote {
            .user(selectedUserNote.persistentModelID)
        } else {
            nil
        }
        let currentIndex = selectedID.flatMap { id in
            visibleNotes.firstIndex { $0.id == id }
        }
        let proposedIndex = (currentIndex ?? (offset > 0 ? -1 : visibleNotes.count)) + offset
        let destinationIndex = min(max(proposedIndex, 0), visibleNotes.count - 1)
        select(visibleNotes[destinationIndex])
    }

    private func editSelectedNote() {
        guard selectedScriptureNote != nil || selectedUserNote != nil else { return }
        isEditingSelection = true
    }

    private func requestSelectedNoteDeletion() {
        guard let selectedItem else { return }
        delete(selectedItem)
    }

    private var selectedItem: NotesListItem? {
        if let selectedScriptureNote {
            return .scripture(selectedScriptureNote)
        }
        if let selectedUserNote {
            return .user(selectedUserNote)
        }
        return nil
    }

    private func delete(_ item: NotesListItem) {
        if case .scripture(let note) = item, !note.highlightColor.isEmpty, item.hasNoteText {
            // Match the editor's "Remove Note": clear the written note but keep the verse highlight.
            deletedNoteSnapshot = .scriptureText(note, VerseNoteSnapshot(note: note))
            note.title = ""
            note.content = ""
            note.formattedContent = nil
            note.updatedAt = Date()
            modelContext.saveLoggingErrors()
            showDeleteUndo("Note deleted · Highlight kept")
            return
        }

        let notesBeforeDeletion = visibleNotes
        let deletedIndex = notesBeforeDeletion.firstIndex { $0.id == item.id }
        let wasSelected: Bool

        switch item {
        case .scripture(let note):
            wasSelected = selectedScriptureNote === note
            deletedNoteSnapshot = .scripture(VerseNoteSnapshot(note: note), wasSelected: wasSelected)
            modelContext.delete(note)
        case .user(let note):
            wasSelected = selectedUserNote === note
            deletedNoteSnapshot = .user(UserNoteSnapshot(note: note), wasSelected: wasSelected)
            modelContext.delete(note)
        }
        modelContext.saveLoggingErrors()

        if wasSelected {
            selectedScriptureNote = nil
            selectedUserNote = nil
            let remainingNotes = notesBeforeDeletion.filter { $0.id != item.id }
            if !remainingNotes.isEmpty {
                select(remainingNotes[min(deletedIndex ?? 0, remainingNotes.count - 1)])
            }
        }

        showDeleteUndo(item.hasNoteText ? "Note deleted" : "Highlight removed")
    }

    private func showDeleteUndo(_ text: String) {
        deleteUndoText = text
        isShowingDeleteUndo = false
        Task { @MainActor in
            await Task.yield()
            withAnimation(.snappy) {
                isShowingDeleteUndo = true
            }
        }
    }

    private func undoLastDeletion() {
        guard let deletedNoteSnapshot else { return }

        switch deletedNoteSnapshot {
        case .scriptureText(let note, let snapshot):
            snapshot.restoreText(to: note)
        case .scripture(let snapshot, let wasSelected):
            let note = snapshot.makeNote()
            modelContext.insert(note)
            if wasSelected {
                select(.scripture(note))
            }
        case .user(let snapshot, let wasSelected):
            let note = snapshot.makeNote()
            modelContext.insert(note)
            if wasSelected {
                select(.user(note))
            }
        }

        modelContext.saveLoggingErrors()
        self.deletedNoteSnapshot = nil
    }

    private func select(_ item: NotesListItem) {
        switch item {
        case .scripture(let note):
            selectedScriptureNote = note
            selectedUserNote = nil
        case .user(let note):
            selectedScriptureNote = nil
            selectedUserNote = note
        }
    }

    private func selectFirstVisibleNote() {
        switch visibleNotes.first {
        case .scripture(let note):
            selectedScriptureNote = note
            selectedUserNote = nil
        case .user(let note):
            selectedScriptureNote = nil
            selectedUserNote = note
        case nil:
            selectedScriptureNote = nil
            selectedUserNote = nil
        }
    }
}

private struct ResizableNotesColumns<ListContent: View, DetailContent: View>: View {
    @State private var listColumnFraction: CGFloat = 0.4
    @GestureState private var dragTranslation: CGFloat = 0

    let listContent: ListContent
    let detailContent: DetailContent

    init(
        @ViewBuilder listContent: () -> ListContent,
        @ViewBuilder detail: () -> DetailContent
    ) {
        self.listContent = listContent()
        self.detailContent = detail()
    }

    var body: some View {
        GeometryReader { proxy in
            let dividerWidth: CGFloat = 20
            let availableWidth = max(proxy.size.width - dividerWidth, 1)
            let minimumListWidth = min(300, availableWidth * 0.45)
            let minimumDetailWidth = min(360, availableWidth - minimumListWidth)
            let minimumFraction = minimumListWidth / availableWidth
            let maximumFraction = (availableWidth - minimumDetailWidth) / availableWidth
            let committedFraction = min(max(listColumnFraction, minimumFraction), maximumFraction)
            let previewFraction = min(
                max(
                    committedFraction + (dragTranslation / availableWidth),
                    minimumFraction
                ),
                maximumFraction
            )
            let listWidth = availableWidth * committedFraction
            let previewListWidth = availableWidth * previewFraction

            ZStack(alignment: .leading) {
                HStack(alignment: .top, spacing: 0) {
                    listContent
                        .frame(width: listWidth)

                    Color.clear
                        .frame(width: dividerWidth)

                    detailContent
                        .frame(width: availableWidth - listWidth)
                }

                Capsule()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 4, height: 48)
                    .frame(width: dividerWidth)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .offset(x: previewListWidth)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .updating($dragTranslation) { value, translation, _ in
                                translation = value.translation.width
                            }
                            .onEnded { value in
                                listColumnFraction = min(
                                    max(
                                        committedFraction + (value.translation.width / availableWidth),
                                        minimumFraction
                                    ),
                                    maximumFraction
                                )
                            }
                    )
                    .accessibilityElement()
                    .accessibilityLabel("Resize notes list")
                    .accessibilityValue("\(Int(previewFraction * 100)) percent")
                    .accessibilityAdjustableAction { direction in
                        let adjustment: CGFloat = direction == .increment ? 0.05 : -0.05
                        listColumnFraction = min(
                            max(committedFraction + adjustment, minimumFraction),
                            maximumFraction
                        )
                    }
            }
        }
    }
}
