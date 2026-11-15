import Foundation
import Testing
@testable import Bible

@MainActor
struct HomeColumnLayoutTests {
    private let defaultHidden: Set<HomeCardID> = [.resumeReading, .setup]

    @Test
    func seedingSpreadsVisibleCardsRowByRow() {
        // Verse of the Day heads the left column, then visible cards fill the three columns
        // row by row; hidden cards only need a place for when they are shown again.
        let order: [HomeCardID] = [.verseOfDay, .today, .savedVerses, .streaks, .timer, .dailyFocus, .resumeReading, .setup]
        let layout = HomeColumnLayout.seeded(from: order, hidden: defaultHidden)
        // Cards added since (left out of `order`) are appended by normalizing; only the seeded ones are checked.
        func seededVisible(_ cards: [HomeCardID]) -> [HomeCardID] {
            cards.filter { order.contains($0) && !defaultHidden.contains($0) }
        }

        #expect(seededVisible(layout.left) == [.verseOfDay, .today, .timer])
        #expect(seededVisible(layout.middle) == [.savedVerses, .dailyFocus])
        #expect(seededVisible(layout.right) == [.streaks])
        #expect(Set(layout.left + layout.middle + layout.right) == Set(HomeCardID.allCases))
    }

    @Test
    func seedingUsesAllThreeColumns() {
        let layout = HomeColumnLayout.seeded(from: [.verseOfDay, .today, .savedVerses, .streaks], hidden: [])
        #expect(layout.left.first == .verseOfDay)
        #expect(layout.left.contains(.today))
        #expect(layout.middle.first == .savedVerses)
        #expect(layout.right.first == .streaks)
    }

    @Test
    func normalizingRemovesDuplicatesAndSpreadsMissingCards() {
        let layout = HomeColumnLayout(left: [.savedVerses, .savedVerses, .timer], right: [.timer]).normalized()

        let all = layout.left + layout.middle + layout.right
        #expect(all.count == HomeCardID.allCases.count)
        #expect(Set(all) == Set(HomeCardID.allCases))
        #expect(layout.left.prefix(2) == [.savedVerses, .timer])
        // Missing cards go to the shortest columns, so none is left empty.
        #expect(HomeColumn.allCases.allSatisfy { !layout[$0].isEmpty })
    }

    @Test
    func movingCardsAcrossAndWithinColumns() {
        var layout = HomeColumnLayout(left: [.verseOfDay, .today, .streaks], middle: [.savedVerses], right: [.timer]).normalized()

        // Slides straight across at the same row, one column at a time.
        layout.moveAcross(.today, by: 1)
        #expect(layout.left.prefix(2) == [.verseOfDay, .streaks])
        #expect(layout.middle.prefix(2) == [.savedVerses, .today])

        layout.moveAcross(.today, by: 1)
        #expect(layout.right.prefix(2) == [.timer, .today])
        #expect(!layout.canMoveAcross(.today, by: 1))
        #expect(!layout.canMoveAcross(.verseOfDay, by: -1))

        layout.move(.today, by: -1)
        #expect(layout.right.prefix(2) == [.today, .timer])
        #expect(!layout.canMove(.today, by: -1))

        // A move past either edge changes nothing. "Today" is in the last column and at its
        // top here, so there is nowhere further to go.
        let before = layout
        layout.moveAcross(.today, by: 1)
        layout.move(.today, by: -1)
        #expect(layout == before)

        // The Settings column menu can send a card directly to any named column.
        layout.move(.today, to: .left)
        #expect(layout.left.prefix(3) == [.today, .verseOfDay, .streaks])
        #expect(layout.column(of: .today) == .left)

        // Sending a card to the column it is already in changes nothing.
        let inLeft = layout
        layout.move(.today, to: .left)
        #expect(layout == inLeft)
    }

    @Test
    func flatOrderReadsRowByRowForNarrowWidths() {
        let layout = HomeColumnLayout(left: [.verseOfDay, .today], middle: [.savedVerses], right: [.timer, .streaks])
        #expect(layout.flatOrder == [.verseOfDay, .savedVerses, .timer, .today, .streaks])
    }

    @Test
    func storageRoundTripsAndRejectsInvalidData() {
        let layout = HomeColumnLayout.seeded(from: HomeCardID.allCases, hidden: [])
        #expect(HomeColumnLayout(storageString: layout.storageString) == layout)
        #expect(HomeColumnLayout(storageString: "") == nil)
        #expect(HomeColumnLayout(storageString: "not json") == nil)

        // Unknown card names from a newer version are dropped, and the rest still load.
        let decoded = HomeColumnLayout(
            storageString: #"{"left":["savedVerses","futureCard"],"middle":["today"],"right":["timer"]}"#
        )
        #expect(decoded?.left.first == .savedVerses)
        #expect(decoded?.middle.first == .today)
        #expect(decoded?.right.first == .timer)
    }

    @Test
    func twoColumnLayoutsLoadIntoTheLeftAndMiddleColumns() {
        let legacy = #"{"left":["verseOfDay","today"],"right":["savedVerses","timer"]}"#

        let layout = HomeColumnLayout(storageString: legacy)
        #expect(layout?.left.prefix(2) == [.verseOfDay, .today])
        #expect(layout?.middle.prefix(2) == [.savedVerses, .timer])
    }

    @Test
    func rebalancingFillsTheColumnTheReadingPanelKeptClear() {
        // A layout saved beside the removed Today's Reading panel: every card in two columns.
        let hidden: Set<HomeCardID> = [.savedVerses, .study, .streaks, .dailyFocus]
        var saved = HomeColumnLayout(
            left: [.setup, .verseOfDay, .resumeReading, .savedVerses, .study],
            middle: [.readingPlan, .today, .timer, .streaks, .dailyFocus],
            right: []
        ).normalized()
        saved.verseOfDayWidth = .leftTwoColumns

        let layout = saved.rebalanced(hidden: hidden)

        let all = layout.left + layout.middle + layout.right
        #expect(all.count == HomeCardID.allCases.count)
        #expect(Set(all) == Set(HomeCardID.allCases))
        #expect(HomeColumn.allCases.allSatisfy { column in
            layout.stackedCards(in: column).contains { !hidden.contains($0) }
        })
        #expect(layout.verseOfDayWidth == .leftTwoColumns)
    }

    // MARK: - Wide Verse of the Day

    @Test
    func widenedVerseOfDayCoversItsOwnSide() {
        var layout = HomeColumnLayout(left: [.verseOfDay, .today], middle: [.savedVerses], right: [.timer]).normalized()
        layout.setVerseOfDayColumnCount(2)
        #expect(layout.verseOfDayWidth == .leftTwoColumns)

        var fromRight = HomeColumnLayout(left: [.today], middle: [.savedVerses], right: [.verseOfDay]).normalized()
        fromRight.setVerseOfDayColumnCount(2)
        #expect(fromRight.verseOfDayWidth == .rightTwoColumns)

        // From the middle, it covers the left two columns.
        var fromMiddle = HomeColumnLayout(left: [.today], middle: [.verseOfDay], right: [.timer]).normalized()
        fromMiddle.setVerseOfDayColumnCount(2)
        #expect(fromMiddle.verseOfDayWidth == .leftTwoColumns)

        // Already two columns wide, it stays on its side.
        fromMiddle.moveAcross(.verseOfDay, by: 1)
        fromMiddle.setVerseOfDayColumnCount(2)
        #expect(fromMiddle.verseOfDayWidth == .rightTwoColumns)

        fromMiddle.setVerseOfDayColumnCount(3)
        #expect(fromMiddle.verseOfDayWidth == .allColumns)
    }

    @Test
    func wideVerseOfDayStaysOnTopAndKeepsItsColumnPlace() {
        var layout = HomeColumnLayout(left: [.today, .verseOfDay, .streaks], middle: [.savedVerses], right: [.timer]).normalized()
        layout.setVerseOfDayColumnCount(2)

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
        layout.setVerseOfDayColumnCount(3)
        #expect(!layout.canMoveAcross(.verseOfDay, by: -1) && !layout.canMoveAcross(.verseOfDay, by: 1))

        layout.setVerseOfDayColumnCount(1)
        #expect(layout.stackedCards(in: .left).prefix(3) == [.streaks, .verseOfDay, .today])
    }

    @Test
    func draggingPastAWideVerseOfDayKeepsItsColumnPlace() {
        var layout = HomeColumnLayout(left: [.today, .verseOfDay, .streaks, .savedVerses], middle: [], right: [.timer]).normalized()
        layout.verseOfDayWidth = .allColumns

        // Settings lists only the stacked cards, so drag offsets refer to them.
        layout.moveStacked(in: .left, fromOffsets: [2], toOffset: 0)
        #expect(layout.stackedCards(in: .left).prefix(3) == [.savedVerses, .today, .streaks])
        #expect(layout.left[1] == .verseOfDay)

        layout.moveStacked(in: .left, fromOffsets: [0], toOffset: 3)
        #expect(layout.stackedCards(in: .left).prefix(3) == [.today, .streaks, .savedVerses])
        #expect(layout.left[1] == .verseOfDay)
        #expect(Set(layout.left + layout.middle + layout.right) == Set(HomeCardID.allCases))
    }

    @Test
    func wideVerseOfDayLeadsTheNarrowOrderAndIsSaved() {
        var layout = HomeColumnLayout(left: [.today, .verseOfDay], middle: [.savedVerses], right: [.timer, .streaks])
        layout.verseOfDayWidth = .allColumns
        #expect(layout.flatOrder == [.verseOfDay, .today, .savedVerses, .timer, .streaks])

        let normalized = layout.normalized()
        #expect(HomeColumnLayout(storageString: normalized.storageString) == normalized)

        // Every width survives saving.
        for width in HomeCardWidth.allCases {
            var saved = normalized
            saved.verseOfDayWidth = width
            #expect(HomeColumnLayout(storageString: saved.storageString)?.verseOfDayWidth == width)
        }

        // Layouts saved before widths existed load at one column.
        let legacy = HomeColumnLayout(storageString: #"{"left":["verseOfDay"],"middle":[],"right":[]}"#)
        #expect(legacy?.verseOfDayWidth == .oneColumn)
    }
}
