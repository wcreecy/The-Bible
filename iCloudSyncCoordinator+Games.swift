import Foundation

@MainActor
extension iCloudSyncCoordinator {
    // Game keys: Hangman
    static let hangmanKeys: [String] = {
        let diffs = ["easy", "medium", "hard"]
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

    // Game keys: Reference Match
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

    // Game keys: Book Order — now per-difficulty (easy/normal/hard/all)
    static let bookOrderKeys: [String] = {
        let diffs = ["easy", "normal", "hard", "all"]
        var keys: [String] = []
        for d in diffs {
            keys.append("bookorderAllTimeCorrect_\(d)")
            keys.append("bookorderAllTimeAnswered_\(d)")
            keys.append("bookorderAllTimeBestStreak_\(d)")
        }
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
        Self.quizKeys.contains(key) ||
        Self.bookOrderKeys.contains(key) ||
        Self.whoAmIKeys.contains(key)
    }

    // Local -> KVS for games
    func mirrorGamesKeyToKVS(_ key: String) {
        if Self.gameDailyAndLastPlayedKeys.contains(key) {
            switch key {
            case "gamesDailyAnswered", "gamesDailyCorrect":
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
            // Only write if the value actually differs or doesn't exist remotely
            if remoteVal == nil || remoteVal != localVal {
                kvs.set(localVal, forKey: key)
                // Update and mirror timestamp for LWW only when value changed
                writeLocalTimestampNow(for: key)
                writeRemoteTimestampNow(for: key)
            }
            return
        }
    }

    // KVS -> Local for games
    func mergeGamesIncoming(forKey key: String) {
        if Self.gameDailyAndLastPlayedKeys.contains(key) {
            switch key {
            case "gamesDailyAnswered", "gamesDailyCorrect":
                guard let remoteData = kvs.object(forKey: key) as? Data else { return }
                let localData = defaults.data(forKey: key)
                typealias Map = [String: Int]
                let merged = mergeIntMapMax(localData: localData, remoteData: remoteData, type: Map.self)
                if let data = try? JSONEncoder().encode(merged) {
                    defaults.set(data, forKey: key)
                }
            case "gamesLastPlayedAt":
                let remote = kvs.double(forKey: key)
                let local = defaults.double(forKey: key)
                // Latest timestamp wins
                if remote > local {
                    defaults.set(remote, forKey: key)
                } else if remote < local {
                    kvs.set(local, forKey: key)
                }
            case "gamesLastPlayedGameName":
                let remoteName = kvs.string(forKey: key) ?? ""
                let localName = defaults.string(forKey: key) ?? ""
                // Prefer the one with newer gamesLastPlayedAt
                let remoteAt = kvs.double(forKey: "gamesLastPlayedAt")
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
            default:
                break
            }
            return
        }

        if isGameCounterKey(key) {
            // Last-write-wins using per-key timestamps
            let remoteTS = readRemoteTimestamp(for: key)
            let localTS = readLocalTimestamp(for: key)

            // Read values
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
                // Schedule a sync (debounced)
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
        let gameKeys = Array(Self.hangmanKeys + Self.beatClockKeys + Self.refMatchKeys + Self.quizKeys + Self.bookOrderKeys + Self.whoAmIKeys)
        for key in gameKeys {
            defaults.set(0, forKey: key)
            // Update per-key timestamp so the zero wins in LWW merges.
            writeLocalTimestampNow(for: key)
            kvs.set(0, forKey: key)
            writeRemoteTimestampNow(for: key)
        }
        enqueueKeysForSync(Set(gameKeys))

        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
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
                // Update local
                defaults.set(c, forKey: answeredKey)
                writeLocalTimestampNow(for: answeredKey)
                // Update remote
                kvs.set(c, forKey: answeredKey)
                writeRemoteTimestampNow(for: answeredKey)
                changed.insert(answeredKey)
            }
        }

        // Helper to iterate suffixed difficulties
        func repairSuffixed(prefix: String, diffs: [String]) {
            for d in diffs {
                let cKey = "\(prefix)AllTimeCorrect_\(d)"
                let aKey = "\(prefix)AllTimeAnswered_\(d)"
                repairPair(correctKey: cKey, answeredKey: aKey)
            }
        }

        // Hangman (easy/medium/hard) + legacy unsuffixed
        repairSuffixed(prefix: "hangman", diffs: ["easy","medium","hard"])
        repairPair(correctKey: "hangmanAllTimeCorrect", answeredKey: "hangmanAllTimeAnswered")

        // Beat the Clock — include both normal and medium
        repairSuffixed(prefix: "beatclock", diffs: ["easy","normal","medium","hard"])

        // Verse Match + legacy — include both normal and medium
        repairSuffixed(prefix: "refmatch", diffs: ["easy","normal","medium","hard"])
        repairPair(correctKey: "refmatchAllTimeCorrect", answeredKey: "refmatchAllTimeAnswered")

        // Quiz (easy/normal/hard)
        repairSuffixed(prefix: "quiz", diffs: ["easy","normal","hard"])

        // Who am I? (easy/normal/hard)
        repairSuffixed(prefix: "whoami", diffs: ["easy","normal","hard"])

        // Book Order (easy/normal/hard/all)
        repairSuffixed(prefix: "bookorder", diffs: ["easy","normal","hard","all"])

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
