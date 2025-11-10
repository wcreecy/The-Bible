import Foundation
import SwiftData

// Lightweight value used by views/helpers.
// We persist its pieces as primitive fields on JournalEntry (below).
public struct VerseRef: Codable, Hashable, Sendable {
    public var book: String
    public var chapter: Int
    public var verse: Int
    public var translation: String?  // e.g., "KJV", "NKJV"

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
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    var title: String
    var body: String
    
    // Verse reference persisted as primitives (no transformables)
    var verseBook: String?
    var verseChapter: Int?
    var verseNumber: Int?
    var verseTranslation: String?
    
    // Other metadata
    var tags: [String]
    var isPinned: Bool
    var isFavorite: Bool
    var isArchived: Bool
    
    // MARK: - Computed convenience accessor (not used in init())
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
    
    // MARK: - Designated initializer required by @Model
    init() {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.title = ""
        self.body = ""
        self.verseBook = nil
        self.verseChapter = nil
        self.verseNumber = nil
        self.verseTranslation = nil
        self.tags = []
        self.isPinned = false
        self.isFavorite = false
        self.isArchived = false
    }
    
    // MARK: - Convenience initializer used by your UI code
    convenience init(
        title: String = "",
        body: String = "",
        verseRef: VerseRef? = nil,
        tags: [String] = [],
        isPinned: Bool = false,
        isFavorite: Bool = false,
        isArchived: Bool = false
    ) {
        self.init()
        self.title = title
        self.body = body
        self.tags = tags
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        
        if let ref = verseRef {
            self.verseBook = ref.book
            self.verseChapter = ref.chapter
            self.verseNumber = ref.verse
            self.verseTranslation = ref.translation
        }
    }
}
