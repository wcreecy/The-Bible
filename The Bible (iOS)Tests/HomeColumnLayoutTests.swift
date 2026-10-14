import Foundation
import Testing
@testable import Bible

@MainActor
struct HomeColumnLayoutTests {
    private let defaultHidden: Set<HomeCardID> = [.resumeReading, .search, .bibleStats]

    @Test
    func seedingMatchesTheOldDashboardPlacement() {
        // The iPad default: Verse of the Day spanned the top, then visible cards filled
        // the two card columns row by row, with Today's Reading on the right.
        let layout = HomeColumnLayout.seeded(
            from: [.verseOfDay, .today, .study, .streaks, .timer, .dailyFocus, .resumeReading, .search, .bibleStats],
            hidden: defaultHidden,
            readerColumn: .right
        )

        #expect(layout.left.filter { !defaultHidden.contains($0) } == [.verseOfDay, .today, .streaks, .dailyFocus])
        #expect(layout.middle.filter { !defaultHidden.contains($0) } == [.study, .timer])
        #expect(layout.right.isEmpty)
        #expect(Set(layout.left + layout.middle + layout.right) == Set(HomeCardID.allCases))
    }

    @Test
    func seedingUsesAllThreeColumnsWhenTheReaderIsHidden() {
        let layout = HomeColumnLayout.seeded(from: [.verseOfDay, .today, .study, .streaks], hidden: [], readerColumn: nil)
        #expect(layout.left.first == .verseOfDay)
        #expect(layout.left.contains(.today))
        #expect(layout.middle.first == .study)
        #expect(layout.right.first == .streaks)
    }

    @Test
    func normalizingRemovesDuplicatesAndAvoidsTheReaderColumn() {
        let layout = HomeColumnLayout(left: [.study, .study, .timer], right: [.timer]).normalized(avoiding: .right)

        let all = layout.left + layout.middle + layout.right
        #expect(all.count == HomeCardID.allCases.count)
        #expect(Set(all) == Set(HomeCardID.allCases))
        #expect(layout.left.prefix(2) == [.study, .timer])
        #expect(layout.right.isEmpty)
    }

    @Test
    func movingCardsAcrossAndWithinColumns() {
        var layout = HomeColumnLayout(left: [.verseOfDay, .today, .streaks], middle: [.study], right: [.timer]).normalized()

        // Slides straight across at the same row, one column at a time.
        layout.moveAcross(.today, by: 1)
        #expect(layout.left.prefix(2) == [.verseOfDay, .streaks])
        #expect(layout.middle.prefix(2) == [.study, .today])

        layout.moveAcross(.today, by: 1)
        #expect(layout.right.prefix(2) == [.timer, .today])
        #expect(!layout.canMoveAcross(.today, by: 1))
        #expect(!layout.canMoveAcross(.verseOfDay, by: -1))

        layout.move(.today, by: -1)
        #expect(layout.right.prefix(2) == [.today, .timer])
        #expect(!layout.canMove(.today, by: -1))

        // A move past either edge changes nothing.
        let before = layout
        layout.moveAcross(.today, by: 1)
        layout.move(.today, by: -1)
        #expect(layout == before)
    }

    @Test
    func flatOrderReadsRowByRowForNarrowWidths() {
        let layout = HomeColumnLayout(left: [.verseOfDay, .today], middle: [.study], right: [.timer, .streaks])
        #expect(layout.flatOrder == [.verseOfDay, .study, .timer, .today, .streaks])
    }

    @Test
    func storageRoundTripsAndRejectsInvalidData() {
        let layout = HomeColumnLayout.seeded(from: HomeCardID.allCases, hidden: [], readerColumn: nil)
        #expect(HomeColumnLayout(storageString: layout.storageString, readerColumn: nil) == layout)
        #expect(HomeColumnLayout(storageString: "", readerColumn: .right) == nil)
        #expect(HomeColumnLayout(storageString: "not json", readerColumn: .right) == nil)

        // Unknown card names from a newer version are dropped, and the rest still load.
        let decoded = HomeColumnLayout(
            storageString: #"{"left":["study","futureCard"],"middle":["today"],"right":["timer"]}"#,
            readerColumn: nil
        )
        #expect(decoded?.left.first == .study)
        #expect(decoded?.middle.first == .today)
        #expect(decoded?.right.first == .timer)
    }

    @Test
    func twoColumnLayoutsMoveBesideTheReader() {
        let legacy = #"{"left":["verseOfDay","today"],"right":["study","timer"]}"#

        // Reader on the right: the old two card columns become left and middle.
        let readerRight = HomeColumnLayout(storageString: legacy, readerColumn: .right)
        #expect(readerRight?.left.prefix(2) == [.verseOfDay, .today])
        #expect(readerRight?.middle.prefix(2) == [.study, .timer])
        #expect(readerRight?.right.isEmpty == true)

        // Reader on the left: they become middle and right.
        let readerLeft = HomeColumnLayout(storageString: legacy, readerColumn: .left)
        #expect(readerLeft?.left.isEmpty == true)
        #expect(readerLeft?.middle.prefix(2) == [.verseOfDay, .today])
        #expect(readerLeft?.right.prefix(2) == [.study, .timer])
    }
}
