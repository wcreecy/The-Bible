import Foundation

/// Records foreground time spent in the Study Bible and Chapter Insights views.
/// Overlapping study views share one active session, so time is never counted twice.
@MainActor
final class StudyTimeTracker {
    static let shared = StudyTimeTracker()

    private static let dailyTotalsKey = "studyTimeDailyTotals"
    private let persistInterval: Duration = .seconds(15)

    private var activeSources: Set<UUID> = []
    private var isApplicationActive = true
    private var checkpointDate: Date?
    private var tickerTask: Task<Void, Never>?

    private init() {}

    func start(_ source: UUID) {
        guard activeSources.insert(source).inserted else { return }
        guard isApplicationActive, activeSources.count == 1 else { return }
        beginSession()
    }

    func stop(_ source: UUID) {
        guard activeSources.remove(source) != nil else { return }
        guard activeSources.isEmpty else { return }
        endSession()
    }

    func setApplicationActive(_ isActive: Bool) {
        guard isApplicationActive != isActive else { return }
        isApplicationActive = isActive

        if isActive, !activeSources.isEmpty {
            beginSession()
        } else {
            endSession()
        }
    }

    func seconds(on date: Date = .now) -> Int {
        dailyTotals()[Self.dayKey(for: date), default: 0]
    }

    var allTimeSeconds: Int {
        dailyTotals().values.reduce(0, +)
    }

    private func beginSession() {
        guard checkpointDate == nil else { return }
        checkpointDate = .now
        startTicker()
    }

    private func endSession() {
        recordElapsed()
        checkpointDate = nil
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func startTicker() {
        guard tickerTask == nil else { return }

        let persistInterval = persistInterval
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: persistInterval)
                } catch {
                    return
                }

                guard let self else { return }
                self.recordElapsed()
            }
        }
    }

    private func recordElapsed(now: Date = .now) {
        guard let start = checkpointDate else { return }

        let elapsed = Int(now.timeIntervalSince(start))
        guard elapsed > 0 else { return }

        let end = start.addingTimeInterval(TimeInterval(elapsed))
        checkpointDate = end

        var totals = dailyTotals()
        for allocation in Self.dailyAllocations(seconds: elapsed, from: start, to: end) {
            totals[Self.dayKey(for: allocation.date), default: 0] += allocation.seconds
        }

        UserDefaults.standard.set(totals, forKey: Self.dailyTotalsKey)
        NotificationCenter.default.post(name: .studyTimeUpdated, object: nil)
    }

    private func dailyTotals() -> [String: Int] {
        UserDefaults.standard.dictionary(forKey: Self.dailyTotalsKey) as? [String: Int] ?? [:]
    }

    private static func dayKey(for date: Date) -> String {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        return BibleStatsStore.isoDateString(date, calendar: calendar)
    }

    private static func dailyAllocations(
        seconds: Int,
        from start: Date,
        to end: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [(date: Date, seconds: Int)] {
        guard seconds > 0 else { return [] }

        var intervals: [(start: Date, end: Date)] = []
        var cursor = start
        while let nextDay = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: cursor)
        ), nextDay < end {
            intervals.append((cursor, nextDay))
            cursor = nextDay
        }
        intervals.append((cursor, end))

        guard intervals.count > 1 else { return [(start, seconds)] }

        let totalDuration = max(end.timeIntervalSince(start), 0.001)
        var remainingSeconds = seconds

        return intervals.enumerated().compactMap { index, interval in
            let allocation: Int
            if index == intervals.index(before: intervals.endIndex) {
                allocation = remainingSeconds
            } else {
                let fraction = interval.end.timeIntervalSince(interval.start) / totalDuration
                allocation = min(
                    remainingSeconds,
                    max(0, Int((Double(seconds) * fraction).rounded()))
                )
            }

            remainingSeconds -= allocation
            return allocation > 0 ? (interval.start, allocation) : nil
        }
    }
}
