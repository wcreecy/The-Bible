import Foundation

@MainActor
extension iCloudSyncCoordinator {
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

    func isTimestampedStatsKey(_ key: String) -> Bool {
        Self.timestampedStatsKeySet.contains(key)
    }

    private static let timestampedStatsKeySet: Set<String> = {
        Set(bibleStatsKeys + sessionKeys + settingsKeys).union(allKnownGameDataKeySet)
    }()

    // Identify game counter keys
    func isGameCounterKey(_ key: String) -> Bool {
        Self.gameCounterKeySet.contains(key)
    }

    private static let gameCounterKeySet: Set<String> = {
        Set(
            allPersistentStreakKeys + hangmanKeys + beatClockKeys + refMatchKeys
                + verseMatchKeys + quizKeys + bibleTriviaKeys + bookOrderKeys + whoAmIKeys
                + wordleKeys + wordSearchKeys + scrambleKeys + crosswordKeys
        )
    }()

    /// Keys merged and mirrored by the games code: counters plus the daily, per-book,
    /// per-category, and WORD maps.
    func isGamesDomainKey(_ key: String) -> Bool {
        Self.gamesDomainKeySet.contains(key)
    }

    private static let gamesDomainKeySet: Set<String> = {
        gameCounterKeySet.union(
            gameDailyAndLastPlayedKeys + quizPerBookMapKeys + triviaPerBookMapKeys
                + quizPerBookDailyMapKeys + triviaPerBookDailyMapKeys
                + verseMatchPerBookMapKeys + beatClockPerTypeMapKeys + hangmanPerCategoryMapKeys
                + perGameDailyMapKeys + wordleSolvedMapKeys + wordleDailyResultKeys
                + wordleDailyFlagKeys + bibleTriviaProgressKeys
        )
    }()

    // Local -> KVS for games
    func mirrorGamesKeyToKVS(_ key: String) {
        // Counters and maps are published through per-device ledgers. Their legacy
        // shared keys stay frozen so devices migrating later read a stable baseline.
        guard !GameStatsLedger.isManaged(key) else { return }

        if Self.bibleTriviaProgressKeys.contains(key) {
            let merged = BibleTriviaProgressStore.mergedData(
                local: defaults.data(forKey: key),
                remote: kvs.object(forKey: key) as? Data
            )
            if let merged {
                defaults.set(merged, forKey: key)
                kvs.set(merged, forKey: key)
            } else {
                kvs.removeObject(forKey: key)
            }
            return
        }

        let localTimestamp = readLocalTimestamp(for: key)
        let remoteTimestamp = readRemoteTimestamp(for: key)
        guard remoteTimestamp <= localTimestamp || (remoteTimestamp == 0 && localTimestamp == 0) else {
            return
        }
        defer {
            if localTimestamp > 0 {
                kvs.set(localTimestamp, forKey: tsKey(for: key))
            }
        }

        if Self.gameDailyAndLastPlayedKeys.contains(key)
            || Self.quizPerBookMapKeys.contains(key)
            || Self.triviaPerBookMapKeys.contains(key)
            || Self.quizPerBookDailyMapKeys.contains(key)
            || Self.triviaPerBookDailyMapKeys.contains(key)
            || Self.hangmanPerCategoryMapKeys.contains(key)
            || Self.beatClockPerTypeMapKeys.contains(key)
            || Self.verseMatchPerBookMapKeys.contains(key)
            || Self.perGameDailyMapKeys.contains(key)
            || Self.wordleSolvedMapKeys.contains(key)
            || Self.wordleDailyResultKeys.contains(key)
            || Self.wordleDailyFlagKeys.contains(key) {
            switch key {
            case "gamesDailyAnswered", "gamesDailyCorrect",
                 "quizPerBookAnsweredMap", "quizPerBookCorrectMap",
                 "triviaPerBookAnsweredMap", "triviaPerBookCorrectMap",
                 "hangmanPerCategoryAnsweredMap", "hangmanPerCategoryCorrectMap",
                 "beatclockPerTypeAnsweredMap", "beatclockPerTypeCorrectMap",
                 "versematchPerBookAnsweredMap", "versematchPerBookCorrectMap",
                 "quizPerBookDailyAnswered", "quizPerBookDailyCorrect",
                 "triviaPerBookDailyAnswered", "triviaPerBookDailyCorrect",
                 // per-game daily maps
                 _ where Self.perGameDailyMapKeys.contains(key),
                 "wordleDailySolvedDays",
                 "wordleDailyResultMap":
                let localData = defaults.data(forKey: key)
                let remoteData = kvs.object(forKey: key) as? Data
                if localData != remoteData {
                    if let data = localData {
                        kvs.set(data, forKey: key)
                    } else if remoteData != nil {
                        kvs.removeObject(forKey: key)
                    }
                }

            case "wordleDailyCompletedDay", "wordleDailyTarget":
                let local = defaults.string(forKey: key)
                let remote = kvs.string(forKey: key)
                if local != remote {
                    if let s = local {
                        kvs.set(s, forKey: key)
                    } else if remote != nil {
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
            }
            return
        }
    }

    // KVS -> Local for games
    func mergeGamesIncoming(forKey key: String) {
        // Ledger-managed values are rebuilt from every device's ledger instead.
        guard !GameStatsLedger.isManaged(key) else { return }

        if Self.bibleTriviaProgressKeys.contains(key) {
            let merged = BibleTriviaProgressStore.mergedData(
                local: defaults.data(forKey: key),
                remote: kvs.object(forKey: key) as? Data
            )
            if let merged {
                defaults.set(merged, forKey: key)
                if kvs.object(forKey: key) as? Data != merged {
                    kvs.set(merged, forKey: key)
                    enqueueKeyForSync(key)
                }
            } else {
                defaults.removeObject(forKey: key)
            }
            AppDataChanges.shared.gameStatsChanged()
            return
        }

        let remoteTimestamp = readRemoteTimestamp(for: key)
        let localTimestamp = readLocalTimestamp(for: key)
        if remoteTimestamp > 0 || localTimestamp > 0 {
            if remoteTimestamp > localTimestamp {
                if let remoteValue = kvs.object(forKey: key) {
                    defaults.set(remoteValue, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
                defaults.set(remoteTimestamp, forKey: tsKey(for: key))
            } else if localTimestamp > remoteTimestamp {
                mirrorGamesKeyToKVS(key)
                enqueueKeyForSync(key)
            }
            return
        }

        // Legacy values without timestamps retain their existing merge behavior.
        if Self.quizPerBookDailyMapKeys.contains(key) || Self.triviaPerBookDailyMapKeys.contains(key) {
            if let remoteData = kvs.object(forKey: key) as? Data {
                let local = decode(defaults.data(forKey: key), as: [String: [String: Int]].self) ?? [:]
                let remote = decode(remoteData, as: [String: [String: Int]].self) ?? [:]
                var merged = local
                for (day, remoteBooks) in remote {
                    var books = merged[day] ?? [:]
                    for (book, count) in remoteBooks {
                        books[book] = max(books[book] ?? 0, max(0, count))
                    }
                    merged[day] = books
                }
                if let data = try? JSONEncoder().encode(merged) {
                    defaults.set(data, forKey: key)
                }
            }
            return
        }

        if Self.gameDailyAndLastPlayedKeys.contains(key)
            || Self.quizPerBookMapKeys.contains(key)
            || Self.triviaPerBookMapKeys.contains(key)
            || Self.quizPerBookDailyMapKeys.contains(key)
            || Self.triviaPerBookDailyMapKeys.contains(key)
            || Self.hangmanPerCategoryMapKeys.contains(key)
            || Self.beatClockPerTypeMapKeys.contains(key)
            || Self.verseMatchPerBookMapKeys.contains(key)
            || Self.perGameDailyMapKeys.contains(key)
            || Self.wordleSolvedMapKeys.contains(key)
            || Self.wordleDailyResultKeys.contains(key)
            || Self.wordleDailyFlagKeys.contains(key) {
            switch key {
            case "gamesDailyAnswered", "gamesDailyCorrect",
                 "quizPerBookAnsweredMap", "quizPerBookCorrectMap",
                 "triviaPerBookAnsweredMap", "triviaPerBookCorrectMap",
                 "hangmanPerCategoryAnsweredMap", "hangmanPerCategoryCorrectMap",
                 "beatclockPerTypeAnsweredMap", "beatclockPerTypeCorrectMap",
                 "versematchPerBookAnsweredMap", "versematchPerBookCorrectMap",
                 // per-game daily maps
                 _ where Self.perGameDailyMapKeys.contains(key),
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

            case "wordleDailyResultMap":
                // Merge [String: DailyResult] by day key, preferring remote for overlapping days
                if let remoteData = kvs.object(forKey: key) as? Data {
                    let localData = defaults.data(forKey: key)
                    struct Result: Codable { let won: Bool; let guesses: Int; let elapsed: Int; let word: String }
                    let remoteMap = decode(remoteData, as: [String: Result].self) ?? [:]
                    let localMap = decode(localData, as: [String: Result].self) ?? [:]
                    var merged = localMap
                    for (k, v) in remoteMap {
                        merged[k] = v // remote wins for overlapping keys
                    }
                    if merged.isEmpty {
                        defaults.removeObject(forKey: key)
                    } else if let data = try? JSONEncoder().encode(merged) {
                        defaults.set(data, forKey: key)
                    }
                } else {
                    // Remote deletion: clear local
                    defaults.removeObject(forKey: key)
                }

            case "wordleDailyCompletedDay", "wordleDailyTarget":
                if kvs.object(forKey: key) == nil {
                    defaults.removeObject(forKey: key)
                } else {
                    let remoteVal = kvs.string(forKey: key) ?? ""
                    let localVal = defaults.string(forKey: key) ?? ""
                    if remoteVal != localVal {
                        if remoteVal.isEmpty {
                            defaults.removeObject(forKey: key)
                        } else {
                            defaults.set(remoteVal, forKey: key)
                        }
                    }
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
