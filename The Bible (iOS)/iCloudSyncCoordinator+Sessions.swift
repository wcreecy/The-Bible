import Foundation

@MainActor
extension iCloudSyncCoordinator {
    // Reading sessions key(s)
    static let sessionKeys: [String] = ["readingSessions"]

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
        let merged = mergeSessions(localData: localData, remoteData: remoteData, type: Arr.self)
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
        // Let ReadingSessionsStore own retention; do not prune here.
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
