import Foundation
import Testing
@testable import Bible

@MainActor
struct HomeColumnLayoutTests {
    @Test
    func seedingMatchesTheOldDashboardPlacement() {
        // The iPad default: Verse of the Day spanned the top, then visible cards filled
        // the grid row by row starting on the left.
        let layout = HomeColumnLayout.seeded(
            from: [.verseOfDay, .today, .study, .streaks, .timer, .dailyFocus, .resumeReading, .search, .bibleStats],
            hidden: [.resumeReading, .search, .bibleStats]
        )

        let visibleLeft = layout.left.filter { ![.resumeReading, .search, .bibleStats].contains($0) }
        let visibleRight = layout.right.filter { ![.resumeReading, .search, .bibleStats].contains($0) }
        #expect(visibleLeft == [.verseOfDay, .today, .streaks, .dailyFocus])
        #expect(visibleRight == [.study, .timer])
        #expect(Set(layout.left + layout.right) == Set(HomeCardID.allCases))
    }

    @Test
    func normalizingRemovesDuplicatesAndAddsMissingCards() {
        let layout = HomeColumnLayout(left: [.study, .study, .timer], right: [.timer]).normalized()

        let all = layout.left + layout.right
        #expect(all.count == HomeCardID.allCases.count)
        #expect(Set(all) == Set(HomeCardID.allCases))
        #expect(layout.left.prefix(2) == [.study, .timer])
    }

    @Test
    func movingCardsBetweenAndWithinColumns() {
        var layout = HomeColumnLayout(left: [.verseOfDay, .today, .streaks], right: [.study, .timer]).normalized()

        // Slides straight across at the same row.
        layout.moveToOtherColumn(.streaks)
        #expect(layout.left.prefix(2) == [.verseOfDay, .today])
        #expect(layout.right.prefix(3) == [.study, .timer, .streaks])

        layout.moveToOtherColumn(.study)
        #expect(layout.left.prefix(3) == [.study, .verseOfDay, .today])

        layout.move(.verseOfDay, by: -1)
        #expect(layout.left.prefix(2) == [.verseOfDay, .study])
        #expect(!layout.canMove(.verseOfDay, by: -1))

        // A move past either end changes nothing.
        let before = layout
        layout.move(.verseOfDay, by: -1)
        #expect(layout == before)
    }

    @Test
    func flatOrderReadsRowByRowForNarrowWidths() {
        let layout = HomeColumnLayout(left: [.verseOfDay, .today, .streaks], right: [.study])
        #expect(layout.flatOrder == [.verseOfDay, .study, .today, .streaks])
    }

    @Test
    func storageRoundTripsAndRejectsInvalidData() {
        let layout = HomeColumnLayout.seeded(from: HomeCardID.allCases, hidden: [])
        #expect(HomeColumnLayout(storageString: layout.storageString) == layout)
        #expect(HomeColumnLayout(storageString: "") == nil)
        #expect(HomeColumnLayout(storageString: "not json") == nil)

        // Unknown card names from a newer version are dropped, and the rest still load.
        let decoded = HomeColumnLayout(storageString: #"{"left":["study","futureCard"],"right":["timer"]}"#)
        #expect(decoded?.left.first == .study)
        #expect(decoded?.right.first == .timer)
    }
}
