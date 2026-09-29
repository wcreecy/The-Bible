import Testing
@testable import The_Bible__iOS_

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
}
