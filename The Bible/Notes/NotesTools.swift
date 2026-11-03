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
                details.append(String(localized: "\(String(localized: color.name)) highlight"))
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
