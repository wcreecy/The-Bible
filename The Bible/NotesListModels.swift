import SwiftData
import SwiftUI

enum NotesTabSort: String, CaseIterable, Identifiable {
    case modified
    case created
    case title
    case tag
    case color

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .modified: "Date Modified"
        case .created: "Date Created"
        case .title: "Title"
        case .tag: "Tag"
        case .color: "Highlight Color"
        }
    }

    var systemImage: String {
        switch self {
        case .modified: "pencil"
        case .created: "calendar"
        case .title: "textformat"
        case .tag: "tag"
        case .color: "highlighter"
        }
    }

    /// Dates read most naturally newest-first; text-based fields read A–Z.
    var defaultAscending: Bool {
        switch self {
        case .modified, .created: false
        case .title, .tag, .color: true
        }
    }

    func orderTitle(ascending: Bool) -> LocalizedStringResource {
        switch self {
        case .modified, .created: ascending ? "Oldest First" : "Newest First"
        case .title, .tag: ascending ? "A–Z" : "Z–A"
        case .color: ascending ? "Ascending" : "Descending"
        }
    }
}

enum NotesFilter: String, CaseIterable, Identifiable {
    case all
    case sermon
    case personal
    case scripture

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .all: "All"
        case .sermon: "Sermon"
        case .personal: "Personal"
        case .scripture: "Scripture"
        }
    }

    func libraryTitle(noteCount: Int) -> LocalizedStringKey {
        switch self {
        case .all: "All Notes (\(noteCount))"
        case .sermon: "Sermon Notes (\(noteCount))"
        case .personal: "Personal Notes (\(noteCount))"
        case .scripture: "Scripture Notes (\(noteCount))"
        }
    }
}

enum NotesListItem: Identifiable {
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

    var preview: String {
        let content: String
        switch self {
        case .scripture(let note): content = note.content
        case .user(let note): content = note.content
        }
        return content
            .components(separatedBy: .newlines)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    var highlightColor: String {
        switch self {
        case .scripture(let note): note.highlightColor
        case .user: ""
        }
    }

    var reference: String? {
        switch self {
        case .scripture(let note):
            "\(note.bookName) \(note.chapterNumber):\(note.verseNumber)"
        case .user:
            nil
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

    var isFavorite: Bool {
        switch self {
        case .scripture(let note): note.isFavorite
        case .user(let note): note.isFavorite
        }
    }

    /// Whether the entry has written content, as opposed to being a verse highlight only.
    var hasNoteText: Bool {
        switch self {
        case .scripture(let note): !note.title.isEmpty || !note.content.isEmpty
        case .user: true
        }
    }

    /// Scripture notes with a highlight keep the highlight when their note is deleted,
    /// matching the editor's "Remove Note" behavior. Highlight-only entries remove the highlight.
    var deleteTitle: LocalizedStringResource {
        guard !highlightColor.isEmpty else { return "Delete" }
        return hasNoteText ? "Delete Note" : "Remove Highlight"
    }

    var shareText: String {
        switch self {
        case .scripture(let note):
            let title = note.title.isEmpty ? "Scripture Note" : note.title
            return "\(title)\n\(note.bookName) \(note.chapterNumber):\(note.verseNumber)\n\n\(note.verseText)\n\n\(note.content)"
        case .user(let note):
            let title = note.title.isEmpty ? "Untitled Note" : note.title
            return "\(title)\n\n\(note.content)"
        }
    }

    func toggleFavorite() {
        switch self {
        case .scripture(let note): note.isFavorite.toggle()
        case .user(let note): note.isFavorite.toggle()
        }
    }

    func openInBible() {
        guard case .scripture(let note) = self else { return }
        NotificationCenter.default.post(name: .openBibleReference, object: nil, userInfo: [
            "book": note.bookName,
            "chapter": note.chapterNumber,
            "verse": note.verseNumber
        ])
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

enum NotesHighlightFilter: String, CaseIterable, Identifiable {
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

    var highlightColor: VerseHighlightColor? {
        VerseHighlightColor(rawValue: rawValue)
    }
}

extension NotesFilter {
    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
        case .sermon: "person.wave.2"
        case .personal: "person.crop.circle"
        case .scripture: "book.closed"
        }
    }
}

extension NotesFilter {
    var noteCategory: NoteCategory? {
        switch self {
        case .all: nil
        case .sermon: .sermon
        case .personal: .personal
        case .scripture: .scripture
        }
    }
}

enum DeletedNoteSnapshot {
    case scripture(VerseNoteSnapshot, wasSelected: Bool)
    case user(UserNoteSnapshot, wasSelected: Bool)
    /// The note's text was cleared but the entry was kept for its verse highlight.
    case scriptureText(VerseNote, VerseNoteSnapshot)
}

struct VerseNoteSnapshot {
    let title: String
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String
    let content: String
    let formattedContent: Data?
    let highlightColor: String
    let categoryRawValue: String
    let isFavorite: Bool
    let createdAt: Date?
    let updatedAt: Date?

    init(note: VerseNote) {
        title = note.title
        bookName = note.bookName
        chapterNumber = note.chapterNumber
        verseNumber = note.verseNumber
        verseText = note.verseText
        content = note.content
        formattedContent = note.formattedContent
        highlightColor = note.highlightColor
        categoryRawValue = note.categoryRawValue
        isFavorite = note.isFavorite
        createdAt = note.createdAt
        updatedAt = note.updatedAt
    }

    func makeNote() -> VerseNote {
        let note = VerseNote()
        note.title = title
        note.bookName = bookName
        note.chapterNumber = chapterNumber
        note.verseNumber = verseNumber
        note.verseText = verseText
        note.content = content
        note.formattedContent = formattedContent
        note.highlightColor = highlightColor
        note.categoryRawValue = categoryRawValue
        note.isFavorite = isFavorite
        note.createdAt = createdAt
        note.updatedAt = updatedAt
        return note
    }

    func restoreText(to note: VerseNote) {
        note.title = title
        note.content = content
        note.formattedContent = formattedContent
        note.updatedAt = updatedAt
    }
}

struct UserNoteSnapshot {
    let title: String
    let content: String
    let formattedContent: Data?
    let categoryRawValue: String
    let isFavorite: Bool
    let createdAt: Date?
    let updatedAt: Date?

    init(note: UserNote) {
        title = note.title
        content = note.content
        formattedContent = note.formattedContent
        categoryRawValue = note.categoryRawValue
        isFavorite = note.isFavorite
        createdAt = note.createdAt
        updatedAt = note.updatedAt
    }

    func makeNote() -> UserNote {
        let note = UserNote()
        note.title = title
        note.content = content
        note.formattedContent = formattedContent
        note.categoryRawValue = categoryRawValue
        note.isFavorite = isFavorite
        note.createdAt = createdAt
        note.updatedAt = updatedAt
        return note
    }
}
