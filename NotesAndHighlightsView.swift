import SwiftData
import SwiftUI

@MainActor
struct NotesAndHighlightsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    // Unsorted: NotesLibrary applies the chosen sort, so the store doesn't need to.
    @Query private var scriptureNotes: [VerseNote]
    @Query private var userNotes: [UserNote]

    @AppStorage("notesTabSortField") private var sortFieldRawValue = NotesTabSort.modified.rawValue
    @AppStorage("notesTabSortAscending") private var sortAscending = NotesTabSort.modified.defaultAscending
    @AppStorage("notesTabListColumnFraction") private var listColumnFraction = 0.4
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @State private var filters = NotesFilters()
    @State private var isSearchPresented = false
    @State private var selectedID: NotesListItem.ID?
    @State private var isCreatingNote = false
    @State private var isEditingSelection = false
    @State private var isShowingCompactDetail = false
    @State private var isManagingTags = false
    @State private var exportDocument: NotesMarkdownDocument?
    @State private var deletedNoteSnapshot: DeletedNoteSnapshot?
    @State private var isShowingDeleteUndo = false
    @State private var deleteUndoText = ""

    var body: some View {
        let library = library
        let selectedItem = library.item(withID: selectedID)

        return Group {
            if horizontalSizeClass == .compact {
                compactContent(library)
            } else {
                regularContent(library, selectedItem: selectedItem)
                    .modifier(NoteEditorCover(isPresented: $isEditingSelection, item: selectedItem))
            }
        }
        .background(AppBackgroundView(tab: .notes))
        .navigationTitle("Notes")
        .navigationDestination(isPresented: $isShowingCompactDetail) {
            // The editor opens over the detail page, so closing it returns here without a pop.
            NoteDetailCard(item: selectedItem, editAction: { isEditingSelection = true })
                .padding()
                .background(AppBackgroundView(tab: .notes))
                .navigationTitle("Note")
                .navigationBarTitleDisplayMode(.inline)
                .modifier(NoteEditorCover(isPresented: $isEditingSelection, item: selectedItem))
        }
        .searchable(
            text: $filters.search,
            isPresented: $isSearchPresented,
            prompt: "Search notes, verses, or #tags"
        )
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NotesViewOptionsMenu(
                    sortField: sortFieldBinding,
                    sortAscending: $sortAscending,
                    contentFilter: $filters.content,
                    hasTags: !library.tags.isEmpty,
                    manageTagsAction: { isManagingTags = true },
                    exportAction: {
                        exportDocument = NotesMarkdownDocument(text: NotesMarkdownExporter.markdown(for: library.allItems))
                    }
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
                    defaultCategory: filters.category.noteCategory ?? .personal
                )
            }
        }
        .sheet(isPresented: $isManagingTags) {
            NavigationStack {
                NotesTagManagerView()
            }
        }
        .fileExporter(
            isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
            document: exportDocument,
            contentType: NotesMarkdownDocument.markdownType,
            defaultFilename: String(localized: "Bible Notes")
        ) { result in
            if case .success = result { Haptics.success() }
            exportDocument = nil
        }
        .background {
            ZStack {
                keyboardShortcutControls(hasSelection: selectedItem != nil)
                NotesKeyboardCommandResponder(
                    isEnabled: !isSearchPresented && !isCreatingNote && !isEditingSelection && !isManagingTags,
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
        .onChange(of: filters) { _, _ in selectFirstVisibleNoteIfNeeded() }
        .onChange(of: library.tags.map(\.tag)) { _, newTags in
            // A renamed or removed tag can't stay selected.
            if let tag = filters.tag, !newTags.contains(tag) {
                filters.tag = nil
            }
        }
        .onChange(of: selectedItem == nil) { _, isMissing in
            // The open note was deleted (from its editor or another device).
            guard isMissing else { return }
            isShowingCompactDetail = false
            selectFirstVisibleNoteIfNeeded()
        }
        .onChange(of: sortFieldRawValue) { _, _ in selectFirstVisibleNoteIfNeeded() }
        .onChange(of: sortAscending) { _, _ in selectFirstVisibleNoteIfNeeded() }
    }

    private var library: NotesLibrary {
        NotesLibrary(
            scriptureNotes: scriptureNotes,
            userNotes: userNotes,
            filters: filters,
            sort: sortField,
            ascending: sortAscending
        )
    }

    private func keyboardShortcutControls(hasSelection: Bool) -> some View {
        Group {
            Button("Search Notes") {
                isSearchPresented = true
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("Edit Selected Note") {
                editSelectedNote()
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(!hasSelection)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func filterBar(_ library: NotesLibrary) -> some View {
        NotesFilterBar(
            filters: $filters,
            tags: library.tags,
            manageTagsAction: { isManagingTags = true }
        )
    }

    private func compactContent(_ library: NotesLibrary) -> some View {
        VStack(spacing: 12) {
            filterBar(library)
            contextualTip

            notesList(
                library,
                newNoteAction: nil,
                selectAction: { item in
                    selectedID = item.id
                    isShowingCompactDetail = true
                }
            )
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private func regularContent(_ library: NotesLibrary, selectedItem: NotesListItem?) -> some View {
        VStack(spacing: 12) {
            filterBar(library)
            contextualTip

            ResizableNotesColumns(listColumnFraction: $listColumnFraction) {
                notesList(
                    library,
                    newNoteAction: { isCreatingNote = true },
                    selectAction: { selectedID = $0.id }
                )
                .padding(.horizontal, 2)
                .padding(.vertical, 12)
            } detail: {
                VStack(spacing: 12) {
                    if selectedItem != nil, !library.isVisible(selectedID) {
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

                    NoteDetailCard(item: selectedItem, editAction: { isEditingSelection = true })
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
                message: "Filter by type or color, or tap #Tags to filter by your own tags. Search for a verse such as John 3:16 to find every note on it. Swipe or press and hold a note for quick actions.",
                systemImage: "hand.point.up.left"
            )
        }
    }

    private func notesList(
        _ library: NotesLibrary,
        newNoteAction: (() -> Void)?,
        selectAction: @escaping (NotesListItem) -> Void
    ) -> some View {
        NotesListCard(
            sections: library.sections,
            selectedID: selectedID,
            summaryTitle: library.summaryTitle,
            hasAnyNotes: !library.allItems.isEmpty,
            showsClearFiltersAction: filters.isActive,
            clearFiltersAction: clearFilters,
            newNoteAction: newNoteAction,
            createFirstNoteAction: { isCreatingNote = true },
            selectAction: selectAction,
            editAction: { item in
                selectedID = item.id
                isEditingSelection = true
            },
            deleteAction: delete
        )
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

    private func clearFilters() {
        withAnimation(.snappy) {
            filters = NotesFilters()
        }
    }

    /// Keeps a note open in the detail column: the first visible one when nothing (or a deleted
    /// note) is selected.
    private func selectFirstVisibleNoteIfNeeded() {
        let library = library
        guard library.item(withID: selectedID) == nil else { return }
        selectedID = library.visibleItems.first?.id
    }

    private func moveSelection(by offset: Int) {
        let visibleNotes = library.visibleItems
        guard !visibleNotes.isEmpty else { return }

        let currentIndex = selectedID.flatMap { id in
            visibleNotes.firstIndex { $0.id == id }
        }
        let proposedIndex = (currentIndex ?? (offset > 0 ? -1 : visibleNotes.count)) + offset
        let destinationIndex = min(max(proposedIndex, 0), visibleNotes.count - 1)
        selectedID = visibleNotes[destinationIndex].id
    }

    private func editSelectedNote() {
        guard library.item(withID: selectedID) != nil else { return }
        isEditingSelection = true
    }

    private func requestSelectedNoteDeletion() {
        guard let selectedItem = library.item(withID: selectedID) else { return }
        delete(selectedItem)
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

        let notesBeforeDeletion = library.visibleItems
        let deletedIndex = notesBeforeDeletion.firstIndex { $0.id == item.id }
        let wasSelected = item.id == selectedID

        switch item {
        case .scripture(let note):
            deletedNoteSnapshot = .scripture(VerseNoteSnapshot(note: note), wasSelected: wasSelected)
            modelContext.delete(note)
        case .user(let note):
            deletedNoteSnapshot = .user(UserNoteSnapshot(note: note), wasSelected: wasSelected)
            modelContext.delete(note)
        }
        modelContext.saveLoggingErrors()

        if wasSelected {
            // Select the note that took the deleted one's place.
            let remainingNotes = notesBeforeDeletion.filter { $0.id != item.id }
            selectedID = remainingNotes.isEmpty ? nil : remainingNotes[min(deletedIndex ?? 0, remainingNotes.count - 1)].id
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

        // Save before reading the restored note's ID, since inserting gives it a temporary one.
        var restoredID: NotesListItem.ID?
        switch deletedNoteSnapshot {
        case .scriptureText(let note, let snapshot):
            snapshot.restoreText(to: note)
            modelContext.saveLoggingErrors()
        case .scripture(let snapshot, let wasSelected):
            let note = snapshot.makeNote()
            modelContext.insert(note)
            modelContext.saveLoggingErrors()
            if wasSelected { restoredID = .scripture(note.persistentModelID) }
        case .user(let snapshot, let wasSelected):
            let note = snapshot.makeNote()
            modelContext.insert(note)
            modelContext.saveLoggingErrors()
            if wasSelected { restoredID = .user(note.persistentModelID) }
        }

        if let restoredID { selectedID = restoredID }
        self.deletedNoteSnapshot = nil
    }
}

/// Presents the editor for the selected note.
private struct NoteEditorCover: ViewModifier {
    @Binding var isPresented: Bool
    let item: NotesListItem?

    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $isPresented) {
            NavigationStack {
                if let item {
                    NoteEditorView(item: item)
                }
            }
        }
    }
}

private struct ResizableNotesColumns<ListContent: View, DetailContent: View>: View {
    /// The list's share of the width, kept between launches.
    @Binding var listColumnFraction: Double
    @GestureState private var dragTranslation: CGFloat = 0

    let listContent: ListContent
    let detailContent: DetailContent

    init(
        listColumnFraction: Binding<Double>,
        @ViewBuilder listContent: () -> ListContent,
        @ViewBuilder detail: () -> DetailContent
    ) {
        _listColumnFraction = listColumnFraction
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
            let committedFraction = min(max(CGFloat(listColumnFraction), minimumFraction), maximumFraction)
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
                                listColumnFraction = Double(min(
                                    max(
                                        committedFraction + (value.translation.width / availableWidth),
                                        minimumFraction
                                    ),
                                    maximumFraction
                                ))
                            }
                    )
                    .accessibilityElement()
                    .accessibilityLabel("Resize notes list")
                    .accessibilityValue("\(Int(previewFraction * 100)) percent")
                    .accessibilityAdjustableAction { direction in
                        let adjustment: CGFloat = direction == .increment ? 0.05 : -0.05
                        listColumnFraction = Double(min(
                            max(committedFraction + adjustment, minimumFraction),
                            maximumFraction
                        ))
                    }
            }
        }
    }
}
