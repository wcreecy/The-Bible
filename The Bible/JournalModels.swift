import Foundation
import SwiftData

public struct VerseRef: Codable, Hashable, Sendable {
    public var book: String
    public var chapter: Int
    public var verse: Int
    public var translation: String?

    public init(book: String, chapter: Int, verse: Int, translation: String? = nil) {
        self.book = book
        self.chapter = chapter
        self.verse = verse
        self.translation = translation
    }

    public var display: String {
        if let t = translation, !t.isEmpty {
            return "\(book) \(chapter):\(verse) (\(t))"
        }
        return "\(book) \(chapter):\(verse)"
    }
}

@Model
final class JournalEntry {
    // Core
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var title: String = ""
    var body: String = ""
    
    // Verse reference persisted as primitives
    var verseBook: String? = nil
    var verseChapter: Int? = nil
    var verseNumber: Int? = nil
    var verseTranslation: String? = nil
    
    // Other metadata
    var tags: [String] = []
    var isPinned: Bool = false
    var isFavorite: Bool = false
    var isArchived: Bool = false

    // Computed convenience
    var verseRef: VerseRef? {
        get {
            guard let b = verseBook, let c = verseChapter, let v = verseNumber else { return nil }
            return VerseRef(book: b, chapter: c, verse: v, translation: verseTranslation)
        }
        set {
            verseBook = newValue?.book
            verseChapter = newValue?.chapter
            verseNumber = newValue?.verse
            verseTranslation = newValue?.translation
        }
    }

    init() {}
}
