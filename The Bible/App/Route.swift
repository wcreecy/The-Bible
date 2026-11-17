import Foundation

// Central app navigation routes
enum Route: Hashable {
    case book(Book)
    /// `highlightsStartVerse` briefly marks `startVerse` so the eye lands on it. It's off when
    /// a chapter is picked from the chapter list, which simply opens at the top.
    /// `requestID` is the app-wide request that opened this reader (`BibleReaderLocation.id`).
    /// Each request is distinct, so asking again for the passage already open (such as the
    /// Verse of the Day, twice) opens it afresh: scrolled back to the verse and marked again.
    case reader(
        book: Book,
        chapter: Chapter,
        startVerse: Int,
        highlightsStartVerse: Bool = true,
        requestID: UUID? = nil
    )
    case search
    case study(AppRouter.StudyDestination?)
    case readingPlans
    case readingPlan(id: String)
    case readingPlanDay(planID: String, day: Int)
    case customReadingPlanBuilder(book: String?)
    case readingPlanSeries(String)
}

struct BibleReaderLocation: Hashable {
    /// Each request is distinct, so opening the same passage twice still opens it.
    let id = UUID()
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
}
