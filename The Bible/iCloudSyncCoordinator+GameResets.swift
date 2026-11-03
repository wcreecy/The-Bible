import Foundation

// Resetting game stats, locally and on every device, plus repairs to synced counters.

@MainActor
extension iCloudSyncCoordinator {
    // Centralized reset for all game counters (all scoreboard keys).
    func resetAllGameCountersToZero() {
        let gameKeys = Array(
            Self.hangmanKeys
            + Self.beatClockKeys
            + Self.refMatchKeys
            + Self.verseMatchKeys
            + Self.quizKeys
            + Self.bibleTriviaKeys
            + Self.bookOrderKeys
            + Self.whoAmIKeys
            + Self.wordleKeys
            + Self.wordSearchKeys
            + Self.scrambleKeys
            + Self.crosswordKeys
        )
        for key in gameKeys {
            defaults.set(0, forKey: key)
            writeLocalTimestampNow(for: key)
            kvs.set(Int(0), forKey: key)
            writeRemoteTimestampNow(for: key)
        }
        enqueueKeysForSync(Set(gameKeys))

        AppDataChanges.shared.gameStatsChanged()
    }

    // Local-only purge of all game-related data (used when a newer remote reset epoch is observed).
    func clearAllGameDataLocalOnly() {
        // 1) Remove numeric counters locally (let remote zeros/timestamps win)
        let gameKeys = Array(
            Self.hangmanKeys
            + Self.beatClockKeys
            + Self.refMatchKeys
            + Self.verseMatchKeys
            + Self.quizKeys
            + Self.bibleTriviaKeys
            + Self.bookOrderKeys
            + Self.whoAmIKeys
            + Self.wordleKeys
            + Self.wordSearchKeys
            + Self.scrambleKeys
            + Self.crosswordKeys
        )
        for key in gameKeys {
            defaults.removeObject(forKey: key)
            defaults.removeObject(forKey: tsKey(for: key))
        }

        // 1b) Clear local-only persistent streak caches (Beat the Clock + Verses + Hangman + Book Order)
        for key in Self.allPersistentStreakKeys {
            defaults.removeObject(forKey: key)
        }

        // 2) Clear overall daily maps and last played locally
        for key in ["gamesDailyAnswered", "gamesDailyCorrect", "gamesLastPlayedAt", "gamesLastPlayedGameName"] {
            defaults.removeObject(forKey: key)
        }

        // 2b) Clear per-WORD mode daily maps locally
        for modeKey in ["word_normal", "word_hard"] {
            defaults.removeObject(forKey: "gamesDailyAnswered_\(modeKey)")
            defaults.removeObject(forKey: "gamesDailyCorrect_\(modeKey)")
        }

        // 2c) Clear analytics maps locally
        for key in ["quizPerBookAnsweredMap", "quizPerBookCorrectMap",
                    "triviaPerBookAnsweredMap", "triviaPerBookCorrectMap",
                    "hangmanPerCategoryAnsweredMap", "hangmanPerCategoryCorrectMap",
                    "beatclockPerTypeAnsweredMap", "beatclockPerTypeCorrectMap",
                    "versematchPerBookAnsweredMap", "versematchPerBookCorrectMap",
                    "wordleDailySolvedDays", "wordleDailyResultMap",
                    "wordleDailyCompletedDay", "wordleDailyTarget",
                    "quizPerBookDailyAnswered", "quizPerBookDailyCorrect",
                    "triviaPerBookDailyAnswered", "triviaPerBookDailyCorrect",
                    "versematchPerBookDailyAnswered", "versematchPerBookDailyCorrect"] {
            defaults.removeObject(forKey: key)
        }

        // 3) Clear per-game daily maps locally
        let perGameKeys = ["quiz","hangman","beatclock","versematch","bookorder","whoami","wordsearch","scramble","crossword","word"]
        for g in perGameKeys {
            defaults.removeObject(forKey: "gamesDailyAnswered_\(g)")
            defaults.removeObject(forKey: "gamesDailyCorrect_\(g)")
        }

        // 3b) Clear the Review Round history
        MissedGameQuestionStore.shared.clearAll()

        // 4) Notify UI to recompute derived metrics to zero
        AppDataChanges.shared.gameStatsChanged()
    }

    // Full wipe of all game-related data: counters, daily maps (overall + per-game), and last played.
    func resetAllGameDataToZero() {
        // 1) Reset all-time counters (includes WORD extras)
        resetAllGameCountersToZero()

        // 1b) Clear any local-only persistent streak caches (Beat the Clock + Verses + Hangman + Book Order)
        for key in Self.allPersistentStreakKeys {
            defaults.removeObject(forKey: key)
            // Not mirrored to KVS; these keys are local-only
        }

        // 2) Clear overall daily maps (JSON [String:Int]) and last played metadata
        let overallMapKeys = ["gamesDailyAnswered", "gamesDailyCorrect"]
        for key in overallMapKeys {
            defaults.removeObject(forKey: key)
            // Mirror removal to KVS
            kvs.removeObject(forKey: key)
        }
        defaults.removeObject(forKey: "gamesLastPlayedAt")
        defaults.removeObject(forKey: "gamesLastPlayedGameName")
        kvs.removeObject(forKey: "gamesLastPlayedAt")
        kvs.removeObject(forKey: "gamesLastPlayedGameName")

        // Clear WORD daily solved flags
        defaults.removeObject(forKey: "wordleDailySolvedDays")
        kvs.removeObject(forKey: "wordleDailySolvedDays")

        // Clear WORD daily result summaries
        defaults.removeObject(forKey: "wordleDailyResultMap")
        kvs.removeObject(forKey: "wordleDailyResultMap")

        // Enqueue these for sync (they are in allKnownKeys)
        enqueueKeysForSync(overallMapKeys + ["gamesLastPlayedAt", "gamesLastPlayedGameName", "wordleDailySolvedDays", "wordleDailyResultMap"])

        // 2b) Clear per-WORD mode daily maps (now mirrored via KVS too)
        for modeKey in ["word_normal", "word_hard"] {
            let aKey = "gamesDailyAnswered_\(modeKey)"
            let cKey = "gamesDailyCorrect_\(modeKey)"
            defaults.removeObject(forKey: aKey)
            defaults.removeObject(forKey: cKey)
            kvs.removeObject(forKey: aKey)
            kvs.removeObject(forKey: cKey)
        }

        // 2c) Clear Bible Quiz per-book analytics (all-time maps mirrored, daily nested local-only)
        for key in ["quizPerBookAnsweredMap", "quizPerBookCorrectMap",
                    "triviaPerBookAnsweredMap", "triviaPerBookCorrectMap"] {
            defaults.removeObject(forKey: key)
            kvs.removeObject(forKey: key)
        }
        defaults.removeObject(forKey: "quizPerBookDailyAnswered")
        defaults.removeObject(forKey: "quizPerBookDailyCorrect")
        defaults.removeObject(forKey: "triviaPerBookDailyAnswered")
        defaults.removeObject(forKey: "triviaPerBookDailyCorrect")
        defaults.removeObject(forKey: "versematchPerBookDailyAnswered")
        defaults.removeObject(forKey: "versematchPerBookDailyCorrect")
        enqueueKeysForSync(["quizPerBookAnsweredMap", "quizPerBookCorrectMap",
                            "triviaPerBookAnsweredMap", "triviaPerBookCorrectMap"])

        // 2c.1) Clear Hangman per-category analytics (all-time maps mirrored)
        for key in ["hangmanPerCategoryAnsweredMap", "hangmanPerCategoryCorrectMap"] {
            defaults.removeObject(forKey: key)
            kvs.removeObject(forKey: key)
        }
        enqueueKeysForSync(["hangmanPerCategoryAnsweredMap", "hangmanPerCategoryCorrectMap"])

        // 2c.2) Clear Beat the Clock per-type analytics (all-time maps mirrored)
        for key in ["beatclockPerTypeAnsweredMap", "beatclockPerTypeCorrectMap"] {
            defaults.removeObject(forKey: key)
            kvs.removeObject(forKey: key)
        }
        enqueueKeysForSync(["beatclockPerTypeAnsweredMap", "beatclockPerTypeCorrectMap"])

        // 2c.3) Clear Verses per-book analytics (all-time maps mirrored)
        for key in ["versematchPerBookAnsweredMap", "versematchPerBookCorrectMap"] {
            defaults.removeObject(forKey: key)
            kvs.removeObject(forKey: key)
        }
        enqueueKeysForSync(["versematchPerBookAnsweredMap", "versematchPerBookCorrectMap"])

        // 2d) Optional: clear WORD daily completion flags so Daily isn’t “completed” after reset
        defaults.removeObject(forKey: "wordleDailyCompletedDay")
        defaults.removeObject(forKey: "wordleDailyTarget")

        // 3) Clear per-game daily maps (now mirrored — clear both local and remote)
        let perGameKeys = ["quiz","hangman","beatclock","versematch","bookorder","whoami","wordsearch","scramble","crossword","word"]
        for g in perGameKeys {
            let aKey = "gamesDailyAnswered_\(g)"
            let cKey = "gamesDailyCorrect_\(g)"
            defaults.removeObject(forKey: aKey)
            defaults.removeObject(forKey: cKey)
            kvs.removeObject(forKey: aKey)
            kvs.removeObject(forKey: cKey)
        }

        // 3b) Clear the Review Round history here and in iCloud so no device can restore it
        MissedGameQuestionStore.shared.clearAll()
        for key in Self.missedQuestionKeys {
            kvs.removeObject(forKey: key)
        }

        // 4) Set/reset the Game Stats reset epoch in both KVS and local so older devices won’t re-populate
        let now = Date().timeIntervalSince1970
        kvs.set(now, forKey: "gameStatsResetEpoch")
        defaults.set(now, forKey: "gameStatsLastSeenResetEpoch")

        // 4b) Start an empty per-device ledger for the new epoch so older ledgers,
        // including those from other devices, no longer count toward totals.
        GameStatsLedger.shared.resetForNewEpoch()

        // 5) Notify UI to recompute all derived metrics to zero (streaks, Qs/day, 7D accuracy, per-game charts, insights)
        AppDataChanges.shared.gameStatsChanged()

        // 6) Immediately push all known keys so zeros/removals propagate across devices now (also flushes epoch)
        pushAllNow()
    }

    // Invariant repair: answered >= correct for all games
    // Returns set of keys that were changed (for debounced sync)
    @discardableResult
    func normalizeGameCountersInvariant() -> Set<String> {
        var changed: Set<String> = []

        func repairPair(correctKey: String, answeredKey: String) {
            let c = max(0, defaults.integer(forKey: correctKey))
            let a = max(0, defaults.integer(forKey: answeredKey))
            if a < c {
                // Local only: the ledger publishes the change on its next reconcile.
                defaults.set(c, forKey: answeredKey)
                changed.insert(answeredKey)
            }
        }

        func repairSuffixed(prefix: String, diffs: [String]) {
            for d in diffs {
                let cKey = "\(prefix)AllTimeCorrect_\(d)"
                let aKey = "\(prefix)AllTimeAnswered_\(d)"
                repairPair(correctKey: cKey, answeredKey: aKey)
            }
        }

        // Hangman (easy/normal/medium/hard/all) + legacy unsuffixed
        repairSuffixed(prefix: "hangman", diffs: ["easy","normal","medium","hard","all"])
        repairPair(correctKey: "hangmanAllTimeCorrect", answeredKey: "hangmanAllTimeAnswered")

        // Beat the Clock — include normal, medium (legacy), and combined "all"
        repairSuffixed(prefix: "beatclock", diffs: ["easy","normal","medium","hard","all"])

        // Verses (new) + Reference Match (legacy) — include combined "all"
        repairSuffixed(prefix: "versematch", diffs: ["easy","normal","medium","hard","all"])
        repairSuffixed(prefix: "refmatch", diffs: ["easy","normal","medium","hard"])
        repairPair(correctKey: "refmatchAllTimeCorrect", answeredKey: "refmatchAllTimeAnswered")

        // Quiz — include combined "all" so shared all-time stays consistent
        repairSuffixed(prefix: "quiz", diffs: ["easy","normal","hard","all"])
        repairPair(correctKey: "quizAllTimeCorrect", answeredKey: "quizAllTimeAnswered")

        // Who am I? — include combined "all" + legacy unsuffixed
        repairSuffixed(prefix: "whoami", diffs: ["easy","normal","hard","all"])
        repairPair(correctKey: "whoamiAllTimeCorrect", answeredKey: "whoamiAllTimeAnswered")

        // Book Order (easy/normal/hard/expert/all) + legacy unsuffixed
        repairSuffixed(prefix: "bookorder", diffs: ["easy","normal","hard","expert","all"])
        repairPair(correctKey: "bookorderAllTimeCorrect", answeredKey: "bookorderAllTimeAnswered")

        // Wordle (daily/free/all + normal/hard)
        repairSuffixed(prefix: "wordle", diffs: ["daily","free","all","normal","hard"])

        // Word Search (easy/normal/hard/all)
        repairSuffixed(prefix: "wordsearch", diffs: ["easy","normal","hard","all"])

        return changed
    }

    // One-time migration: copy legacy refmatch* values into new versematch* if the latter are zero.
    // Returns set of versematch keys that were written (for debounced sync).
    @discardableResult
    func migrateRefMatchToVerseMatchIfNeeded() -> Set<String> {
        var changed: Set<String> = []
        let diffs = ["easy","normal","medium","hard"]

        func copyIfNeeded(suffix: String) {
            let srcC = "refmatchAllTimeCorrect_\(suffix)"
            let srcA = "refmatchAllTimeAnswered_\(suffix)"
            let srcB = "refmatchAllTimeBestStreak_\(suffix)"

            let dstC = "versematchAllTimeCorrect_\(suffix)"
            let dstA = "versematchAllTimeAnswered_\(suffix)"
            let dstB = "versematchAllTimeBestStreak_\(suffix)"

            let srcCv = max(0, defaults.integer(forKey: srcC))
            let srcAv = max(0, defaults.integer(forKey: srcA))
            let srcBv = max(0, defaults.integer(forKey: srcB))

            let dstCv = max(0, defaults.integer(forKey: dstC))
            let dstAv = max(0, defaults.integer(forKey: dstA))
            let dstBv = max(0, defaults.integer(forKey: dstB))

            let hasSrc = (srcCv + srcAv + srcBv) > 0
            let hasDst = (dstCv + dstAv + dstBv) > 0

            guard hasSrc, !hasDst else { return }

            // Copy source into destination
            // Local only: the ledger publishes the copied values on its next reconcile.
            defaults.set(srcCv, forKey: dstC)
            defaults.set(srcAv, forKey: dstA)
            defaults.set(srcBv, forKey: dstB)

            changed.formUnion([dstC, dstA, dstB])
        }

        for d in diffs { copyIfNeeded(suffix: d) }
        return changed
    }
}
