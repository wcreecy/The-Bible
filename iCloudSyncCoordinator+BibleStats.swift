import Foundation

@MainActor
extension iCloudSyncCoordinator {
    // BibleStatsStore keys
    static var stats_keyTotals: String { BibleStatsStore.Defaults.keyTotals }
    static var stats_keyDailyTotals: String { BibleStatsStore.Defaults.keyDailyTotals }
    static var stats_keyDailyTotalsByBook: String { BibleStatsStore.Defaults.keyDailyTotalsByBook }
    static var stats_keyVisitedChapters: String { BibleStatsStore.Defaults.keyVisitedChapters }
    static var stats_keyLastRead: String { BibleStatsStore.Defaults.keyLastRead }
    static var stats_keySeenVersesByChapter: String { BibleStatsStore.Defaults.keySeenVersesByChapter }
    static var stats_keyChapterCompletionDates: String { BibleStatsStore.Defaults.keyChapterCompletionDates }
    static var stats_keyReadingContributions: String { BibleStatsStore.Defaults.keyReadingContributions }
    // Reading sessions (JSON array)
    static var stats_keyReadingSessions: String { "readingSessions" }

    static var bibleStatsKeys: [String] {
        [
            stats_keyTotals,
            stats_keyDailyTotals,
            stats_keyDailyTotalsByBook,
            stats_keyVisitedChapters,
            stats_keyLastRead,
            stats_keySeenVersesByChapter,
            stats_keyChapterCompletionDates,
            stats_keyReadingContributions
        ]
    }

    // Local -> KVS
    func mirrorBibleStatsKeyToKVS(_ key: String) {
        guard Self.bibleStatsKeys.contains(key) else { return }

        let localTimestamp = readLocalTimestamp(for: key)
        let remoteTimestamp = readRemoteTimestamp(for: key)
        guard remoteTimestamp <= localTimestamp || (remoteTimestamp == 0 && localTimestamp == 0) else {
            return
        }

        let localData = defaults.data(forKey: key)
        let remoteData = kvs.object(forKey: key) as? Data
        if localData != remoteData {
            if let data = localData {
                kvs.set(data, forKey: key)
            } else if remoteData != nil {
                kvs.removeObject(forKey: key)
            }
        }
        if localTimestamp > 0 {
            kvs.set(localTimestamp, forKey: tsKey(for: key))
        }
    }

    // KVS -> Local
    func mergeBibleStatsIncoming(forKey key: String) {
        guard Self.bibleStatsKeys.contains(key) else { return }

        let remoteTimestamp = readRemoteTimestamp(for: key)
        let localTimestamp = readLocalTimestamp(for: key)
        // Last-read is a single replaceable value. Cumulative reading history below
        // is always merged so a stale device cannot replace newer history wholesale.
        if key == Self.stats_keyLastRead && (remoteTimestamp > 0 || localTimestamp > 0) {
            if remoteTimestamp > localTimestamp {
                if let remoteValue = kvs.object(forKey: key) {
                    defaults.set(remoteValue, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
                defaults.set(remoteTimestamp, forKey: tsKey(for: key))
                BibleStatsStore.shared.resetCaches()
                NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
            } else if localTimestamp > remoteTimestamp {
                mirrorBibleStatsKeyToKVS(key)
                enqueueKeyForSync(key)
            }
            return
        }

        // Legacy values without timestamps retain the existing safe merge behavior.
        // Remote deletion: clear local copy and notify
        if kvs.object(forKey: key) == nil {
            defaults.removeObject(forKey: key)
            BibleStatsStore.shared.resetCaches()
            NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
            return
        }

        guard let remoteData = kvs.object(forKey: key) as? Data else { return }
        let localData = defaults.data(forKey: key)

        // Helper: treat empty payloads as a reset for this domain.
        func clearAndNotify() {
            defaults.removeObject(forKey: key)
            BibleStatsStore.shared.resetCaches()
            NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
        }

        switch key {
        case Self.stats_keyTotals:
            typealias Map = [String: Int]
            if let remote = decode(remoteData, as: Map.self), remote.isEmpty {
                clearAndNotify(); return
            }
            let merged = mergeIntMapMax(localData: localData, remoteData: remoteData, type: Map.self)
            if let data = try? JSONEncoder().encode(merged) { defaults.set(data, forKey: key) }

        case Self.stats_keyDailyTotals:
            typealias Map = [String: Int]
            if let remote = decode(remoteData, as: Map.self), remote.isEmpty {
                clearAndNotify(); return
            }
            let merged = mergeIntMapMax(localData: localData, remoteData: remoteData, type: Map.self)
            if let data = try? JSONEncoder().encode(merged) { defaults.set(data, forKey: key) }

        case Self.stats_keyDailyTotalsByBook:
            typealias Map = [String: [String: Int]]
            if let remote = decode(remoteData, as: Map.self), remote.isEmpty {
                clearAndNotify(); return
            }
            let merged = mergeNestedIntMapMax(localData: localData, remoteData: remoteData, type: Map.self)
            if let data = try? JSONEncoder().encode(merged) { defaults.set(data, forKey: key) }

        case Self.stats_keyReadingContributions:
            typealias Map = [String: [String: [String: Int]]]
            if let remote = decode(remoteData, as: Map.self), remote.isEmpty {
                clearAndNotify(); return
            }
            let merged = mergeContributionMap(localData: localData, remoteData: remoteData)
            if let data = try? JSONEncoder().encode(merged) { defaults.set(data, forKey: key) }

        case Self.stats_keyVisitedChapters:
            typealias Arr = [String]
            if let remote = decode(remoteData, as: Arr.self), remote.isEmpty {
                clearAndNotify(); return
            }
            let mergedSet = mergeStringSet(localData: localData, remoteData: remoteData, type: Arr.self)
            if let data = try? JSONEncoder().encode(Array(mergedSet)) { defaults.set(data, forKey: key) }

        case Self.stats_keySeenVersesByChapter:
            typealias Map = [String: [Int]]
            if let remote = decode(remoteData, as: Map.self), remote.isEmpty {
                clearAndNotify(); return
            }
            let merged = mergeSeenVerses(localData: localData, remoteData: remoteData, type: Map.self)
            if let data = try? JSONEncoder().encode(merged) { defaults.set(data, forKey: key) }

        case Self.stats_keyChapterCompletionDates:
            typealias Map = [String: Date]
            if let remote = decode(remoteData, as: Map.self), remote.isEmpty {
                clearAndNotify(); return
            }
            let merged = mergeDateMap(localData: localData, remoteData: remoteData, type: Map.self, strategy: .earliest)
            if let data = try? JSONEncoder().encode(merged) { defaults.set(data, forKey: key) }

        case Self.stats_keyLastRead:
            typealias Entry = BibleStatsStore.LastRead
            // If remote payload is present but decodes to nil (corrupt), treat as clear.
            if decode(remoteData, as: Entry.self) == nil {
                clearAndNotify(); return
            }
            let merged = mergeLastRead(localData: localData, remoteData: remoteData, type: Entry.self)
            if let data = try? JSONEncoder().encode(merged) { defaults.set(data, forKey: key) }

        case Self.stats_keyReadingSessions:
            // Sessions array: if empty -> clear; else accept wholesale (sessions are append-only analytics)
            if let arr = try? JSONDecoder().decode([ReadingSessionsStore.Session].self, from: remoteData), arr.isEmpty {
                clearAndNotify(); return
            }
            defaults.set(remoteData, forKey: key)

        default:
            break
        }

        // Publish a repaired union back to KVS. This is important when this device
        // had local entries the remote snapshot did not yet contain.
        if let mergedData = defaults.data(forKey: key),
           mergedData != (kvs.object(forKey: key) as? Data) {
            let timestamp = Date().timeIntervalSince1970
            kvs.set(mergedData, forKey: key)
            kvs.set(timestamp, forKey: tsKey(for: key))
            defaults.set(timestamp, forKey: tsKey(for: key))
            enqueueKeyForSync(key)
        }

        // Invalidate caches and notify after any merge
        BibleStatsStore.shared.resetCaches()
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
    }

    // MARK: - Merge helpers (stats)

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

    private func mergeContributionMap(localData: Data?, remoteData: Data) -> [String: [String: [String: Int]]] {
        typealias Map = [String: [String: [String: Int]]]
        let local = decode(localData, as: Map.self) ?? [:]
        let remote = decode(remoteData, as: Map.self) ?? [:]
        var merged = local
        for (day, books) in remote {
            for (book, devices) in books {
                for (device, seconds) in devices {
                    merged[day, default: [:]][book, default: [:]][device] = max(
                        merged[day]?[book]?[device] ?? 0,
                        max(0, seconds)
                    )
                }
            }
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
}
