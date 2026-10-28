import Foundation

/// Syncs the Review Round history (`MissedGameQuestionStore`) between devices.
///
/// Both directions do the same thing: fold the other device's published history into the local
/// one, then publish the union. Retired questions travel as tombstones, so a question answered
/// correctly on one device doesn't come back from another.
@MainActor
extension iCloudSyncCoordinator {
    static let missedQuestionKeys: [String] = [MissedGameQuestionStore.storageKey]

    // Local -> KVS
    func mirrorMissedQuestionsKeyToKVS(_ key: String) {
        guard Self.missedQuestionKeys.contains(key) else { return }
        reconcileMissedQuestions(forKey: key)
    }

    // KVS -> Local
    func mergeMissedQuestionsIncoming(forKey key: String) {
        guard Self.missedQuestionKeys.contains(key) else { return }
        if reconcileMissedQuestions(forKey: key) {
            NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
        }
    }

    /// Merges what is in iCloud, then publishes the result if iCloud differs.
    /// Returns whether the local history changed.
    @discardableResult
    private func reconcileMissedQuestions(forKey key: String) -> Bool {
        let store = MissedGameQuestionStore.shared
        let remoteData = kvs.object(forKey: key) as? Data
        var changed = false
        if let remote = decode(remoteData, as: MissedGameQuestionStore.CloudPayload.self) {
            changed = store.merge(remote)
        }

        // Nothing to publish for an empty history, such as right after a reset.
        if store.isEmpty && remoteData == nil { return changed }

        guard let localData = try? JSONEncoder().encode(store.cloudPayload()) else { return changed }
        if localData != remoteData {
            kvs.set(localData, forKey: key)
            enqueueKeyForSync(key)
        }
        return changed
    }
}
