import Foundation
import SwiftUI
import Testing
@testable import Bible

@MainActor
struct The_Bible__iOS_Tests {
    private let firstVerse = SeenVerseUpdate(
        bookName: "John",
        chapter: 1,
        verse: 1,
        totalVerses: 51
    )

    @Test
    func verseRequiresContinuousVisibilityForTheFullDwell() async throws {
        var commits: [Set<SeenVerseUpdate>] = []
        let tracker = VerseReadingTracker(
            dwellDuration: 0.02,
            batchDuration: 0.01
        ) { commits.append($0) }

        tracker.setActive(true)
        tracker.visibilityChanged(firstVerse, isVisible: true)
        try await Task.sleep(nanoseconds: 10_000_000)
        tracker.visibilityChanged(firstVerse, isVisible: false)
        try await Task.sleep(nanoseconds: 30_000_000)

        #expect(commits.isEmpty)
    }

    @Test
    func verseCommitsAfterVisibilityDwell() async throws {
        var commits: [Set<SeenVerseUpdate>] = []
        let tracker = VerseReadingTracker(
            dwellDuration: 0.02,
            batchDuration: 0.01
        ) { commits.append($0) }

        tracker.setActive(true)
        tracker.visibilityChanged(firstVerse, isVisible: true)
        // Allow the dwell task and its subsequent batching task to run independently.
        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(commits == [[firstVerse]])
    }

    @Test
    func directEngagementIsBatchedWithoutDwell() async throws {
        let secondVerse = SeenVerseUpdate(
            bookName: "John",
            chapter: 1,
            verse: 2,
            totalVerses: 51
        )
        var commits: [Set<SeenVerseUpdate>] = []
        let tracker = VerseReadingTracker(
            dwellDuration: 1,
            batchDuration: 0.01
        ) { commits.append($0) }

        tracker.recordDirectEngagement(firstVerse)
        tracker.recordDirectEngagement(secondVerse)
        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(commits.count == 1)
        #expect(commits.first == [firstVerse, secondVerse])
    }

    @Test
    func inactiveReaderCancelsDwellAndRestartsWhenActive() async throws {
        var commits: [Set<SeenVerseUpdate>] = []
        let tracker = VerseReadingTracker(
            dwellDuration: 0.02,
            batchDuration: 0.01
        ) { commits.append($0) }

        tracker.setActive(true)
        tracker.visibilityChanged(firstVerse, isVisible: true)
        try await Task.sleep(nanoseconds: 10_000_000)
        tracker.setActive(false)
        try await Task.sleep(nanoseconds: 25_000_000)
        #expect(commits.isEmpty)

        tracker.setActive(true)
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(commits == [[firstVerse]])
    }

    @Test
    func stoppingFlushesPendingEngagement() {
        var commits: [Set<SeenVerseUpdate>] = []
        let tracker = VerseReadingTracker(
            dwellDuration: 1,
            batchDuration: 1
        ) { commits.append($0) }

        tracker.recordDirectEngagement(firstVerse)
        tracker.stop()

        #expect(commits == [[firstVerse]])
    }

    @Test
    func sevenDayWindowStartsSixDatesBeforeToday() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 12)))
        let expected = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 23)))

        let cutoff = ReadingSessionsStore.startDate(forLastDays: 7, now: now, calendar: calendar)

        #expect(cutoff == expected)
    }

    @Test
    func elapsedSecondsAreAllocatedAcrossMidnight() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 23, minute: 59, second: 50)))
        let end = try #require(calendar.date(byAdding: .second, value: 20, to: start))

        let allocations = ReadingTimeTracker.dailyAllocations(
            seconds: 20,
            from: start,
            to: end,
            calendar: calendar
        )

        #expect(allocations.count == 2)
        #expect(allocations.map(\.seconds) == [10, 10])
        #expect(allocations.reduce(0) { $0 + $1.seconds } == 20)
    }

    @Test
    func sessionAnalyticsRequireAtLeastOneMinute() {
        let start = Date(timeIntervalSince1970: 1_000)
        let tooShort = ReadingSessionsStore.Session(
            start: start,
            end: start.addingTimeInterval(59),
            book: "John",
            chapter: 1
        )
        let valid = ReadingSessionsStore.Session(
            start: start,
            end: start.addingTimeInterval(60),
            book: "John",
            chapter: 1
        )

        #expect(!ReadingSessionsStore.isValid(tooShort))
        #expect(ReadingSessionsStore.isValid(valid))
        #expect(StatsSeriesBuilder.averageSessionLength(sessions: [tooShort, valid]) == 60)
    }

    @Test
    func chapterSegmentsWithTheSameReadingSessionAreCombined() {
        let sessionID = UUID()
        let start = Date(timeIntervalSince1970: 2_000)
        let firstChapter = ReadingSessionsStore.Session(
            readingSessionID: sessionID,
            start: start,
            end: start.addingTimeInterval(120),
            book: "John",
            chapter: 1
        )
        let secondChapter = ReadingSessionsStore.Session(
            readingSessionID: sessionID,
            start: start.addingTimeInterval(120),
            end: start.addingTimeInterval(300),
            book: "John",
            chapter: 2
        )

        let durations = StatsSeriesBuilder.sessionDurations(sessions: [firstChapter, secondChapter])

        #expect(durations == [300])
        #expect(StatsSeriesBuilder.averageSessionLength(sessions: [firstChapter, secondChapter]) == 300)
    }

    @Test
    func dailySessionAveragesAreGroupedByCalendarDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
        let firstDay = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: 10))
        )
        let secondDay = try #require(
            calendar.date(from: DateComponents(year: 2026, month: 9, day: 29, hour: 10))
        )
        let sessions = [
            ReadingSessionsStore.Session(
                start: firstDay,
                end: firstDay.addingTimeInterval(600),
                book: "John",
                chapter: 1
            ),
            ReadingSessionsStore.Session(
                start: firstDay.addingTimeInterval(3_600),
                end: firstDay.addingTimeInterval(4_800),
                book: "John",
                chapter: 2
            ),
            ReadingSessionsStore.Session(
                start: secondDay,
                end: secondDay.addingTimeInterval(1_800),
                book: "Acts",
                chapter: 1
            )
        ]

        let averages = StatsSeriesBuilder.dailyAverageSessionLengths(
            sessions: sessions,
            days: 7,
            now: secondDay.addingTimeInterval(3_600),
            calendar: calendar
        )

        #expect(averages.count == 2)
        #expect(averages.map(\.seconds) == [900, 1_800])
        #expect(averages.map(\.date) == [
            calendar.startOfDay(for: firstDay),
            calendar.startOfDay(for: secondDay)
        ])
    }

    @Test
    func readingComparisonHandlesGrowthDeclineAndNoBaseline() {
        #expect(ReadingInsights(recentSeconds: 900, previousSeconds: 600).comparisonPercent == 50)
        #expect(ReadingInsights(recentSeconds: 300, previousSeconds: 600).comparisonPercent == -50)
        #expect(ReadingInsights(recentSeconds: 300, previousSeconds: 0).comparisonPercent == 100)
        #expect(ReadingInsights(recentSeconds: 0, previousSeconds: 0).comparisonPercent == nil)
    }

    @Test
    func cloudSessionPayloadIsBoundedAndKeepsRecentHistory() throws {
        let firstStart = Date().addingTimeInterval(-TimeInterval(3_000 * 60))
        let sessions = (0..<3_000).map { index in
            let start = firstStart.addingTimeInterval(TimeInterval(index * 60))
            return ReadingSessionsStore.Session(
                start: start,
                end: start.addingTimeInterval(60),
                book: "John",
                chapter: 1
            )
        }

        let payload = iCloudSyncCoordinator.cloudSessionPayload(from: sessions)
        let decoded = try JSONDecoder().decode([ReadingSessionsStore.Session].self, from: payload)

        #expect(payload.count <= iCloudSyncCoordinator.maximumCloudSessionBytes)
        #expect(decoded.count <= iCloudSyncCoordinator.maximumCloudSessions)
        #expect(decoded.first?.end == sessions.last?.end)
    }

    // MARK: - Streaks

    /// Runs `pattern` (true = goal met) through a runner, one day per entry.
    private func runStreak(_ pattern: [Bool], allowsGraceDays: Bool) -> (runner: StreakRunner, outcomes: [StreakRunner.Outcome]) {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? Date()
        var runner = StreakRunner(allowsGraceDays: allowsGraceDays)
        var outcomes: [StreakRunner.Outcome] = []
        for (offset, met) in pattern.enumerated() {
            let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            outcomes.append(runner.advance(goalMet: met, on: day, calendar: calendar))
        }
        return (runner, outcomes)
    }

    @Test
    func missedDayEndsStreakWithoutGraceDays() {
        let result = runStreak([true, true, false, true], allowsGraceDays: false)
        #expect(result.runner.run == 1)
        #expect(result.runner.best == 2)
    }

    @Test
    func graceDayKeepsStreakWithoutCountingIt() {
        let result = runStreak([true, true, false, true], allowsGraceDays: true)
        #expect(result.outcomes[2] == .grace)
        #expect(result.runner.run == 3)
    }

    @Test
    func secondMissInsideGraceWindowEndsStreak() {
        let result = runStreak([true, false, true, false, true], allowsGraceDays: true)
        #expect(result.outcomes[1] == .grace)
        #expect(result.outcomes[3] == .missed)
        #expect(result.runner.run == 1)
    }

    @Test
    func graceDayIsAvailableAgainAfterAWeek() {
        let pattern = [true, false] + Array(repeating: true, count: 6) + [false, true]
        let result = runStreak(pattern, allowsGraceDays: true)
        #expect(result.outcomes[1] == .grace)
        #expect(result.outcomes[8] == .grace)
        #expect(result.runner.run == 8)
    }

    @Test
    func graceDayNeedsAnActiveStreak() {
        let result = runStreak([false, true], allowsGraceDays: true)
        #expect(result.outcomes[0] == .missed)
        #expect(result.runner.run == 1)
    }

    @Test
    func streakMilestonesStepThroughFixedThenYearly() {
        #expect(StreakMilestone.reached(by: 6) == 0)
        #expect(StreakMilestone.reached(by: 7) == 7)
        #expect(StreakMilestone.reached(by: 99) == 30)
        #expect(StreakMilestone.reached(by: 800) == 730)
        #expect(StreakMilestone.next(after: 0) == 7)
        #expect(StreakMilestone.next(after: 365) == 730)
        #expect(StreakMilestone.title(for: 365) == "1-year streak")
    }

    // MARK: - Prayer stats sync

    @Test
    func prayerContributionsMergeKeepsEachDevicesLargestValue() {
        let phone: PrayerStatsStore.Contributions = ["2026-10-10": ["phone": 600, "ipad": 120]]
        let cloud: PrayerStatsStore.Contributions = [
            "2026-10-10": ["phone": 300, "ipad": 900],
            "2026-10-09": ["ipad": 60]
        ]

        let merged = PrayerStatsStore.merged(phone, cloud)

        #expect(merged["2026-10-10"] == ["phone": 600, "ipad": 900])
        #expect(merged["2026-10-09"] == ["ipad": 60])
        // Merging again changes nothing, so devices settle on the same copy.
        #expect(PrayerStatsStore.merged(merged, cloud) == merged)
        #expect(PrayerStatsStore.merged(cloud, phone) == merged)
    }

    @Test
    func prayerLastSessionMergeKeepsTheMostRecent() {
        let older = PrayerStatsStore.LastSession(seconds: 600, endedAt: Date(timeIntervalSince1970: 100))
        let newer = PrayerStatsStore.LastSession(seconds: 300, endedAt: Date(timeIntervalSince1970: 200))

        #expect(PrayerStatsStore.newer(older, newer) == newer)
        #expect(PrayerStatsStore.newer(newer, older) == newer)
        #expect(PrayerStatsStore.newer(nil, older) == older)
        #expect(PrayerStatsStore.newer(nil, nil) == nil)
    }

    // MARK: - Scripture data and references

    @Test
    func kjvTextCleanerPreservesMarkedWordRangesAndDropsFootnotes() {
        let cleaned = KJVTextCleaner.clean("Before \u{E000}said\u{E001} {word} {or: a note}")

        #expect(cleaned.text == "Before said word")
        #expect(cleaned.redLetterRanges == [7..<11])
        #expect(cleaned.suppliedWordRanges == [12..<16])
    }

    @Test
    func bibleDataDecodingExpandsNamesNumbersAndCleansVerses() throws {
        let data = try #require(
            """
            [{"abbrev":"joh","chapters":[["In the beginning", "{And} \u{E000}said\u{E001}"]]}]
            """.data(using: .utf8)
        )

        let books = try BibleData.decodeBooks(from: data)

        #expect(books.map(\.name) == ["John"])
        #expect(books.first?.chapters.first?.number == 1)
        #expect(books.first?.chapters.first?.verses.map(\.number) == [1, 2])
        #expect(books.first?.chapters.first?.verses[1].text == "And said")
    }

    @Test
    func bibleReferenceParserResolvesAliasesAndReturnsChapterOrVerseResults() {
        let books = [
            Book(
                name: "John",
                chapters: [Chapter(number: 3, verses: [Verse(number: 16, text: "For God so loved"), Verse(number: 17, text: "For God sent")])]
            ),
            Book(
                name: "1 Corinthians",
                chapters: [Chapter(number: 13, verses: [Verse(number: 1, text: "Though I speak")])]
            )
        ]

        let verseReference = BibleReferenceParser.reference(for: " Jn. 3:16 ", in: books)
        let chapterResults = BibleReferenceParser.results(for: "John 3", in: books)
        let numberedReference = BibleReferenceParser.reference(for: "1 Cor 13:1", in: books)

        #expect(verseReference?.title == "John 3:16")
        #expect(verseReference?.verse?.text == "For God so loved")
        #expect(chapterResults?.map(\.verseNumber) == [16, 17])
        #expect(numberedReference?.title == "1 Corinthians 13:1")
    }

    @Test
    func bibleReferenceParserSeparatesInvalidReferencesFromOrdinarySearches() {
        let books = [Book(name: "John", chapters: [Chapter(number: 3, verses: [Verse(number: 16, text: "Text")])])]

        #expect(!BibleReferenceParser.isReferenceShaped("love one another"))
        #expect(BibleReferenceParser.isReferenceShaped("John 3:99"))
        #expect(BibleReferenceParser.results(for: "John 3:99", in: books) == [])
        #expect(BibleReferenceParser.results(for: "love one another", in: books) == nil)
    }

    // MARK: - History and game configuration

    @Test
    func readingHistoryArchiveTotalsIgnoreNegativeDeviceValues() {
        let archive = ReadingHistoryArchive(
            cutoff: "2025-01-01",
            books: [
                "John": ["phone": 120, "tablet": -30],
                "Acts": ["phone": 60]
            ]
        )

        #expect(!archive.isEmpty)
        #expect(archive.bookTotals == ["John": 120, "Acts": 60])
    }

    @Test
    func readingHistoryArchiveMergeKeepsTheMostCompleteCopy() {
        var contributions: ReadingHistoryArchive.Contributions = [:]
        let local = ReadingHistoryArchive(
            cutoff: "2025-01-01",
            books: ["John": ["phone": 100]],
            years: ["2024": 100],
            streakRunAtCutoff: 4,
            bestStreak: 8
        )
        let remote = ReadingHistoryArchive(
            cutoff: "2025-02-01",
            books: ["John": ["phone": 80, "tablet": 70]],
            years: ["2024": 150],
            streakRunAtCutoff: 5,
            bestStreak: 7
        )

        let merged = ReadingHistoryArchive.merged(
            local: local,
            remote: remote,
            localContributions: &contributions
        )

        #expect(merged.cutoff == "2025-02-01")
        #expect(merged.books == ["John": ["phone": 100, "tablet": 70]])
        #expect(merged.years == ["2024": 150])
        #expect(merged.streakRunAtCutoff == 5)
        #expect(merged.bestStreak == 8)
    }

    @Test
    func historyDayKeysParseAndCompareInCalendarOrder() throws {
        let date = try #require(StatsHistoryRetention.date(fromDayKey: "2026-02-03"))
        let components = Calendar.autoupdatingCurrent.dateComponents([.year, .month, .day], from: date)

        #expect(components.year == 2026)
        #expect(components.month == 2)
        #expect(components.day == 3)
        #expect(StatsHistoryRetention.isBeforeCutoff("2025-12-31", cutoff: "2026-01-01"))
        #expect(!StatsHistoryRetention.isBeforeCutoff("2026-01-01", cutoff: "2026-01-01"))
        #expect(StatsHistoryRetention.date(fromDayKey: "not-a-day") == nil)
    }

    @Test
    func bookOrderScopesUseCanonicalBoundariesAndRequestedRoundLengths() {
        #expect(BookOrderDifficulty.easy.runLength == 5)
        #expect(BookOrderDifficulty.normal.runLength == 10)
        #expect(BookOrderDifficulty.hard.runLength == 15)
        #expect(BookOrderDifficulty.all.runLength == nil)
        #expect(BookSourceScope.ot.bookNames.count == 39)
        #expect(BookSourceScope.nt.bookNames.count == 27)
        #expect(BookSourceScope.gospels.bookNames == ["Matthew", "Mark", "Luke", "John"])
        #expect(BookSourceScope.epistles.previewBookNames == ["Romans", "1 Corinthians", "2 Corinthians"])
    }

    @Test
    func colorSchemePreferencesExposeExpectedOverrides() {
        #expect(ColorSchemePreference.system.colorScheme == nil)
        #expect(ColorSchemePreference.light.colorScheme == .light)
        #expect(ColorSchemePreference.dark.colorScheme == .dark)
        #expect(ColorSchemePreference.allCases.map(\.id) == ["system", "light", "dark"])
    }
}
