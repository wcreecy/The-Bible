import Foundation
import SwiftData

/// Moves saved favorites, bookmarks, and verse notes to the right verse after the bundled
/// KJV was corrected to standard numbering (six missing verses restored and four split
/// verses re-joined; see Scripts/kjv_fixes_review.md).
///
/// Records saved under the old numbering point one verse off in the chapters below. Each
/// record keeps the verse text it was saved with, so it is matched back to the verse that
/// text belongs to. This runs with deduplication whenever synced records may arrive,
/// because a device still on an older version keeps saving with the old numbering.
@MainActor
enum SavedVerseRenumberRepair {
    /// Chapters whose verse numbers changed. Revelation 12's last verse joined 13:1.
    private static let affectedChapters: [String: Set<Int>] = [
        "Matthew": [2, 22, 26],
        "Mark": [4, 7, 8],
        "1 Samuel": [20],
        "1 Kings": [22],
        "3 John": [1],
        "Revelation": [12],
    ]

    /// Saved text shorter than this is too generic to place reliably.
    private static let minimumMatchLength = 12

    /// Returns whether any record changed. Does nothing until the Bible text has loaded.
    static func run(in context: ModelContext) -> Bool {
        let books = BibleData.books
        guard !books.isEmpty else { return false }
        var changed = false

        for favorite in (try? context.fetch(FetchDescriptor<Favorite>())) ?? [] {
            if let fix = correctedLocation(book: favorite.bookName, chapter: favorite.chapterNumber, verse: favorite.verseNumber, savedText: favorite.verseText, books: books) {
                favorite.chapterNumber = fix.chapter
                favorite.verseNumber = fix.verse
                changed = true
            }
        }
        for bookmark in (try? context.fetch(FetchDescriptor<Bookmark>())) ?? [] {
            if let fix = correctedLocation(book: bookmark.bookName, chapter: bookmark.chapterNumber, verse: bookmark.verseNumber, savedText: bookmark.verseText, books: books) {
                bookmark.chapterNumber = fix.chapter
                bookmark.verseNumber = fix.verse
                changed = true
            }
        }
        for note in (try? context.fetch(FetchDescriptor<VerseNote>())) ?? [] {
            if let fix = correctedLocation(book: note.bookName, chapter: note.chapterNumber, verse: note.verseNumber, savedText: note.verseText, books: books) {
                note.chapterNumber = fix.chapter
                note.verseNumber = fix.verse
                changed = true
            }
        }
        return changed
    }

    /// The verse the saved text belongs to, or nil when the record is already right or
    /// can't be placed confidently.
    private static func correctedLocation(book: String, chapter: Int, verse: Int, savedText: String, books: [Book]) -> (chapter: Int, verse: Int)? {
        guard affectedChapters[book]?.contains(chapter) == true,
              let bookData = books.first(where: { $0.name == book }) else { return nil }
        let saved = normalized(savedText)
        guard saved.count >= minimumMatchLength else { return nil }

        // Revelation 12:18 now opens 13:1, so that search continues into chapter 13.
        let searchChapters = book == "Revelation" ? [chapter, chapter + 1] : [chapter]
        var candidates: [(chapter: Int, verse: Int, text: String)] = []
        for chapterData in bookData.chapters where searchChapters.contains(chapterData.number) {
            for verseData in chapterData.verses {
                candidates.append((chapterData.number, verseData.number, normalized(verseData.text)))
            }
        }

        // Already right: the verse at the saved number is (or now contains) the saved text.
        if let current = candidates.first(where: { $0.chapter == chapter && $0.verse == verse }),
           current.text == saved || current.text.contains(saved) {
            return nil
        }

        // Prefer an exact match, then a re-joined verse that contains the saved half,
        // choosing the one nearest the saved number.
        func distance(_ c: (chapter: Int, verse: Int, text: String)) -> Int {
            c.chapter == chapter ? abs(c.verse - verse) : 1_000 + c.verse
        }
        let match = candidates.filter { $0.text == saved }.min { distance($0) < distance($1) }
            ?? candidates.filter { $0.text.contains(saved) }.min { distance($0) < distance($1) }
        guard let match else { return nil }
        return (match.chapter, match.verse)
    }

    /// Lowercased letters and single spaces, so punctuation and markup differences don't matter.
    private static func normalized(_ text: String) -> String {
        let letters = text.lowercased().map { $0.isLetter ? $0 : " " }
        return String(letters).split(separator: " ").joined(separator: " ")
    }
}
