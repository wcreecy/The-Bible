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

    @State private var noteText: AttributedString
    @State private var noteSelection = AttributedTextSelection()
    @State private var selectedColor: VerseHighlightColor?
    @State private var persistenceFailure: PersistenceFailure?
    @State private var selectedScriptureReference: ScriptureRef?

    init(verse: VerseActionReference, existingNote: VerseNote?) {
        self.verse = verse
        self.existingNote = existingNote
        _noteText = State(initialValue: Self.loadFormattedContent(from: existingNote))
        _selectedColor = State(
            initialValue: existingNote.flatMap { VerseHighlightColor(rawValue: $0.highlightColor) }
        )
    }

    var body: some View {
        Form {
            VerseNotePassageSection(reference: verse)

            Section("Highlight") {
                HighlightColorPicker(selection: $selectedColor)
            }

            Section("Note") {
                NoteFormattingBar(
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
                copyAction: { copyScripture(reference) },
                openAction: { openScripture(reference) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var trimmedNote: String {
        String(noteText.characters).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func loadFormattedContent(from note: VerseNote?) -> AttributedString {
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

    private func openScripture(_ reference: ScriptureRef) {
        selectedScriptureReference = nil
        dismiss()
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .openBibleReference,
                object: nil,
                userInfo: [
                    "book": reference.bookName,
                    "chapter": reference.chapter,
                    "verse": reference.startVerse
                ]
            )
        }
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
                note.content = trimmedNote
                note.formattedContent = try JSONEncoder().encode(noteText)
                note.highlightColor = selectedColor?.rawValue ?? ""
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
    let openAction: () -> Void

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

                    Button(action: openAction) {
                        Image(systemName: "arrow.right.circle")
                    }
                    .accessibilityLabel("Go to scripture")
                    .disabled(passage?.verses.isEmpty != false)
                }
            }
        }
    }
}

private struct NoteFormattingBar: View {
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

private struct VerseNotePassageSection: View {
    let reference: VerseActionReference

    var body: some View {
        Section {
            Text(reference.verseText)
            Text("\(reference.bookName) \(reference.chapterNumber):\(reference.verseNumber)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
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

@MainActor
struct NotesAndHighlightsView: View {
    @Query private var scriptureNotes: [VerseNote]
    @Query private var userNotes: [UserNote]
    @State private var isCreatingNote = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                NotesCategoryCard(
                    title: "Scripture Notes & Highlights",
                    subtitle: "Notes and highlights saved from Bible verses",
                    systemImage: "text.book.closed",
                    count: scriptureNotes.count,
                    tint: .orange
                ) {
                    ScriptureNotesView()
                }

                NotesCategoryCard(
                    title: "My Notes",
                    subtitle: "Personal notes, reflections, and study thoughts",
                    systemImage: "note.text",
                    count: userNotes.count,
                    tint: .blue
                ) {
                    UserNotesView()
                }
            }
            .padding()
        }
        .background(AppBackgroundView(tab: .notes))
        .navigationTitle("Notes")
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
    }
}

private struct NotesCategoryCard<Destination: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let count: Int
    let tint: Color
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.title)
                        .foregroundStyle(tint)
                        .frame(width: 52, height: 52)
                        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)

                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)

                Text("\(count) \(count == 1 ? "note" : "notes")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }
            .padding(20)
            .frame(maxWidth: .infinity, minHeight: 210, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
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
                Text(reference)
                    .font(.headline)
                    .foregroundStyle(.primary)
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
    @State private var persistenceFailure: PersistenceFailure?
    @State private var selectedScriptureReference: ScriptureRef?

    init(existingNote: UserNote?) {
        self.existingNote = existingNote
        _title = State(initialValue: existingNote?.title ?? "")
        _noteText = State(initialValue: Self.loadFormattedContent(from: existingNote))
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
                copyAction: { copyScripture(reference) },
                openAction: { openScripture(reference) }
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

    private func openScripture(_ reference: ScriptureRef) {
        selectedScriptureReference = nil
        dismiss()
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .openBibleReference,
                object: nil,
                userInfo: [
                    "book": reference.bookName,
                    "chapter": reference.chapter,
                    "verse": reference.startVerse
                ]
            )
        }
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
