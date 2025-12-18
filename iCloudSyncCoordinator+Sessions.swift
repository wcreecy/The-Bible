import Foundation

@MainActor
extension iCloudSyncCoordinator {
    // Reading sessions key(s)
    static let sessionKeys: [String] = ["readingSessions"]

    // Keep this in sync with ReadingSessionsStore’s retention window (currently ~5 years)
    private static let sessionRetentionDays: Int = 1825

    // Cached formatter for stable session identity
    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    // Local -> KVS
    func mirrorSessionsKeyToKVS(_ key: String) {
        guard Self.sessionKeys.contains(key) else { return }
        let localData = defaults.data(forKey: key)
        let remoteData = kvs.object(forKey: key) as? Data
        if localData != remoteData {
            if let data = localData {
                kvs.set(data, forKey: key)
            } else if remoteData != nil {
                kvs.removeObject(forKey: key)
            }
        }
    }

    // KVS -> Local
    func mergeSessionsIncoming(forKey key: String) {
        guard Self.sessionKeys.contains(key) else { return }
        guard let remoteData = kvs.object(forKey: key) as? Data else { return }
        let localData = defaults.data(forKey: key)
        typealias Arr = [ReadingSessionsStore.Session]
        var merged = mergeSessions(localData: localData, remoteData: remoteData, type: Arr.self)

        // Prune to retention window to avoid unbounded growth from remote merges
        var cal = Calendar.autoupdatingCurrent
        cal.timeZone = TimeZone.autoupdatingCurrent
        let cutoff = cal.date(byAdding: .day, value: -Self.sessionRetentionDays, to: Date()) ?? .distantPast
        merged = merged.filter { $0.end >= cutoff }

        if let data = try? JSONEncoder().encode(merged) {
            defaults.set(data, forKey: key)
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
}
