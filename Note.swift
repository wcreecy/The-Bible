import SwiftData
import Foundation

enum NoteCategory: String, CaseIterable, Identifiable {
    case sermon
    case personal

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .sermon: "Sermon Notes"
        case .personal: "Personal"
        }
    }
}

@Model
final class VerseNote {
    var bookName: String = ""
    var chapterNumber: Int = 0
    var verseNumber: Int = 0
    var verseText: String = ""
    var content: String = ""
    /// Encoded `AttributedString` data. `content` remains the searchable plain-text copy.
    var formattedContent: Data?
    /// Raw value of `VerseHighlightColor`. An empty value means no highlight.
    var highlightColor: String = ""
    var categoryRawValue: String = NoteCategory.sermon.rawValue
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
}

@Model
final class UserNote {
    var title: String = ""
    var content: String = ""
    /// Encoded `AttributedString` data. `content` remains the searchable plain-text copy.
    var formattedContent: Data?
    var categoryRawValue: String = NoteCategory.personal.rawValue
    // Optionals keep the model compatible with the app's CloudKit-backed store.
    var createdAt: Date?
    var updatedAt: Date?

    init() {
        createdAt = Date()
        updatedAt = Date()
    }
}
