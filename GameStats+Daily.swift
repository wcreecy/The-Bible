import Foundation

/// Play time, the daily series, activity streaks, accuracy trend and the last-played summary.
extension GameStats {
    private static func storageKey(forDisplayName rawName: String) -> String? {
        switch canonicalDisplayName(rawName) {
        case "Quiz": return "quiz"
        case "Trivia": return "trivia"
        case "Hangman": return "hangman"
        case "Verses": return "versematch"
        case "Countdown": return "beatclock"
        case "Book Order": return "bookorder"
        case "Who?": return "whoami"
        case "Word Search": return "wordsearch"
        case "Scramble": return "scramble"
        case "Word": return "word"
        default: return nil
        }
    }

    // MARK: - Play time

    static let dailyPlaySecondsKey = "gamesDailyPlaySeconds"
    static let allTimePlaySecondsKey = "allTimeUsageGameSeconds"

    /// Adds time spent with a game screen open. Synced per device through the game ledger.
    func recordPlayTime(seconds: Int, endingAt end: Date = Date()) {
        guard seconds > 0 else { return }
        let start = end.addingTimeInterval(-TimeInterval(seconds))
        var daily: [String: Int] = loadJSONMap(forKey: Self.dailyPlaySecondsKey)
        for allocation in ReadingTimeTracker.dailyAllocations(seconds: seconds, from: start, to: end) {
            daily[Self.localDayKey(for: allocation.date), default: 0] += allocation.seconds
        }
        saveJSONMap(daily, forKey: Self.dailyPlaySecondsKey)

        let defaults = UserDefaults.standard
        defaults.set(max(0, defaults.integer(forKey: Self.allTimePlaySecondsKey)) + seconds, forKey: Self.allTimePlaySecondsKey)
        iCloudSyncCoordinator.shared.pushKey(Self.allTimePlaySecondsKey)
    }

    func playSeconds(on date: Date = Date()) -> Int {
        let daily: [String: Int] = loadJSONMap(forKey: Self.dailyPlaySecondsKey)
        return max(0, daily[Self.localDayKey(for: date)] ?? 0)
    }

    var allTimePlaySeconds: Int {
        max(0, UserDefaults.standard.integer(forKey: Self.allTimePlaySecondsKey))
    }

    func todayStats(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (answered: Int, correct: Int, pct: Double) {
        let key = Self.localDayKey(for: now, calendar: calendar)
        let answeredMap: [String: Int] = loadJSONMap(forKey: "gamesDailyAnswered")
        let correctMap: [String: Int] = loadJSONMap(forKey: "gamesDailyCorrect")
        let ans = max(0, answeredMap[key] ?? 0)
        let cor = max(0, correctMap[key] ?? 0)
        let pct = ans > 0 ? min(100, max(0, (Double(cor) / Double(ans)) * 100.0)) : 0
        return (ans, cor, pct)
    }

    var lastPlayedGameName: String? {
        if let raw = UserDefaults.standard.string(forKey: "gamesLastPlayedGameName") {
            return Self.canonicalDisplayName(raw)
        }
               return nil
    }

    typealias DailyPoint = (date: Date, answered: Int, correct: Int)

    func dailySeriesLast(days: Int, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> [(date: Date, answered: Int, correct: Int)] {
        dailySeries(days: days, answeredKey: "gamesDailyAnswered", correctKey: "gamesDailyCorrect", now: now, calendar: calendar)
    }

    func dailySeriesLast(days: Int, forDisplayName name: String, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> [(date: Date, answered: Int, correct: Int)] {
        // "All Games" and names that match no game read the overall series.
        guard name != "All Games", let gameKey = Self.storageKey(forDisplayName: name) else {
            return dailySeriesLast(days: days, now: now, calendar: calendar)
        }
        return dailySeries(days: days, gameKey: gameKey, now: now, calendar: calendar)
    }

    func dailySeriesLast(days: Int, forWordMode mode: WordMode, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> [(date: Date, answered: Int, correct: Int)] {
        dailySeries(days: days, gameKey: Self.storageKeyForWord(mode: mode), now: now, calendar: calendar)
    }

    private func dailySeries(days: Int, gameKey: String, now: Date, calendar: Calendar) -> [DailyPoint] {
        dailySeries(
            days: days,
            answeredKey: "gamesDailyAnswered_\(gameKey)",
            correctKey: "gamesDailyCorrect_\(gameKey)",
            now: now,
            calendar: calendar
        )
    }

    /// One point per day, oldest first, ending today.
    private func dailySeries(days: Int, answeredKey: String, correctKey: String, now: Date, calendar: Calendar) -> [DailyPoint] {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let startOfToday = cal.startOfDay(for: now)

        let answeredMap = loadJSONMap(forKey: answeredKey)
        let correctMap = loadJSONMap(forKey: correctKey)

        var series: [DailyPoint] = []
        for i in stride(from: days - 1, through: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                let key = Self.localDayKey(for: d, calendar: cal)
                series.append((d, max(0, answeredMap[key] ?? 0), max(0, correctMap[key] ?? 0)))
            }
        }
        return series
    }

    /// The longest run of days with answers, and the run ending today. A today with no
    /// answers yet doesn't end the current run.
    private static func streaks(in series: [DailyPoint]) -> (current: Int, longest: Int) {
        var longest = 0
        var run = 0
        for point in series {
            if point.answered > 0 {
                run += 1
                longest = max(longest, run)
            } else {
                run = 0
            }
        }

        var current = 0
        var recent = series
        if recent.last?.answered == 0 { recent.removeLast() }
        for point in recent.reversed() {
            if point.answered > 0 { current += 1 } else { break }
        }
        return (current, longest)
    }

    /// Accuracy over the last 7 days, and how far it moved from the 7 days before.
    private static func accuracyTrend(in last14Days: [DailyPoint]) -> (currentPct: Double, deltaVsPrev: Double) {
        func pct(for slice: ArraySlice<DailyPoint>) -> Double {
            let a = slice.reduce(0) { $0 + max(0, $1.answered) }
            let c = slice.reduce(0) { $0 + max(0, $1.correct) }
            guard a > 0 else { return 0 }
            return min(100, max(0, (Double(c) / Double(a)) * 100.0))
        }

        let cur = pct(for: last14Days.suffix(7))
        let prev = pct(for: last14Days.prefix(max(0, last14Days.count - 7)))
        return (cur, cur - prev)
    }

    func activityStreaks(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (current: Int, longest: Int) {
        Self.streaks(in: dailySeriesLast(days: 1825, now: now, calendar: calendar))
    }

    func activityStreaks(forDisplayName name: String, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (current: Int, longest: Int) {
        Self.streaks(in: dailySeriesLast(days: 1825, forDisplayName: name, now: now, calendar: calendar))
    }

    func activityStreaks(forWordMode mode: WordMode, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (current: Int, longest: Int) {
        Self.streaks(in: dailySeriesLast(days: 1825, forWordMode: mode, now: now, calendar: calendar))
    }

    func accuracy7DayTrend(now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (currentPct: Double, deltaVsPrev: Double) {
        Self.accuracyTrend(in: dailySeriesLast(days: 14, now: now, calendar: calendar))
    }

    func accuracy7DayTrend(forDisplayName name: String, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (currentPct: Double, deltaVsPrev: Double) {
        Self.accuracyTrend(in: dailySeriesLast(days: 14, forDisplayName: name, now: now, calendar: calendar))
    }

    func accuracy7DayTrend(forWordMode mode: WordMode, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> (currentPct: Double, deltaVsPrev: Double) {
        Self.accuracyTrend(in: dailySeriesLast(days: 14, forWordMode: mode, now: now, calendar: calendar))
    }

    func lastPlayedSummary(now: Date = Date()) -> (name: String?, relative: String?) {
        let defaults = UserDefaults.standard
        let name = lastPlayedGameName
        let ts = defaults.double(forKey: "gamesLastPlayedAt")
        guard ts > 0 else { return (name, nil) }
        let date = Date(timeIntervalSince1970: ts)
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return (name, f.localizedString(for: date, relativeTo: now))
    }
}
