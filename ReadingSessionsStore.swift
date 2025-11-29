import Foundation

// Stores lightweight reading sessions to support time-of-day charts and average session length.
final class ReadingSessionsStore {
    static let shared = ReadingSessionsStore()
    private init() {}

    struct Session: Codable, Equatable {
        let start: Date
        let end: Date
        let book: String
        let chapter: Int?
    }

    private struct Defaults {
        static let key = "readingSessions"
        static var provider: UserDefaults { UserDefaults.standard }
    }

    // Keep a rolling window to prevent unbounded growth (e.g., 180 days)
    private let maxRetentionDays: Int = 180

    func appendSession(_ session: Session) {
        var all = loadAll()
        all.append(session)
        // Prune older than retention window
        let cutoff = Calendar.current.date(byAdding: .day, value: -maxRetentionDays, to: Date()) ?? Date.distantPast
        all = all.filter { $0.end >= cutoff }
        saveAll(all)
    }

    func sessions(inLastDays days: Int, now: Date = Date(), calendar: Calendar = .current) -> [Session] {
        guard days > 0 else { return [] }
        let cutoff = calendar.date(byAdding: .day, value: -days, to: now) ?? Date.distantPast
        return loadAll().filter { $0.end >= cutoff }
    }

    func sessions(inMonthContaining date: Date, calendar: Calendar = .current) -> [Session] {
        let cal = calendar
        let comps = cal.dateComponents([.year, .month], from: date)
        guard let start = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: start),
              let monthEnd = cal.date(byAdding: .day, value: range.count, to: start) else {
            return []
        }
        return loadAll().filter { $0.end >= start && $0.end < monthEnd }
    }

    // MARK: - Persistence

    private func loadAll() -> [Session] {
        let defaults = Defaults.provider
        guard let data = defaults.data(forKey: Defaults.key) else { return [] }
        if let arr = try? JSONDecoder().decode([Session].self, from: data) {
            return arr
        }
        return []
    }

    private func saveAll(_ arr: [Session]) {
        let defaults = Defaults.provider
        if let data = try? JSONEncoder().encode(arr) {
            defaults.set(data, forKey: Defaults.key)
        }
    }
}

