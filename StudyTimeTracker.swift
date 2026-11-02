import Foundation

/// Records foreground time spent in the Study Bible and Chapter Insights views.
/// Overlapping study views share one active session, so time is never counted twice.
/// Time stops counting five minutes after the last touch (see `UserActivityMonitor`).
///
/// Synced through iCloud key-value storage like prayer time: each device records under its
/// own ID (day → device → seconds), so merging keeps the larger value per device and never
/// double-counts. See `iCloudSyncCoordinator+Prayer`.
@MainActor
final class StudyTimeTracker {
    static let shared = StudyTimeTracker()

    /// Seconds per day per device.
    typealias Contributions = [String: [String: Int]]

    static let contributionsKey = "studyTimeContributionsV1"
    /// Device-only daily totals written by earlier versions; moved into this device's
    /// contributions on first load.
    private static let legacyDailyTotalsKey = "studyTimeDailyTotals"
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
        guard let checkpoint = checkpointDate else { return }

        let span = UserActivityMonitor.shared.countedSpan(since: checkpoint, now: now)
        checkpointDate = span.nextCheckpoint
        guard span.seconds > 0 else { return }

        let end = span.start.addingTimeInterval(TimeInterval(span.seconds))
        add(Self.dailyAllocations(seconds: span.seconds, from: span.start, to: end))
    }

    /// Adds study time to this device's daily totals, keeping any time already recorded.
    func add(_ allocations: [(date: Date, seconds: Int)]) {
        var contributions = loadContributions()
        let device = BibleStatsStore.shared.installationID
        for allocation in allocations where allocation.seconds > 0 {
            contributions[Self.dayKey(for: allocation.date), default: [:]][device, default: 0] += allocation.seconds
        }

        saveContributions(contributions)
        iCloudSyncCoordinator.shared.pushKey(Self.contributionsKey)
    }

    /// Removes all recorded study time on this device. An active session keeps counting from now.
    /// The reading stats reset calls this through `iCloudSyncCoordinator.clearPrayerStats()`,
    /// which also removes the iCloud copy.
    func clearAll() {
        if checkpointDate != nil {
            checkpointDate = .now
        }
        UserDefaults.standard.removeObject(forKey: Self.contributionsKey)
        UserDefaults.standard.removeObject(forKey: Self.legacyDailyTotalsKey)
        NotificationCenter.default.post(name: .studyTimeUpdated, object: nil)
    }

    // MARK: - Storage

    func loadContributions() -> Contributions {
        migrateLegacyTotalsIfNeeded()
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Self.contributionsKey) else { return [:] }
        return PersistedDecoding.decode(
            Contributions.self,
            from: data,
            key: Self.contributionsKey,
            keepingUnreadableIn: defaults
        ) ?? [:]
    }

    /// Saves contributions, including ones merged from another device.
    func saveContributions(_ contributions: Contributions) {
        if let data = try? JSONEncoder().encode(contributions) {
            UserDefaults.standard.set(data, forKey: Self.contributionsKey)
        }
        NotificationCenter.default.post(name: .studyTimeUpdated, object: nil)
    }

    /// Seconds per day, summed across devices.
    private func dailyTotals() -> [String: Int] {
        loadContributions().mapValues { devices in devices.values.reduce(0) { $0 + max(0, $1) } }
    }

    /// Moves the device-only totals of earlier versions into this device's contributions.
    private func migrateLegacyTotalsIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Self.legacyDailyTotalsKey) != nil else { return }

        let legacy = Self.legacyDailyTotals(in: defaults)
        defaults.removeObject(forKey: Self.legacyDailyTotalsKey)
        guard !legacy.isEmpty else { return }

        var contributions = defaults.data(forKey: Self.contributionsKey).flatMap {
            PersistedDecoding.decode(Contributions.self, from: $0, key: Self.contributionsKey, keepingUnreadableIn: defaults)
        } ?? [:]
        let device = BibleStatsStore.shared.installationID
        for (day, seconds) in legacy where seconds > 0 {
            contributions[day, default: [:]][device, default: 0] += seconds
        }
        if let data = try? JSONEncoder().encode(contributions) {
            defaults.set(data, forKey: Self.contributionsKey)
        }
        iCloudSyncCoordinator.shared.pushKey(Self.contributionsKey)
    }

    private static func legacyDailyTotals(in defaults: UserDefaults) -> [String: Int] {
        if let data = defaults.data(forKey: legacyDailyTotalsKey),
           let totals = try? JSONDecoder().decode([String: Int].self, from: data) {
            return totals
        }

        // The oldest versions stored a property list.
        guard let storedTotals = defaults.dictionary(forKey: legacyDailyTotalsKey) else {
            return [:]
        }
        return storedTotals.reduce(into: [String: Int]()) { totals, entry in
            if let seconds = entry.value as? Int {
                totals[entry.key] = seconds
            } else if let number = entry.value as? NSNumber {
                totals[entry.key] = number.intValue
            }
        }
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
