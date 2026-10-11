import SwiftUI

/// Prayer timer stats for one moment in time, computed from the per-day totals.
struct PrayerStatsSummary {
    /// Seconds prayed on each day of the current week, Sunday first.
    var week: [(date: Date, seconds: Int)] = []
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var lastSessionSeconds: Int = 0

    var weekSeconds: Int { week.reduce(0) { $0 + $1.seconds } }
    var hasHistory: Bool { bestStreak > 0 || lastSessionSeconds > 0 }
}

extension Notification.Name {
    /// Posted when prayer stats change, locally or from another device.
    static let prayerStatsUpdated = Notification.Name("prayerStatsUpdated")
}

/// Time spent with the prayer timer counting down, per local day. Only active time
/// counts: paused time is left out, like the Apple Health mindful minutes.
///
/// Synced through iCloud key-value storage. Like reading time, each device records
/// under its own ID (day → device → seconds), so merging takes the larger value per
/// device and never double-counts. See `iCloudSyncCoordinator+Prayer`.
@MainActor
final class PrayerStatsStore {
    static let shared = PrayerStatsStore()
    private init() {}

    /// Seconds per day per device.
    typealias Contributions = [String: [String: Int]]

    /// The most recent session on any device; the latest one wins when merging.
    struct LastSession: Codable, Equatable {
        var seconds: Int
        var endedAt: Date
    }

    /// A day counts toward the prayer streak once this much time is recorded.
    static let minimumStreakSeconds = 60

    nonisolated static let contributionsKey = "prayerContributionsV1"
    nonisolated static let lastSessionKey = "prayerLastSessionV1"

    // Written by the first, device-only version; moved into the synced keys on first load.
    private let legacyDailyKey = "prayerDailySecondsV1"
    private let legacyLastSessionKey = "prayerLastSessionSeconds"

    private var defaults: UserDefaults { .standard }

    private var calendar: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        calendar.firstWeekday = 1
        return calendar
    }

    // MARK: - Storage

    func loadContributions() -> Contributions {
        migrateLegacyIfNeeded()
        guard let data = defaults.data(forKey: Self.contributionsKey) else { return [:] }
        return (try? JSONDecoder().decode(Contributions.self, from: data)) ?? [:]
    }

    func saveContributions(_ contributions: Contributions) {
        if let data = try? JSONEncoder().encode(contributions) {
            defaults.set(data, forKey: Self.contributionsKey)
        }
    }

    func loadLastSession() -> LastSession? {
        migrateLegacyIfNeeded()
        guard let data = defaults.data(forKey: Self.lastSessionKey) else { return nil }
        return try? JSONDecoder().decode(LastSession.self, from: data)
    }

    func saveLastSession(_ session: LastSession) {
        if let data = try? JSONEncoder().encode(session) {
            defaults.set(data, forKey: Self.lastSessionKey)
        }
    }

    /// Seconds per day, summed across devices.
    func dailySeconds() -> [String: Int] {
        loadContributions().mapValues { devices in devices.values.reduce(0) { $0 + max(0, $1) } }
    }

    private func migrateLegacyIfNeeded() {
        if let data = defaults.data(forKey: legacyDailyKey) {
            defaults.removeObject(forKey: legacyDailyKey)
            let legacy = (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
            var contributions = (defaults.data(forKey: Self.contributionsKey))
                .flatMap { try? JSONDecoder().decode(Contributions.self, from: $0) } ?? [:]
            let device = BibleStatsStore.shared.installationID
            for (day, seconds) in legacy where seconds > 0 {
                contributions[day, default: [:]][device, default: 0] += seconds
            }
            saveContributions(contributions)
        }
        if defaults.object(forKey: legacyLastSessionKey) != nil {
            let seconds = defaults.integer(forKey: legacyLastSessionKey)
            defaults.removeObject(forKey: legacyLastSessionKey)
            if seconds > 0, defaults.data(forKey: Self.lastSessionKey) == nil {
                saveLastSession(LastSession(seconds: seconds, endedAt: Date()))
            }
        }
    }

    // MARK: - Recording

    /// Adds the time between `start` and `end`, split at midnight so each day gets its share.
    func record(from start: Date, to end: Date) {
        guard end > start else { return }
        var contributions = loadContributions()
        let device = BibleStatsStore.shared.installationID
        var cursor = start
        while cursor < end {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: cursor)) ?? end
            let segmentEnd = min(end, nextDay)
            let key = BibleStatsStore.isoDateString(cursor, calendar: calendar)
            contributions[key, default: [:]][device, default: 0] += Int(segmentEnd.timeIntervalSince(cursor).rounded())
            cursor = segmentEnd
        }
        saveContributions(contributions)
        iCloudSyncCoordinator.shared.pushKey(Self.contributionsKey)
        NotificationCenter.default.post(name: .prayerStatsUpdated, object: nil)
    }

    func recordSessionEnded(seconds: Int, at date: Date = Date()) {
        guard seconds > 0 else { return }
        saveLastSession(LastSession(seconds: seconds, endedAt: date))
        iCloudSyncCoordinator.shared.pushKey(Self.lastSessionKey)
        NotificationCenter.default.post(name: .prayerStatsUpdated, object: nil)
    }

    /// Clears this device's copy only. Use `iCloudSyncCoordinator.resetAllBibleStatsAndSessions()`
    /// to clear every device.
    func clearLocal() {
        defaults.removeObject(forKey: Self.contributionsKey)
        defaults.removeObject(forKey: Self.lastSessionKey)
        defaults.removeObject(forKey: legacyDailyKey)
        defaults.removeObject(forKey: legacyLastSessionKey)
        NotificationCenter.default.post(name: .prayerStatsUpdated, object: nil)
    }

    // MARK: - Merging

    /// Combines two copies, keeping the larger value for each day and device.
    nonisolated static func merged(_ a: Contributions, _ b: Contributions) -> Contributions {
        var result = a
        for (day, devices) in b {
            for (device, seconds) in devices {
                result[day, default: [:]][device] = max(result[day]?[device] ?? 0, max(0, seconds))
            }
        }
        return result
    }

    /// The session that ended most recently.
    nonisolated static func newer(_ a: LastSession?, _ b: LastSession?) -> LastSession? {
        switch (a, b) {
        case let (a?, b?): a.endedAt >= b.endedAt ? a : b
        case let (a?, nil): a
        case let (nil, b): b
        }
    }

    // MARK: - Summary

    func summary(now: Date = Date()) -> PrayerStatsSummary {
        let totals = dailySeconds()
        let cal = calendar
        let today = cal.startOfDay(for: now)
        var summary = PrayerStatsSummary()
        summary.lastSessionSeconds = loadLastSession()?.seconds ?? 0

        if let interval = cal.dateInterval(of: .weekOfYear, for: now) {
            summary.week = (0..<7).compactMap { offset in
                guard let date = cal.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
                return (date, totals[BibleStatsStore.isoDateString(date, calendar: cal), default: 0])
            }
        }

        func prayed(on date: Date) -> Bool {
            totals[BibleStatsStore.isoDateString(date, calendar: cal), default: 0] >= Self.minimumStreakSeconds
        }

        // Current streak: today counts once prayed; until then the streak runs through yesterday.
        var day = today
        if !prayed(on: day) {
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        while prayed(on: day) {
            summary.currentStreak += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }

        // Best streak over every recorded day.
        let prayedDays = totals
            .filter { $0.value >= Self.minimumStreakSeconds }
            .compactMap { StatsHistoryRetention.date(fromDayKey: $0.key, calendar: cal) }
            .map { cal.startOfDay(for: $0) }
            .sorted()
        var run = 0
        var previous: Date?
        for date in prayedDays {
            if let previous, cal.dateComponents([.day], from: previous, to: date).day == 1 {
                run += 1
            } else {
                run = 1
            }
            summary.bestStreak = max(summary.bestStreak, run)
            previous = date
        }

        return summary
    }
}

/// "45 min", or "1 hr 5 min" for longer totals.
func prayerMinutesText(_ seconds: Int) -> String {
    let minutes = max(0, seconds) / 60
    let hours = minutes / 60
    let rest = minutes % 60
    if hours == 0 { return "\(minutes) min" }
    if rest == 0 { return "\(hours) hr" }
    return "\(hours) hr \(rest) min"
}

/// Prayer stats for the Stats screen.
struct PrayerStatsCard: View {
    private let weekdaySymbols = ["S", "M", "T", "W", "Th", "F", "Sa"]

    /// Bumped when prayer stats change so the summary is recomputed.
    @State private var revision = 0

    var body: some View {
        let _ = revision
        let summary = PrayerStatsStore.shared.summary()
        let maxSeconds = max(60, summary.week.map(\.seconds).max() ?? 0)

        HeroCard(
            title: "Prayer",
            subtitle: nil,
            icon: "hands.sparkles.fill",
            tint: .indigo
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 10) {
                    metric("This Week", value: prayerMinutesText(summary.weekSeconds), systemImage: "clock.fill")
                    metric("Streak", value: summary.currentStreak == 1 ? "1 day" : "\(summary.currentStreak) days", systemImage: "flame.fill")
                    metric("Best", value: summary.bestStreak == 1 ? "1 day" : "\(summary.bestStreak) days", systemImage: "trophy.fill")
                }

                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(summary.week.enumerated()), id: \.offset) { index, day in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.indigo.opacity(day.seconds > 0 ? 0.8 : 0.15))
                                .frame(height: max(4, 64 * CGFloat(day.seconds) / CGFloat(maxSeconds)))
                            Text(weekdaySymbols[index])
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            "\(day.date.formatted(.dateTime.weekday(.wide))), \(prayerMinutesText(day.seconds)) of prayer"
                        )
                    }
                }
                .frame(height: 84, alignment: .bottom)

                if summary.lastSessionSeconds > 0 {
                    Label("Last session: \(prayerMinutesText(summary.lastSessionSeconds))", systemImage: "clock.arrow.circlepath")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Start the Prayer Timer on Home to track your prayer time here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .prayerStatsUpdated)) { _ in
            revision += 1
        }
    }

    private func metric(_ title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: AppDesignMetrics.compactControlCornerRadius, style: .continuous)
                .fill(Color.indigo.opacity(0.08))
        }
        .accessibilityElement(children: .combine)
    }
}
