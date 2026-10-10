import Foundation

/// How much per-day history is kept in synced storage. iCloud key-value storage is capped
/// at 1 MB, so per-day records older than this are folded into running totals or dropped.
enum StatsHistoryRetention {
    static let retainedMonths = 24

    /// The first day still kept per day, as a `yyyy-MM-dd` key: the 1st of the month
    /// `retainedMonths` ago. It moves once a month, so archives change rarely.
    static func cutoffDayKey(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> String {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        let cutoff = cal.date(byAdding: .month, value: -retainedMonths, to: monthStart) ?? monthStart
        return BibleStatsStore.isoDateString(cutoff, calendar: cal)
    }

    /// Day keys are zero-padded `yyyy-MM-dd`, so text order is date order.
    static func isBeforeCutoff(_ dayKey: String, cutoff: String) -> Bool {
        !cutoff.isEmpty && dayKey < cutoff
    }

    static func date(fromDayKey key: String, calendar: Calendar = .autoupdatingCurrent) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        return cal.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}

/// Reading history older than the retention cutoff, kept as running totals so all-time
/// numbers stay exact after the per-day records are removed.
///
/// Every value is merged by maximum. Each one is a sum of real reading, and a copy built
/// from more complete data is never smaller, so the larger value is the better one.
struct ReadingHistoryArchive: Codable, Equatable {
    /// Days before this `yyyy-MM-dd` key are included here instead of stored per day.
    var cutoff: String = ""
    /// Seconds per book per device, matching the per-day contributions' layout.
    var books: [String: [String: Int]] = [:]
    /// Seconds per calendar year ("2024"), for the yearly All-time chart.
    var years: [String: Int] = [:]
    /// Days in a row the daily goal was met, ending the day before `cutoff`.
    var streakRunAtCutoff: Int = 0
    /// Longest goal streak among archived days.
    var bestStreak: Int = 0

    typealias Contributions = BibleStatsStore.ReadingContributions

    var isEmpty: Bool { cutoff.isEmpty }

    /// Seconds per book, summed across devices.
    var bookTotals: [String: Int] {
        books.mapValues { devices in devices.values.reduce(0) { $0 + max(0, $1) } }
    }

    /// Moves days before `target` (or the current cutoff, if later) from `contributions`
    /// into the archive. Days already before the existing cutoff were folded earlier and
    /// are only removed. Returns whether anything changed.
    @MainActor
    @discardableResult
    mutating func fold(
        _ contributions: inout Contributions,
        upTo target: String,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Bool {
        let newCutoff = max(target, cutoff)
        let oldDays = contributions.keys.filter { $0 < newCutoff }
        guard !oldDays.isEmpty || (!isEmpty && newCutoff > cutoff) else { return false }

        var foldedDailyTotals: [String: Int] = [:]
        for day in oldDays {
            let dayBooks = contributions.removeValue(forKey: day) ?? [:]
            guard !StatsHistoryRetention.isBeforeCutoff(day, cutoff: cutoff) else { continue }
            for (book, devices) in dayBooks {
                for (device, seconds) in devices where seconds > 0 {
                    books[book, default: [:]][device, default: 0] += seconds
                    years[String(day.prefix(4)), default: 0] += seconds
                    foldedDailyTotals[day, default: 0] += seconds
                }
            }
        }

        // Continue the goal streak through the newly archived days.
        let walkStart = isEmpty ? (foldedDailyTotals.keys.min() ?? newCutoff) : cutoff
        if var day = StatsHistoryRetention.date(fromDayKey: walkStart, calendar: calendar),
           let end = StatsHistoryRetention.date(fromDayKey: newCutoff, calendar: calendar) {
            var run = isEmpty ? 0 : streakRunAtCutoff
            var best = max(bestStreak, run)
            while day < end {
                if StreakTracker.isGoalMet(on: day, dailyTotals: foldedDailyTotals, calendar: calendar) {
                    run += 1
                    best = max(best, run)
                } else {
                    run = 0
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
            streakRunAtCutoff = run
            bestStreak = best
        }

        cutoff = newCutoff
        return true
    }

    /// Combines this device's archive with one from iCloud. The earlier archive is first
    /// brought up to the later cutoff using this device's per-day records, then each
    /// value keeps the larger copy.
    @MainActor
    static func merged(
        local: ReadingHistoryArchive,
        remote: ReadingHistoryArchive,
        localContributions: inout Contributions,
        calendar: Calendar = .autoupdatingCurrent
    ) -> ReadingHistoryArchive {
        let target = max(local.cutoff, remote.cutoff)
        var local = local
        var remote = remote
        // Both copies are brought forward; `fold` removes the days it uses, so only the
        // first call sees them, and the second just advances its cutoff.
        local.fold(&localContributions, upTo: target, calendar: calendar)
        var noDays: Contributions = [:]
        remote.fold(&noDays, upTo: target, calendar: calendar)

        var result = ReadingHistoryArchive(cutoff: target)
        for archive in [local, remote] {
            for (book, devices) in archive.books {
                for (device, seconds) in devices {
                    result.books[book, default: [:]][device] = max(result.books[book]?[device] ?? 0, seconds)
                }
            }
            for (year, seconds) in archive.years {
                result.years[year] = max(result.years[year] ?? 0, seconds)
            }
            result.streakRunAtCutoff = max(result.streakRunAtCutoff, archive.streakRunAtCutoff)
            result.bestStreak = max(result.bestStreak, archive.bestStreak)
        }
        return result
    }
}

@MainActor
extension BibleStatsStore {
    func loadReadingHistoryArchive() -> ReadingHistoryArchive? {
        let archive = loadJSON(key: Defaults.keyReadingHistoryArchive, default: ReadingHistoryArchive())
        return archive.isEmpty ? nil : archive
    }

    func saveReadingHistoryArchive(_ archive: ReadingHistoryArchive) {
        saveJSON(archive, key: Defaults.keyReadingHistoryArchive)
    }

    /// Folds reading history older than the retention cutoff into the archive and syncs
    /// both records if anything moved. Safe to call often; it only does work once a month.
    func compactReadingHistoryIfNeeded(now: Date = Date()) {
        guard Defaults.provider.data(forKey: Defaults.keyReadingContributions) != nil else { return }
        var contributions = loadReadingContributions()
        var archive = loadReadingHistoryArchive() ?? ReadingHistoryArchive()
        guard archive.fold(&contributions, upTo: StatsHistoryRetention.cutoffDayKey(now: now)) else { return }

        saveReadingHistoryArchive(archive)
        cacheReadingContributions = contributions
        saveJSON(contributions, key: Defaults.keyReadingContributions)
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyReadingHistoryArchive)
        iCloudSyncCoordinator.shared.pushKey(Defaults.keyReadingContributions)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    /// Removes days already covered by the archive from merged contributions, and folds
    /// any days that have since aged past the cutoff.
    func compactedContributions(_ contributions: ReadingContributions) -> ReadingContributions {
        var contributions = contributions
        guard var archive = loadReadingHistoryArchive() else {
            // No archive yet: nothing to drop until this device compacts.
            return contributions
        }
        if archive.fold(&contributions, upTo: StatsHistoryRetention.cutoffDayKey()) {
            saveReadingHistoryArchive(archive)
            iCloudSyncCoordinator.shared.pushKey(Defaults.keyReadingHistoryArchive)
        }
        return contributions
    }

    /// Archived seconds per book, for all-time totals.
    func archivedBookTotals() -> [String: Int] {
        loadReadingHistoryArchive()?.bookTotals ?? [:]
    }
}
