import Foundation

/// Reads for the Word game: win-guess and time stats, and the Daily solved days and win streak.
extension GameStats {
    func wordleWinGuessStats(type: WordleType) -> (averageGuessesOnWins: Double, winsByGuess: [Int]) {
        let suf = (type == .daily) ? "daily" : "free"
        let totalWins = max(0, readInt("wordleAllTimeCorrect_\(suf)"))
        let sumGuesses = max(0, readInt("wordleWinsGuessSum_\(suf)"))
        let dist = (1...6).map { idx in max(0, readInt("wordleWinsOnGuess\(idx)_\(suf)")) }
        let avg: Double = totalWins > 0 ? Double(sumGuesses) / Double(totalWins) : 0
        return (avg, dist)
    }

    func wordleWinGuessStats(mode: WordMode) -> (averageGuessesOnWins: Double, winsByGuess: [Int]) {
        let suf = (mode == .normal) ? "normal" : "hard"
        let totalWins = max(0, readInt("wordleAllTimeCorrect_\(suf)"))
        let sumGuesses = max(0, readInt("wordleWinsGuessSum_\(suf)"))
        let dist = (1...6).map { idx in max(0, readInt("wordleWinsOnGuess\(idx)_\(suf)")) }
        let avg: Double = totalWins > 0 ? Double(sumGuesses) / Double(totalWins) : 0
        return (avg, dist)
    }

    func wordleWinGuessStatsModesCombined() -> (averageGuessesOnWins: Double, winsByGuess: [Int]) {
        let (avgN, distN) = wordleWinGuessStats(mode: .normal)
        let (avgH, distH) = wordleWinGuessStats(mode: .hard)

        let winsN = max(0, readInt("wordleAllTimeCorrect_normal"))
        let winsH = max(0, readInt("wordleAllTimeCorrect_hard"))
        let sumN = max(0, readInt("wordleWinsGuessSum_normal"))
        let sumH = max(0, readInt("wordleWinsGuessSum_hard"))
        let totalWins = winsN + winsH
        let totalSum = sumN + sumH
        let avg = totalWins > 0 ? Double(totalSum) / Double(totalWins) : max(avgN, avgH)

        let dist = zip(distN, distH).map(+)
        return (avg, dist)
    }

    func wordleTimeStats(type: WordleType) -> (total: Int, wins: Int, losses: Int) {
        let suf = (type == .daily) ? "daily" : "free"
        let total = max(0, readInt("wordleTimeTotal_seconds_\(suf)"))
        let wins = max(0, readInt("wordleTimeWins_seconds_\(suf)"))
        let losses = max(0, readInt("wordleTimeLosses_seconds_\(suf)"))
        return (total, wins, losses)
    }

    func wordleCounts(type: WordleType) -> (answered: Int, wins: Int) {
        let suf = (type == .daily) ? "daily" : "free"
        let wins = max(0, readInt("wordleAllTimeCorrect_\(suf)"))
        let answered = max(0, readInt("wordleAllTimeAnswered_\(suf)"))
        return (answered, wins)
    }

    func wordleTimeStats(mode: WordMode) -> (total: Int, wins: Int, losses: Int) {
        let suf = (mode == .normal) ? "normal" : "hard"
        let total = max(0, readInt("wordleTimeTotal_seconds_\(suf)"))
        let wins = max(0, readInt("wordleTimeWins_seconds_\(suf)"))
        let losses = max(0, readInt("wordleTimeLosses_seconds_\(suf)"))
        return (total, wins, losses)
    }

    func wordleTimeStatsModesCombined() -> (total: Int, wins: Int, losses: Int) {
        let n = wordleTimeStats(mode: .normal)
        let h = wordleTimeStats(mode: .hard)
        return (n.total + h.total, n.wins + h.wins, n.losses + h.losses)
    }

    func wordleCounts(mode: WordMode) -> (answered: Int, wins: Int) {
        let suf = (mode == .normal) ? "normal" : "hard"
        let wins = max(0, readInt("wordleAllTimeCorrect_\(suf)"))
        let answered = max(0, readInt("wordleAllTimeAnswered_\(suf)"))
        return (answered, wins)
    }

    func wordleDailySolvedDayKeysLast(days: Int, now: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> Set<String> {
        let solved: [String: Int] = loadJSONMap(forKey: "wordleDailySolvedDays")
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let startOfToday = cal.startOfDay(for: now)
        var keys: Set<String> = []
        for i in stride(from: days - 1, through: 0, by: -1) {
            if let d = cal.date(byAdding: .day, value: -i, to: startOfToday) {
                let k = Self.localDayKey(for: d, calendar: cal)
                if solved[k] == 1 {
                    keys.insert(k)
                }
            }
        }
        return keys
    }

    /// Consecutive calendar days with a solved Daily WORD, ending today (or yesterday if
    /// today's Daily has not been played yet). A missed day or a loss ends the streak.
    /// - Parameter treatingTodayAsSolved: Counts today as solved before the result is recorded.
    func wordleDailyWinStreak(
        treatingTodayAsSolved: Bool = false,
        now: Date = Date(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> Int {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let solved: [String: Int] = loadJSONMap(forKey: "wordleDailySolvedDays")
        let todayKey = Self.localDayKey(for: now, calendar: cal)

        func isSolved(_ key: String) -> Bool {
            solved[key] == 1 || (treatingTodayAsSolved && key == todayKey)
        }

        var day = cal.startOfDay(for: now)
        if !isSolved(todayKey) {
            // A Daily loss today ends the streak immediately.
            if playedDailyWithoutWinning(on: todayKey) { return 0 }
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while isSolved(Self.localDayKey(for: day, calendar: cal)) {
            streak += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    private func playedDailyWithoutWinning(on dayKey: String) -> Bool {
        struct DailyResult: Decodable { let won: Bool }
        guard let data = UserDefaults.standard.data(forKey: "wordleDailyResultMap"),
              let results = PersistedDecoding.decode([String: DailyResult].self, from: data, key: "wordleDailyResultMap", keepingUnreadableIn: .standard),
              let result = results[dayKey] else {
            return false
        }
        return !result.won
    }
}
