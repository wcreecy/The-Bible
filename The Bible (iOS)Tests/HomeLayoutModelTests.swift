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
        "homeTodayVisibilityMigratedV1",
        "homeCardFavoriteHidden",
        HomeLayoutStore.keyFavColumns,
        HomeLayoutStore.keyReaderPanelRemovalMigrated
    ] + HomeLayoutStore.retiredReaderPanelKeys

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
    func layoutsBuiltAroundTheRemovedReadingPanelAreRearrangedOnce() {
        withRestoredDefaults {
            let defaults = UserDefaults.standard
            // Saved while the panel was showing (never turned off): the right column held no cards.
            let panelEra = HomeColumnLayout(
                left: [.setup, .verseOfDay, .resumeReading, .savedVerses, .study],
                middle: [.readingPlan, .today, .timer, .streaks, .dailyFocus],
                right: []
            )
            defaults.set(panelEra.storageString, forKey: HomeLayoutStore.keyColumns)
            defaults.set(#"["savedVerses","study","streaks","dailyFocus"]"#, forKey: "homeCardHidden")
            defaults.set(true, forKey: "homeTodayVisibilityMigratedV1")
            defaults.removeObject(forKey: HomeLayoutStore.keyFavColumns)
            defaults.removeObject(forKey: HomeLayoutStore.keyReaderPanelRemovalMigrated)
            HomeLayoutStore.retiredReaderPanelKeys.forEach(defaults.removeObject(forKey:))
            defaults.set("right", forKey: "homeBibleReaderColumn")
            defaults.set("bookmark", forKey: "homeReaderSource")

            let loaded = HomeLayoutStore().load()

            // The panel's settings are gone either way.
            for key in HomeLayoutStore.retiredReaderPanelKeys {
                #expect(defaults.object(forKey: key) == nil, "\(key) was kept")
            }
            #expect(defaults.bool(forKey: HomeLayoutStore.keyReaderPanelRemovalMigrated))

            // Only iPad keeps its own columns; there, every column now shows a card.
            guard HomeLayoutStore.storesColumns else { return }
            #expect(HomeColumn.allCases.allSatisfy { column in
                loaded.columns.stackedCards(in: column).contains { !loaded.hidden.contains($0) }
            })

            // It happens once: a column emptied on purpose afterward stays empty.
            defaults.set(panelEra.storageString, forKey: HomeLayoutStore.keyColumns)
            #expect(HomeLayoutStore().load().columns.right.isEmpty)
        }
    }

    @Test
    func theDefaultOrderReadsLikeTheDefaultColumns() {
        // Narrow widths use the order, so it should match the columns read row by row.
        guard HomeLayoutStore.storesColumns else { return }
        #expect(HomeLayoutStore.baselineOrder == HomeLayoutStore.baselineColumns.flatOrder)
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
            storageString: #"{"left":["search","verseOfDay"],"middle":["bibleStats","today"],"right":["timer"]}"#
        )
        #expect(decoded?.left.first == .verseOfDay)
        #expect(decoded?.middle.first == .today)
        #expect(decoded?.right.first == .timer)
    }
}
