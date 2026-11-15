import Testing
@testable import Bible

struct HomeLayoutPresetTests {
    @Test
    func minimalPresetShowsTheVerseAndContinueReadingOnIPhone() {
        #expect(HomeLayoutPreset.minimal.visibleCards(usesDashboard: false) == [.verseOfDay, .resumeReading])
        #expect(HomeLayoutPreset.minimal.visibleCards(usesDashboard: true).isEmpty)
    }

    @Test
    func readingPresetLeadsWithThePlanAndYourPlace() {
        #expect(HomeLayoutPreset.reading.preferredOrder.prefix(2) == [.readingPlan, .resumeReading])
    }

    @Test
    func readingPresetUsesTheRequestedDashboardColumns() {
        let layout = HomeLayoutPreset.reading.dashboardColumns

        #expect(layout.verseOfDayWidth == .oneColumn)
        // Hidden cards follow in the columns, ready to be shown again.
        #expect(layout.left.prefix(2) == [.readingPlan, .savedVerses])
        #expect(layout.middle.prefix(2) == [.resumeReading, .verseOfDay])
        #expect(layout.right.first == .streaks)
    }

    @Test
    func studyPresetUsesTheRequestedDashboardColumns() {
        let layout = HomeLayoutPreset.study.dashboardColumns

        #expect(layout.verseOfDayWidth == .oneColumn)
        #expect(layout.left.first == .study)
        #expect(layout.middle.prefix(2) == [.resumeReading, .verseOfDay])
        #expect(layout.right.prefix(2) == [.timer, .savedVerses])
    }

    @Test
    func dailyPracticePresetUsesTheRequestedDashboardColumns() {
        let layout = HomeLayoutPreset.dailyPractice.dashboardColumns

        #expect(layout.verseOfDayWidth == .allColumns)
        #expect(layout.left.prefix(3) == [.verseOfDay, .today, .timer])
        #expect(layout.middle.prefix(2) == [.readingPlan, .dailyFocus])
        #expect(layout.right.first == .streaks)
    }

    @Test
    func dashboardPresetsShowCardsInEveryColumn() {
        // Minimal replaces the cards with its quick actions on iPad.
        for preset in HomeLayoutPreset.allCases where preset != .minimal {
            let layout = preset.dashboardColumns
            let visible = preset.visibleCards(usesDashboard: true)
            for column in HomeColumn.allCases {
                #expect(layout.stackedCards(in: column).contains(where: visible.contains), "\(preset.title): \(column.title)")
            }
        }
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
