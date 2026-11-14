import Testing
@testable import Bible

struct HomeLayoutPresetTests {
    @Test
    func minimalPresetShowsTheVerseAndContinueReadingOnIPhone() {
        #expect(HomeLayoutPreset.minimal.visibleCards(usesDashboard: false) == [.verseOfDay, .resumeReading])
        #expect(HomeLayoutPreset.minimal.visibleCards(usesDashboard: true).isEmpty)
        #expect(HomeLayoutPreset.minimal.showsTodayReadingPanel == false)
    }

    @Test
    func readingPresetLeadsWithThePlanAndYourPlace() {
        #expect(HomeLayoutPreset.reading.preferredOrder.prefix(2) == [.readingPlan, .resumeReading])
        #expect(HomeLayoutPreset.reading.showsTodayReadingPanel)
    }

    @Test
    func readingPresetUsesTheRequestedDashboardColumns() {
        let layout = HomeLayoutPreset.reading.dashboardColumns

        #expect(layout.verseOfDayWidth == .oneColumn)
        // Hidden cards follow in the columns, ready to be shown again.
        #expect(layout.left.prefix(2) == [.readingPlan, .resumeReading])
        #expect(layout.middle.prefix(3) == [.verseOfDay, .streaks, .savedVerses])
        #expect(HomeLayoutPreset.reading.showsTodayReadingPanel)
    }

    @Test
    func studyPresetUsesTheRequestedDashboardColumns() {
        let layout = HomeLayoutPreset.study.dashboardColumns

        #expect(layout.verseOfDayWidth == .oneColumn)
        #expect(layout.left.prefix(2) == [.study, .timer])
        #expect(layout.middle.prefix(3) == [.resumeReading, .savedVerses, .verseOfDay])
        #expect(HomeLayoutPreset.study.showsTodayReadingPanel)
    }

    @Test
    func dailyPracticePresetUsesTheRequestedDashboardColumns() {
        let layout = HomeLayoutPreset.dailyPractice.dashboardColumns

        #expect(layout.verseOfDayWidth == .allColumns)
        #expect(layout.left.prefix(2) == [.verseOfDay, .readingPlan])
        #expect(layout.middle.prefix(2) == [.today, .streaks])
        #expect(layout.right.prefix(2) == [.timer, .dailyFocus])
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
