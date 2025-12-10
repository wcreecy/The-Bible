import Foundation

// iCloud Key-Value sync coordinator for small aggregates and reading stats.
// Mirrors selected UserDefaults keys to NSUbiquitousKeyValueStore and merges incoming changes.
// Add iCloud capability with "Key-Value storage" enabled for this target.
@MainActor
final class iCloudSyncCoordinator {
    static let shared = iCloudSyncCoordinator()

    private let kvs = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard

    // One-time bootstrap flag so we push existing local values to KVS on first run after adding sync.
    private let bootstrapFlagKey = "kvsBootstrapComplete_v1"

    // Track last push/merge timestamps (persisted so Settings can show across launches)
    private let lastPushKey = "kvsLastPushDate"
    private let lastMergeKey = "kvsLastMergeDate"
    private(set) var lastPushDate: Date? {
        get { defaults.object(forKey: lastPushKey) as? Date }
        set { defaults.set(newValue, forKey: lastPushKey) }
    }
    private(set) var lastMergeDate: Date? {
        get { defaults.object(forKey: lastMergeKey) as? Date }
        set { defaults.set(newValue, forKey: lastMergeKey) }
    }

    // Simple availability hint for KVS (user signed into iCloud)
    var kvsAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKVSExternalChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs
        )
        kvs.synchronize()

        // Perform one-time bootstrap
        if !defaults.bool(forKey: bootstrapFlagKey) {
            pushAllLocalToKVS()
            defaults.set(true, forKey: bootstrapFlagKey)
            kvs.synchronize()
            lastPushDate = Date()
        }

        // Opportunistic push at launch to reduce drift
        pushAllLocalToKVS()
        lastPushDate = Date()
    }

    // MARK: - Public API

    func start() {
        // Intentionally empty; initializer wires everything.
        // Call iCloudSyncCoordinator.shared.start() once at app launch.
    }

    // Call after local writes if you want to eagerly push a specific key.
    func pushKey(_ key: String) {
        // Only push keys we know how to merge.
        guard allKnownKeys.contains(key) else { return }
        mirrorLocalKeyToKVS(key)
        kvs.synchronize()
        lastPushDate = Date()
    }

    // Optional: push all known keys now (useful on app background)
    func pushAllNow() {
        pushAllLocalToKVS()
        lastPushDate = Date()
    }

    // NEW: Centralized reset for all game counters (all scoreboard keys).
    func resetAllGameCountersToZero() {
        // Zero every game key we know, stamp timestamps, and mirror to KVS.
        let gameKeys = Array(hangmanKeys + beatClockKeys + refMatchKeys + quizKeys + bookOrderKeys)
        for key in gameKeys {
            defaults.set(0, forKey: key)
            // Update per-key timestamp so the zero wins in LWW merges.
            writeLocalTimestampNow(for: key)
            kvs.set(0, forKey: key)
            writeRemoteTimestampNow(for: key)
        }
        kvs.synchronize()
        lastPushDate = Date()

        // Invalidate any in-memory consumers and notify UI to refresh scoreboards.
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // MARK: - Key sets

    // BibleStatsStore keys
    private var stats_keyTotals: String { BibleStatsStore.Defaults.keyTotals }
    private var stats_keyDailyTotals: String { BibleStatsStore.Defaults.keyDailyTotals }
    private var stats_keyDailyTotalsByBook: String { BibleStatsStore.Defaults.keyDailyTotalsByBook }
    private var stats_keyVisitedChapters: String { BibleStatsStore.Defaults.keyVisitedChapters }
    private var stats_keyLastRead: String { BibleStatsStore.Defaults.keyLastRead }
    private var stats_keySeenVersesByChapter: String { BibleStatsStore.Defaults.keySeenVersesByChapter }
    private var stats_keyChapterCompletionDates: String { BibleStatsStore.Defaults.keyChapterCompletionDates }

    // Reading sessions key
    private var sessions_key: String { "readingSessions" }

    // Settings keys to sync across devices
    private let settingsKeys: [String] = [
        "dailyGoalMinutes"
    ]

    // Game keys: Hangman
    private let hangmanKeys: [String] = {
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
    private let beatClockKeys: [String] = {
        let diffs = ["easy", "medium", "hard"]
        var keys: [String] = []
        for d in diffs {
            keys.append("beatclockAllTimeCorrect_\(d)")
            keys.append("beatclockAllTimeAnswered_\(d)")
            keys.append("beatclockAllTimeBestStreak_\(d)")
        }
        return keys
    }()

    // Game keys: Reference Match
    private let refMatchKeys: [String] = {
        let diffs = ["easy", "medium", "hard"]
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
    private let quizKeys: [String] = {
        let diffs = ["easy", "normal", "hard"]
        var keys: [String] = []
        for d in diffs {
            keys.append("quizAllTimeCorrect_\(d)")
            keys.append("quizAllTimeAnswered_\(d)")
            keys.append("quizAllTimeBestStreak_\(d)")
        }
        return keys
    }()

    // Game keys: Book Order — enabled for KVS sync
    private let bookOrderKeys: [String] = [
        "bookorderAllTimeCorrect",
        "bookorderAllTimeAnswered",
        "bookorderAllTimeBestStreak"
    ]

    // NEW: Game daily + last played keys
    private let gamesDailyAnsweredKey = "gamesDailyAnswered"      // JSON [String: Int]
    private let gamesDailyCorrectKey = "gamesDailyCorrect"        // JSON [String: Int]
    private let gamesLastPlayedAtKey = "gamesLastPlayedAt"        // Double
    private let gamesLastPlayedGameNameKey = "gamesLastPlayedGameName" // String

    private var bibleStatsKeys: [String] {
        [
            stats_keyTotals,
            stats_keyDailyTotals,
            stats_keyDailyTotalsByBook,
            stats_keyVisitedChapters,
            stats_keyLastRead,
            stats_keySeenVersesByChapter,
            stats_keyChapterCompletionDates
        ]
    }

    private var sessionKeys: [String] {
        [sessions_key]
    }

    private var gameDailyAndLastPlayedKeys: [String] {
        [gamesDailyAnsweredKey, gamesDailyCorrectKey, gamesLastPlayedAtKey, gamesLastPlayedGameNameKey]
    }

    private var allKnownKeys: Set<String> {
        Set(bibleStatsKeys + sessionKeys + settingsKeys + hangmanKeys + beatClockKeys + refMatchKeys + quizKeys + bookOrderKeys + gameDailyAndLastPlayedKeys)
    }

    // MARK: - Bootstrap

    private func pushAllLocalToKVS() {
        for key in allKnownKeys {
            mirrorLocalKeyToKVS(key)
        }
        kvs.synchronize()
    }

    // MARK: - Timestamp helpers (for LWW game keys)

    private func tsKey(for key: String) -> String { "__ts__\(key)" }

    private func readLocalTimestamp(for key: String) -> Double {
        defaults.double(forKey: tsKey(for: key)) // returns 0 if missing
    }

    private func writeLocalTimestampNow(for key: String) {
        defaults.set(Date().timeIntervalSince1970, forKey: tsKey(for: key))
    }

    private func readRemoteTimestamp(for key: String) -> Double {
        kvs.double(forKey: tsKey(for: key)) // returns 0 if missing
    }

    private func writeRemoteTimestampNow(for key: String) {
        kvs.set(Date().timeIntervalSince1970, forKey: tsKey(for: key))
    }

    // MARK: - KVS change handling

    @objc
    private func handleKVSExternalChange(_ note: Notification) {
        guard let userInfo = note.userInfo else { return }

        let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
        // Filter to known data keys; ignore our timestamp companion keys
        let keysToProcess = changedKeys.filter { allKnownKeys.contains($0) }

        guard !keysToProcess.isEmpty else { return }

        var mergedGameKey = false

        for key in keysToProcess {
            if isGameCounterKey(key) || gameDailyAndLastPlayedKeys.contains(key) { mergedGameKey = true }
            mergeIncomingKVSValue(forKey: key)
        }

        // Invalidate caches so subsequent reads reflect merged values
        BibleStatsStore.shared.resetCaches()

        // Notify UI that stats may have changed (StatsView can refresh)
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)

        // If any game keys merged, notify interested views (scoreboard) as well
        if mergedGameKey {
            NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
        }

        // Record last merge time
        lastMergeDate = Date()
    }

    // MARK: - Mirroring local -> KVS

    private func mirrorLocalKeyToKVS(_ key: String) {
        // Settings keys (simple scalar Ints for now)
        if settingsKeys.contains(key) {
            let v = defaults.integer(forKey: key)
            kvs.set(v, forKey: key)
            return
        }

        // Game daily maps + last played scalar mirrors
        if gameDailyAndLastPlayedKeys.contains(key) {
            switch key {
            case gamesDailyAnsweredKey, gamesDailyCorrectKey:
                if let data = defaults.data(forKey: key) {
                    kvs.set(data, forKey: key)
                } else {
                    kvs.removeObject(forKey: key)
                }
            case gamesLastPlayedAtKey:
                let ts = defaults.double(forKey: key)
                kvs.set(ts, forKey: key)
            case gamesLastPlayedGameNameKey:
                let name = defaults.string(forKey: key) ?? ""
                kvs.set(name, forKey: key)
            default:
                break
            }
            return
        }

        // We store JSON blobs for complex values, and Ints directly for counters.
        if isGameCounterKey(key) {
            let v = defaults.integer(forKey: key)
            kvs.set(v, forKey: key)
            // Update and mirror timestamp for LWW
            writeLocalTimestampNow(for: key)
            writeRemoteTimestampNow(for: key)
            return
        }

        if bibleStatsKeys.contains(key) || sessionKeys.contains(key) {
            if let data = defaults.data(forKey: key) {
                kvs.set(data, forKey: key)
            } else {
                kvs.removeObject(forKey: key)
            }
            return
        }

        // Unknown keys are ignored
    }

    // MARK: - Merging KVS -> local

    private func mergeIncomingKVSValue(forKey key: String) {
        // Settings keys (simple scalar Ints)
        if settingsKeys.contains(key) {
            let remoteVal = Int(kvs.longLong(forKey: key))
            // Only update if different to avoid churn
            if defaults.integer(forKey: key) != remoteVal {
                defaults.set(remoteVal, forKey: key)
            }
            return
        }

        // NEW: Game daily maps and last played fields
        if gameDailyAndLastPlayedKeys.contains(key) {
            switch key {
            case gamesDailyAnsweredKey, gamesDailyCorrectKey:
                guard let remoteData = kvs.object(forKey: key) as? Data else { return }
                let localData = defaults.data(forKey: key)
                typealias Map = [String: Int]
                let merged = mergeIntMapMax(localData: localData, remoteData: remoteData, type: Map.self)
                if let data = try? JSONEncoder().encode(merged) {
                    defaults.set(data, forKey: key)
                }
            case gamesLastPlayedAtKey:
                let remote = kvs.double(forKey: key)
                let local = defaults.double(forKey: key)
                // Latest timestamp wins
                if remote > local {
                    defaults.set(remote, forKey: key)
                } else if remote < local {
                    kvs.set(local, forKey: key)
                }
            case gamesLastPlayedGameNameKey:
                let remoteName = kvs.string(forKey: key) ?? ""
                let localName = defaults.string(forKey: key) ?? ""
                // Prefer the one with newer gamesLastPlayedAt
                let remoteAt = kvs.double(forKey: gamesLastPlayedAtKey)
                let localAt = defaults.double(forKey: gamesLastPlayedAtKey)
                if remoteAt > localAt {
                    // Adopt remote name and timestamp pair
                    defaults.set(remoteName, forKey: key)
                    defaults.set(remoteAt, forKey: gamesLastPlayedAtKey)
                } else if remoteAt < localAt {
                    // Keep local; ensure KVS reflects local pair for propagation
                    kvs.set(localName, forKey: key)
                    kvs.set(localAt, forKey: gamesLastPlayedAtKey)
                } else {
                    // Timestamps equal or both zero: keep non-empty
                    if localName.isEmpty && !remoteName.isEmpty {
                        defaults.set(remoteName, forKey: key)
                    } else if !localName.isEmpty && remoteName.isEmpty {
                        kvs.set(localName, forKey: key)
                    } else if localName != remoteName && !remoteName.isEmpty {
                        // If both non-empty but different and timestamps equal, prefer remote conservatively
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

            // Missing timestamps are treated as very old (0)
            // If remote newer, adopt remote; if local newer or equal, keep local.
            if remoteTS > localTS {
                defaults.set(max(0, remoteVal), forKey: key)
                // Update local timestamp to remote's timestamp so both sides agree
                defaults.set(remoteTS, forKey: tsKey(for: key))
            } else if remoteTS == 0 && localTS == 0 {
                // Legacy case: fall back to max once, then stamp local as now
                let merged = max(max(0, localVal), max(0, remoteVal))
                defaults.set(merged, forKey: key)
                writeLocalTimestampNow(for: key)
                kvs.set(merged, forKey: key)
                writeRemoteTimestampNow(for: key)
            } else {
                // Local is newer or equal; ensure KVS reflects local (helps propagate clears)
                kvs.set(max(0, localVal), forKey: key)
                // Also mirror the local timestamp to KVS
                if localTS > 0 { kvs.set(localTS, forKey: tsKey(for: key)) }
            }
            return
        }

        if bibleStatsKeys.contains(key) {
            guard let remoteData = kvs.object(forKey: key) as? Data else { return }
            let localData = defaults.data(forKey: key)

            switch key {
            case stats_keyTotals:
                // CHANGE: per-book totals use max per entry
                typealias Map = [String: Int]
                let merged = mergeIntMapMax(localData: localData, remoteData: remoteData, type: Map.self)
                if let data = try? JSONEncoder().encode(merged) { defaults.set(data, forKey: key) }

            case stats_keyDailyTotals:
                // CHANGE: per-day totals use max per entry
                typealias Map = [String: Int]
                let merged = mergeIntMapMax(localData: localData, remoteData: remoteData, type: Map.self)
                if let data = try? JSONEncoder().encode(merged) { defaults.set(data, forKey: key) }

            case stats_keyDailyTotalsByBook:
                // CHANGE: nested per-day per-book totals use max per entry
                typealias Map = [String: [String: Int]]
                let merged = mergeNestedIntMapMax(localData: localData, remoteData: remoteData, type: Map.self)
                if let data = try? JSONEncoder().encode(merged) { defaults.set(data, forKey: key) }

            case stats_keyVisitedChapters:
                typealias Arr = [String]
                let mergedSet = mergeStringSet(localData: localData, remoteData: remoteData, type: Arr.self)
                if let data = try? JSONEncoder().encode(Array(mergedSet)) { defaults.set(data, forKey: key) }

            case stats_keySeenVersesByChapter:
                typealias Map = [String: [Int]]
                let merged = mergeSeenVerses(localData: localData, remoteData: remoteData, type: Map.self)
                if let data = try? JSONEncoder().encode(merged) { defaults.set(data, forKey: key) }

            case stats_keyChapterCompletionDates:
                typealias Map = [String: Date]
                let merged = mergeDateMap(localData: localData, remoteData: remoteData, type: Map.self, strategy: .earliest)
                if let data = try? JSONEncoder().encode(merged) { defaults.set(data, forKey: key) }

            case stats_keyLastRead:
                typealias Entry = BibleStatsStore.LastRead
                let merged = mergeLastRead(localData: localData, remoteData: remoteData, type: Entry.self)
                if let data = try? JSONEncoder().encode(merged) { defaults.set(data, forKey: key) }

            default:
                break
            }
            return
        }

        if sessionKeys.contains(key) {
            // Merge reading sessions by union/dedupe using a stable identity (start, end, book, chapter)
            guard let remoteData = kvs.object(forKey: key) as? Data else { return }
            let localData = defaults.data(forKey: key)
            typealias Arr = [ReadingSessionsStore.Session]
            let merged = mergeSessions(localData: localData, remoteData: remoteData, type: Arr.self)
            if let data = try? JSONEncoder().encode(merged) {
                defaults.set(data, forKey: key)
            }
            return
        }
    }

    // MARK: - Merge helpers

    private func isGameCounterKey(_ key: String) -> Bool {
        hangmanKeys.contains(key) ||
        beatClockKeys.contains(key) ||
        refMatchKeys.contains(key) ||
        quizKeys.contains(key) ||
        bookOrderKeys.contains(key)
    }

    private func safeSum(_ a: Int, _ b: Int) -> Int {
        let (sum, overflow) = a.addingReportingOverflow(b)
        return overflow ? Int.max : sum
    }

    private func decode<T: Decodable>(_ data: Data?, as type: T.Type) -> T? {
        guard let d = data else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }

    // Sum-merge (kept for reference; not used for stats after max-merge change)
    private func mergeIntMapSum(localData: Data?, remoteData: Data, type: [String: Int].Type) -> [String: Int] {
        let local = decode(localData, as: type) ?? [:]
        let remote = decode(remoteData, as: type) ?? [:]
        var merged = local
        for (k, v) in remote {
            merged[k, default: 0] = safeSum(merged[k, default: 0], max(0, v))
        }
        return merged
    }

    private func mergeNestedIntMapSum(localData: Data?, remoteData: Data, type: [String: [String: Int]].Type) -> [String: [String: Int]] {
        let local = decode(localData, as: type) ?? [:]
        let remote = decode(remoteData, as: type) ?? [:]
        var merged = local
        for (date, perBookRemote) in remote {
            var perBook = merged[date] ?? [:]
            for (book, sec) in perBookRemote {
                perBook[book, default: 0] = safeSum(perBook[book, default: 0], max(0, sec))
            }
            merged[date] = perBook
        }
        return merged
    }

    // NEW: Max-merge helpers for stats
    private func mergeIntMapMax(localData: Data?, remoteData: Data, type: [String: Int].Type) -> [String: Int] {
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

    private func mergeNestedIntMapMax(localData: Data?, remoteData: Data, type: [String: [String: Int]].Type) -> [String: [String: Int]] {
        let local = decode(localData, as: type) ?? [:]
        let remote = decode(remoteData, as: type) ?? [:]
        var merged = local
        for (date, perBookRemote) in remote {
            var perBook = merged[date] ?? [:]
            for (book, sec) in perBookRemote {
                let sanitized = max(0, sec)
                if let existing = perBook[book] {
                    perBook[book] = max(existing, sanitized)
                } else {
                    perBook[book] = sanitized
                }
            }
            merged[date] = perBook
        }
        return merged
    }

    private func mergeStringSet(localData: Data?, remoteData: Data, type: [String].Type) -> Set<String> {
        let localArr = decode(localData, as: type) ?? []
        let remoteArr = decode(remoteData, as: type) ?? []
        return Set(localArr).union(remoteArr)
    }

    private func mergeSeenVerses(localData: Data?, remoteData: Data, type: [String: [Int]].Type) -> [String: [Int]] {
        let local = decode(localData, as: type) ?? [:]
        let remote = decode(remoteData, as: type) ?? [:]
        var merged: [String: [Int]] = local
        for (chapterKey, remoteVerses) in remote {
            let localSet = Set(local[chapterKey] ?? [])
            let remoteSet = Set(remoteVerses)
            let union = localSet.union(remoteSet)
            merged[chapterKey] = Array(union).sorted()
        }
        return merged
    }

    private enum DateMergeStrategy { case earliest, latest }

    private func mergeDateMap(localData: Data?, remoteData: Data, type: [String: Date].Type, strategy: DateMergeStrategy) -> [String: Date] {
        let local = decode(localData, as: type) ?? [:]
        let remote = decode(remoteData, as: type) ?? [:]
        var merged = local
        for (k, rDate) in remote {
            if let lDate = merged[k] {
                switch strategy {
                case .earliest: merged[k] = min(lDate, rDate)
                case .latest: merged[k] = max(lDate, rDate)
                }
            } else {
                merged[k] = rDate
            }
        }
        return merged
    }

    private func mergeLastRead(localData: Data?, remoteData: Data, type: BibleStatsStore.LastRead.Type) -> BibleStatsStore.LastRead? {
        let local = decode(localData, as: type)
        let remote = decode(remoteData, as: type)
        switch (local, remote) {
        case (nil, nil): return nil
        case (let a?, nil): return a
        case (nil, let b?): return b
        case (let a?, let b?):
            return (a.date >= b.date) ? a : b
        }
    }

    private func mergeSessions(localData: Data?, remoteData: Data, type: [ReadingSessionsStore.Session].Type) -> [ReadingSessionsStore.Session] {
        let local = decode(localData, as: type) ?? []
        let remote = decode(remoteData, as: type) ?? []
        // Union with dedupe by stable identity: (start, end, book, chapter)
        var set: Set<String> = Set(local.map { sessionIdentity($0) })
        var merged = local
        for s in remote {
            let id = sessionIdentity(s)
            if !set.contains(id) {
                set.insert(id)
                merged.append(s)
            }
        }
        // Keep only last N days (respect the store’s retention policy of 180 days)
        let cutoff = Calendar.current.date(byAdding: .day, value: -180, to: Date()) ?? .distantPast
        merged = merged.filter { $0.end >= cutoff }
        // Sort ascending by end date to keep consistent order; StatsView does its own ordering later
        merged.sort { $0.end < $1.end }
        return merged
    }

    private func sessionIdentity(_ s: ReadingSessionsStore.Session) -> String {
        // Use ISO8601 + fields to avoid collisions
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let startStr = formatter.string(from: s.start)
        let endStr = formatter.string(from: s.end)
        let chapStr = s.chapter.map { String($0) } ?? "_"
        return "\(startStr)|\(endStr)|\(s.book)|\(chapStr)"
    }
}

// MARK: - Notifications

extension Notification.Name {
    // Posted when KVS merges BibleStats-related keys; UI can refresh.
    static let bibleStatsExternallyUpdated = Notification.Name("bibleStatsExternallyUpdated")

    // Posted when game counters merge via KVS; UI scoreboards can refresh.
    static let gameStatsExternallyUpdated = Notification.Name("gameStatsExternallyUpdated")

    // Posted when chapter read/verse progress changes anywhere in the app.
    static let chapterProgressChanged = Notification.Name("chapterProgressChanged")

    // Posted to request switching to a particular tab (used to close sheets, etc.).
    static let switchToTab = Notification.Name("switchToTab")

    // If you deep link to a passage elsewhere, you already have:
    // static let openBibleReference = Notification.Name("openBibleReference")
}

