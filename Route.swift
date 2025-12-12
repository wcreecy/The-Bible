import Foundation

// Central app navigation routes
enum Route: Hashable {
    case book(Book)
    case chapter(book: Book, chapter: Chapter)
    case reader(book: Book, chapter: Chapter, startVerse: Int)

    // Games
    case gameQuiz
    case gameBeatTheClock
    case gameReferenceMatch
    case gameBookOrder
    case gameHangman
    case gameWhoAmI
}
