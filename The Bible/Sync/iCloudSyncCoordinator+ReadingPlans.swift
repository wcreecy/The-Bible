import Foundation

/// Reading plan sync. One key holds every plan's progress and every custom plan:
///
/// - `readingPlansV1`: JSON `ReadingPlansDocument`. Copies merge record by record (see
///   `ReadingPlansDocument.merged`), so progress made on two devices is kept, and the most
///   recent restart, stop, or deletion wins.
///
/// Plans are separate from reading stats, so a stats reset leaves them alone.
@MainActor
extension iCloudSyncCoordinator {
    static var readingPlanKeys: [String] { [ReadingPlanStore.storageKey] }

    // Local -> KVS
    func mirrorReadingPlansKeyToKVS(_ key: String) {
        let store = ReadingPlanStore.shared
        // Publish the union, so plans only another device has are kept.
        let remote = ReadingPlanStore.decode(kvs.data(forKey: key))
        let merged = remote.map { ReadingPlansDocument.merged(store.document, $0) } ?? store.document
        guard merged != remote, let data = try? JSONEncoder().encode(merged) else { return }
        kvs.set(data, forKey: key)
    }

    // KVS -> Local
    func mergeReadingPlansIncoming(forKey key: String) {
        guard let remote = ReadingPlanStore.decode(kvs.data(forKey: key)) else { return }
        let merged = ReadingPlanStore.shared.merge(remote: remote)
        // This device had changes the cloud copy lacked; republish the union.
        if merged != remote, let data = try? JSONEncoder().encode(merged) {
            kvs.set(data, forKey: key)
            enqueueKeyForSync(key)
        }
    }
}
