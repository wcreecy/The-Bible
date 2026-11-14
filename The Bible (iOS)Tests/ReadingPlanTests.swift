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
        // Overview days are titled by their passages; the rest are titled by their chapters.
        let restDays = plan.filter { $0.title.hasPrefix("Test ") }
        let overviewDays = plan.filter { !$0.title.hasPrefix("Test ") }
        #expect(overviewDays.first?.title.hasPrefix("Opening") == true)
        #expect(overviewDays.map(\.day).max()! < restDays.map(\.day).min()!)
        // Every verse is read, including the rest of the chapters after the overview.
        #expect(Set(coverage(plan)).count == verseCounts.reduce(0, +))
        // Chapter 4 is a key passage in full, so it isn't read again.
        #expect(!restDays.contains { $0.readings.contains { $0.contains(chapter: 4) } })
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

@MainActor
struct ReadingPlanLimitAndSessionTests {
    private static func plan(_ id: String, series: String? = nil, days: [PlanDay]? = nil) -> ReadingPlan {
        ReadingPlan(
            id: id,
            title: id.capitalized,
            description: "",
            category: "Testing",
            series: series,
            difficulty: nil,
            planType: "guided",
            durationDays: days?.count ?? 1,
            days: days ?? [PlanDay(day: 1, title: "One", readings: [PlanReading(book: "Test", chapter: 1)])]
        )
    }

    private static let longDay = PlanDay(day: 1, title: "Long", readings: [
        PlanReading(book: "Test", chapter: 1, endChapter: 3),
        PlanReading(book: "Test", chapter: 4, startVerse: 1, endVerse: 5)
    ])

    private static let catalog = [
        plan("a"), plan("b"), plan("c"), plan("d"),
        plan("long", days: [longDay]),
        plan("part-1", series: "Fruit"), plan("part-2", series: "Fruit"), plan("part-3", series: "Fruit")
    ]

    private func makeStore(defaults: UserDefaults? = nil) -> ReadingPlanStore {
        let defaults = defaults ?? UserDefaults(suiteName: "ReadingPlanLimitTests-\(UUID().uuidString)")!
        let store = ReadingPlanStore(defaults: defaults, catalog: Self.catalog, publishesChanges: false)
        store.verseCountsForBook = { _ in [10, 10, 10, 10] }
        return store
    }

    @Test
    func noMoreThanThreePlansRunAtOnce() {
        let store = makeStore()
        #expect(store.start("a"))
        #expect(store.start("b"))
        #expect(store.start("c"))
        #expect(!store.canStartAnotherPlan)
        #expect(!store.start("d"))
        #expect(store.enrollment(for: "d") == nil)
        // A running plan can still start over.
        #expect(store.restart("a"))
        // Stopping one makes room.
        store.stop("b")
        #expect(store.start("d"))
    }

    @Test
    func customPlansStopAtTheLimit() {
        let store = makeStore()
        var created: [String] = []
        for _ in 0..<ReadingPlanStore.maximumCustomPlans {
            guard let id = store.createCustomPlan(bookName: "Test", dayCount: 2, style: .inOrder) else { break }
            created.append(id)
            store.stop(id)
        }
        #expect(created.count == ReadingPlanStore.maximumCustomPlans)
        #expect(!store.canCreateCustomPlan)
        #expect(store.createCustomPlan(bookName: "Test", dayCount: 2, style: .inOrder) == nil)
    }

    @Test
    func deletedCustomPlansKeepOnlyASmallRecord() throws {
        let store = makeStore()
        let id = try #require(store.createCustomPlan(bookName: "Test", dayCount: 4, style: .inOrder))
        store.deleteCustomPlan(id)
        let record = try #require(store.document.customPlans[id])
        #expect(record.isDeleted)
        #expect(record.days.isEmpty)
        #expect(store.plan(id: id) == nil)
    }

    @Test
    func theOpenReadingIsRememberedAcrossLaunches() {
        let defaults = UserDefaults(suiteName: "ReadingPlanLimitTests-\(UUID().uuidString)")!
        let store = makeStore(defaults: defaults)
        store.start("long")
        store.beginReading(1, day: 1, of: "long")

        let reopened = makeStore(defaults: defaults)
        #expect(reopened.session == ReadingPlanStore.Session(planID: "long", day: 1, readingIndex: 1))
    }

    @Test
    func theReaderKnowsWhereItIsInALongReading() throws {
        let store = makeStore()
        store.start("long")
        store.beginReading(0, day: 1, of: "long")

        let middle = try #require(store.sessionContext(atBook: "Test", chapter: 2))
        #expect(middle.chapterPosition == 2)
        #expect(middle.chapterCount == 3)
        #expect(!middle.isLastChapter)
        #expect(middle.endsAfterVerse == nil)
        #expect(store.sessionContext(atBook: "Test", chapter: 4) == nil)
    }

    @Test
    func aPartialReadingEndsAfterItsLastVerse() throws {
        let store = makeStore()
        store.start("long")
        store.beginReading(1, day: 1, of: "long")

        let context = try #require(store.sessionContext(atBook: "Test", chapter: 4))
        #expect(context.isLastChapter)
        #expect(context.endsAfterVerse == 5)
    }

    @Test
    func checkingThingsOffIsAnnounced() {
        let store = makeStore()
        store.start("long")
        store.setReading(0, day: 1, of: "long", complete: true)
        #expect(store.latestEvent?.kind == .readingCompleted("Test 1–3"))
        store.setReading(1, day: 1, of: "long", complete: true)
        #expect(store.latestEvent?.kind == .planFinished("Long"))
    }

    @Test
    func seriesKeepTheirOrder() throws {
        let store = makeStore()
        let first = try #require(store.plan(id: "part-1"))
        #expect(store.plans(inSeries: "Fruit").map(\.id) == ["part-1", "part-2", "part-3"])
        #expect(store.seriesPosition(of: first)?.position == 1)
        #expect(store.seriesPosition(of: first)?.count == 3)
        #expect(store.nextInSeries(after: first)?.id == "part-2")
        #expect(store.nextInSeries(after: try #require(store.plan(id: "part-3"))) == nil)
    }

    @Test
    func suggestionsSkipFinishedAndRunningPlansAndKeepSeriesInOrder() {
        let store = makeStore()
        store.start("a")
        store.start("b")
        store.setDay(1, of: "b", complete: true)   // finished
        let suggested = Set(store.plansToSuggest.map(\.id))
        #expect(!suggested.contains("a"))           // running
        #expect(!suggested.contains("b"))           // finished
        #expect(suggested.contains("c"))
        // Only the first unfinished part of a series.
        #expect(suggested.contains("part-1"))
        #expect(!suggested.contains("part-2"))

        store.start("part-1")
        store.setDay(1, of: "part-1", complete: true)
        #expect(store.plansToSuggest.contains { $0.id == "part-2" })
    }

    @Test
    func suggestionsStopOnceEveryPlanIsFinishedAndReturnForNewOnes() {
        let catalog = [Self.plan("one"), Self.plan("two")]
        let defaults = UserDefaults(suiteName: "ReadingPlanLimitTests-\(UUID().uuidString)")!
        let store = ReadingPlanStore(defaults: defaults, catalog: catalog, publishesChanges: false)
        for id in ["one", "two"] {
            store.start(id)
            store.setDay(1, of: id, complete: true)
        }
        #expect(store.plansToSuggest.isEmpty)

        // A later version adds a plan; the same progress now has something to suggest.
        let updated = ReadingPlanStore(defaults: defaults, catalog: catalog + [Self.plan("three")], publishesChanges: false)
        #expect(updated.plansToSuggest.map(\.id) == ["three"])
    }

    @Test
    func aPlanSuggestionIsNotADayReading() {
        var task = TodayChallenge(
            id: UUID(), kind: .reflection, title: "Start a reading plan: John", detail: "",
            bookName: nil, chapterNumber: nil, gameName: nil, minimumMinutes: nil, isCompleted: false,
            planID: "gospel-of-john"
        )
        #expect(task.isStartReadingPlan)
        task.planDay = 3
        #expect(!task.isStartReadingPlan)
    }

    @Test
    func theBundledFruitOfTheSpiritSeriesIsComplete() {
        let catalog = ReadingPlanStore.loadCatalog()
        #expect(catalog.filter { $0.series == "Fruit of the Spirit" }.count == 9)
    }
}
