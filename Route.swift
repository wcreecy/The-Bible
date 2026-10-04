import Foundation

// Central app navigation routes
enum Route: Hashable {
    case book(Book)
    case chapter(book: Book, chapter: Chapter)
    case reader(book: Book, chapter: Chapter, startVerse: Int)
    case search

    // Games
    case gameQuiz
    case gameBeatTheClock
    case gameVerseMatch
    case gameBookOrder
    case gameHangman
    case gameWhoAmI
    case gameWordle // NEW
}

struct BibleReaderLocation: Hashable {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
}

enum DeviceReaderPositionStore {
    private static let bookKey = "readerPositionBook"
    private static let chapterKey = "readerPositionChapter"
    private static let verseKey = "readerPositionVerse"

    static func load(defaults: UserDefaults = .standard) -> BibleReaderLocation? {
        guard let bookName = defaults.string(forKey: bookKey), !bookName.isEmpty else {
            return nil
        }

        let chapterNumber = defaults.integer(forKey: chapterKey)
        let verseNumber = defaults.integer(forKey: verseKey)
        guard chapterNumber > 0, verseNumber > 0 else { return nil }

        return BibleReaderLocation(
            bookName: bookName,
            chapterNumber: chapterNumber,
            verseNumber: verseNumber
        )
    }

    static func save(_ location: BibleReaderLocation, defaults: UserDefaults = .standard) {
        defaults.set(location.bookName, forKey: bookKey)
        defaults.set(location.chapterNumber, forKey: chapterKey)
        defaults.set(location.verseNumber, forKey: verseKey)
    }
}
