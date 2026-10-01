import Combine
import Foundation

@MainActor
final class ReadingTimeTracker: ObservableObject {
    static let shared = ReadingTimeTracker()

    @Published private(set) var lastTotalsVersion: Int = 0

    private let clock = ContinuousClock()
    private let persistInterval: TimeInterval = 15

    private var currentBook: String?
    private var currentChapterNumber: Int?
    private var readingSessionID: UUID?
    private var segmentStartDate: Date?
    private var checkpointDate: Date?
    private var checkpointInstant: ContinuousClock.Instant?
    private var fractionalSeconds: Double = 0
    private var segmentRecordedSeconds: Int = 0
    private var unpersistedSeconds: Int = 0
    private var unpersistedStartDate: Date?
    private var tickerTask: Task<Void, Never>?
    private var lastPersist: Date = .distantPast

    private(set) var isPaused = false

    private init() {}

    func start(bookName: String, chapter: Int? = nil) {
        guard !bookName.isEmpty else { return }

        if currentBook == bookName {
            if let chapter, chapter != currentChapterNumber {
                changeLocation(to: bookName, chapter: chapter)
            }
            return
        }

        closeActiveSegment()
        currentBook = bookName
        currentChapterNumber = chapter
        readingSessionID = UUID()
        isPaused = false
        beginActiveSegment()
    }

    func changeBook(to bookName: String, chapter: Int? = nil) {
        guard !bookName.isEmpty else { return }
        changeLocation(to: bookName, chapter: chapter)
    }

    func setCurrentLocation(bookName: String, chapter: Int) {
        guard currentBook != bookName || currentChapterNumber != chapter else { return }
        changeLocation(to: bookName, chapter: chapter)
    }

    func stopAndFlush() {
        closeActiveSegment()
        stopTicker()
        currentBook = nil
        currentChapterNumber = nil
        readingSessionID = nil
        isPaused = false
    }

    func pause() {
        guard !isPaused else { return }
        closeActiveSegment()
        stopTicker()
        isPaused = true
    }

    func resume() {
        guard isPaused, currentBook != nil else { return }
        isPaused = false
        beginActiveSegment()
    }

    private func changeLocation(to bookName: String, chapter: Int?) {
        let wasActive = !isPaused
        closeActiveSegment()
        currentBook = bookName
        currentChapterNumber = chapter

        if wasActive {
            beginActiveSegment()
        }
    }

    private func beginActiveSegment(at date: Date = Date()) {
        guard currentBook != nil, !isPaused else { return }
        segmentStartDate = date
        checkpointDate = date
        checkpointInstant = clock.now
        fractionalSeconds = 0
        segmentRecordedSeconds = 0
        unpersistedSeconds = 0
        unpersistedStartDate = date
        lastPersist = date
        startTickerIfNeeded()
    }

    private func startTickerIfNeeded() {
        guard tickerTask == nil, !isPaused else { return }
        let clock = clock
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await clock.sleep(for: .seconds(1))
                } catch {
                    return
                }

                guard let self else { return }
                self.tick()
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func tick() {
        recordElapsed()
    }

    private func recordElapsed(nowDate: Date = Date()) {
        guard let book = currentBook,
              checkpointDate != nil,
              let previousInstant = checkpointInstant,
              !isPaused else { return }

        let nowInstant = clock.now
        fractionalSeconds += Self.seconds(in: previousInstant.duration(to: nowInstant))
        let wholeSeconds = Int(fractionalSeconds.rounded(.down))
        fractionalSeconds -= Double(wholeSeconds)
        checkpointDate = nowDate
        checkpointInstant = nowInstant

        guard wholeSeconds > 0 else { return }
        segmentRecordedSeconds += wholeSeconds
        unpersistedSeconds += wholeSeconds

        if nowDate.timeIntervalSince(lastPersist) >= persistInterval {
            persistPending(bookName: book, through: nowDate)
            lastPersist = nowDate
            lastTotalsVersion &+= 1
        }
    }

    private func closeActiveSegment() {
        guard let book = currentBook,
              let start = segmentStartDate else {
            clearSegmentState()
            return
        }

        recordElapsed()
        persistPending(bookName: book, through: checkpointDate ?? Date())
        if segmentRecordedSeconds >= ReadingSessionsStore.minimumValidSessionSeconds {
            let activeEnd = start.addingTimeInterval(TimeInterval(segmentRecordedSeconds))
            for interval in Self.splitAtMidnight(from: start, to: activeEnd) {
                ReadingSessionsStore.shared.appendSession(.init(
                    readingSessionID: readingSessionID,
                    start: interval.start,
                    end: interval.end,
                    book: book,
                    chapter: currentChapterNumber
                ))
            }
        }

        if segmentRecordedSeconds > 0, let chapter = currentChapterNumber {
            BibleStatsStore.shared.saveLastRead(bookName: book, chapterNumber: chapter, date: Date())
            lastTotalsVersion &+= 1
        }
        clearSegmentState()
    }

    private func clearSegmentState() {
        segmentStartDate = nil
        checkpointDate = nil
        checkpointInstant = nil
        fractionalSeconds = 0
        segmentRecordedSeconds = 0
        unpersistedSeconds = 0
        unpersistedStartDate = nil
    }

    private func persistPending(bookName: String, through end: Date) {
        guard unpersistedSeconds > 0, let start = unpersistedStartDate else { return }
        persist(seconds: unpersistedSeconds, bookName: bookName, from: start, to: end)
        unpersistedSeconds = 0
        unpersistedStartDate = end
    }

    private func persist(seconds: Int, bookName: String, from start: Date, to end: Date) {
        for allocation in Self.dailyAllocations(seconds: seconds, from: start, to: end) {
            BibleStatsStore.shared.addReadingTime(bookName: bookName, seconds: allocation.seconds, on: allocation.date)
        }
    }

    private static func seconds(in duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    static func dailyAllocations(
        seconds: Int,
        from start: Date,
        to end: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [(date: Date, seconds: Int)] {
        guard seconds > 0 else { return [] }
        let intervals = splitAtMidnight(from: start, to: end, calendar: calendar)
        guard intervals.count > 1 else { return [(start, seconds)] }

        let wallDuration = max(end.timeIntervalSince(start), 0.001)
        var remaining = seconds
        return intervals.enumerated().map { index, interval in
            let allocated: Int
            if index == intervals.index(before: intervals.endIndex) {
                allocated = remaining
            } else {
                let fraction = interval.end.timeIntervalSince(interval.start) / wallDuration
                allocated = min(remaining, max(0, Int((Double(seconds) * fraction).rounded())))
            }
            remaining -= allocated
            return (interval.start, allocated)
        }.filter { $0.seconds > 0 }
    }

    static func splitAtMidnight(
        from start: Date,
        to end: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [(start: Date, end: Date)] {
        guard end > start else { return [] }
        let cal = calendar
        var intervals: [(Date, Date)] = []
        var cursor = start

        while let nextDay = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: cursor)), nextDay < end {
            intervals.append((cursor, nextDay))
            cursor = nextDay
        }
        intervals.append((cursor, end))
        return intervals
    }
}
