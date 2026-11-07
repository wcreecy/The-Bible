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

        model.hidden.remove(.search)
        #expect(!model.hidesEveryCard)
    }
}
