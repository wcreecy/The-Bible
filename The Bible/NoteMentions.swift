import SwiftData
import SwiftUI

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
