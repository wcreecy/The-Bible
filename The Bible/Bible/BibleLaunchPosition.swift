import Foundation

/// Where the Bible tab opens when the app launches on it: the Continue Reading place, or
/// Genesis 1:1 when nothing is saved or the saved place isn't in the loaded Bible.
struct BibleLaunchPosition {
    let book: Book
    let chapter: Chapter
    let verse: Int

    var location: BibleReaderLocation {
        BibleReaderLocation(bookName: book.name, chapterNumber: chapter.number, verseNumber: verse)
    }

    /// Nil only when `books` is empty, such as when the Bible text failed to load.
    static func resolve(in books: [Book], saved: BibleReaderLocation?) -> BibleLaunchPosition? {
        if let saved,
           let book = books.first(where: { $0.name == saved.bookName }),
           let chapter = book.chapters.first(where: { $0.number == saved.chapterNumber }),
           let verse = chapter.verses.first(where: { $0.number == saved.verseNumber })?.number {
            return BibleLaunchPosition(book: book, chapter: chapter, verse: verse)
        }

        guard let genesis = books.first(where: { $0.name == "Genesis" }) ?? books.first,
              let firstChapter = genesis.chapters.first(where: { $0.number == 1 }) ?? genesis.chapters.first
        else { return nil }
        return BibleLaunchPosition(book: genesis, chapter: firstChapter, verse: 1)
    }
}
