import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Editing

/// The editor for a note on the Notes page or in a list of mentions.
struct NoteEditorView: View {
    let item: NotesListItem

    var body: some View {
        switch item {
        case .scripture(let note):
            VerseNoteEditorView(
                verse: VerseActionReference(
                    bookName: note.bookName,
                    chapterNumber: note.chapterNumber,
                    verseNumber: note.verseNumber,
                    verseText: note.verseText
                ),
                existingNote: note,
                preservesHighlightWhenRemovingNote: true
            )
        case .user(let note):
            UserNoteEditorView(existingNote: note)
        }
    }
}

// MARK: - Tags

/// Renames, merges, and removes custom tags across notes.
@MainActor
enum NoteTagEditor {
    /// Replaces `tag` with `replacement` in every note's title and body, merging into an existing
    /// tag of that name; a nil replacement removes the "#" and keeps the word. Notes keep their
    /// modified dates, since the writing itself didn't change. Returns how many notes changed.
    @discardableResult
    static func rename(
        _ tag: String,
        to replacement: String?,
        verseNotes: [VerseNote],
        userNotes: [UserNote]
    ) -> Int {
        var changed = 0
        for note in verseNotes where apply(tag, replacement, title: &note.title, content: &note.content, formatted: &note.formattedContent) {
            changed += 1
        }
        for note in userNotes where apply(tag, replacement, title: &note.title, content: &note.content, formatted: &note.formattedContent) {
            changed += 1
        }
        return changed
    }

    private static func apply(
        _ tag: String,
        _ replacement: String?,
        title: inout String,
        content: inout String,
        formatted: inout Data?
    ) -> Bool {
        let newTitle = NoteCustomTags.renaming(tag, to: replacement, in: title)
        let newContent = NoteCustomTags.renaming(tag, to: replacement, in: content)
        guard newTitle != title || newContent != content else { return false }
        if formatted != nil {
            let text = NoteFormattedContent.decode(formatted, fallback: content)
            formatted = try? JSONEncoder().encode(NoteCustomTags.renaming(tag, to: replacement, in: text))
        }
        title = newTitle
        content = newContent
        return true
    }
}

/// Lists every custom tag with its count, to rename, merge, or remove tags.
struct NotesTagManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var verseNotes: [VerseNote]
    @Query private var userNotes: [UserNote]

    @State private var renamingTag: String?
    @State private var newName = ""
    @State private var removingTag: String?
    @State private var persistenceFailure: PersistenceFailure?

    var body: some View {
        List {
            if tags.isEmpty {
                ContentUnavailableView(
                    "No Tags",
                    systemImage: "tag",
                    description: Text("Type # and a word in a note, such as #prayer, to tag it.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(tags) { tag in
                        HStack {
                            Text(verbatim: "#\(tag.tag)")
                            Spacer()
                            Text(tag.count == 1 ? "1 note" : "\(tag.count) notes")
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(.rect)
                        .onTapGesture { beginRename(tag.tag) }
                        .swipeActions {
                            Button("Remove", systemImage: "trash", role: .destructive) { removingTag = tag.tag }
                            Button("Rename", systemImage: "pencil") { beginRename(tag.tag) }
                                .tint(.accentColor)
                        }
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") { beginRename(tag.tag) }
                            Button("Remove Tag", systemImage: "trash", role: .destructive) { removingTag = tag.tag }
                        }
                    }
                } footer: {
                    Text("Tap a tag to rename it. Renaming to an existing tag merges the two. Removing a tag keeps the word in your notes without the #.")
                }
            }
        }
        .navigationTitle("Manage Tags")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .alert("Rename Tag", isPresented: isRenaming) {
            TextField("Tag name", text: $newName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Rename") { commitRename() }
                .disabled(validNewName == nil)
            Button("Cancel", role: .cancel) { renamingTag = nil }
        } message: {
            if let validNewName, validNewName != renamingTag, tags.contains(where: { $0.tag == validNewName }) {
                Text("#\(renamingTag ?? "") will be merged into #\(validNewName).")
            } else {
                Text("Letters, numbers, and underscores only.")
            }
        }
        .confirmationDialog(
            Text("Remove #\(removingTag ?? "")?"),
            isPresented: isRemoving,
            titleVisibility: .visible
        ) {
            Button("Remove Tag", role: .destructive) {
                if let removingTag { change(removingTag, to: nil) }
                removingTag = nil
            }
            Button("Cancel", role: .cancel) { removingTag = nil }
        } message: {
            Text("The word stays in your notes without the #.")
        }
        .persistenceFailureAlert(failure: $persistenceFailure)
    }

    private var tags: [NotesLibrary.TagCount] {
        NotesLibrary(scriptureNotes: verseNotes, userNotes: userNotes, filters: NotesFilters(), sort: .title, ascending: true).tags
    }

    private var validNewName: String? { NoteCustomTags.normalizedTag(newName) }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renamingTag != nil }, set: { if !$0 { renamingTag = nil } })
    }

    private var isRemoving: Binding<Bool> {
        Binding(get: { removingTag != nil }, set: { if !$0 { removingTag = nil } })
    }

    private func beginRename(_ tag: String) {
        newName = tag
        renamingTag = tag
    }

    private func commitRename() {
        defer { renamingTag = nil }
        guard let renamingTag, let validNewName, validNewName != renamingTag else { return }
        change(renamingTag, to: validNewName)
    }

    private func change(_ tag: String, to replacement: String?) {
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                NoteTagEditor.rename(tag, to: replacement, verseNotes: verseNotes, userNotes: userNotes)
                try modelContext.save()
            },
            onSuccess: { Haptics.success() },
            onFailure: { persistenceFailure = $0 }
        )
    }
}

// MARK: - Export

@MainActor
enum NotesMarkdownExporter {
    /// Every note as Markdown, newest first: title, type, verses or passage, then the note.
    static func markdown(for items: [NotesListItem], exportedAt date: Date = .now) -> String {
        var lines = [
            "# Bible Notes",
            "",
            String(localized: "Exported \(date.formatted(date: .long, time: .shortened)) · \(items.count) notes"),
        ]
        for item in NotesLibrary.sorted(items, by: .modified, ascending: false) {
            lines += ["", "---", "", "## \(item.title)", ""]
            var details: [String] = []
            if let category = item.category { details.append(String(localized: category.title)) }
            if let passage = item.passage { details.append(passage) }
            if let date = item.updatedAt ?? item.createdAt {
                details.append(date.formatted(date: .abbreviated, time: .omitted))
            }
            if !item.highlightColor.isEmpty, let color = VerseHighlightColor(rawValue: item.highlightColor) {
                details.append(String(localized: "\(String(localized: color.title)) highlight"))
            }
            lines.append("*\(details.joined(separator: " · "))*")
            switch item {
            case .scripture(let note):
                if !note.verseText.isEmpty { lines += ["", "> \(note.verseText)"] }
            case .user(let note):
                let sermonLines = item.sermonDetailLines(for: note)
                if !sermonLines.isEmpty { lines += [""] + sermonLines }
            }
            if !item.content.isEmpty { lines += ["", item.content] }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

/// A Markdown file of notes, for the system's export panel.
struct NotesMarkdownDocument: FileDocument {
    static let markdownType = UTType(filenameExtension: "md", conformingTo: .plainText) ?? .plainText
    static let readableContentTypes: [UTType] = [markdownType, .plainText]

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        text = String(decoding: data, as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

// MARK: - Mentions

/// Finds notes that mention a verse: a reference in the body, or a personal note's passage.
@MainActor
enum NoteMentions {
    private struct CacheKey: Hashable {
        let id: NotesListItem.ID
        let updatedAt: Date?
        let length: Int
    }

    /// Each note's references, reparsed only when the note changes.
    private static var cache: [CacheKey: [ScriptureRef]] = [:]

    static func items(
        mentioning verse: VerseActionReference,
        scriptureNotes: [VerseNote],
        userNotes: [UserNote]
    ) -> [NotesListItem] {
        let items = scriptureNotes
            // A note on the verse itself is its own note, not a mention.
            .filter { !$0.covers(bookName: verse.bookName, chapterNumber: verse.chapterNumber, verseNumber: verse.verseNumber) }
            .map(NotesListItem.scripture) + userNotes.map(NotesListItem.user)
        // Only notes containing "3:" for chapter 3 can mention it; skip parsing the rest.
        let chapterMarker = "\(verse.chapterNumber):"
        let matches = items.filter { item in
            let text = searchableText(for: item)
            guard text.contains(chapterMarker) else { return false }
            return references(for: item, text: text).contains { reference in
                reference.bookName.caseInsensitiveCompare(verse.bookName) == .orderedSame &&
                    reference.chapter == verse.chapterNumber &&
                    (reference.startVerse...max(reference.startVerse, reference.endVerse ?? reference.startVerse))
                        .contains(verse.verseNumber)
            }
        }
        return NotesLibrary.sorted(matches, by: .modified, ascending: false)
    }

    /// Every verse reference written in `text`.
    static func references(in text: String) -> [ScriptureRef] {
        BibleReferenceLinker.linkify(text).runs.compactMap { run in
            run.link.flatMap(BibleReferenceLinker.parse(url:))
        }
    }

    private static func searchableText(for item: NotesListItem) -> String {
        switch item {
        case .scripture(let note): "\(note.title)\n\(note.content)"
        case .user(let note): "\(note.passageReference)\n\(note.title)\n\(note.content)"
        }
    }

    private static func references(for item: NotesListItem, text: String) -> [ScriptureRef] {
        let key = CacheKey(id: item.id, updatedAt: item.updatedAt, length: text.utf8.count)
        if let cached = cache[key] { return cached }
        let found = references(in: text)
        cache[key] = found
        return found
    }
}

/// Lists the notes that mention a verse, opened from the verse's action menu.
struct NoteMentionsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var scriptureNotes: [VerseNote]
    @Query private var userNotes: [UserNote]
    @State private var editingItem: NotesListItem.ID?

    let verse: VerseActionReference

    var body: some View {
        let items = NoteMentions.items(mentioning: verse, scriptureNotes: scriptureNotes, userNotes: userNotes)
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "No Mentions",
                    systemImage: "link",
                    description: Text("Notes that mention \(verse.bookName) \(verse.chapterNumber):\(verse.verseNumber) appear here.")
                )
                .listRowBackground(Color.clear)
            }
            ForEach(items) { item in
                NavigationLink(value: item.id) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline.weight(.semibold))
                        if !item.preview.isEmpty {
                            Text(item.preview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        HStack(spacing: 6) {
                            if let category = item.category {
                                Text(category.shortTitle).foregroundStyle(.tint)
                            }
                            if let passage = item.passage {
                                Label(passage, systemImage: "book.closed")
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .navigationTitle("Notes Mentioning \(verse.bookName) \(verse.chapterNumber):\(verse.verseNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: NotesListItem.ID.self) { id in
            let all = scriptureNotes.map(NotesListItem.scripture) + userNotes.map(NotesListItem.user)
            if let item = all.first(where: { $0.id == id }) {
                NoteDetailCard(item: item, editAction: { editingItem = id })
                    .padding()
                    .navigationBarTitleDisplayMode(.inline)
                    .sheet(isPresented: Binding(get: { editingItem == id }, set: { if !$0 { editingItem = nil } })) {
                        NavigationStack { NoteEditorView(item: item) }
                    }
            } else {
                ContentUnavailableView("Note Deleted", systemImage: "trash")
            }
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}
