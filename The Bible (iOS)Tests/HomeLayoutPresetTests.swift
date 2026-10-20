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
    func readingPresetUsesTheRequestedDashboardColumns() {
        let layout = HomeLayoutPreset.reading.dashboardColumns

        #expect(layout.verseOfDayWidth == .allColumns)
        #expect(layout.left.prefix(2) == [.verseOfDay, .resumeReading])
        #expect(layout.middle.prefix(2) == [.streaks, .dailyFocus])
        #expect(HomeLayoutPreset.reading.showsTodayReadingPanel)
    }

    @Test
    func studyPresetUsesTheRequestedDashboardColumns() {
        let layout = HomeLayoutPreset.study.dashboardColumns

        #expect(layout.verseOfDayWidth == .leftTwoColumns)
        #expect(layout.left.prefix(3) == [.verseOfDay, .study, .search])
        #expect(layout.middle.prefix(2) == [.resumeReading, .savedVerses])
        #expect(HomeLayoutPreset.study.showsTodayReadingPanel)
    }

    @Test
    func dailyPracticePresetUsesTheRequestedDashboardColumns() {
        let layout = HomeLayoutPreset.dailyPractice.dashboardColumns

        #expect(layout.verseOfDayWidth == .allColumns)
        #expect(layout.left.prefix(3) == [.verseOfDay, .resumeReading, .timer])
        #expect(layout.middle.prefix(2) == [.search, .dailyFocus])
        #expect(layout.right.first == .today)
        #expect(!HomeLayoutPreset.dailyPractice.showsTodayReadingPanel)
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
