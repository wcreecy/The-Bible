import Foundation

@MainActor
extension iCloudSyncCoordinator {
    // Reading sessions key(s)
    static let sessionKeys: [String] = ["readingSessions"]
    static let maximumCloudSessions = 2_000
    static let maximumCloudSessionBytes = 256 * 1_024

    // Cached formatter for stable session identity
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // Local -> KVS
    func mirrorSessionsKeyToKVS(_ key: String) {
        guard Self.sessionKeys.contains(key) else { return }

        let localTimestamp = readLocalTimestamp(for: key)
        let remoteTimestamp = readRemoteTimestamp(for: key)
        guard remoteTimestamp <= localTimestamp || (remoteTimestamp == 0 && localTimestamp == 0) else {
            return
        }

        let localSessions = decode(
            defaults.data(forKey: key),
            as: [ReadingSessionsStore.Session].self
        ) ?? []
        let localData = Self.cloudSessionPayload(from: localSessions)
        let remoteData = kvs.object(forKey: key) as? Data
        if localData != remoteData {
            kvs.set(localData, forKey: key)
        }
        if localTimestamp > 0 {
            kvs.set(localTimestamp, forKey: tsKey(for: key))
        }
    }

    // KVS -> Local
    func mergeSessionsIncoming(forKey key: String) {
        guard Self.sessionKeys.contains(key) else { return }

        guard let remoteData = kvs.object(forKey: key) as? Data else { return }
        let localData = defaults.data(forKey: key)
        typealias Arr = [ReadingSessionsStore.Session]
        var merged = mergeSessions(localData: localData, remoteData: remoteData, type: Arr.self)

        merged = merged.filter(ReadingSessionsStore.isValid)

        if let localData = try? JSONEncoder().encode(merged) {
            // Keep complete history on-device. Only the bounded recent window is
            // mirrored through KVS; cumulative reading aggregates preserve totals.
            defaults.set(localData, forKey: key)

            // Sessions are append-only history. Republish the union so opening a
            // stale device cannot replace sessions recorded on another device.
            let cloudData = Self.cloudSessionPayload(from: merged)
            if cloudData != (kvs.object(forKey: key) as? Data) {
                let timestamp = Date().timeIntervalSince1970
                kvs.set(cloudData, forKey: key)
                kvs.set(timestamp, forKey: tsKey(for: key))
                defaults.set(timestamp, forKey: tsKey(for: key))
                enqueueKeyForSync(key)
            }
        }
    }

    // Merge helpers

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
        // Sort ascending by end date to keep consistent order; StatsView does its own ordering later
        merged.sort { $0.end < $1.end }
        return merged
    }

    private func sessionIdentity(_ s: ReadingSessionsStore.Session) -> String {
        // Use ISO8601 + fields to avoid collisions (cached formatter)
        let startStr = Self.isoFormatter.string(from: s.start)
        let endStr = Self.isoFormatter.string(from: s.end)
        let chapStr = s.chapter.map { String($0) } ?? "_"
        return "\(startStr)|\(endStr)|\(s.book)|\(chapStr)"
    }

    static func cloudSessionPayload(from sessions: [ReadingSessionsStore.Session]) -> Data {
        var bounded = Array(
            sessions
                .filter(ReadingSessionsStore.isValid)
                .sorted { $0.end > $1.end }
                .prefix(maximumCloudSessions)
        )
        let encoder = JSONEncoder()
        while !bounded.isEmpty {
            let data = (try? encoder.encode(bounded)) ?? Data()
            if data.count <= maximumCloudSessionBytes { return data }
            bounded.removeLast(max(1, bounded.count / 10))
        }
        return (try? encoder.encode([ReadingSessionsStore.Session]())) ?? Data()
    }
}
