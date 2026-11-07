import Foundation

/// Pure decisions for the iCloud KVS sync lifecycle, kept separate from
/// `iCloudSyncCoordinator` so they can be unit-tested without a live store.
enum KVSSyncLifecyclePolicy {
    enum InitialDownloadAction: Equatable {
        case bootstrapLocalDifferences
        case flushPendingWrites
        case mergeOnly
    }

    struct AccountChangePlan: Equatable {
        let initialDownloadComplete: Bool
        let pendingKeys: Set<String>
        let permitsBootstrap: Bool
    }

    static func initialDownloadAction(
        bootstrapComplete: Bool,
        pendingKeys: Set<String>
    ) -> InitialDownloadAction {
        if !bootstrapComplete { return .bootstrapLocalDifferences }
        return pendingKeys.isEmpty ? .mergeOnly : .flushPendingWrites
    }

    static func accountChangePlan() -> AccountChangePlan {
        // An established install must download and merge the new account before writing.
        AccountChangePlan(
            initialDownloadComplete: false,
            pendingKeys: [],
            permitsBootstrap: false
        )
    }

    /// KVS has no "download finished" signal, so the coordinator waits for a quiet period.
    /// A first sync or an account switch bootstraps local values into the cloud, so it waits
    /// longer for slow downloads. An established install only defers writes, and data that
    /// arrives late is still merged when it lands.
    static func initialDownloadFallbackDelay(
        bootstrapComplete: Bool,
        isAccountChange: Bool
    ) -> Duration {
        (!bootstrapComplete || isAccountChange) ? .seconds(12) : .seconds(3)
    }

    /// When the app goes to the background before the fallback fires, sync settles once it
    /// has waited at least this long, so short sessions on a first sync still publish.
    static let minimumWaitBeforeBackgroundSettle: TimeInterval = 3

    static func shouldSettleOnBackground(waited: TimeInterval) -> Bool {
        waited >= minimumWaitBeforeBackgroundSettle
    }

    static func shouldApplyReset(remoteEpoch: Double, lastSeenEpoch: Double) -> Bool {
        remoteEpoch > 0 && remoteEpoch > lastSeenEpoch
    }
}
