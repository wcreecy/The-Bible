import Foundation
import SwiftUI

struct StatsSeriesBuilder {
    enum Aggregation { case daily, weekly, monthly, yearly }

    // Buckets daily totals for the last N days, aligned to startOfDay, inclusive of today.
    static func dailySeries(lastNDays: Int, now: Date, calendar: Calendar) -> [(date: Date, seconds: Int)] {
        guard lastNDays > 0 else { return [] }
        let sessions = ReadingSessionsStore.shared.sessions(inLastDays: lastNDays, now: now, calendar: calendar)
        var buckets: [String: Int] = [:]
        for s in sessions {
            let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
            let key = BibleStatsStore.isoDateString(s.end, calendar: calendar)
            buckets[key, default: 0] += dur
        }
        let series: [(Date, Int)] = (0..<lastNDays).compactMap { i -> (Date, Int)? in
            guard let d = calendar.date(byAdding: .day, value: -(lastNDays - 1 - i), to: calendar.startOfDay(for: now)) else { return nil }
            let key = BibleStatsStore.isoDateString(d, calendar: calendar)
            return (d, buckets[key, default: 0])
        }
        return series
    }

    // Buckets daily totals for the month containing a given date.
    static func dailySeriesForMonth(containing date: Date, calendar: Calendar) -> [(date: Date, seconds: Int)] {
        var cal = Calendar.autoupdatingCurrent
        cal.timeZone = TimeZone.autoupdatingCurrent

        let sessions = ReadingSessionsStore.shared.sessions(inMonthContaining: date, calendar: cal)

        var buckets: [String: Int] = [:]
        for s in sessions {
            let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
            let key = BibleStatsStore.isoDateString(s.end, calendar: cal)
            buckets[key, default: 0] += dur
        }

        let comps = cal.dateComponents([.year, .month], from: date)
        guard
            let startOfMonth = cal.date(from: comps),
            let startOfNextMonth = cal.date(byAdding: .month, value: 1, to: startOfMonth)
        else {
            return []
        }

        var series: [(Date, Int)] = []
        var cursor = startOfMonth
        while cursor < startOfNextMonth {
            let key = BibleStatsStore.isoDateString(cursor, calendar: cal)
            let seconds = buckets[key, default: 0]
            series.append((cursor, seconds))
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return series
    }

    // Aggregates all-time sessions monthly or yearly based on span.
    static func allTimeAggregatedSeries(calendar: Calendar) -> (series: [(date: Date, seconds: Int)], aggregation: Aggregation) {
        let sessions = ReadingSessionsStore.shared.sessions(inLastDays: 1825, now: Date(), calendar: calendar)
        guard !sessions.isEmpty else { return ([], .daily) }

        let ends = sessions.map { $0.end }
        let now = Date()
        let start = calendar.startOfDay(for: ends.min() ?? now)
        let end = calendar.startOfDay(for: now)

        let monthsSpan = calendar.dateComponents([.month], from: start, to: end).month ?? 0
        let aggregation: Aggregation = (monthsSpan <= 12) ? .monthly : .yearly

        func bucketStart(for date: Date) -> Date {
            switch aggregation {
            case .monthly:
                let comps = calendar.dateComponents([.year, .month], from: date)
                return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
            case .yearly:
                let comps = calendar.dateComponents([.year], from: date)
                return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
            default:
                return calendar.startOfDay(for: date)
            }
        }

        var buckets: [Date: Int] = [:]
        for s in sessions {
            let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
            let key = bucketStart(for: s.end)
            buckets[key, default: 0] += dur
        }

        var series: [(Date, Int)] = []
        var cursor: Date = {
            switch aggregation {
            case .monthly:
                let comps = calendar.dateComponents([.year, .month], from: start)
                return calendar.date(from: comps) ?? start
            case .yearly:
                let comps = calendar.dateComponents([.year], from: start)
                return calendar.date(from: comps) ?? start
            default:
                return start
            }
        }()

        func step(_ date: Date) -> Date {
            switch aggregation {
            case .monthly: return calendar.date(byAdding: .month, value: 1, to: date) ?? date
            case .yearly: return calendar.date(byAdding: .year, value: 1, to: date) ?? date
            default: return date
            }
        }

        while cursor <= end {
            let val = buckets[cursor, default: 0]
            series.append((cursor, val))
            cursor = step(cursor)
        }

        if aggregation == .monthly {
            let maxMonths = (monthsSpan <= 6) ? 6 : 12
            if series.count > maxMonths {
                series = Array(series.suffix(maxMonths))
            }
        }

        if aggregation == .yearly {
            let maxYears = 10
            if series.count > maxYears {
                series = Array(series.suffix(maxYears))
            }
        }

        return (series, aggregation)
    }

    // Average length of sessions (seconds) with pre-filtering done by caller if needed.
    static func averageSessionLength(sessions: [ReadingSessionsStore.Session], minSessionSeconds: Int) -> Int {
        let filtered = sessions.filter { Int(max(0, $0.end.timeIntervalSince($0.start))) >= minSessionSeconds }
        guard !filtered.isEmpty else { return 0 }
        let total = filtered.reduce(0) { $0 + Int(max(0, $1.end.timeIntervalSince($1.start))) }
        return total / filtered.count
    }

    // Groups seconds per book from a list of sessions.
    static func groupSessionsByBook(_ sessions: [ReadingSessionsStore.Session]) -> [String: Int] {
        var map: [String: Int] = [:]
        for s in sessions {
            let dur = Int(max(0, s.end.timeIntervalSince(s.start)))
            guard dur > 0 else { continue }
            let name = s.book.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            map[name, default: 0] += dur
        }
        return map
    }

    enum Genre: String, CaseIterable, Identifiable {
        case Law = "Law"
        case History = "History"
        case Poetry = "Poetry"
        case MajorProphets = "Major Prophets"
        case MinorProphets = "Minor Prophets"
        case Gospels = "Gospels"
        case Acts = "Acts"
        case Epistles = "Epistles"
        case Apocalypse = "Apocalypse"

        var id: String { rawValue }
    }

    static func genreForBook(_ book: String) -> Genre {
        switch book {
        case "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy":
            return .Law
        case "Joshua", "Judges", "Ruth",
             "1 Samuel", "2 Samuel",
             "1 Kings", "2 Kings",
             "1 Chronicles", "2 Chronicles",
             "Ezra", "Nehemiah", "Esther":
            return .History
        case "Job", "Psalms", "Proverbs", "Ecclesiastes", "Song of Solomon":
            return .Poetry
        case "Isaiah", "Jeremiah", "Lamentations", "Ezekiel", "Daniel":
            return .MajorProphets
        case "Hosea", "Joel", "Amos", "Obadiah", "Jonah",
             "Micah", "Nahum", "Habakkuk", "Zephaniah",
             "Haggai", "Zechariah", "Malachi":
            return .MinorProphets
        case "Matthew", "Mark", "Luke", "John":
            return .Gospels
        case "Acts":
            return .Acts
        case "Romans",
             "1 Corinthians", "2 Corinthians",
             "Galatians", "Ephesians", "Philippians", "Colossians",
             "1 Thessalonians", "2 Thessalonians",
             "1 Timothy", "2 Timothy",
             "Titus", "Philemon",
             "Hebrews", "James",
             "1 Peter", "2 Peter",
             "1 John", "2 John", "3 John",
             "Jude":
            return .Epistles
        case "Revelation":
            return .Apocalypse
        default:
            return .History
        }
    }

    static func computeGenreTotals(from perBook: [String: Int]) -> [(genre: String, seconds: Int)] {
        var buckets: [Genre: Int] = [:]
        for (book, seconds) in perBook {
            let g = genreForBook(book)
            buckets[g, default: 0] += max(0, seconds)
        }
        let order: [Genre] = [.Law, .History, .Poetry, .MajorProphets, .MinorProphets, .Gospels, .Acts, .Epistles, .Apocalypse]
        return order.map { g in (genre: g.rawValue, seconds: buckets[g, default: 0]) }
    }
}
