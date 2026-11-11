import Foundation
import Testing
@testable import Bible

@MainActor
struct HomeLayoutModelTests {
    /// HomeLayoutStore persists to the standard defaults; each test restores what it changes.
    private static let storedKeys = [
        "homeCardOrder",
        "homeCardHidden",
        HomeLayoutStore.keyColumns,
        "homeTodayVisibilityMigratedV1"
    ]

    private func withRestoredDefaults(_ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let saved = Self.storedKeys.map { ($0, defaults.object(forKey: $0)) }
        defer {
            for (key, value) in saved {
                defaults.set(value, forKey: key)
            }
        }
        try body()
    }

    @Test
    func hidingACardIsSavedAndReloaded() {
        withRestoredDefaults {
            let model = HomeLayoutModel()
            model.load()
            let card = HomeCardID.streaks
            let wasHidden = model.hidden.contains(card)

            model.toggleHidden(card)

            let reloaded = HomeLayoutModel()
            reloaded.load()
            #expect(reloaded.hidden.contains(card) == !wasHidden)
            #expect(reloaded.visibleOrder.contains(card) == wasHidden)
        }
    }

    @Test
    func columnChangesKeepTheNarrowOrderInStep() {
        withRestoredDefaults {
            let model = HomeLayoutModel()
            model.load()
            let card = model.columns.flatOrder.first ?? .verseOfDay

            model.updateColumns { $0.move(card, by: 1) }

            #expect(model.order == model.columns.flatOrder)
        }
    }

    @Test
    func everyCardHiddenIsDetected() {
        let model = HomeLayoutModel()
        model.hidden = Set(HomeCardID.allCases)
        #expect(model.hidesEveryCard)
        #expect(model.visibleOrder.isEmpty)

        model.hidden.remove(.today)
        #expect(!model.hidesEveryCard)
    }

    @Test
    func aLayoutThatShowedYourStatsShowsYourProgress() {
        // Your Stats ("bibleStats") was shown and the streak card hidden.
        var hidden: Set<HomeCardID> = [.streaks, .timer]
        HomeLayoutStore.showProgressIfStatsWasShown(
            &hidden,
            savedOrder: ["verseOfDay", "streaks", "bibleStats", "timer"],
            savedHidden: ["streaks", "timer"]
        )
        #expect(hidden == [.timer])

        // Your Stats was hidden too, so nothing changes.
        hidden = [.streaks]
        HomeLayoutStore.showProgressIfStatsWasShown(
            &hidden,
            savedOrder: ["streaks", "bibleStats"],
            savedHidden: ["streaks", "bibleStats"]
        )
        #expect(hidden == [.streaks])

        // A layout saved after the merge no longer lists Your Stats.
        HomeLayoutStore.showProgressIfStatsWasShown(&hidden, savedOrder: ["streaks"], savedHidden: ["streaks"])
        #expect(hidden == [.streaks])
    }

    @Test
    func retiredCardsDropOutOfSavedColumns() {
        let decoded = HomeColumnLayout(
            storageString: #"{"left":["search","verseOfDay"],"middle":["bibleStats","today"],"right":["timer"]}"#,
            readerColumn: nil
        )
        #expect(decoded?.left.first == .verseOfDay)
        #expect(decoded?.middle.first == .today)
        #expect(decoded?.right.first == .timer)
    }
}
