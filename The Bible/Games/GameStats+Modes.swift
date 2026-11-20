import Foundation

// Results for each way of playing a game, for the "By Mode" section on the Stats tab.
// Only games with more than one mode record these; WORD keeps its own Daily and Practice stats.
// A game's headline numbers still blend every mode.

/// The games whose modes are counted separately. The raw value starts every stored key.
enum GameModeStatsGame: String, CaseIterable {
    case quiz
    case beatclock
    case bookorder
    case whoami

    /// Answers (or puzzles) played in each mode, summed across devices.
    var answeredKey: String { "\(rawValue)PerModeAnsweredMap" }
    /// Right answers (or solved puzzles) in each mode, summed across devices.
    var correctKey: String { "\(rawValue)PerModeCorrectMap" }
    /// Finished timed rounds in each mode, summed across devices.
    var roundsKey: String { "\(rawValue)PerModeRoundsMap" }
    /// The scores of those rounds added together, for the average.
    var roundScoreKey: String { "\(rawValue)PerModeRoundScoreMap" }
    /// The best score in one round, kept at its largest across devices.
    var bestRoundKey: String { "\(rawValue)PerModeBestRoundMap" }
    /// Seconds spent on solved puzzles, for the average solve time.
    var solveSecondsKey: String { "\(rawValue)PerModeSolveSecondsMap" }

    var sumMapKeys: [String] { [answeredKey, correctKey, roundsKey, roundScoreKey, solveSecondsKey] }
    var maxMapKeys: [String] { [bestRoundKey] }

    static var allSumMapKeys: [String] { allCases.flatMap(\.sumMapKeys) }
    static var allMaxMapKeys: [String] { allCases.flatMap(\.maxMapKeys) }
    static var allMapKeys: [String] { allSumMapKeys + allMaxMapKeys }
}

/// What has been recorded for one mode of one game.
struct GameModeResult: Equatable {
    let mode: String
    let answered: Int
    let correct: Int
    let rounds: Int
    let roundScoreTotal: Int
    let bestRound: Int
    let solveSeconds: Int

    var hasPlays: Bool { answered > 0 || rounds > 0 }

    /// Percent right, 0–100.
    var accuracy: Double {
        answered > 0 ? min(100, Double(correct) / Double(answered) * 100) : 0
    }

    var averageRoundScore: Double? {
        rounds > 0 ? Double(roundScoreTotal) / Double(rounds) : nil
    }

    /// Average seconds per solved puzzle.
    var averageSolveSeconds: Int? {
        correct > 0 && solveSeconds > 0 ? Int((Double(solveSeconds) / Double(correct)).rounded()) : nil
    }
}

extension GameStats {
    /// Counts one answer, or one finished puzzle, toward a mode.
    func recordModeAnswer(_ game: GameModeStatsGame, mode: String, correct: Bool) {
        addToModeMap(game.answeredKey, mode: mode) { $0 + 1 }
        if correct {
            addToModeMap(game.correctKey, mode: mode) { $0 + 1 }
        }
        AppDataChanges.shared.gameStatsChanged()
    }

    /// Counts one finished timed round and its score toward a mode.
    func recordModeRound(_ game: GameModeStatsGame, mode: String, score: Int) {
        let score = max(0, score)
        addToModeMap(game.roundsKey, mode: mode) { $0 + 1 }
        addToModeMap(game.roundScoreKey, mode: mode) { $0 + score }
        addToModeMap(game.bestRoundKey, mode: mode) { max($0, score) }
        AppDataChanges.shared.gameStatsChanged()
    }

    /// Adds a solved puzzle's time to a mode, for its average solve time.
    func recordModeSolveTime(_ game: GameModeStatsGame, mode: String, seconds: Int) {
        guard seconds > 0 else { return }
        addToModeMap(game.solveSecondsKey, mode: mode) { $0 + seconds }
        AppDataChanges.shared.gameStatsChanged()
    }

    /// The results for each of `modes` (raw values), in that order.
    func modeResults(_ game: GameModeStatsGame, modes: [String]) -> [GameModeResult] {
        let answered = loadJSONMap(forKey: game.answeredKey)
        let correct = loadJSONMap(forKey: game.correctKey)
        let rounds = loadJSONMap(forKey: game.roundsKey)
        let roundScore = loadJSONMap(forKey: game.roundScoreKey)
        let bestRound = loadJSONMap(forKey: game.bestRoundKey)
        let solveSeconds = loadJSONMap(forKey: game.solveSecondsKey)
        return modes.map { mode in
            let answeredCount = max(0, answered[mode] ?? 0)
            return GameModeResult(
                mode: mode,
                answered: answeredCount,
                // A synced map can briefly run ahead of its partner; never show more right than played.
                correct: min(answeredCount, max(0, correct[mode] ?? 0)),
                rounds: max(0, rounds[mode] ?? 0),
                roundScoreTotal: max(0, roundScore[mode] ?? 0),
                bestRound: max(0, bestRound[mode] ?? 0),
                solveSeconds: max(0, solveSeconds[mode] ?? 0)
            )
        }
    }

    private func addToModeMap(_ key: String, mode: String, _ update: (Int) -> Int) {
        var map = loadJSONMap(forKey: key)
        let current = map[mode] ?? 0
        let updated = max(0, update(current))
        guard updated != current else { return }
        map[mode] = updated
        saveJSONMap(map, forKey: key)
        iCloudSyncCoordinator.shared.pushKey(key)
    }
}
