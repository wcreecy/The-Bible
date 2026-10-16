import SwiftData
import SwiftUI

/// Parses custom tags from note text. Tags begin with # and may contain letters,
/// numbers, or underscores; matching is case-insensitive.
nonisolated enum NoteCustomTags {
    static func tags(in text: String) -> [String] {
        Set(ranges(in: text).map { range in
            String(text[text.index(after: range.lowerBound)..<range.upperBound]).lowercased()
        })
        .sorted {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    /// The range of each tag in `text`, including its leading "#".
    static func ranges(in text: String) -> [Range<String.Index>] {
        var tagRanges: [Range<String.Index>] = []
        var index = text.startIndex

        while index < text.endIndex {
            guard text[index] == "#" else {
                index = text.index(after: index)
                continue
            }

            if index != text.startIndex {
                let precedingCharacter = text[text.index(before: index)]
                guard !isTagCharacter(precedingCharacter) else {
                    index = text.index(after: index)
                    continue
                }
            }

            let tagStart = text.index(after: index)
            guard tagStart < text.endIndex, isTagCharacter(text[tagStart]) else {
                index = tagStart
                continue
            }

            var tagEnd = tagStart
            while tagEnd < text.endIndex, isTagCharacter(text[tagEnd]) {
                tagEnd = text.index(after: tagEnd)
            }

            tagRanges.append(index..<tagEnd)
            index = tagEnd
        }

        return tagRanges
    }

    static func normalizedSearchTag(from searchText: String) -> String? {
        let trimmedText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.first == "#" else { return nil }

        let tag = trimmedText.dropFirst()
        guard !tag.isEmpty, tag.allSatisfy(isTagCharacter) else { return nil }
        return String(tag).lowercased()
    }

    /// A tag name as typed, lowercased without its "#", or nil when it isn't a valid tag.
    static func normalizedTag(_ name: String) -> String? {
        var trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.first == "#" { trimmed.removeFirst() }
        guard !trimmed.isEmpty, trimmed.allSatisfy(isTagCharacter) else { return nil }
        return trimmed.lowercased()
    }

    /// The partial tag being typed just before `offset`, without its "#" (possibly empty),
    /// or nil when the caret isn't in a tag.
    static func partialTag(in text: String, endingAt offset: Int) -> (range: Range<String.Index>, prefix: String)? {
        guard offset > 0, offset <= text.count else { return nil }
        let end = text.index(text.startIndex, offsetBy: offset)
        var start = end
        while start > text.startIndex, isTagCharacter(text[text.index(before: start)]) {
            start = text.index(before: start)
        }
        guard start > text.startIndex else { return nil }
        let hash = text.index(before: start)
        guard text[hash] == "#" else { return nil }
        if hash > text.startIndex, isTagCharacter(text[text.index(before: hash)]) { return nil }
        if end < text.endIndex, isTagCharacter(text[end]) { return nil }
        return (hash..<end, String(text[start..<end]).lowercased())
    }

    /// Replaces every occurrence of `tag` with `#replacement`, or with the bare word when
    /// `replacement` is nil (removing the tag but keeping the word).
    static func renaming(_ tag: String, to replacement: String?, in text: String) -> String {
        var result = text
        for range in ranges(in: text).reversed() where isTag(range, in: text, named: tag) {
            let word = text[text.index(after: range.lowerBound)..<range.upperBound]
            result.replaceSubrange(range, with: replacement.map { "#\($0)" } ?? String(word))
        }
        return result
    }

    /// The same change as `renaming(_:to:in:)`, keeping the rest of the formatting.
    static func renaming(_ tag: String, to replacement: String?, in text: AttributedString) -> AttributedString {
        let plain = String(text.characters)
        var result = text
        for range in ranges(in: plain).reversed() where isTag(range, in: plain, named: tag) {
            let word = plain[plain.index(after: range.lowerBound)..<range.upperBound]
            guard let lower = AttributedString.Index(range.lowerBound, within: result),
                  let upper = AttributedString.Index(range.upperBound, within: result) else { continue }
            let attributes = result[lower..<upper].runs.first?.attributes ?? AttributeContainer()
            result.replaceSubrange(
                lower..<upper,
                with: AttributedString(replacement.map { "#\($0)" } ?? String(word), attributes: attributes)
            )
        }
        return result
    }

    private static func isTag(_ range: Range<String.Index>, in text: String, named tag: String) -> Bool {
        text[text.index(after: range.lowerBound)..<range.upperBound].lowercased() == tag
    }

    static func isTagCharacter(_ character: Character) -> Bool {
        !character.unicodeScalars.isEmpty &&
            character.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.contains($0) || $0.value == 95
            }
    }
}

enum NotesTabSort: String, CaseIterable, Identifiable {
    case modified
    case created
    case title
    /// Sorts by the note's type. The raw value stays "tag" so saved preferences carry over.
    case tag
    /// By the note's passage, Genesis to Revelation, then chapter and verse.
    case bibleOrder

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .modified: "Date Modified"
        case .created: "Date Created"
        case .title: "Title"
        case .tag: "Type"
        case .bibleOrder: "Bible Order"
        }
    }

    var systemImage: String {
        switch self {
        case .modified: "pencil"
        case .created: "calendar"
        case .title: "textformat"
        case .tag: "square.stack"
        case .bibleOrder: "book"
        }
    }

    /// Dates read most naturally newest-first; text-based fields read A–Z.
    var defaultAscending: Bool {
        switch self {
        case .modified, .created: false
        case .title, .tag, .bibleOrder: true
        }
    }

    func orderTitle(ascending: Bool) -> LocalizedStringResource {
        switch self {
        case .modified, .created: ascending ? "Oldest First" : "Newest First"
        case .title, .tag: ascending ? "A–Z" : "Z–A"
        case .bibleOrder: ascending ? "Genesis to Revelation" : "Revelation to Genesis"
        }
    }
}

/// Filters notes by their type (category).
enum NotesFilter: String, CaseIterable, Identifiable {
    case all
    case sermon
    case personal
    case scripture
    case chapterInsights

    var id: String { rawValue }

    var title: LocalizedStringResource {
        noteCategory?.shortTitle ?? "All"
    }

    /// The list heading for this filter: "All Notes" or the type's full name.
    var libraryTitle: LocalizedStringResource {
        noteCategory?.title ?? "All Notes"
    }

    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
        case .sermon: "person.wave.2"
        case .personal: "person.crop.circle"
        case .scripture: "book.closed"
        case .chapterInsights: "text.book.closed"
        }
    }

    var noteCategory: NoteCategory? {
        switch self {
        case .all: nil
        case .sermon: .sermon
        case .personal: .personal
        case .scripture: .scripture
        case .chapterInsights: .chapterInsights
        }
    }
}

/// One entry on the Notes page: a verse note (or highlight) or a personal note.
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
            note.title.isEmpty ? note.reference : note.title
        case .user(let note):
            note.title.isEmpty ? String(localized: "Untitled Note") : note.title
        }
    }

    var category: NoteCategory? {
        NoteCategory(rawValue: categoryRawValue)
    }

    var categoryRawValue: String {
        switch self {
        case .scripture(let note): note.categoryRawValue
        case .user(let note): note.categoryRawValue
        }
    }

    var content: String {
        switch self {
        case .scripture(let note): note.content
        case .user(let note): note.content
        }
    }

    var formattedContent: Data? {
        switch self {
        case .scripture(let note): note.formattedContent
        case .user(let note): note.formattedContent
        }
    }

    /// Custom tags written in the title or body.
    var customTags: [String] {
        let rawTitle: String
        switch self {
        case .scripture(let note): rawTitle = note.title
        case .user(let note): rawTitle = note.title
        }
        return Array(Set(NoteCustomTags.tags(in: rawTitle) + NoteCustomTags.tags(in: content))).sorted()
    }

    var preview: String {
        content
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

    /// The verse or verses a Scripture note is attached to.
    var reference: String? {
        switch self {
        case .scripture(let note): note.reference
        case .user: nil
        }
    }

    /// The passage shown with the note: a Scripture note's verses or a personal note's passage.
    var passage: String? {
        switch self {
        case .scripture(let note): note.reference
        case .user(let note): note.passageReference.isEmpty ? nil : note.passageReference
        }
    }

    /// The passage for a list row, left out when the title already is the passage (an
    /// untitled Scripture note is titled with its reference).
    var rowPassage: String? {
        passage == title ? nil : passage
    }

    /// Where "Open in Bible" goes: the note's verse, or the start of a personal note's passage.
    var bibleLocation: ScriptureRef? {
        switch self {
        case .scripture(let note):
            ScriptureRef(
                bookName: note.bookName,
                chapter: note.chapterNumber,
                startVerse: note.verseNumber,
                endVerse: note.lastVerseNumber > note.verseNumber ? note.lastVerseNumber : nil
            )
        case .user(let note):
            BibleReferenceLinker.parse(note.passageReference)
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
            let title = note.title.isEmpty ? String(localized: "Scripture Note") : note.title
            return "\(title)\n\(note.reference)\n\n\(note.verseText)\n\n\(note.content)"
        case .user(let note):
            var lines = [title]
            lines += sermonDetailLines(for: note)
            if !note.passageReference.isEmpty { lines.append(note.passageReference) }
            return lines.joined(separator: "\n") + "\n\n" + note.content
        }
    }

    /// Sermon speaker, location, and date as display lines.
    func sermonDetailLines(for note: UserNote) -> [String] {
        guard note.categoryRawValue == NoteCategory.sermon.rawValue else { return [] }
        var lines: [String] = []
        let speakerAndPlace = [note.sermonSpeaker, note.sermonLocation].filter { !$0.isEmpty }
        if !speakerAndPlace.isEmpty { lines.append(speakerAndPlace.joined(separator: " · ")) }
        if let date = note.sermonDate { lines.append(date.formatted(date: .long, time: .omitted)) }
        return lines
    }

    /// Toggles the favorite and saves, with selection feedback.
    func toggleFavorite(in context: ModelContext) {
        switch self {
        case .scripture(let note): note.isFavorite.toggle()
        case .user(let note): note.isFavorite.toggle()
        }
        context.saveLoggingErrors()
        Haptics.selection()
    }

    func openInBible() {
        guard let location = bibleLocation else { return }
        AppRouter.shared.openBibleReference(book: location.bookName, chapter: location.chapter, verse: location.startVerse)
    }

    /// Search text: matches title, body, verse text, reference, passage, and sermon details. A
    /// search that is a reference ("John 3:16", "Jn 3:16") also finds notes covering that verse,
    /// and a search that is a tag ("#prayer") matches only that tag.
    func matchesSearch(_ searchText: String, tags: [String]) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        if let searchTag = NoteCustomTags.normalizedSearchTag(from: query) {
            return tags.contains(searchTag)
        }
        if let searched = BibleReferenceLinker.parse(query), covers(searched) {
            return true
        }

        var fields = [title, content]
        switch self {
        case .scripture(let note):
            fields += [note.reference, note.verseText]
        case .user(let note):
            fields += [note.passageReference, note.sermonSpeaker, note.sermonLocation]
        }
        return fields.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    /// Whether the note's verses or passage include the start of `reference`.
    private func covers(_ reference: ScriptureRef) -> Bool {
        guard let location = bibleLocation,
              location.bookName.caseInsensitiveCompare(reference.bookName) == .orderedSame,
              location.chapter == reference.chapter else { return false }
        let last = location.endVerse ?? location.startVerse
        return (location.startVerse...last).contains(reference.startVerse)
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
    let endVerseNumber: Int
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
        endVerseNumber = note.endVerseNumber
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
        note.endVerseNumber = endVerseNumber
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
    let sourceBookName: String
    let sourceChapterNumber: Int
    let passageReference: String
    let sermonSpeaker: String
    let sermonLocation: String
    let sermonDate: Date?
    let isFavorite: Bool
    let createdAt: Date?
    let updatedAt: Date?

    init(note: UserNote) {
        title = note.title
        content = note.content
        formattedContent = note.formattedContent
        categoryRawValue = note.categoryRawValue
        sourceBookName = note.sourceBookName
        sourceChapterNumber = note.sourceChapterNumber
        passageReference = note.passageReference
        sermonSpeaker = note.sermonSpeaker
        sermonLocation = note.sermonLocation
        sermonDate = note.sermonDate
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
        note.sourceBookName = sourceBookName
        note.sourceChapterNumber = sourceChapterNumber
        note.passageReference = passageReference
        note.sermonSpeaker = sermonSpeaker
        note.sermonLocation = sermonLocation
        note.sermonDate = sermonDate
        note.isFavorite = isFavorite
        note.createdAt = createdAt
        note.updatedAt = updatedAt
        return note
    }
}
