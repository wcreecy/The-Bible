import Foundation
import Observation

/// App-wide navigation requests: switching tabs, opening a verse, Stats, and so on.
///
/// Any code can ask the router to go somewhere with `open(_:)`, including code outside
/// views such as the app delegate or stores. `ContentView` performs every request; a
/// few screens also watch `latest` to react, for example a sheet that closes when the
/// app navigates elsewhere.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    enum StatsPage: String {
        case reading = "Reading Stats"
        case games = "Game Stats"
    }

    enum StudyDestination: Equatable, Hashable {
        case bookOverview(bookName: String)
        case chapterInsights(bookName: String, chapterNumber: Int)
    }

    enum Destination: Equatable {
        case tab(AppTab)
        case favorites
        case settings
        case stats(StatsPage)
        /// Opens the reader at a verse, switching to the Bible tab.
        case bibleReference(BibleReaderLocation)
        case bibleSearch
        case bibleStudy
        case bibleStudyDestination(StudyDestination)
        /// The person opened a Verse of the Day notification.
        case verseOfDayNotification
        /// A scripture link was tapped while a note editor is open.
        case scripturePreview(URL)
        /// Starts the game stored in `GameLaunchRequest`.
        case gameStart
        /// Reading plans in the Home tab: one plan when an ID is given, otherwise all of them.
        case readingPlan(String?)
        /// A plan reading in the Bible tab's reader, with its plan and day behind it.
        case readingPlanReading(planID: String, day: Int, location: BibleReaderLocation)
        /// A plan day, back from the reader when it's open behind it.
        case readingPlanDay(planID: String, day: Int)
        /// The custom plan builder in the Home tab, with a book chosen.
        case readingPlanBuilder(book: String?)
        /// A reading plan screen in the Bible tab, such as from a book's Study page, so Back
        /// returns to the Bible tab.
        case readingPlanInBible(Route)

        /// The tab this destination lives in, or nil when it doesn't change tabs.
        var targetTab: AppTab? {
            switch self {
            case .tab(let tab): tab
            case .favorites, .settings, .stats: .more
            case .bibleReference, .bibleSearch, .bibleStudy, .bibleStudyDestination: .bible
            case .gameStart: .games
            case .readingPlan: .home
            case .readingPlanReading: .bible
            case .readingPlanDay: nil
            case .readingPlanBuilder: .home
            case .readingPlanInBible: .bible
            case .verseOfDayNotification, .scripturePreview: nil
            }
        }
    }

    /// One request. Each has its own ID, so asking for the same destination twice
    /// still counts as a new request.
    struct Request: Equatable, Identifiable {
        let id = UUID()
        let destination: Destination
    }

    /// The most recent request.
    private(set) var latest: Request?

    private init() {}

    func open(_ destination: Destination) {
        latest = Request(destination: destination)
    }

    /// Opens the reader at `book chapter:verse`.
    func openBibleReference(book: String, chapter: Int, verse: Int) {
        open(.bibleReference(BibleReaderLocation(bookName: book, chapterNumber: chapter, verseNumber: verse)))
    }
}
