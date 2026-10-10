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
