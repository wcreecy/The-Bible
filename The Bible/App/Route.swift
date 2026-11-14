import Foundation

// Central app navigation routes
enum Route: Hashable {
    case book(Book)
    case reader(book: Book, chapter: Chapter, startVerse: Int)
    case search
    case study(AppRouter.StudyDestination?)
    case readingPlans
    case readingPlan(id: String)
    case readingPlanDay(planID: String, day: Int)
    case customReadingPlanBuilder
}

struct BibleReaderLocation: Hashable {
    /// Each request is distinct, so opening the same passage twice still opens it.
    let id = UUID()
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
}
