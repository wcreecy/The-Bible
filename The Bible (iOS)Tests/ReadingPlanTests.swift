import Foundation
import Testing
@testable import Bible

struct CustomPlanGeneratorTests {
    /// A made-up book: 10 chapters of uneven length.
    private let verseCounts = [30, 12, 25, 40, 8, 18, 22, 35, 10, 20]

    private var highlights: [CustomPlanGenerator.Highlight] {
        [
            .init(title: "Opening", reading: PlanReading(book: "Test", chapter: 1, startVerse: 1, endVerse: 10)),
            .init(title: "Turning Point", reading: PlanReading(book: "Test", chapter: 4)),
            .init(title: "Promise", reading: PlanReading(book: "Test", chapter: 6, startVerse: 3, endVerse: 9)),
            .init(title: "Ending", reading: PlanReading(book: "Test", chapter: 10, startVerse: 15, endVerse: 20))
        ]
    }

    private func coverage(_ days: [PlanDay]) -> [String] {
        days.flatMap { day in
            day.readings.flatMap { reading in
                reading.verses(verseCounts: verseCounts).map { "\($0.chapter):\($0.verse)" }
            }
        }
    }

    @Test(arguments: [1, 3, 7, 10, 25, 44])
    func inOrderReadsEveryVerseOnceInTheRequestedDays(days: Int) {
        let plan = CustomPlanGenerator.makeDays(
            bookName: "Test", verseCounts: verseCounts, highlights: [], style: .inOrder, dayCount: days
        )
        let read = coverage(plan)
        #expect(plan.count == days)
        #expect(read.count == verseCounts.reduce(0, +))
        #expect(Set(read).count == read.count)
        #expect(plan.allSatisfy { !$0.readings.isEmpty })
        #expect(plan.map(\.day) == Array(1...days))
    }

    @Test
    func inOrderKeepsWholeChaptersWhenThereAreEnough() {
        let plan = CustomPlanGenerator.makeDays(
            bookName: "Test", verseCounts: verseCounts, highlights: [], style: .inOrder, dayCount: 5
        )
        #expect(plan.allSatisfy { day in day.readings.allSatisfy { $0.startVerse == nil } })
        #expect(plan.first?.readings.first?.title == "Test 1–2")
    }

    @Test
    func majorPointsReadsOnlyTheKeyPassagesInOrder() {
        let plan = CustomPlanGenerator.makeDays(
            bookName: "Test", verseCounts: verseCounts, highlights: highlights, style: .majorPoints, dayCount: 4
        )
        #expect(plan.count == 4)
        #expect(plan.map(\.title) == ["Opening", "Turning Point", "Promise", "Ending"])
    }

    @Test
    func skipAroundReadsKeyPassagesFirstThenTheWholeBook() {
        let plan = CustomPlanGenerator.makeDays(
            bookName: "Test", verseCounts: verseCounts, highlights: highlights, style: .skipAround, dayCount: 8
        )
        #expect(plan.count == 8)
        #expect(plan.first?.title == "Opening" || plan.first?.title.hasPrefix("Opening") == true)
        // Every verse is read, including the rest of the chapters after the overview.
        #expect(Set(coverage(plan)).count == verseCounts.reduce(0, +))
        // Chapter 4 is a key passage in full, so it isn't read again.
        let restReadings = plan.drop { $0.readings.contains { $0.startVerse != nil || $0.chapter == 4 } }
        #expect(!restReadings.contains { $0.readings.contains { $0.contains(chapter: 4) } })
    }

    @Test
    func skipAroundNeedsADayForTheRestOfTheBook() {
        let range = CustomPlanGenerator.dayRange(for: .skipAround, verseCounts: verseCounts, highlights: highlights)
        #expect(range.lowerBound == 2)
    }

    @Test
    func highlightStylesNeedEnoughKeyPassages() {
        #expect(CustomPlanGenerator.isAvailable(.inOrder, highlights: []))
        #expect(!CustomPlanGenerator.isAvailable(.majorPoints, highlights: Array(highlights.prefix(3))))
        #expect(CustomPlanGenerator.isAvailable(.majorPoints, highlights: highlights))
        #expect(CustomPlanGenerator.isAvailable(.skipAround, highlights: highlights))
    }

    @Test
    func requestedDaysAreKeptWithinTheAllowedRange() {
        let plan = CustomPlanGenerator.makeDays(
            bookName: "Test", verseCounts: verseCounts, highlights: highlights, style: .majorPoints, dayCount: 99
        )
        #expect(plan.count == highlights.count)
    }

    @Test
    func referencesParseInEveryCatalogForm() {
        #expect(CustomPlanGenerator.parse("Genesis 3") == PlanReading(book: "Genesis", chapter: 3))
        #expect(CustomPlanGenerator.parse("Genesis 1-2") == PlanReading(book: "Genesis", chapter: 1, endChapter: 2))
        #expect(CustomPlanGenerator.parse("John 3:16") == PlanReading(book: "John", chapter: 3, startVerse: 16, endVerse: 16))
        #expect(CustomPlanGenerator.parse("1 John 4:7-12") == PlanReading(book: "1 John", chapter: 4, startVerse: 7, endVerse: 12))
        #expect(CustomPlanGenerator.parse("Genesis 6:5-9:29")
            == PlanReading(book: "Genesis", chapter: 6, endChapter: 9, startVerse: 5, endVerse: 29))
        #expect(CustomPlanGenerator.parse("not a reference") == nil)
    }

    @Test
    func highlightsDropDuplicatesAndPassagesInsideLongerOnes() {
        let found = CustomPlanGenerator.highlights(
            from: [
                (title: "Later", reference: "Test 8:1-5"),
                (title: "Whole Chapter", reference: "Test 4"),
                (title: "Inside", reference: "Test 4:2-6"),
                (title: "Repeat", reference: "Test 8:1-5"),
                (title: "Other Book", reference: "Elsewhere 1"),
                (title: "Early", reference: "Test 1:1-3")
            ],
            bookName: "Test",
            verseCounts: verseCounts
        )
        #expect(found.map(\.title) == ["Early", "Whole Chapter", "Later"])
    }

    @Test
    func readingTitlesMatchTheAppsStyle() {
        #expect(PlanReading(book: "Psalms", chapter: 23).title == "Psalms 23")
        #expect(PlanReading(book: "Genesis", chapter: 1, endChapter: 2).title == "Genesis 1–2")
        #expect(PlanReading(book: "Genesis", chapter: 12, startVerse: 1, endVerse: 9).title == "Genesis 12:1–9")
        #expect(PlanReading(book: "Ruth", chapter: 1, endChapter: 2, startVerse: 15, endVerse: 10).title == "Ruth 1:15–2:10")
        #expect(PlanReading(book: "John", chapter: 3, startVerse: 16, endVerse: 16).title == "John 3:16")
    }
}

struct ReadingPlanSyncTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test
    func copiesOfTheSameRunKeepEveryDayRead() {
        var phone = PlanEnrollment(planID: "john", startedAt: start)
        phone.completedDays = [1, 2]
        phone.updatedAt = start.addingTimeInterval(100)
        var tablet = PlanEnrollment(planID: "john", startedAt: start)
        tablet.completedDays = [1, 3]
        tablet.completedReadings = [4: [0]]
        tablet.updatedAt = start.addingTimeInterval(50)

        let merged = PlanEnrollment.merged(phone, tablet)
        #expect(merged.completedDays == [1, 2, 3])
        #expect(merged.completedReadings == [4: [0]])
    }

    @Test
    func aRestartOnOneDeviceWins() {
        var old = PlanEnrollment(planID: "john", startedAt: start)
        old.completedDays = [1, 2, 3]
        old.updatedAt = start.addingTimeInterval(100)
        let restarted = PlanEnrollment(planID: "john", startedAt: start.addingTimeInterval(500))

        #expect(PlanEnrollment.merged(old, restarted).completedDays.isEmpty)
        #expect(PlanEnrollment.merged(restarted, old).startedAt == restarted.startedAt)
    }

    @Test
    func documentsMergePlanByPlan() {
        var a = ReadingPlansDocument()
        a.enrollments["john"] = PlanEnrollment(planID: "john", startedAt: start)
        var b = ReadingPlansDocument()
        b.enrollments["james"] = PlanEnrollment(planID: "james", startedAt: start)

        let merged = ReadingPlansDocument.merged(a, b)
        #expect(Set(merged.enrollments.keys) == ["john", "james"])
    }

    @Test
    func theDocumentSurvivesEncoding() throws {
        var document = ReadingPlansDocument()
        var enrollment = PlanEnrollment(planID: "john", startedAt: start)
        enrollment.completedDays = [1, 2]
        enrollment.completedReadings = [3: [1]]
        document.enrollments["john"] = enrollment

        let data = try JSONEncoder().encode(document)
        #expect(try JSONDecoder().decode(ReadingPlansDocument.self, from: data) == document)
    }
}

@MainActor
struct ReadingPlanStoreTests {
    private static let plan = ReadingPlan(
        id: "sample",
        title: "Sample",
        description: "A sample plan.",
        category: "Testing",
        difficulty: "beginner",
        planType: "guided",
        durationDays: 2,
        days: [
            PlanDay(day: 1, title: "One", readings: [
                PlanReading(book: "Test", chapter: 1),
                PlanReading(book: "Test", chapter: 2, startVerse: 1, endVerse: 5)
            ]),
            PlanDay(day: 2, title: "Two", readings: [PlanReading(book: "Test", chapter: 3)])
        ]
    )

    private func makeStore() -> ReadingPlanStore {
        let defaults = UserDefaults(suiteName: "ReadingPlanStoreTests-\(UUID().uuidString)")!
        let store = ReadingPlanStore(defaults: defaults, catalog: [Self.plan], publishesChanges: false)
        store.verseCountsForBook = { _ in [10, 10, 10] }
        return store
    }

    @Test
    func checkingOffEveryReadingCompletesTheDay() {
        let store = makeStore()
        store.start("sample")
        store.setReading(0, day: 1, of: "sample", complete: true)
        #expect(!store.isDayComplete(1, planID: "sample"))
        store.setReading(1, day: 1, of: "sample", complete: true)
        #expect(store.isDayComplete(1, planID: "sample"))
        #expect(store.currentDay(of: Self.plan)?.day == 2)
    }

    @Test
    func finishingTheLastDayFinishesThePlan() {
        let store = makeStore()
        store.start("sample")
        store.setDay(1, of: "sample", complete: true)
        store.setDay(2, of: "sample", complete: true)
        #expect(store.enrollment(for: "sample")?.finishedAt != nil)
        #expect(store.activePlans.isEmpty)
        #expect(store.latestCompletion?.finishedPlan == true)
    }

    @Test
    func readingTheVersesChecksOffTheReading() {
        let store = makeStore()
        store.start("sample")
        let chapterOne = Set((1...10).map { SeenVerseUpdate(bookName: "Test", chapter: 1, verse: $0, totalVerses: 10) })
        store.versesRead(chapterOne)
        #expect(store.isReadingComplete(0, day: 1, planID: "sample"))
        #expect(!store.isReadingComplete(1, day: 1, planID: "sample"))
    }

    @Test
    func skimmingWithoutReachingTheEndDoesNotCount() {
        let store = makeStore()
        store.start("sample")
        let firstHalf = Set((1...9).map { SeenVerseUpdate(bookName: "Test", chapter: 1, verse: $0, totalVerses: 10) })
        store.versesRead(firstHalf)
        #expect(!store.isReadingComplete(0, day: 1, planID: "sample"))
    }

    @Test
    func progressIsSavedAndRestored() {
        let defaults = UserDefaults(suiteName: "ReadingPlanStoreTests-\(UUID().uuidString)")!
        let store = ReadingPlanStore(defaults: defaults, catalog: [Self.plan], publishesChanges: false)
        store.start("sample")
        store.setDay(1, of: "sample", complete: true)

        let reopened = ReadingPlanStore(defaults: defaults, catalog: [Self.plan], publishesChanges: false)
        #expect(reopened.isDayComplete(1, planID: "sample"))
    }

    @Test
    func stoppingRemovesThePlanFromProgress() {
        let store = makeStore()
        store.start("sample")
        store.stop("sample")
        #expect(store.enrollment(for: "sample") == nil)
        #expect(store.activePlans.isEmpty)
    }

    @Test
    func theBundledCatalogLoads() {
        let catalog = ReadingPlanStore.loadCatalog()
        #expect(catalog.count >= 12)
        #expect(catalog.allSatisfy { $0.days.count == $0.durationDays })
    }

    @Test
    func planLinksOpenAPlanOrItsNextReading() throws {
        let read = try #require(URL(string: "thebible://plan?id=gospel-of-john&read=1"))
        #expect(AppDeepLink(url: read) == .readingPlan(id: "gospel-of-john", opensReading: true))
        let list = try #require(URL(string: "thebible://plan"))
        #expect(AppDeepLink(url: list) == .readingPlan(id: nil, opensReading: false))
    }
}
