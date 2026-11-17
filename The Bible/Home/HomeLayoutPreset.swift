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
        case .reading: return "Pick up where you left off and keep your plan on track."
        case .study: return "Prepare a chapter, study with a timer, and keep what you find."
        case .dailyPractice: return "A daily rhythm of Scripture, prayer, and small steps."
        case .minimal: return "Today's verse and your place in the Bible."
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
            // Reading first: the plan and your place lead, the verse follows.
            [.readingPlan, .resumeReading, .verseOfDay, .streaks, .savedVerses]
        case .study:
            [.study, .resumeReading, .savedVerses, .timer, .verseOfDay]
        case .dailyPractice:
            // Built around the day: the verse, the checklist, the plan, then prayer and the day's intention.
            [.verseOfDay, .today, .readingPlan, .timer, .dailyFocus, .streaks]
        case .minimal:
            [.verseOfDay, .resumeReading]
        }
    }

    func visibleCards(usesDashboard: Bool) -> Set<HomeCardID> {
        if usesDashboard && self == .minimal {
            // iPad's existing minimal dashboard replaces all cards with its focused actions.
            return []
        }

        return Set(preferredOrder)
    }

    /// The curated three-column arrangement used on iPad, balanced so the columns end at
    /// about the same height (Your Progress is much the tallest card, so it stands alone).
    /// Hidden cards remain in the layout so people can reveal and customize them later.
    var dashboardColumns: HomeColumnLayout {
        var layout: HomeColumnLayout

        switch self {
        case .reading:
            layout = HomeColumnLayout(
                left: [.readingPlan, .savedVerses],
                middle: [.resumeReading, .verseOfDay],
                right: [.streaks],
                verseOfDayWidth: .oneColumn
            )
        case .study:
            layout = HomeColumnLayout(
                left: [.study],
                middle: [.resumeReading, .verseOfDay],
                right: [.timer, .savedVerses],
                verseOfDayWidth: .oneColumn
            )
        case .dailyPractice:
            layout = HomeColumnLayout(
                left: [.verseOfDay, .today, .timer],
                middle: [.readingPlan, .dailyFocus],
                right: [.streaks],
                verseOfDayWidth: .allColumns
            )
        case .minimal:
            layout = HomeColumnLayout(left: [], middle: [], right: [])
        }

        return layout.normalized()
    }

    func orderedCards() -> [HomeCardID] {
        preferredOrder + HomeCardID.allCases.filter { !preferredOrder.contains($0) }
    }
}
