import Foundation
import Testing
import UIKit
@testable import Bible

/// Checks on the bundled `ReadingPlans.json` against the Bible text and the asset catalog.
@MainActor
struct ReadingPlanCatalogTests {
    private let catalog = ReadingPlanStore.loadCatalog()

    @Test
    func everyReadingIsRealScripture() async {
        _ = await BibleRepository.shared.loadAllBooks()
        #expect(!catalog.isEmpty)
        for plan in catalog {
            for day in plan.days {
                #expect(!day.readings.isEmpty, "\(plan.id) day \(day.day) has no readings")
                for reading in day.readings {
                    let counts = ReadingPlanStore.verseCounts(forBook: reading.book)
                    let place = "\(plan.id) day \(day.day): \(reading.title)"
                    #expect(!counts.isEmpty, "\(place): unknown book")
                    #expect(reading.lastChapter >= reading.chapter, "\(place): ends before it starts")
                    #expect(reading.lastChapter <= counts.count, "\(place): chapter past the end of the book")
                    if let start = reading.startVerse, counts.indices.contains(reading.chapter - 1) {
                        #expect(start >= 1 && start <= counts[reading.chapter - 1], "\(place): start verse")
                    }
                    if let end = reading.endVerse, counts.indices.contains(reading.lastChapter - 1) {
                        #expect(end <= counts[reading.lastChapter - 1], "\(place): end verse")
                    }
                    #expect(!reading.verses(verseCounts: counts).isEmpty, "\(place): covers no verses")
                }
            }
        }
    }

    @Test
    func idsAreUniqueAndDaysAreNumberedInOrder() {
        let ids = catalog.map(\.id)
        #expect(Set(ids).count == ids.count, "Duplicate plan IDs")
        for plan in catalog {
            #expect(!plan.isCustom, "\(plan.id) uses the custom plan prefix")
            #expect(plan.days.map(\.day) == Array(1...max(1, plan.days.count)), "\(plan.id) day numbers skip or repeat")
        }
    }

    @Test
    func everySymbolAndImageExists() {
        for plan in catalog {
            if let symbol = plan.symbol {
                // The artwork draws a few names itself, such as the Latin cross.
                #expect(PlanArtworkStyle.isDrawable(symbol), "\(plan.id): no SF Symbol \"\(symbol)\"")
            }
            if let image = plan.image {
                #expect(UIImage(named: image) != nil, "\(plan.id): no image \"\(image)\" in the asset catalog")
            }
        }
    }

    @Test
    func seriesHaveSeveralPlansInOneCategory() {
        let series = Dictionary(grouping: catalog.filter { $0.series != nil }, by: { $0.series ?? "" })
        for (name, plans) in series {
            #expect(plans.count >= 2, "\"\(name)\" is a series of one")
            #expect(Set(plans.map(\.category)).count == 1, "\"\(name)\" spans categories")
        }
    }
}

/// The "About a chapter a day" estimate shown with each plan.
@MainActor
struct ReadingPlanLoadTests {
    /// A plan with the same readings every day; the ID is unique since estimates are cached.
    private func plan(days: Int = 7, _ reading: (Int) -> PlanReading) -> ReadingPlan {
        ReadingPlan(
            id: "load-test-\(UUID().uuidString)",
            title: "Load",
            description: "",
            category: "Testing",
            difficulty: nil,
            planType: "guided",
            durationDays: days,
            days: (1...days).map { PlanDay(day: $0, title: "Day \($0)", readings: [reading($0)]) }
        )
    }

    private func description(of plan: ReadingPlan) async -> String? {
        _ = await BibleRepository.shared.loadAllBooks()
        return ReadingPlanLoad.dailyDescription(for: plan)
    }

    @Test
    func oneChapterADay() async {
        let estimate = await description(of: plan { PlanReading(book: "Genesis", chapter: $0) })
        #expect(estimate == "About a chapter a day")
    }

    @Test
    func severalChaptersADay() async {
        let estimate = await description(of: plan { day in
            PlanReading(book: "Genesis", chapter: day * 3 - 2, endChapter: day * 3)
        })
        #expect(estimate == "About 3 chapters a day")
    }

    @Test
    func aFewVersesADayIsRoundedToFives() async {
        // Genesis 1:1–11 every day: 11 verses, rounded to 10.
        let estimate = await description(of: plan { _ in
            PlanReading(book: "Genesis", chapter: 1, startVerse: 1, endVerse: 11)
        })
        #expect(estimate == "About 10 verses a day")
    }

    @Test
    func aVerseOrTwoADayStillReadsFive() async {
        let estimate = await description(of: plan { _ in
            PlanReading(book: "John", chapter: 3, startVerse: 16, endVerse: 16)
        })
        #expect(estimate == "About 5 verses a day")
    }
}

/// When the monthly "Start a reading plan" Today task is due.
@MainActor
struct ReadingPlanTodayTaskTests {
    private let calendar = Calendar.autoupdatingCurrent
    private let taskKey = HistoryKey.reflection(TodayChallengeStore.readingPlanTaskTitle)

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try #require(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
    }

    /// The task's day in March 2027, picked the same way the app does.
    private func dueDay() throws -> Int {
        TodayChallengeStore.monthlySystemTaskDay(
            for: TodayChallengeStore.readingPlanTaskTitle,
            on: try date(2027, 3, 1)
        )
    }

    private func isDue(on day: Int, history: TodayChallengeHistory = .init(), canStart: Bool = true) throws -> Bool {
        TodayChallengeStore.isReadingPlanTaskDue(in: history, on: try date(2027, 3, day), canStartAnotherPlan: canStart)
    }

    @Test
    func itIsDueFromItsDayOfTheMonthOn() throws {
        let day = try dueDay()
        #expect(try isDue(on: day))
        #expect(try isDue(on: 31))
        if day > 1 {
            #expect(try !isDue(on: day - 1))
        }
    }

    @Test
    func itComesOnceAMonth() throws {
        let day = try dueDay()
        var history = TodayChallengeHistory()
        history.days[GameStats.localDayKey(for: try date(2027, 3, day))] = [taskKey]
        #expect(try !isDue(on: min(day + 1, 31), history: history))
        #expect(try !isDue(on: 31, history: history))
    }

    @Test
    func lastMonthsTaskDoesNotHoldUpThisMonths() throws {
        var history = TodayChallengeHistory()
        history.days[GameStats.localDayKey(for: try date(2027, 2, 27))] = [taskKey]
        #expect(try isDue(on: 31, history: history))
    }

    @Test
    func otherTasksThisMonthDoNotCount() throws {
        var history = TodayChallengeHistory()
        history.days[GameStats.localDayKey(for: try date(2027, 3, 1))] = [HistoryKey.reflection("Something else")]
        #expect(try isDue(on: 31, history: history))
    }

    @Test
    func itIsNotDueWhenNoMorePlansCanStart() throws {
        #expect(try !isDue(on: 31, canStart: false))
    }
}
