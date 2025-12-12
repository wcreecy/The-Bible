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
    // Core (optionals for CloudKit schema)
    var uuid: UUID?
    var createdAt: Date?
    var updatedAt: Date?
    var title: String = ""
    var body: String = ""

    // Verse reference persisted as primitives
    var verseBook: String? = nil
    var verseChapter: Int? = nil
    var verseNumber: Int? = nil
    var verseTranslation: String? = nil

    // Other metadata
    // Persist tags in a CloudKit-safe way: a single comma-separated string.
    var tagsRaw: String = ""
    var isPinned: Bool = false
    var isFavorite: Bool = false
    var isArchived: Bool = false

    // NEW: Draft flag so autosaves of new entries don’t look “final” until Save is tapped.
    var isDraft: Bool = false

    // Computed convenience API so the rest of the app still uses [String]
    var tags: [String] {
        get {
            tagsRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        set {
            let normalized = newValue
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            tagsRaw = normalized.joined(separator: ",")
        }
    }

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

    init() {
        self.uuid = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
