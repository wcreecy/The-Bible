import Foundation

/// Curated Home arrangements that people can apply and then continue to customize.
enum HomeLayoutPreset: CaseIterable, Identifiable, Equatable {
    case reading
    case study
    case dailyPractice
    case minimal

    var id: Self { self }

    var title: String {
        switch self {
        case .reading: return "Reading"
        case .study: return "Study"
        case .dailyPractice: return "Daily Practice"
        case .minimal: return "Minimal"
        }
    }

    var detail: String {
        switch self {
        case .reading: return "Pick up reading and stay consistent."
        case .study: return "Study tools, saved verses, and quick search."
        case .dailyPractice: return "A focused daily rhythm of reading, prayer, and challenges."
        case .minimal: return "Just the essentials."
        }
    }

    var systemImage: String {
        switch self {
        case .reading: return "book.pages"
        case .study: return "text.book.closed"
        case .dailyPractice: return "sun.max"
        case .minimal: return "rectangle.compress.vertical"
        }
    }

    /// The preferred top-to-bottom card order. Unlisted cards remain available in Customize Layout.
    var preferredOrder: [HomeCardID] {
        switch self {
        case .reading:
            [.verseOfDay, .resumeReading, .streaks, .dailyFocus, .savedVerses]
        case .study:
            [.verseOfDay, .study, .search, .resumeReading, .savedVerses]
        case .dailyPractice:
            [.verseOfDay, .resumeReading, .timer, .search, .dailyFocus, .today]
        case .minimal:
            [.resumeReading, .search]
        }
    }

    func visibleCards(usesDashboard: Bool) -> Set<HomeCardID> {
        if usesDashboard && self == .minimal {
            // iPad's existing minimal dashboard replaces all cards with its focused actions.
            return []
        }

        return Set(preferredOrder)
    }

    var showsTodayReadingPanel: Bool {
        self == .reading || self == .study
    }

    /// The curated three-column arrangement used on iPad. Hidden cards remain in the
    /// layout so people can reveal and customize them later.
    var dashboardColumns: HomeColumnLayout {
        let readerColumn: HomeColumn? = showsTodayReadingPanel ? .right : nil
        var layout: HomeColumnLayout

        switch self {
        case .reading:
            layout = HomeColumnLayout(
                left: [.verseOfDay, .resumeReading],
                middle: [.streaks, .dailyFocus],
                right: [],
                verseOfDayWidth: .allColumns
            )
        case .study:
            layout = HomeColumnLayout(
                left: [.verseOfDay, .study, .search],
                middle: [.resumeReading, .savedVerses],
                right: [],
                verseOfDayWidth: .leftTwoColumns
            )
        case .dailyPractice:
            layout = HomeColumnLayout(
                left: [.verseOfDay, .resumeReading, .timer],
                middle: [.search, .dailyFocus],
                right: [.today],
                verseOfDayWidth: .allColumns
            )
        case .minimal:
            layout = HomeColumnLayout(left: [], middle: [], right: [])
        }

        return layout.normalized(avoiding: readerColumn)
    }

    func orderedCards() -> [HomeCardID] {
        preferredOrder + HomeCardID.allCases.filter { !preferredOrder.contains($0) }
    }
}
