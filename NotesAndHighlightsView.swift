import SwiftData
import SwiftUI
import UIKit

enum VerseHighlightColor: String, CaseIterable, Identifiable {
    case yellow
    case green
    case blue
    case pink
    case purple

    var id: String { rawValue }

    var name: LocalizedStringResource {
        switch self {
        case .yellow: "Yellow"
        case .green: "Green"
        case .blue: "Blue"
        case .pink: "Pink"
        case .purple: "Purple"
        }
    }

    var color: Color {
        switch self {
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .pink: .pink
        case .purple: .purple
        }
    }
}

@MainActor
struct VerseNoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontResolutionContext) private var fontResolutionContext
    @Environment(\.modelContext) private var modelContext

    let verse: VerseActionReference
    let existingNote: VerseNote?

    @State private var title: String
    @State private var noteText: AttributedString
    @State private var noteSelection = AttributedTextSelection()
    @State private var selectedColor: VerseHighlightColor?
    @State private var selectedCategory: NoteCategory
    @State private var persistenceFailure: PersistenceFailure?
    @State private var selectedScriptureReference: ScriptureRef?

    init(verse: VerseActionReference, existingNote: VerseNote?) {
        self.verse = verse
        self.existingNote = existingNote
        _title = State(initialValue: existingNote?.title ?? "")
        _noteText = State(initialValue: Self.loadFormattedContent(from: existingNote, verse: verse))
        _selectedColor = State(
            initialValue: existingNote.flatMap { VerseHighlightColor(rawValue: $0.highlightColor) }
        )
        _selectedCategory = State(
            initialValue: existingNote.flatMap { NoteCategory(rawValue: $0.categoryRawValue) } ?? .scripture
        )
    }

    var body: some View {
        Form {
            Section("Title") {
                TextField("Title", text: $title)
                    .accessibilityLabel("Note title")
            }

            Section("Highlight") {
                HighlightColorPicker(selection: $selectedColor)
            }

            Section("Note") {
                NoteFormattingBar(
                    category: $selectedCategory,
                    toggleBold: { toggleFontTrait(\.isBold) },
                    toggleUnderline: toggleUnderline,
                    toggleItalic: { toggleFontTrait(\.isItalic) },
                    toggleStrikethrough: toggleStrikethrough,
                    insertBullet: insertBullet
                )

                TextEditor(text: $noteText, selection: $noteSelection)
                    .frame(minHeight: 140)
                    .accessibilityLabel("Note")
                    .environment(\.openURL, OpenURLAction { url in
                        guard let reference = BibleReferenceLinker.parse(url: url) else {
                            return .systemAction(url)
                        }
                        selectedScriptureReference = reference
                        return .handled
                    })
            }

            if existingNote != nil {
                Section {
                    Button("Remove Note & Highlight", role: .destructive, action: deleteEntry)
                }
            }
        }
        .navigationTitle(existingNote == nil ? "Add Note & Highlight" : "Edit Note & Highlight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(existingNote == nil && trimmedNote.isEmpty && selectedColor == nil)
            }
        }
        .persistenceFailureAlert(failure: $persistenceFailure)
        .onAppear(perform: linkScriptureReferences)
        .onChange(of: String(noteText.characters)) { _, _ in
            linkScriptureReferences()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openScripturePreview)) { notification in
            guard let url = notification.object as? URL,
                  let reference = BibleReferenceLinker.parse(url: url) else { return }
            selectedScriptureReference = reference
        }
        .sheet(item: $selectedScriptureReference) { reference in
            ScriptureReferencePreview(
                reference: reference,
                copyAction: { copyScripture(reference) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var trimmedNote: String {
        String(noteText.characters).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func loadFormattedContent(
        from note: VerseNote?,
        verse: VerseActionReference
    ) -> AttributedString {
        guard let note else {
            let reference = "\(verse.bookName) \(verse.chapterNumber):\(verse.verseNumber)"
            return BibleReferenceLinker.linkify(AttributedString(reference))
        }
        if let data = note.formattedContent,
           let formatted = try? JSONDecoder().decode(AttributedString.self, from: data) {
            return formatted
        }
        return AttributedString(note.content)
    }

    private func linkScriptureReferences() {
        let linked = BibleReferenceLinker.linkify(noteText)
        guard linked != noteText else { return }
        noteText = linked
    }

    private func copyScripture(_ reference: ScriptureRef) {
        guard let passage = BibleReferenceLinker.loadVerses(for: reference),
              !passage.verses.isEmpty else { return }
        let text = passage.verses.map(\.text).joined(separator: " ")
        UIPasteboard.general.string = "\(text)\n\(passage.title)"
        Haptics.success()
    }

    private func toggleFontTrait(_ trait: KeyPath<Font.Resolved, Bool>) {
        let resolvedFont = (noteSelection.typingAttributes(in: noteText).font ?? .body)
            .resolve(in: fontResolutionContext)
        let shouldEnable = !resolvedFont[keyPath: trait]
        noteText.transformAttributes(in: &noteSelection) {
            let font = $0.font ?? .body
            if trait == \.isBold {
                $0.font = font.bold(shouldEnable)
            } else {
                $0.font = font.italic(shouldEnable)
            }
        }
    }

    private func toggleUnderline() {
        let shouldEnable = noteSelection.typingAttributes(in: noteText).underlineStyle == nil
        noteText.transformAttributes(in: &noteSelection) {
            $0.underlineStyle = shouldEnable ? .single : nil
        }
    }

    private func toggleStrikethrough() {
        let shouldEnable = noteSelection.typingAttributes(in: noteText).strikethroughStyle == nil
        noteText.transformAttributes(in: &noteSelection) {
            $0.strikethroughStyle = shouldEnable ? .single : nil
        }
    }

    private func insertBullet() {
        noteText.replaceSelection(&noteSelection, withCharacters: "• ")
    }

    private func save() {
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                if let existingNote, trimmedNote.isEmpty, selectedColor == nil {
                    modelContext.delete(existingNote)
                    try modelContext.save()
                    return
                }

                let note = existingNote ?? VerseNote(
                    bookName: verse.bookName,
                    chapterNumber: verse.chapterNumber,
                    verseNumber: verse.verseNumber,
                    verseText: verse.verseText
                )
                note.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                note.content = trimmedNote
                note.formattedContent = try JSONEncoder().encode(noteText)
                note.highlightColor = selectedColor?.rawValue ?? ""
                note.categoryRawValue = selectedCategory.rawValue
                note.updatedAt = Date()
                if existingNote == nil {
                    modelContext.insert(note)
                }
                try modelContext.save()
            },
            onSuccess: {
                Haptics.success()
                dismiss()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }

    private func deleteEntry() {
        guard let existingNote else { return }
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                modelContext.delete(existingNote)
                try modelContext.save()
            },
            onSuccess: {
                Haptics.selection()
                dismiss()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }
}

private struct ScriptureReferencePreview: View {
    @Environment(\.dismiss) private var dismiss
    @State private var passage: (title: String, verses: [Verse])?
    @State private var isLoading = true

    let reference: ScriptureRef
    let copyAction: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView("Loading scripture…")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if let passage, !passage.verses.isEmpty {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(passage.verses) { verse in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text(verse.number, format: .number)
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                        .frame(minWidth: 24, alignment: .trailing)

                                    Text(verse.text)
                                        .font(.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .textSelection(.enabled)
                    } else {
                        ContentUnavailableView(
                            "Scripture Unavailable",
                            systemImage: "book.closed",
                            description: Text("The referenced passage could not be loaded.")
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle(passage?.title ?? "Scripture")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: reference.id) {
                isLoading = true
                passage = await BibleReferenceLinker.loadVersesEnsuringLoaded(for: reference)
                isLoading = false
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close scripture")
                }

                ToolbarItemGroup(placement: .confirmationAction) {
                    Button(action: copyAction) {
                        Image(systemName: "doc.on.doc")
                    }
                    .accessibilityLabel("Copy scripture")
                    .disabled(passage?.verses.isEmpty != false)

                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share scripture")
                    .disabled(passage?.verses.isEmpty != false)
                }
            }
        }
    }

    private var shareText: String {
        guard let passage else { return "" }
        let verses = passage.verses
            .map { "\($0.number) \($0.text)" }
            .joined(separator: "\n")
        return "\(passage.title)\n\n\(verses)"
    }
}

private struct NoteFormattingBar: View {
    @Binding var category: NoteCategory

    let toggleBold: () -> Void
    let toggleUnderline: () -> Void
    let toggleItalic: () -> Void
    let toggleStrikethrough: () -> Void
    let insertBullet: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            formattingButton("Bold", systemImage: "bold", action: toggleBold)
            formattingButton("Underline", systemImage: "underline", action: toggleUnderline)
            formattingButton("Italic", systemImage: "italic", action: toggleItalic)
            formattingButton("Strikethrough", systemImage: "strikethrough", action: toggleStrikethrough)
            formattingButton("Bulleted list", systemImage: "list.bullet", action: insertBullet)
            Spacer(minLength: 0)

            Menu {
                Picker("Category", selection: $category) {
                    ForEach(NoteCategory.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            } label: {
                ViewThatFits(in: .horizontal) {
                    Label(category.title, systemImage: "tag")
                    Image(systemName: "tag")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
                .padding(.horizontal, 8)
                .frame(minHeight: 30)
                .background(.tint.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Note category")
            .accessibilityValue(Text(category.title))
        }
    }

    private func formattingButton(
        _ accessibilityLabel: LocalizedStringKey,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 30, height: 30)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct HighlightColorPicker: View {
    @Binding var selection: VerseHighlightColor?

    var body: some View {
        HStack(spacing: 14) {
            ForEach(VerseHighlightColor.allCases) { highlight in
                Button {
                    selection = highlight
                } label: {
                    Circle()
                        .fill(highlight.color)
                        .frame(width: 32, height: 32)
                        .overlay {
                            if selection == highlight {
                                Circle().stroke(.primary, lineWidth: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(highlight.name))
                .accessibilityAddTraits(selection == highlight ? .isSelected : [])
            }

            Button {
                selection = nil
            } label: {
                Circle()
                    .fill(Color.secondary.opacity(0.16))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .overlay {
                        if selection == nil {
                            Circle().stroke(.primary, lineWidth: 3)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear highlight")
            .accessibilityAddTraits(selection == nil ? .isSelected : [])
        }
        .frame(maxWidth: .infinity)
    }
}

private enum NotesHighlightsSort: String, CaseIterable, Identifiable {
    case modifiedNewest
    case modifiedOldest
    case addedNewest
    case addedOldest
    case bibleOrder
    case highlightColor
    case reference

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .modifiedNewest: "Modified: Newest First"
        case .modifiedOldest: "Modified: Oldest First"
        case .addedNewest: "Added: Newest First"
        case .addedOldest: "Added: Oldest First"
        case .bibleOrder: "Bible Order"
        case .highlightColor: "Highlight Color"
        case .reference: "Reference A–Z"
        }
    }

    var systemImage: String {
        switch self {
        case .modifiedNewest, .modifiedOldest: "pencil.and.list.clipboard"
        case .addedNewest, .addedOldest: "calendar"
        case .bibleOrder: "book"
        case .highlightColor: "paintpalette"
        case .reference: "textformat.abc"
        }
    }
}

private enum NotesTabSort: String, CaseIterable, Identifiable {
    case modifiedNewest
    case modifiedOldest
    case createdNewest
    case createdOldest
    case highlightColor
    case tag
    case titleAscending
    case titleDescending

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .modifiedNewest: "Modified: Newest First"
        case .modifiedOldest: "Modified: Oldest First"
        case .createdNewest: "Created: Newest First"
        case .createdOldest: "Created: Oldest First"
        case .highlightColor: "Color"
        case .tag: "Tag"
        case .titleAscending: "Title: A–Z"
        case .titleDescending: "Title: Z–A"
        }
    }
}

private enum NotesFilter: String, CaseIterable, Identifiable {
    case all
    case sermon
    case personal
    case scripture

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .all: "All Tags"
        case .sermon: "Sermon"
        case .personal: "Personal"
        case .scripture: "Scripture"
        }
    }
}

private enum NotesListItem: Identifiable {
    enum ID: Hashable {
        case scripture(PersistentIdentifier)
        case user(PersistentIdentifier)
    }

    case scripture(VerseNote)
    case user(UserNote)

    var id: ID {
        switch self {
        case .scripture(let note): .scripture(note.persistentModelID)
        case .user(let note): .user(note.persistentModelID)
        }
    }

    var title: String {
        switch self {
        case .scripture(let note):
            note.title.isEmpty ? "\(note.bookName) \(note.chapterNumber):\(note.verseNumber)" : note.title
        case .user(let note):
            note.title.isEmpty ? "Untitled Note" : note.title
        }
    }

    var categoryRawValue: String {
        switch self {
        case .scripture(let note): note.categoryRawValue
        case .user(let note): note.categoryRawValue
        }
    }

    var highlightColor: String {
        switch self {
        case .scripture(let note): note.highlightColor
        case .user: ""
        }
    }

    var createdAt: Date? {
        switch self {
        case .scripture(let note): note.createdAt
        case .user(let note): note.createdAt
        }
    }

    var updatedAt: Date? {
        switch self {
        case .scripture(let note): note.updatedAt
        case .user(let note): note.updatedAt
        }
    }

    func matchesSearch(_ searchText: String) -> Bool {
        guard !searchText.isEmpty else { return true }
        switch self {
        case .scripture(let note):
            return title.localizedCaseInsensitiveContains(searchText) ||
                note.bookName.localizedCaseInsensitiveContains(searchText) ||
                note.verseText.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText) ||
                "\(note.chapterNumber):\(note.verseNumber)".localizedCaseInsensitiveContains(searchText)
        case .user(let note):
            return title.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private enum NotesHighlightFilter: String, CaseIterable, Identifiable {
    case all
    case none
    case yellow
    case green
    case blue
    case pink
    case purple

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .all: "All Highlight Colors"
        case .none: "No Highlight"
        case .yellow: "Yellow"
        case .green: "Green"
        case .blue: "Blue"
        case .pink: "Pink"
        case .purple: "Purple"
        }
    }
}

@MainActor
struct NotesAndHighlightsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \VerseNote.updatedAt, order: .reverse) private var scriptureNotes: [VerseNote]
    @Query(sort: \UserNote.updatedAt, order: .reverse) private var userNotes: [UserNote]

    @AppStorage("notesTabSort") private var sortRawValue = NotesTabSort.modifiedNewest.rawValue
    @State private var selectedFilter = NotesFilter.all
    @State private var highlightFilter = NotesHighlightFilter.all
    @State private var searchText = ""
    @State private var selectedScriptureNote: VerseNote?
    @State private var selectedUserNote: UserNote?
    @State private var isCreatingNote = false
    @State private var isEditingSelection = false
    @State private var isShowingCompactDetail = false

    var body: some View {
        VStack(spacing: 12) {
            GeometryReader { proxy in
                if horizontalSizeClass == .compact {
                    NotesListCard(
                        notes: visibleNotes,
                        selectedScriptureNote: $selectedScriptureNote,
                        selectedUserNote: $selectedUserNote,
                        selectedFilter: $selectedFilter,
                        highlightFilter: $highlightFilter,
                        selectionAction: { isShowingCompactDetail = true }
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 16) {
                        NotesListCard(
                            notes: visibleNotes,
                            selectedScriptureNote: $selectedScriptureNote,
                            selectedUserNote: $selectedUserNote,
                            selectedFilter: $selectedFilter,
                            highlightFilter: $highlightFilter,
                            selectionAction: {}
                        )
                        .frame(width: max(240, (proxy.size.width - 16) / 3))

                        NoteDetailCard(
                            scriptureNote: selectedScriptureNote,
                            userNote: selectedUserNote,
                            editAction: { isEditingSelection = true }
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
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
        .searchable(text: $searchText, prompt: "Search all notes")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $sortRawValue) {
                        ForEach(NotesTabSort.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort notes")

                Button {
                    isCreatingNote = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create note")
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
                        existingNote: selectedScriptureNote
                    )
                } else if let selectedUserNote {
                    UserNoteEditorView(existingNote: selectedUserNote)
                }
            }
        }
        .onAppear(perform: selectFirstVisibleNoteIfNeeded)
        .onChange(of: selectedFilter) { _, _ in selectFirstVisibleNoteIfNeeded() }
        .onChange(of: highlightFilter) { _, _ in selectFirstVisibleNote() }
        .onChange(of: sortRawValue) { _, _ in selectFirstVisibleNoteIfNeeded() }
        .onChange(of: searchText) { _, _ in selectFirstVisibleNoteIfNeeded() }
    }

    private var visibleNotes: [NotesListItem] {
        let allNotes = scriptureNotes.map(NotesListItem.scripture) + userNotes.map(NotesListItem.user)
        return sort(allNotes.filter { note in
            matchesSelectedCategory(note.categoryRawValue) &&
                matchesHighlight(note.highlightColor) &&
                note.matchesSearch(searchText)
        })
    }

    private func matchesSelectedCategory(_ rawValue: String) -> Bool {
        selectedFilter == .all || rawValue == selectedFilter.rawValue
    }

    private func matchesHighlight(_ rawValue: String) -> Bool {
        switch highlightFilter {
        case .all: true
        case .none: rawValue.isEmpty
        default: rawValue == highlightFilter.rawValue
        }
    }

    private func sort(_ notes: [NotesListItem]) -> [NotesListItem] {
        let selectedSort = NotesTabSort(rawValue: sortRawValue) ?? .modifiedNewest
        switch selectedSort {
        case .modifiedNewest:
            return notes.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
        case .modifiedOldest:
            return notes.sorted { ($0.updatedAt ?? .distantPast) < ($1.updatedAt ?? .distantPast) }
        case .createdNewest:
            return notes.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .createdOldest:
            return notes.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        case .highlightColor:
            return notes.sorted {
                if $0.highlightColor != $1.highlightColor {
                    return $0.highlightColor < $1.highlightColor
                }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        case .tag:
            return notes.sorted {
                if $0.categoryRawValue != $1.categoryRawValue {
                    return $0.categoryRawValue.localizedStandardCompare($1.categoryRawValue) == .orderedAscending
                }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        case .titleAscending:
            return notes.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .titleDescending:
            return notes.sorted { $0.title.localizedStandardCompare($1.title) == .orderedDescending }
        }
    }

    private func selectFirstVisibleNoteIfNeeded() {
        let scriptureSelectionIsVisible = selectedScriptureNote.map { selected in
            visibleNotes.contains {
                if case .scripture(let note) = $0 { return note === selected }
                return false
            }
        } ?? false
        let userSelectionIsVisible = selectedUserNote.map { selected in
            visibleNotes.contains {
                if case .user(let note) = $0 { return note === selected }
                return false
            }
        } ?? false

        if !scriptureSelectionIsVisible && !userSelectionIsVisible {
            selectFirstVisibleNote()
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

private extension NotesFilter {
    var noteCategory: NoteCategory? {
        switch self {
        case .all: nil
        case .sermon: .sermon
        case .personal: .personal
        case .scripture: .scripture
        }
    }
}

private struct NotesListCard: View {
    @Environment(\.modelContext) private var modelContext

    let notes: [NotesListItem]
    @Binding var selectedScriptureNote: VerseNote?
    @Binding var selectedUserNote: UserNote?
    @Binding var selectedFilter: NotesFilter
    @Binding var highlightFilter: NotesHighlightFilter
    let selectionAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Notes")
                    .font(.headline)

                Spacer()

                NotesFilterMenu(
                    selectedFilter: $selectedFilter,
                    highlightFilter: $highlightFilter
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 4) {
                if notes.isEmpty {
                    ContentUnavailableView(
                        "No Notes",
                        systemImage: "note.text",
                        description: Text("Try another tag, color, sort order, or search.")
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(notes) { item in
                        switch item {
                        case .scripture(let note):
                            NotesTitleButton(
                                title: item.title,
                                tag: NoteCategory(rawValue: note.categoryRawValue)?.title,
                                highlight: VerseHighlightColor(rawValue: note.highlightColor),
                                isSelected: selectedScriptureNote === note
                            ) {
                                selectedScriptureNote = note
                                selectedUserNote = nil
                                selectionAction()
                            }
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) { delete(note) }
                            }
                        case .user(let note):
                            NotesTitleButton(
                                title: item.title,
                                tag: NoteCategory(rawValue: note.categoryRawValue)?.title,
                                highlight: nil,
                                isSelected: selectedUserNote === note
                            ) {
                                selectedUserNote = note
                                selectedScriptureNote = nil
                                selectionAction()
                            }
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) { delete(note) }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            }
        }
        .heroCardSurface()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func delete(_ note: VerseNote) {
        if selectedScriptureNote === note {
            selectedScriptureNote = nil
        }
        modelContext.delete(note)
        try? modelContext.save()
    }

    private func delete(_ note: UserNote) {
        if selectedUserNote === note {
            selectedUserNote = nil
        }
        modelContext.delete(note)
        try? modelContext.save()
    }
}

private struct NotesFilterMenu: View {
    @Binding var selectedFilter: NotesFilter
    @Binding var highlightFilter: NotesHighlightFilter

    var body: some View {
        Menu {
            Picker("Tag", selection: $selectedFilter) {
                ForEach(NotesFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }

            Divider()

            Picker("Highlight Color", selection: $highlightFilter) {
                ForEach(NotesHighlightFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }

        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("Filter and sort notes")
    }
}

private struct NotesTitleButton: View {
    let title: String
    let tag: LocalizedStringResource?
    let highlight: VerseHighlightColor?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Circle()
                    .fill(highlight?.color ?? .secondary.opacity(0.25))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if let tag {
                        Text(tag)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44)
            .background(isSelected ? Color.accentColor.opacity(0.16) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct NoteDetailCard: View {
    @State private var selectedScriptureReference: ScriptureRef?

    let scriptureNote: VerseNote?
    let userNote: UserNote?
    let editAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let scriptureNote {
                NoteDetailHeader(
                    title: scriptureNote.title.isEmpty ? "Scripture Note" : scriptureNote.title,
                    subtitle: "\(scriptureNote.bookName) \(scriptureNote.chapterNumber):\(scriptureNote.verseNumber)",
                    editAction: editAction
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(scriptureNote.verseText)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text(formattedContent(data: scriptureNote.formattedContent, fallback: scriptureNote.content))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        NoteTimestampView(createdAt: scriptureNote.createdAt, updatedAt: scriptureNote.updatedAt)
                    }
                }
            } else if let userNote {
                NoteDetailHeader(
                    title: userNote.title.isEmpty ? "Untitled Note" : userNote.title,
                    subtitle: nil,
                    editAction: editAction
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(formattedContent(data: userNote.formattedContent, fallback: userNote.content))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        NoteTimestampView(createdAt: userNote.createdAt, updatedAt: userNote.updatedAt)
                    }
                }
            } else {
                ContentUnavailableView(
                    "Select a Note",
                    systemImage: "note.text",
                    description: Text("Choose a note from the card on the left to read it here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.openURL, OpenURLAction { url in
            guard let reference = BibleReferenceLinker.parse(url: url) else {
                return .systemAction(url)
            }
            selectedScriptureReference = reference
            return .handled
        })
        .sheet(item: $selectedScriptureReference) { reference in
            ScriptureReferencePreview(
                reference: reference,
                copyAction: { copyScripture(reference) }
            )
        }
    }

    private func formattedContent(data: Data?, fallback: String) -> AttributedString {
        if let data, let formatted = try? JSONDecoder().decode(AttributedString.self, from: data) {
            return BibleReferenceLinker.linkify(formatted)
        }
        return BibleReferenceLinker.linkify(AttributedString(fallback))
    }

    private func copyScripture(_ reference: ScriptureRef) {
        guard let passage = BibleReferenceLinker.loadVerses(for: reference),
              !passage.verses.isEmpty else { return }
        let text = passage.verses.map(\.text).joined(separator: " ")
        UIPasteboard.general.string = "\(text)\n\(passage.title)"
        Haptics.success()
    }

}

private struct NoteDetailHeader: View {
    let title: String
    let subtitle: String?
    let editAction: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.bold())
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Edit", systemImage: "pencil", action: editAction)
                .buttonStyle(.bordered)
        }
    }
}

@MainActor
private struct ScriptureNotesView: View {
    @Query(sort: \VerseNote.updatedAt, order: .reverse) private var notes: [VerseNote]
    @AppStorage("notesHighlightsSort") private var sortRawValue = NotesHighlightsSort.modifiedNewest.rawValue
    @State private var searchText = ""
    @State private var selectedNote: VerseNote?

    var body: some View {
        List {
            if visibleNotes.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Notes or Highlights" : "No Results",
                    systemImage: searchText.isEmpty ? "highlighter" : "magnifyingglass",
                    description: Text(searchText.isEmpty
                        ? "Press and hold a verse to add a private note or highlight."
                        : "Try searching for a reference, verse, or note.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(visibleNotes) { note in
                    Button {
                        selectedNote = note
                    } label: {
                        NoteHighlightRow(
                            title: note.title,
                            reference: "\(note.bookName) \(note.chapterNumber):\(note.verseNumber)",
                            verseText: note.verseText,
                            noteText: formattedContent(for: note),
                            highlight: VerseHighlightColor(rawValue: note.highlightColor),
                            createdAt: note.createdAt,
                            updatedAt: note.updatedAt
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button("Open", systemImage: "book") {
                            open(note)
                        }
                        .tint(.accentColor)
                    }
                }
                .onDelete(perform: delete)
                .listRowBackground(HeroCardListRowBackground())
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackgroundView(tab: .notes))
        .navigationTitle("Notes")
        .searchable(text: $searchText, prompt: "Search notes and verses")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $sortRawValue) {
                        ForEach(NotesHighlightsSort.allCases) { option in
                            Label(option.title, systemImage: option.systemImage)
                                .tag(option.rawValue)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort notes and highlights")
            }
        }
        .sheet(item: $selectedNote) { note in
            NavigationStack {
                VerseNoteEditorView(
                    verse: VerseActionReference(
                        bookName: note.bookName,
                        chapterNumber: note.chapterNumber,
                        verseNumber: note.verseNumber,
                        verseText: note.verseText
                    ),
                    existingNote: note
                )
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Open in Bible", systemImage: "book") {
                            selectedNote = nil
                            open(note)
                        }
                    }
                }
            }
        }
    }

    private var visibleNotes: [VerseNote] {
        let filteredNotes: [VerseNote]
        if searchText.isEmpty {
            filteredNotes = notes
        } else {
            filteredNotes = notes.filter {
                $0.bookName.localizedCaseInsensitiveContains(searchText) ||
                $0.verseText.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                "\($0.chapterNumber):\($0.verseNumber)".localizedCaseInsensitiveContains(searchText)
            }
        }

        let selectedSort = NotesHighlightsSort(rawValue: sortRawValue) ?? .modifiedNewest
        switch selectedSort {
        case .modifiedNewest:
            return filteredNotes.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
        case .modifiedOldest:
            return filteredNotes.sorted { ($0.updatedAt ?? .distantPast) < ($1.updatedAt ?? .distantPast) }
        case .addedNewest:
            return filteredNotes.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .addedOldest:
            return filteredNotes.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        case .bibleOrder:
            let bookPositions = Dictionary(
                uniqueKeysWithValues: BibleData.books.enumerated().map { ($0.element.name, $0.offset) }
            )
            return filteredNotes.sorted {
                let left = bookPositions[$0.bookName] ?? .max
                let right = bookPositions[$1.bookName] ?? .max
                if left != right { return left < right }
                if $0.chapterNumber != $1.chapterNumber { return $0.chapterNumber < $1.chapterNumber }
                return $0.verseNumber < $1.verseNumber
            }
        case .highlightColor:
            let colorPositions = Dictionary(
                uniqueKeysWithValues: VerseHighlightColor.allCases.enumerated().map { ($0.element.rawValue, $0.offset) }
            )
            return filteredNotes.sorted {
                let left = colorPositions[$0.highlightColor] ?? .max
                let right = colorPositions[$1.highlightColor] ?? .max
                if left != right { return left < right }
                return referencePrecedes($0, $1)
            }
        case .reference:
            return filteredNotes.sorted(by: referencePrecedes)
        }
    }

    private func referencePrecedes(_ left: VerseNote, _ right: VerseNote) -> Bool {
        let comparison = left.bookName.localizedStandardCompare(right.bookName)
        if comparison != .orderedSame { return comparison == .orderedAscending }
        if left.chapterNumber != right.chapterNumber { return left.chapterNumber < right.chapterNumber }
        return left.verseNumber < right.verseNumber
    }

    private func formattedContent(for note: VerseNote) -> AttributedString {
        if let data = note.formattedContent,
           let formatted = try? JSONDecoder().decode(AttributedString.self, from: data) {
            return formatted
        }
        return AttributedString(note.content)
    }

    private func open(_ note: VerseNote) {
        NotificationCenter.default.post(
            name: .openBibleReference,
            object: nil,
            userInfo: [
                "book": note.bookName,
                "chapter": note.chapterNumber,
                "verse": note.verseNumber
            ]
        )
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(visibleNotes[index])
        }
        try? modelContext.save()
    }

    @Environment(\.modelContext) private var modelContext
}

private struct NoteHighlightRow: View {
    let title: String
    let reference: String
    let verseText: String
    let noteText: AttributedString
    let highlight: VerseHighlightColor?
    let createdAt: Date?
    let updatedAt: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(highlight?.color ?? .clear)
                .frame(width: 6)
                .overlay {
                    if highlight == nil {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.2))
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(title.isEmpty ? reference : title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if !title.isEmpty {
                    Text(reference)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(verseText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                if !noteText.characters.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "note.text")
                        Text(noteText)
                    }
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }
                NoteTimestampView(createdAt: createdAt, updatedAt: updatedAt)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

private struct NoteTimestampView: View {
    let createdAt: Date?
    let updatedAt: Date?

    var body: some View {
        if let displayDate {
            Group {
                if wasModified {
                    Text(
                        "Modified \(displayDate, format: .dateTime.month(.abbreviated).day().year().hour().minute())",
                        comment: "Timestamp beneath a saved Bible note."
                    )
                } else {
                    Text(
                        "Added \(displayDate, format: .dateTime.month(.abbreviated).day().year().hour().minute())",
                        comment: "Timestamp beneath a newly added Bible note."
                    )
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    private var wasModified: Bool {
        guard let createdAt, let updatedAt else { return false }
        return updatedAt.timeIntervalSince(createdAt) > 1
    }

    private var displayDate: Date? {
        wasModified ? updatedAt : (createdAt ?? updatedAt)
    }
}

@MainActor
private struct UserNotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserNote.updatedAt, order: .reverse) private var notes: [UserNote]
    @State private var searchText = ""
    @State private var selectedNote: UserNote?
    @State private var isCreatingNote = false

    var body: some View {
        List {
            if visibleNotes.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Personal Notes" : "No Results",
                    systemImage: searchText.isEmpty ? "note.text" : "magnifyingglass",
                    description: Text(searchText.isEmpty
                        ? "Tap the plus button to create your first note."
                        : "Try searching for a note title or its contents.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(visibleNotes) { note in
                    Button {
                        selectedNote = note
                    } label: {
                        UserNoteRow(
                            title: note.title,
                            content: formattedContent(for: note),
                            createdAt: note.createdAt,
                            updatedAt: note.updatedAt
                        )
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: delete)
                .listRowBackground(HeroCardListRowBackground())
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackgroundView(tab: .notes))
        .navigationTitle("My Notes")
        .searchable(text: $searchText, prompt: "Search personal notes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreatingNote = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create note")
            }
        }
        .fullScreenCover(isPresented: $isCreatingNote) {
            NavigationStack {
                UserNoteEditorView(existingNote: nil)
            }
        }
        .fullScreenCover(item: $selectedNote) { note in
            NavigationStack {
                UserNoteEditorView(existingNote: note)
            }
        }
    }

    private var visibleNotes: [UserNote] {
        guard !searchText.isEmpty else { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func formattedContent(for note: UserNote) -> AttributedString {
        if let data = note.formattedContent,
           let formatted = try? JSONDecoder().decode(AttributedString.self, from: data) {
            return formatted
        }
        return AttributedString(note.content)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(visibleNotes[index])
        }
        try? modelContext.save()
    }
}

private struct UserNoteRow: View {
    let title: String
    let content: AttributedString
    let createdAt: Date?
    let updatedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.isEmpty ? "Untitled Note" : title)
                .font(.headline)
                .foregroundStyle(.primary)

            if !content.characters.isEmpty {
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            NoteTimestampView(createdAt: createdAt, updatedAt: updatedAt)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

@MainActor
private struct UserNoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontResolutionContext) private var fontResolutionContext
    @Environment(\.modelContext) private var modelContext

    let existingNote: UserNote?

    @State private var title: String
    @State private var noteText: AttributedString
    @State private var noteSelection = AttributedTextSelection()
    @State private var selectedCategory: NoteCategory
    @State private var persistenceFailure: PersistenceFailure?
    @State private var selectedScriptureReference: ScriptureRef?

    init(existingNote: UserNote?, defaultCategory: NoteCategory = .personal) {
        self.existingNote = existingNote
        _title = State(initialValue: existingNote?.title ?? "")
        _noteText = State(initialValue: Self.loadFormattedContent(from: existingNote))
        _selectedCategory = State(
            initialValue: existingNote.flatMap { NoteCategory(rawValue: $0.categoryRawValue) } ?? defaultCategory
        )
    }

    var body: some View {
        Form {
            Section("Title") {
                TextField("Note title", text: $title)
                    .font(.title3.weight(.semibold))
                    .accessibilityLabel("Note title")
            }

            Section("Note") {
                NoteFormattingBar(
                    category: $selectedCategory,
                    toggleBold: { toggleFontTrait(\.isBold) },
                    toggleUnderline: toggleUnderline,
                    toggleItalic: { toggleFontTrait(\.isItalic) },
                    toggleStrikethrough: toggleStrikethrough,
                    insertBullet: insertBullet
                )

                TextEditor(text: $noteText, selection: $noteSelection)
                    .frame(minHeight: 380)
                    .accessibilityLabel("Note")
                    .environment(\.openURL, OpenURLAction { url in
                        guard let reference = BibleReferenceLinker.parse(url: url) else {
                            return .systemAction(url)
                        }
                        selectedScriptureReference = reference
                        return .handled
                    })
            }

            if existingNote != nil {
                Section {
                    Button("Delete Note", role: .destructive, action: deleteNote)
                }
            }
        }
        .navigationTitle(existingNote == nil ? "New Note" : "Edit Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(trimmedTitle.isEmpty && trimmedNote.isEmpty)
            }
        }
        .persistenceFailureAlert(failure: $persistenceFailure)
        .onAppear(perform: linkScriptureReferences)
        .onChange(of: String(noteText.characters)) { _, _ in
            linkScriptureReferences()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openScripturePreview)) { notification in
            guard let url = notification.object as? URL,
                  let reference = BibleReferenceLinker.parse(url: url) else { return }
            selectedScriptureReference = reference
        }
        .sheet(item: $selectedScriptureReference) { reference in
            ScriptureReferencePreview(
                reference: reference,
                copyAction: { copyScripture(reference) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNote: String {
        String(noteText.characters).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func loadFormattedContent(from note: UserNote?) -> AttributedString {
        guard let note else { return AttributedString() }
        if let data = note.formattedContent,
           let formatted = try? JSONDecoder().decode(AttributedString.self, from: data) {
            return formatted
        }
        return AttributedString(note.content)
    }

    private func linkScriptureReferences() {
        let linked = BibleReferenceLinker.linkify(noteText)
        guard linked != noteText else { return }
        noteText = linked
    }

    private func copyScripture(_ reference: ScriptureRef) {
        guard let passage = BibleReferenceLinker.loadVerses(for: reference),
              !passage.verses.isEmpty else { return }
        let text = passage.verses.map(\.text).joined(separator: " ")
        UIPasteboard.general.string = "\(text)\n\(passage.title)"
        Haptics.success()
    }

    private func toggleFontTrait(_ trait: KeyPath<Font.Resolved, Bool>) {
        let resolvedFont = (noteSelection.typingAttributes(in: noteText).font ?? .body)
            .resolve(in: fontResolutionContext)
        let shouldEnable = !resolvedFont[keyPath: trait]
        noteText.transformAttributes(in: &noteSelection) {
            let font = $0.font ?? .body
            if trait == \.isBold {
                $0.font = font.bold(shouldEnable)
            } else {
                $0.font = font.italic(shouldEnable)
            }
        }
    }

    private func toggleUnderline() {
        let shouldEnable = noteSelection.typingAttributes(in: noteText).underlineStyle == nil
        noteText.transformAttributes(in: &noteSelection) {
            $0.underlineStyle = shouldEnable ? .single : nil
        }
    }

    private func toggleStrikethrough() {
        let shouldEnable = noteSelection.typingAttributes(in: noteText).strikethroughStyle == nil
        noteText.transformAttributes(in: &noteSelection) {
            $0.strikethroughStyle = shouldEnable ? .single : nil
        }
    }

    private func insertBullet() {
        noteText.replaceSelection(&noteSelection, withCharacters: "• ")
    }

    private func save() {
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                let note = existingNote ?? UserNote()
                note.title = trimmedTitle
                note.content = trimmedNote
                note.formattedContent = try JSONEncoder().encode(noteText)
                note.categoryRawValue = selectedCategory.rawValue
                note.updatedAt = Date()
                if existingNote == nil {
                    modelContext.insert(note)
                }
                try modelContext.save()
            },
            onSuccess: {
                Haptics.success()
                dismiss()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }

    private func deleteNote() {
        guard let existingNote else { return }
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                modelContext.delete(existingNote)
                try modelContext.save()
            },
            onSuccess: {
                Haptics.selection()
                dismiss()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }
}
