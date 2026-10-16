import SwiftData
import Foundation

enum NoteCategory: String, CaseIterable, Identifiable {
    case sermon
    case personal
    case scripture
    case chapterInsights

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .sermon: "Sermon Notes"
        case .personal: "Personal Notes"
        case .scripture: "Scripture Notes"
        case .chapterInsights: "Chapter Insights"
        }
    }

    /// The short form used on list rows and filter chips.
    var shortTitle: LocalizedStringResource {
        switch self {
        case .sermon: "Sermon"
        case .personal: "Personal"
        case .scripture: "Scripture"
        case .chapterInsights: "Chapter Insights"
        }
    }
}

@Model
final class VerseNote {
    var title: String = ""
    var bookName: String = ""
    var chapterNumber: Int = 0
    var verseNumber: Int = 0
    /// The last verse of a multi-verse note; 0 (or `verseNumber`) means a single verse.
    var endVerseNumber: Int = 0
    var verseText: String = ""
    var content: String = ""
    /// Encoded `AttributedString` data. `content` remains the searchable plain-text copy.
    var formattedContent: Data?
    /// Raw value of `VerseHighlightColor`. An empty value means no highlight.
    var highlightColor: String = ""
    var categoryRawValue: String = NoteCategory.scripture.rawValue
    var isFavorite: Bool = false
    // Optionals for CloudKit schema
    var createdAt: Date?
    var updatedAt: Date?

    init() {
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    convenience init(
        bookName: String,
        chapterNumber: Int,
        verseNumber: Int,
        verseText: String,
        content: String = "",
        highlightColor: String = ""
    ) {
        self.init()
        self.bookName = bookName
        self.chapterNumber = chapterNumber
        self.verseNumber = verseNumber
        self.verseText = verseText
        self.content = content
        self.highlightColor = highlightColor
    }

    /// The note's last verse, whether it covers one verse or several.
    var lastVerseNumber: Int { max(verseNumber, endVerseNumber) }

    /// "John 3:16", or "John 3:16–18" for a note on several verses.
    var reference: String {
        let start = "\(bookName) \(chapterNumber):\(verseNumber)"
        return lastVerseNumber > verseNumber ? "\(start)–\(lastVerseNumber)" : start
    }

    /// Whether the note covers the given verse.
    func covers(bookName: String, chapterNumber: Int, verseNumber: Int) -> Bool {
        self.bookName == bookName && self.chapterNumber == chapterNumber &&
            (self.verseNumber...lastVerseNumber).contains(verseNumber)
    }
}

@Model
final class UserNote {
    var title: String = ""
    var content: String = ""
    /// Encoded `AttributedString` data. `content` remains the searchable plain-text copy.
    var formattedContent: Data?
    var categoryRawValue: String = NoteCategory.personal.rawValue
    /// The chapter this reflection came from. Empty/zero means a regular personal note.
    var sourceBookName: String = ""
    var sourceChapterNumber: Int = 0
    /// A passage the note is about, such as a sermon's text ("John 3:1-21"). Empty means none.
    var passageReference: String = ""
    /// Sermon details; empty for other kinds of notes.
    var sermonSpeaker: String = ""
    var sermonLocation: String = ""
    var sermonDate: Date?
    var isFavorite: Bool = false
    // Optionals keep the model compatible with the app's CloudKit-backed store.
    var createdAt: Date?
    var updatedAt: Date?

    init() {
        createdAt = Date()
        updatedAt = Date()
    }

    /// Whether this is a Chapter Insights reflection that can open its source chapter.
    var hasSourceChapter: Bool { !sourceBookName.isEmpty && sourceChapterNumber > 0 }
}
