import Foundation

/// All-time totals and the per-game summaries behind the Stats tab and every scorecard.
extension GameStats {
    struct Snapshot {
        let totalCorrect: Int
        let totalAnswered: Int
        let percentage: Double
    }

    func snapshot() -> Snapshot {
        let totals = aggregateAll()
        let pct = percentage(correct: totals.correct, answered: totals.answered)
        return Snapshot(totalCorrect: totals.correct, totalAnswered: totals.answered, percentage: pct)
    }

    struct GameBreakdown {
        struct Entry {
            let name: String
            let correct: Int
            let answered: Int
            let bestStreak: Int?
        }
        let entries: [Entry]
        var totalCorrect: Int { entries.reduce(0) { $0 + max(0, $1.correct) } }
        var totalAnswered: Int { entries.reduce(0) { $0 + max(0, $1.answered) } }
        var percentage: Double {
            guard totalAnswered > 0 else { return 0 }
            let raw = (Double(totalCorrect) / Double(totalAnswered)) * 100.0
            return min(100, max(0, raw))
        }
    }

    func breakdownSnapshot() -> GameBreakdown {
        let q = quiz
        let t = trivia
        let h = hangman
        let r = versematch
        let b = beatclock
        let o = bookorder
        let w = whoami
        let ws = wordsearch
        let s = scramble

        let wdDaily = wordle(type: .daily)
        let wdFree = wordle(type: .free)
        let wdLegacyAll = wordleLegacyAll
        let typedAnswered = wdDaily.answered + wdFree.answered
        let typedCorrect = wdDaily.correct + wdFree.correct
        let wdCombined = GameStat(
            correct: typedAnswered > 0 || typedCorrect > 0 ? typedCorrect : wdLegacyAll.correct,
            answered: typedAnswered > 0 || typedCorrect > 0 ? typedAnswered : wdLegacyAll.answered,
            bestStreak: max((wdDaily.bestStreak ?? 0), (wdFree.bestStreak ?? 0), (wdLegacyAll.bestStreak ?? 0))
        )

        let entries: [GameBreakdown.Entry] = [
            .init(name: "Quiz", correct: q.correct, answered: q.answered, bestStreak: q.bestStreak),
            .init(name: "Trivia", correct: t.correct, answered: t.answered, bestStreak: t.bestStreak),
            .init(name: "Hangman", correct: h.correct, answered: h.answered, bestStreak: h.bestStreak),
            .init(name: "Verses", correct: r.correct, answered: r.answered, bestStreak: r.bestStreak),
            .init(name: "Countdown", correct: b.correct, answered: b.answered, bestStreak: b.bestStreak),
            .init(name: "Book Order", correct: o.correct, answered: o.answered, bestStreak: o.bestStreak),
            .init(name: "Who?", correct: w.correct, answered: w.answered, bestStreak: w.bestStreak),
            .init(name: "Word Search", correct: ws.correct, answered: ws.answered, bestStreak: ws.bestStreak),
            .init(name: "Scramble", correct: s.correct, answered: s.answered, bestStreak: s.bestStreak),
            .init(name: "Word", correct: wdCombined.correct, answered: wdCombined.answered, bestStreak: wdCombined.bestStreak)
        ]
        return GameBreakdown(entries: entries)
    }

    struct ScorecardStats {
        let correct: Int
        let attempts: Int
        let bestStreak: Int
    }

    /// The canonical source used by both the Stats tab and every in-game scorecard.
    func scorecardStats(for game: GameID, wordMode: WordMode? = nil) -> ScorecardStats {
        let stat: GameStat
        switch game {
        case .quiz: stat = quiz
        case .trivia: stat = trivia
        case .hangman: stat = hangman
        case .beatclock: stat = beatclock
        case .versematch: stat = versematch
        case .bookorder: stat = bookorder
        case .whoami: stat = whoami
        case .wordsearch: stat = wordsearch
        case .scramble: stat = scramble
        case .wordle:
            if let wordMode {
                let counts = wordleCounts(mode: wordMode)
                let suffix = wordMode == .hard ? "hard" : "normal"
                return ScorecardStats(
                    correct: counts.wins,
                    attempts: counts.answered,
                    bestStreak: max(0, readInt("wordleAllTimeBestStreak_\(suffix)"))
                )
            }
            let entry = breakdownSnapshot().entries.first { $0.name == "Word" }
            return ScorecardStats(
                correct: entry?.correct ?? 0,
                attempts: entry?.answered ?? 0,
                bestStreak: entry?.bestStreak ?? 0
            )
        }
        return ScorecardStats(correct: stat.correct, attempts: stat.answered, bestStreak: stat.bestStreak ?? 0)
    }

    private func sumAcross(prefix: String, parts: [String], legacyKey: String?) -> Int {
        let partValues = parts.map { readInt("\(prefix)\($0)") }
        let sumParts = partValues.reduce(0) { $0 + max(0, $1) }
        let hasAnySuffixed = partValues.contains { $0 > 0 }
        if hasAnySuffixed {
            return max(0, sumParts)
        } else {
            let legacy = legacyKey.map { readInt($0) } ?? 0
            return max(0, sumParts + legacy)
        }
    }

    private func maxAcross(prefix: String, parts: [String], legacyKey: String?) -> Int {
        let partValues = parts.map { readInt("\(prefix)\($0)") }
        let hasAnySuffixed = partValues.contains { $0 > 0 }
        let bestParts = partValues.max() ?? 0
        if hasAnySuffixed {
            return max(0, bestParts)
        } else {
            let legacy = legacyKey.map { readInt($0) } ?? 0
            return max(0, max(bestParts, legacy))
        }
    }

    private struct GameStat {
        let correct: Int
        let answered: Int
        let bestStreak: Int?
    }

    private var quiz: GameStat {
        // Prefer combined keys if present; otherwise fall back to summing per-difficulty/legacy
        let combinedC = max(0, readInt("quizAllTimeCorrect_all"))
        let combinedA = max(0, readInt("quizAllTimeAnswered_all"))
        let combinedB = max(0, readInt("quizAllTimeBestStreak_all"))
        if (combinedC + combinedA + combinedB) > 0 {
            return GameStat(correct: combinedC, answered: combinedA, bestStreak: combinedB == 0 ? nil : combinedB)
        }

        let c = sumAcross(prefix: "quizAllTimeCorrect", parts: ["_easy","_normal","_hard"], legacyKey: "quizAllTimeCorrect")
        let a = sumAcross(prefix: "quizAllTimeAnswered", parts: ["_easy","_normal","_hard"], legacyKey: "quizAllTimeAnswered")
        let best = maxAcross(prefix: "quizAllTimeBestStreak", parts: ["_easy","_normal","_hard"], legacyKey: "quizAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var trivia: GameStat {
        let correct = max(0, readInt("triviaAllTimeCorrect_all"))
        let answered = max(0, readInt("triviaAllTimeAnswered_all"))
        let bestStreak = max(0, readInt("triviaAllTimeBestStreak_all"))
        return GameStat(
            correct: correct,
            answered: answered,
            bestStreak: bestStreak == 0 ? nil : bestStreak
        )
    }

    func triviaCounts(difficulty: Difficulty) -> (correct: Int, answered: Int) {
        let suffix: String
        switch difficulty {
        case .easy: suffix = "easy"
        case .normal, .medium: suffix = "normal"
        case .hard: suffix = "hard"
        case .none: suffix = "all"
        }
        return (
            max(0, readInt("triviaAllTimeCorrect_\(suffix)")),
            max(0, readInt("triviaAllTimeAnswered_\(suffix)"))
        )
    }

    private var hangman: GameStat {
        // Prefer combined keys if present; otherwise fall back to summing per-difficulty/legacy
        let combinedC = max(0, readInt("hangmanAllTimeCorrect_all"))
        let combinedA = max(0, readInt("hangmanAllTimeAnswered_all"))
        let combinedB = max(0, readInt("hangmanAllTimeBestStreak_all"))
        if (combinedC + combinedA + combinedB) > 0 {
            return GameStat(correct: combinedC, answered: combinedA, bestStreak: combinedB == 0 ? nil : combinedB)
        }

        let c = sumAcross(prefix: "hangmanAllTimeCorrect", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "hangmanAllTimeCorrect")
        let a = sumAcross(prefix: "hangmanAllTimeAnswered", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "hangmanAllTimeAnswered")
        let best = maxAcross(prefix: "hangmanAllTimeBestStreak", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "hangmanAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var versematch: GameStat {
        // Prefer combined keys if present; otherwise fall back to new per-difficulty or legacy refmatch
        let combinedC = max(0, readInt("versematchAllTimeCorrect_all"))
        let combinedA = max(0, readInt("versematchAllTimeAnswered_all"))
        let combinedB = max(0, readInt("versematchAllTimeBestStreak_all"))
        if (combinedC + combinedA + combinedB) > 0 {
            return GameStat(correct: combinedC, answered: combinedA, bestStreak: combinedB == 0 ? nil : combinedB)
        }

        let cNew = sumAcross(prefix: "versematchAllTimeCorrect", parts: ["_easy","_normal","_hard","_medium"], legacyKey: nil)
        let aNew = sumAcross(prefix: "versematchAllTimeAnswered", parts: ["_easy","_normal","_hard","_medium"], legacyKey: nil)
        let bestNew = maxAcross(prefix: "versematchAllTimeBestStreak", parts: ["_easy","_normal","_hard","_medium"], legacyKey: nil)

        let hasNew = (cNew + aNew + (bestNew)) > 0
        if hasNew {
            return GameStat(correct: cNew, answered: aNew, bestStreak: bestNew == 0 ? nil : bestNew)
        } else {
            let cLegacy = sumAcross(prefix: "refmatchAllTimeCorrect", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "refmatchAllTimeCorrect")
            let aLegacy = sumAcross(prefix: "refmatchAllTimeAnswered", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "refmatchAllTimeAnswered")
            let bestLegacy = maxAcross(prefix: "refmatchAllTimeBestStreak", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "refmatchAllTimeBestStreak")
            return GameStat(correct: cLegacy, answered: aLegacy, bestStreak: bestLegacy == 0 ? nil : bestLegacy)
        }
    }

    private var beatclock: GameStat {
        // Prefer combined keys if present; otherwise fall back to summing per-difficulty/legacy
        let combinedC = max(0, readInt("beatclockAllTimeCorrect_all"))
        let combinedA = max(0, readInt("beatclockAllTimeAnswered_all"))
        let combinedB = max(0, readInt("beatclockAllTimeBestStreak_all"))
        if (combinedC + combinedA + combinedB) > 0 {
            return GameStat(correct: combinedC, answered: combinedA, bestStreak: combinedB == 0 ? nil : combinedB)
        }

        let c = sumAcross(prefix: "beatclockAllTimeCorrect", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "beatclockAllTimeCorrect")
        let a = sumAcross(prefix: "beatclockAllTimeAnswered", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "beatclockAllTimeAnswered")
        let best = maxAcross(prefix: "beatclockAllTimeBestStreak", parts: ["_easy","_normal","_hard","_medium"], legacyKey: "beatclockAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var bookorder: GameStat {
        // Prefer combined keys if present; otherwise fall back to summing per-difficulty/legacy
        let combinedC = max(0, readInt("bookorderAllTimeCorrect_all"))
        let combinedA = max(0, readInt("bookorderAllTimeAnswered_all"))
        let combinedB = max(0, readInt("bookorderAllTimeBestStreak_all"))
        if (combinedC + combinedA + combinedB) > 0 {
            return GameStat(correct: combinedC, answered: combinedA, bestStreak: combinedB == 0 ? nil : combinedB)
        }

        let c = sumAcross(prefix: "bookorderAllTimeCorrect", parts: ["_easy","_normal","_hard"], legacyKey: "bookorderAllTimeCorrect")
        let a = sumAcross(prefix: "bookorderAllTimeAnswered", parts: ["_easy","_normal","_hard"], legacyKey: "bookorderAllTimeAnswered")
        let best = maxAcross(prefix: "bookorderAllTimeBestStreak", parts: ["_easy","_normal","_hard"], legacyKey: "bookorderAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var whoami: GameStat {
        // Prefer combined keys if present; otherwise fall back to summing per-difficulty
        let combinedC = max(0, readInt("whoamiAllTimeCorrect_all"))
        let combinedA = max(0, readInt("whoamiAllTimeAnswered_all"))
        let combinedB = max(0, readInt("whoamiAllTimeBestStreak_all"))
        if (combinedC + combinedA + combinedB) > 0 {
            return GameStat(correct: combinedC, answered: combinedA, bestStreak: combinedB == 0 ? nil : combinedB)
        }

        let c = sumAcross(prefix: "whoamiAllTimeCorrect", parts: ["_easy","_normal","_hard"], legacyKey: "whoamiAllTimeCorrect")
        let a = sumAcross(prefix: "whoamiAllTimeAnswered", parts: ["_easy","_normal","_hard"], legacyKey: "whoamiAllTimeAnswered")
        let best = maxAcross(prefix: "whoamiAllTimeBestStreak", parts: ["_easy","_normal","_hard"], legacyKey: "whoamiAllTimeBestStreak")
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var wordsearch: GameStat {
        let combinedC = max(0, readInt("wordsearchAllTimeCorrect_all"))
        let combinedA = max(0, readInt("wordsearchAllTimeAnswered_all"))
        let combinedB = max(0, readInt("wordsearchAllTimeBestStreak_all"))
        if (combinedC + combinedA + combinedB) > 0 {
            return GameStat(correct: combinedC, answered: combinedA, bestStreak: combinedB == 0 ? nil : combinedB)
        }

        let c = sumAcross(prefix: "wordsearchAllTimeCorrect", parts: ["_easy", "_normal", "_hard"], legacyKey: nil)
        let a = sumAcross(prefix: "wordsearchAllTimeAnswered", parts: ["_easy", "_normal", "_hard"], legacyKey: nil)
        let best = maxAcross(prefix: "wordsearchAllTimeBestStreak", parts: ["_easy", "_normal", "_hard"], legacyKey: nil)
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private var scramble: GameStat {
        let combinedC = max(0, readInt("scrambleAllTimeCorrect_all"))
        let combinedA = max(0, readInt("scrambleAllTimeAnswered_all"))
        let combinedB = max(0, readInt("scrambleAllTimeBestStreak_all"))
        if (combinedC + combinedA + combinedB) > 0 {
            return GameStat(correct: combinedC, answered: combinedA, bestStreak: combinedB == 0 ? nil : combinedB)
        }

        let c = sumAcross(prefix: "scrambleAllTimeCorrect", parts: ["_easy", "_normal", "_hard"], legacyKey: nil)
        let a = sumAcross(prefix: "scrambleAllTimeAnswered", parts: ["_easy", "_normal", "_hard"], legacyKey: nil)
        let best = maxAcross(prefix: "scrambleAllTimeBestStreak", parts: ["_easy", "_normal", "_hard"], legacyKey: nil)
        return GameStat(correct: c, answered: a, bestStreak: best == 0 ? nil : best)
    }

    private func wordle(type: WordleType) -> GameStat {
        let suf = (type == .daily) ? "_daily" : "_free"
        let c = readInt("wordleAllTimeCorrect\(suf)")
        let a = readInt("wordleAllTimeAnswered\(suf)")
        let best = readInt("wordleAllTimeBestStreak\(suf)")
        return GameStat(correct: max(0, c), answered: max(0, a), bestStreak: (best == 0 ? nil : best))
    }
    private var wordleLegacyAll: GameStat {
        let c = readInt("wordleAllTimeCorrect_all")
        let a = readInt("wordleAllTimeAnswered_all")
        let best = readInt("wordleAllTimeBestStreak_all")
        return GameStat(correct: max(0, c), answered: max(0, a), bestStreak: (best == 0 ? nil : best))
    }

    private func aggregateAll() -> (correct: Int, answered: Int) {
        let stats = [quiz, trivia, hangman, versematch, beatclock, bookorder, whoami, wordsearch, scramble]
        let typedCorrect = wordle(type: .daily).correct + wordle(type: .free).correct
        let typedAnswered = wordle(type: .daily).answered + wordle(type: .free).answered
        let wordleCombined = GameStat(
            correct: typedCorrect > 0 || typedAnswered > 0 ? typedCorrect : wordleLegacyAll.correct,
            answered: typedCorrect > 0 || typedAnswered > 0 ? typedAnswered : wordleLegacyAll.answered,
            bestStreak: nil
        )
        let totalCorrect = stats.reduce(0) { $0 + max(0, $1.correct) } + wordleCombined.correct
        let totalAnswered = stats.reduce(0) { $0 + max(0, $1.answered) } + wordleCombined.answered
        return (totalCorrect, totalAnswered)
    }

    private func percentage(correct: Int, answered: Int) -> Double {
        guard answered > 0 else { return 0 }
        let raw = (Double(correct) / Double(answered)) * 100.0
        return min(100, max(0, raw))
    }

    func accuracyByDifficulty() -> [(difficulty: String, answered: Int, correct: Int, pct: Double)] {
        [
            (key: "easy", title: String(localized: "Learn")),
            (key: "normal", title: String(localized: "Standard")),
            (key: "hard", title: String(localized: "Challenge"))
        ].map { difficulty in
            let prefixes = ["quiz", "hangman", "versematch", "beatclock", "bookorder", "whoami"]
            let answered = prefixes.reduce(0) { $0 + max(0, readInt("\($1)AllTimeAnswered_\(difficulty.key)")) }
            let correct = prefixes.reduce(0) { $0 + max(0, readInt("\($1)AllTimeCorrect_\(difficulty.key)")) }
            let pct = answered > 0 ? Double(correct) / Double(answered) * 100 : 0
            return (difficulty.title, answered, correct, pct)
        }
    }
}
