import Testing
@testable import Bible

struct HomeLayoutPresetTests {
    @Test
    func minimalPresetShowsOnlyContinueReadingAndSearchOnIPhone() {
        #expect(HomeLayoutPreset.minimal.visibleCards(usesDashboard: false) == [.resumeReading, .search])
        #expect(HomeLayoutPreset.minimal.showsTodayReadingPanel == false)
    }

    @Test
    func readingPresetPrioritizesReadingAndEnablesTheReadingPanel() {
        #expect(HomeLayoutPreset.reading.preferredOrder.prefix(2) == [.verseOfDay, .resumeReading])
        #expect(HomeLayoutPreset.reading.showsTodayReadingPanel)
    }

    @Test
    func presetOrderRetainsEveryCardForFutureCustomization() {
        for preset in HomeLayoutPreset.allCases {
            let order = preset.orderedCards()
            #expect(order.count == HomeCardID.allCases.count)
            #expect(Set(order) == Set(HomeCardID.allCases))
        }
    }
}
