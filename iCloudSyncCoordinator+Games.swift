import Foundation

@MainActor
extension iCloudSyncCoordinator {
    // Game keys: Hangman
    static let hangmanKeys: [String] = {
        // Include both legacy "medium" and new "normal"
        let diffs = ["easy", "normal", "medium", "hard"]
        var keys: [String] = []
        for d in diffs {
            keys.append("hangmanAllTimeCorrect_\(d)")
            keys.append("hangmanAllTimeAnswered_\(d)")
            keys.append("hangmanAllTimeBestStreak_\(d)")
        }
        // Include legacy unsuffixed keys for backward compatibility
        keys.append(contentsOf: ["hangmanAllTimeCorrect", "hangmanAllTimeAnswered", "hangmanAllTimeBestStreak"])
        return keys
    }()

    // Game keys: Beat the Clock
    static let beatClockKeys: [String] = {
        // Include both legacy "medium" and new "normal"
        let diffs = ["easy", "normal", "medium", "hard"]
        var keys: [String] = []
        for d in diffs {
            keys.append("beatclockAllTimeCorrect_\(d)")
            keys.append("beatclockAllTimeAnswered_\(d)")
            keys.append("beatclockAllTimeBestStreak_\(d)")
        }
        return keys
    }()

    // Game keys: Reference Match (legacy)
    static let refMatchKeys: [String] = {
        // Include both legacy "medium" and new "normal"
        let diffs = ["easy", "normal", "medium", "hard"]
        var keys: [String] = []
        for d in diffs {
            keys.append("refmatchAllTimeCorrect_\(d)")
            keys.append("refmatchAllTimeAnswered_\(d)")
            keys.append("refmatchAllTimeBestStreak_\(d)")
        }
        // Include legacy unsuffixed keys for backward compatibility
        keys.append(contentsOf: ["refmatchAllTimeCorrect", "refmatchAllTimeAnswered", "refmatchAllTimeBestStreak"])
        return keys
    }()

    // Game keys: Verse Match (new)
    static let verseMatchKeys: [String] = {
        // Include both "normal" and legacy "medium" to be safe during transition
        let diffs = ["easy", "normal", "medium", "hard"]
        var keys: [String] = []
        for d in diffs {
            keys.append("versematchAllTimeCorrect_\(d)")
            keys.append("versematchAllTimeAnswered_\(d)")
            keys.append("versematchAllTimeBestStreak_\(d)")
        }
        return keys
    }()

    // Game keys: Quiz (@AppStorage uses easy/normal/hard)
    static let quizKeys: [String] = {
        let diffs = ["easy", "normal", "hard"]
        var keys: [String] = []
        for d in diffs {
            keys.append("quizAllTimeCorrect_\(d)")
            keys.append("quizAllTimeAnswered_\(d)")
            keys.append("quizAllTimeBestStreak_\(d)")
        }
        return keys
    }()

    // NEW: Bible Quiz per-book maps mirrored via KVS (JSON [String:Int])
    static let quizPerBookMapKeys: [String] = [
        "quizPerBookAnsweredMap",
        "quizPerBookCorrectMap"
    ]

    // Game keys: Book Order — now per-difficulty (easy/normal/hard/all) + legacy unsuffixed for reset/back-compat
    static let bookOrderKeys: [String] = {
        let diffs = ["easy", "normal", "hard", "all"]
        var keys: [String] = []
        for d in diffs {
            keys.append("bookorderAllTimeCorrect_\(d)")
            keys.append("bookorderAllTimeAnswered_\(d)")
            keys.append("bookorderAllTimeBestStreak_\(d)")
        }
        // Include legacy unsuffixed keys so reset clears older installs too
        keys.append(contentsOf: ["bookorderAllTimeCorrect", "bookorderAllTimeAnswered", "bookorderAllTimeBestStreak"])
        return keys
    }()

    // Game keys: Who am I? (easy/normal/hard) — only suffixed; no legacy unsuffixed shipped
    static let whoAmIKeys: [String] = {
        let diffs = ["easy", "normal", "hard"]
        var keys: [String] = []
        for d in diffs {
            keys.append("whoamiAllTimeCorrect_\(d)")
            keys.append("whoamiAllTimeAnswered_\(d)")
            keys.append("whoamiAllTimeBestStreak_\(d)")
        }
        return keys
    }()

    // Game keys: Wordle — split by type (daily/free) and keep legacy "all"
    static let wordleKeys: [String] = {
        var keys: [String] = []

        // Core per-type counters
        let typeDiffs = ["daily", "free", "all"] // include legacy "all" for back-compat
        for d in typeDiffs {
            keys.append("wordleAllTimeCorrect_\(d)")
            keys.append("wordleAllTimeAnswered_\(d)")
            keys.append("wordleAllTimeBestStreak_\(d)")
        }

        // NEW: Per-type win-guess stats (no legacy "_all" variants)
        for d in ["daily", "free"] {
            keys.append("wordleWinsGuessSum_\(d)")
            for i in 1...6 {
                keys.append("wordleWinsOnGuess\(i)_\(d)")
            }
        }

        // NEW: Per-type timing keys (total, wins, losses) so they mirror/reset via KVS
        for d in ["daily", "free"] {
            keys.append("wordleTimeTotal_seconds_\(d)")
            keys.append("wordleTimeWins_seconds_\(d)")
            keys.append("wordleTimeLosses_seconds_\(d)")
        }

        // NEW: Per-mode aggregates (normal/hard)
        for m in ["normal", "hard"] {
            // Counts + best streak
            keys.append("wordleAllTimeCorrect_\(m)")
            keys.append("wordleAllTimeAnswered_\(m)")
            keys.append("wordleAllTimeBestStreak_\(m)")

            // Win-guess stats
            keys.append("wordleWinsGuessSum_\(m)")
            for i in 1...6 {
                keys.append("wordleWinsOnGuess\(i)_\(m)")
            }

            // Timing totals
            keys.append("wordleTimeTotal_seconds_\(m)")
            keys.append("wordleTimeWins_seconds_\(m)")
            keys.append("wordleTimeLosses_seconds_\(m)")
        }

        return keys
    }()

    // NEW: WORD daily solved flags (JSON [String:Int] dayKey -> 1)
    static let wordleSolvedMapKeys: [String] = [
        "wordleDailySolvedDays"
    ]

    // Game daily + last played keys
    static let gameDailyAndLastPlayedKeys: [String] = [
        "gamesDailyAnswered",      // JSON [String: Int]
        "gamesDailyCorrect",       // JSON [String: Int]
        "gamesLastPlayedAt",       // Double
        "gamesLastPlayedGameName"  // String
    ]

    // Timestamp helpers (for LWW game keys)
    func tsKey(for key: String) -> String { "__ts__\(key)" }

    func readLocalTimestamp(for key: String) -> Double {
        defaults.double(forKey: tsKey(for: key)) // returns 0 if missing
    }

    func writeLocalTimestampNow(for key: String) {
        defaults.set(Date().timeIntervalSince1970, forKey: tsKey(for: key))
    }

    func readRemoteTimestamp(for key: String) -> Double {
        kvs.double(forKey: tsKey(for: key)) // returns 0 if missing
    }

    func writeRemoteTimestampNow(for key: String) {
        kvs.set(Date().timeIntervalSince1970, forKey: tsKey(for: key))
    }

    // Identify game counter keys
    func isGameCounterKey(_ key: String) -> Bool {
        Self.hangmanKeys.contains(key) ||
        Self.beatClockKeys.contains(key) ||
        Self.refMatchKeys.contains(key) ||
        Self.verseMatchKeys.contains(key) ||
        Self.quizKeys.contains(key) ||
        Self.bookOrderKeys.contains(key) ||
        Self.whoAmIKeys.contains(key) ||
        Self.wordleKeys.contains(key)
    }

    // Local -> KVS for games
    func mirrorGamesKeyToKVS(_ key: String) {
        if Self.gameDailyAndLastPlayedKeys.contains(key) || Self.quizPerBookMapKeys.contains(key) || Self.wordleSolvedMapKeys.contains(key) {
            switch key {
            case "gamesDailyAnswered", "gamesDailyCorrect",
                 "quizPerBookAnsweredMap", "quizPerBookCorrectMap",
                 "wordleDailySolvedDays":
                let localData = defaults.data(forKey: key)
                let remoteData = kvs.object(forKey: key) as? Data
                if localData != remoteData {
                    if let data = localData {
                        kvs.set(data, forKey: key)
                    } else if remoteData != nil {
                        kvs.removeObject(forKey: key)
                    }
                }
            case "gamesLastPlayedAt":
                let local = defaults.double(forKey: key)
                let remoteObj = kvs.object(forKey: key) as? NSNumber
                let remote = remoteObj?.doubleValue ?? Double.nan
                if remote.isNaN || remote != local {
                    kvs.set(local, forKey: key)
                }
            case "gamesLastPlayedGameName":
                let local = defaults.string(forKey: key) ?? ""
                let remote = kvs.string(forKey: key) ?? ""
                if remote != local {
                    kvs.set(local, forKey: key)
                }
            default:
                break
            }
            return
        }

        if isGameCounterKey(key) {
            let localVal = defaults.integer(forKey: key)
            let remoteObj = kvs.object(forKey: key) as? NSNumber
            let remoteVal = remoteObj?.intValue
            if remoteVal == nil || remoteVal != localVal {
                kvs.set(localVal, forKey: key)
                writeLocalTimestampNow(for: key)
                writeRemoteTimestampNow(for: key)
            }
            return
        }
    }

    // KVS -> Local for games
    func mergeGamesIncoming(forKey key: String) {
        if Self.gameDailyAndLastPlayedKeys.contains(key) || Self.quizPerBookMapKeys.contains(key) || Self.wordleSolvedMapKeys.contains(key) {
            switch key {
            case "gamesDailyAnswered", "gamesDailyCorrect",
                 "quizPerBookAnsweredMap", "quizPerBookCorrectMap",
                 "wordleDailySolvedDays":
                if let remoteData = kvs.object(forKey: key) as? Data {
                    // If the remote map decodes to empty {}, treat as a reset: clear local.
                    if let remoteMap = decode(remoteData, as: [String: Int].self), remoteMap.isEmpty {
                        defaults.removeObject(forKey: key)
                    } else {
                        // Normal path: max-merge remote into local (sanitized)
                        let localData = defaults.data(forKey: key)
                        typealias Map = [String: Int]
                        let merged = mergeIntMapMax(localData: localData, remoteData: remoteData, type: Map.self)
                        if let data = try? JSONEncoder().encode(merged) {
                            defaults.set(data, forKey: key)
                        }
                    }
                } else {
                    // Remote deletion: clear local value
                    defaults.removeObject(forKey: key)
                }
            case "gamesLastPlayedAt":
                if kvs.object(forKey: key) == nil {
                    // Remote deletion
                    defaults.removeObject(forKey: key)
                } else {
                    let remote = kvs.double(forKey: key)
                    if remote <= 0 {
                        // Treat zero/empty as reset
                        defaults.removeObject(forKey: key)
                    } else {
                        let local = defaults.double(forKey: key)
                        if remote > local {
                            defaults.set(remote, forKey: key)
                        } else if remote < local {
                            kvs.set(local, forKey: key)
                        }
                    }
                }
            case "gamesLastPlayedGameName":
                if kvs.object(forKey: key) == nil {
                    // Remote deletion
                    defaults.removeObject(forKey: key)
                } else {
                    let remoteName = kvs.string(forKey: key) ?? ""
                    let remoteAt = kvs.double(forKey: "gamesLastPlayedAt")
                    if remoteName.isEmpty || remoteAt <= 0 {
                        // Treat empty/zero as reset
                        defaults.removeObject(forKey: key)
                        defaults.removeObject(forKey: "gamesLastPlayedAt")
                    } else {
                        let localName = defaults.string(forKey: key) ?? ""
                        let localAt = defaults.double(forKey: "gamesLastPlayedAt")
                        if remoteAt > localAt {
                            defaults.set(remoteName, forKey: key)
                            defaults.set(remoteAt, forKey: "gamesLastPlayedAt")
                        } else if remoteAt < localAt {
                            kvs.set(localName, forKey: key)
                            kvs.set(localAt, forKey: "gamesLastPlayedAt")
                        } else {
                            if localName.isEmpty && !remoteName.isEmpty {
                                defaults.set(remoteName, forKey: key)
                            } else if !localName.isEmpty && remoteName.isEmpty {
                                kvs.set(localName, forKey: key)
                            } else if localName != remoteName && !remoteName.isEmpty {
                                defaults.set(remoteName, forKey: key)
                            }
                        }
                    }
                }
            default:
                break
            }
            return
        }

        if isGameCounterKey(key) {
            // Last-write-wins using per-key timestamps
            let remoteTS = readRemoteTimestamp(for: key)
            let localTS = readLocalTimestamp(for: key)

            let remoteVal = Int(kvs.longLong(forKey: key))
            let localVal = defaults.integer(forKey: key)

            if remoteTS > localTS {
                defaults.set(max(0, remoteVal), forKey: key)
                defaults.set(remoteTS, forKey: tsKey(for: key))
            } else if remoteTS == 0 && localTS == 0 {
                let merged = max(max(0, localVal), max(0, remoteVal))
                defaults.set(merged, forKey: key)
                writeLocalTimestampNow(for: key)
                kvs.set(merged, forKey: key)
                writeRemoteTimestampNow(for: key)
                enqueueKeyForSync(key)
            } else {
                kvs.set(max(0, localVal), forKey: key)
                if localTS > 0 { kvs.set(localTS, forKey: tsKey(for: key)) }
                enqueueKeyForSync(key)
            }
            return
        }
    }

    // Centralized reset for all game counters (all scoreboard keys).
    func resetAllGameCountersToZero() {
        let gameKeys = Array(
            Self.hangmanKeys
            + Self.beatClockKeys
            + Self.refMatchKeys
            + Self.verseMatchKeys
            + Self.quizKeys
            + Self.bookOrderKeys
            + Self.whoAmIKeys
            + Self.wordleKeys
        )
        for key in gameKeys {
            defaults.set(0, forKey: key)
            writeLocalTimestampNow(for: key)
            kvs.set(0, forKey: key)
            writeRemoteTimestampNow(for: key)
        }
        enqueueKeysForSync(Set(gameKeys))

        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // NEW: Reset only Wordle counters (including timing + histogram) to zero.
    func resetWordleCountersToZero() {
        let keys = Set(Self.wordleKeys)
        for key in keys {
            defaults.set(0, forKey: key)
            writeLocalTimestampNow(for: key)
            kvs.set(0, forKey: key)
            writeRemoteTimestampNow(for: key)
        }
        enqueueKeysForSync(keys)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // NEW: Full wipe of all game-related data: counters, daily maps (overall + per-game), and last played.
    func resetAllGameDataToZero() {
        // 1) Reset all-time counters (includes WORD extras)
        resetAllGameCountersToZero()

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

        // NEW: Clear WORD daily solved flags
        defaults.removeObject(forKey: "wordleDailySolvedDays")
        kvs.removeObject(forKey: "wordleDailySolvedDays")

        // Enqueue these for sync (they are in allKnownKeys)
        enqueueKeysForSync(overallMapKeys + ["gamesLastPlayedAt", "gamesLastPlayedGameName", "wordleDailySolvedDays"])

        // 2b) Clear per-WORD mode daily maps (local-only keys used by Games tab scope)
        for modeKey in ["word_normal", "word_hard"] {
            defaults.removeObject(forKey: "gamesDailyAnswered_\(modeKey)")
            defaults.removeObject(forKey: "gamesDailyCorrect_\(modeKey)")
        }

        // 2c) Clear Bible Quiz per-book analytics (all-time maps mirrored, daily nested local-only)
        for key in ["quizPerBookAnsweredMap", "quizPerBookCorrectMap"] {
            defaults.removeObject(forKey: key)
            kvs.removeObject(forKey: key)
        }
        defaults.removeObject(forKey: "quizPerBookDailyAnswered")
        defaults.removeObject(forKey: "quizPerBookDailyCorrect")
        enqueueKeysForSync(["quizPerBookAnsweredMap", "quizPerBookCorrectMap"])

        // 2d) Optional: clear WORD daily completion flags so Daily isn’t “completed” after reset
        defaults.removeObject(forKey: "wordleDailyCompletedDay")
        defaults.removeObject(forKey: "wordleDailyTarget")

        // 3) Clear per-game daily maps (local-only keys; not mirrored to KVS)
        let perGameKeys = ["quiz","hangman","beatclock","versematch","bookorder","whoami","word"]
        for g in perGameKeys {
            defaults.removeObject(forKey: "gamesDailyAnswered_\(g)")
            defaults.removeObject(forKey: "gamesDailyCorrect_\(g)")
        }

        // 4) Notify UI to recompute all derived metrics to zero (streaks, Qs/day, 7D accuracy, per-game charts, insights)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)

        // 5) NEW: Immediately push all known keys so zeros/removals propagate across devices now.
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
                defaults.set(c, forKey: answeredKey)
                writeLocalTimestampNow(for: answeredKey)
                kvs.set(c, forKey: answeredKey)
                writeRemoteTimestampNow(for: answeredKey)
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

        // Hangman (easy/normal/medium/hard) + legacy unsuffixed
        repairSuffixed(prefix: "hangman", diffs: ["easy","normal","medium","hard"])
        repairPair(correctKey: "hangmanAllTimeCorrect", answeredKey: "hangmanAllTimeAnswered")

        // Beat the Clock — include both normal and medium
        repairSuffixed(prefix: "beatclock", diffs: ["easy","normal","medium","hard"])

        // Verse Match (new) + Reference Match (legacy)
        repairSuffixed(prefix: "versematch", diffs: ["easy","normal","medium","hard"])
        repairSuffixed(prefix: "refmatch", diffs: ["easy","normal","medium","hard"])
        repairPair(correctKey: "refmatchAllTimeCorrect", answeredKey: "refmatchAllTimeAnswered")

        // Quiz (easy/normal/hard)
        repairSuffixed(prefix: "quiz", diffs: ["easy","normal","hard"])

        // Who am I? (easy/normal/hard)
        repairSuffixed(prefix: "whoami", diffs: ["easy","normal","hard"])

        // Book Order (easy/normal/hard/all) + legacy unsuffixed
        repairSuffixed(prefix: "bookorder", diffs: ["easy","normal","hard","all"])
        repairPair(correctKey: "bookorderAllTimeCorrect", answeredKey: "bookorderAllTimeAnswered")

        // Wordle (daily/free/all + normal/hard)
        repairSuffixed(prefix: "wordle", diffs: ["daily","free","all","normal","hard"])

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
            defaults.set(srcCv, forKey: dstC)
            defaults.set(srcAv, forKey: dstA)
            defaults.set(srcBv, forKey: dstB)
            writeLocalTimestampNow(for: dstC); writeRemoteTimestampNow(for: dstC)
            writeLocalTimestampNow(for: dstA); writeRemoteTimestampNow(for: dstA)
            writeLocalTimestampNow(for: dstB); writeRemoteTimestampNow(for: dstB)

            kvs.set(srcCv, forKey: dstC)
            kvs.set(srcAv, forKey: dstA)
            kvs.set(srcBv, forKey: dstB)

            changed.formUnion([dstC, dstA, dstB])
        }

        for d in diffs { copyIfNeeded(suffix: d) }
        return changed
    }

    // Max-merge helper reused for game daily maps
    func mergeIntMapMax(localData: Data?, remoteData: Data, type: [String: Int].Type) -> [String: Int] {
        let local = decode(localData, as: type) ?? [:]
        let remote = decode(remoteData, as: type) ?? [:]
        var merged = local
        for (k, v) in remote {
            let sanitized = max(0, v)
            if let existing = merged[k] {
                merged[k] = max(existing, sanitized)
            } else {
                merged[k] = sanitized
            }
        }
        return merged
    }
}

