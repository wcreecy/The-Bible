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
        let order: [HomeCardID] = [.verseOfDay, .today, .study, .streaks, .timer, .dailyFocus, .resumeReading, .search, .bibleStats]
        let layout = HomeColumnLayout.seeded(
            from: order,
            hidden: defaultHidden,
            readerColumn: .right
        )
        // Cards added since (left out of `order`) are appended by normalizing; only the seeded ones are checked.
        func seededVisible(_ cards: [HomeCardID]) -> [HomeCardID] {
            cards.filter { order.contains($0) && !defaultHidden.contains($0) }
        }

        #expect(seededVisible(layout.left) == [.verseOfDay, .today, .streaks, .dailyFocus])
        #expect(seededVisible(layout.middle) == [.study, .timer])
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

    // MARK: - Wide Verse of the Day

    @Test
    func widenedVerseOfDayCoversItsOwnSideOrTheSideAwayFromTheReader() {
        var layout = HomeColumnLayout(left: [.verseOfDay, .today], middle: [.study], right: [.timer]).normalized()
        layout.setVerseOfDayColumnCount(2, readerColumn: .right)
        #expect(layout.verseOfDayWidth == .leftTwoColumns)

        var fromRight = HomeColumnLayout(left: [.today], middle: [.study], right: [.verseOfDay]).normalized()
        fromRight.setVerseOfDayColumnCount(2, readerColumn: nil)
        #expect(fromRight.verseOfDayWidth == .rightTwoColumns)

        // From the middle, it leaves the reader's column its full height.
        var fromMiddle = HomeColumnLayout(left: [.today], middle: [.verseOfDay], right: [.timer]).normalized()
        fromMiddle.setVerseOfDayColumnCount(2, readerColumn: .left)
        #expect(fromMiddle.verseOfDayWidth == .rightTwoColumns)

        // Already two columns wide, it stays on its side.
        fromMiddle.setVerseOfDayColumnCount(2, readerColumn: .right)
        #expect(fromMiddle.verseOfDayWidth == .rightTwoColumns)

        fromMiddle.setVerseOfDayColumnCount(3, readerColumn: .right)
        #expect(fromMiddle.verseOfDayWidth == .allColumns)
    }

    @Test
    func wideVerseOfDayStaysOnTopAndKeepsItsColumnPlace() {
        var layout = HomeColumnLayout(left: [.today, .verseOfDay, .streaks], middle: [.study], right: [.timer]).normalized()
        layout.setVerseOfDayColumnCount(2, readerColumn: nil)

        #expect(layout.stackedCards(in: .left).prefix(2) == [.today, .streaks])
        #expect(!layout.canMove(.verseOfDay, by: -1))
        #expect(!layout.canMove(.verseOfDay, by: 1))

        // Moves skip over it, then it's back where it was once narrowed.
        layout.move(.streaks, by: -1)
        #expect(layout.stackedCards(in: .left).prefix(2) == [.streaks, .today])
        #expect(layout.left.prefix(3) == [.streaks, .verseOfDay, .today])

        // The arrows switch which two columns it covers; full width can't move.
        #expect(!layout.canMoveAcross(.verseOfDay, by: -1))
        layout.moveAcross(.verseOfDay, by: 1)
        #expect(layout.verseOfDayWidth == .rightTwoColumns)
        #expect(layout.column(of: .verseOfDay) == .left)
        layout.setVerseOfDayColumnCount(3, readerColumn: nil)
        #expect(!layout.canMoveAcross(.verseOfDay, by: -1) && !layout.canMoveAcross(.verseOfDay, by: 1))

        layout.setVerseOfDayColumnCount(1, readerColumn: nil)
        #expect(layout.stackedCards(in: .left).prefix(3) == [.streaks, .verseOfDay, .today])
    }

    @Test
    func draggingPastAWideVerseOfDayKeepsItsColumnPlace() {
        var layout = HomeColumnLayout(left: [.today, .verseOfDay, .streaks, .study], middle: [], right: [.timer]).normalized()
        layout.verseOfDayWidth = .allColumns

        // Settings lists only the stacked cards, so drag offsets refer to them.
        layout.moveStacked(in: .left, fromOffsets: [2], toOffset: 0)
        #expect(layout.stackedCards(in: .left).prefix(3) == [.study, .today, .streaks])
        #expect(layout.left[1] == .verseOfDay)

        layout.moveStacked(in: .left, fromOffsets: [0], toOffset: 3)
        #expect(layout.stackedCards(in: .left).prefix(3) == [.today, .streaks, .study])
        #expect(layout.left[1] == .verseOfDay)
        #expect(Set(layout.left + layout.middle + layout.right) == Set(HomeCardID.allCases))
    }

    @Test
    func wideVerseOfDayLeadsTheNarrowOrderAndIsSaved() {
        var layout = HomeColumnLayout(left: [.today, .verseOfDay], middle: [.study], right: [.timer, .streaks])
        layout.verseOfDayWidth = .allColumns
        #expect(layout.flatOrder == [.verseOfDay, .today, .study, .timer, .streaks])

        let normalized = layout.normalized()
        #expect(HomeColumnLayout(storageString: normalized.storageString, readerColumn: nil) == normalized)

        // Every width survives saving.
        for width in HomeCardWidth.allCases {
            var saved = normalized
            saved.verseOfDayWidth = width
            #expect(HomeColumnLayout(storageString: saved.storageString, readerColumn: nil)?.verseOfDayWidth == width)
        }

        // Layouts saved before widths existed load at one column.
        let legacy = HomeColumnLayout(storageString: #"{"left":["verseOfDay"],"middle":[],"right":[]}"#, readerColumn: nil)
        #expect(legacy?.verseOfDayWidth == .oneColumn)
    }
}
