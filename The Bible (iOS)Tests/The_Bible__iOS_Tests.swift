import Foundation
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
        try await Task.sleep(nanoseconds: 40_000_000)

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
        try await Task.sleep(nanoseconds: 20_000_000)

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
        try await Task.sleep(nanoseconds: 40_000_000)
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
        let sessions = (0..<3_000).map { index in
            let start = Date(timeIntervalSince1970: TimeInterval(index * 60))
            return ReadingSessionsStore.Session(
                start: start,
                end: start.addingTimeInterval(30),
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
}
