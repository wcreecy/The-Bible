import Foundation

#if canImport(UIKit)
import UIKit
#endif

// iCloud Key-Value sync coordinator for small aggregates and reading stats.
// Mirrors selected UserDefaults keys to NSUbiquitousKeyValueStore and merges incoming changes.
// Add iCloud capability with "Key-Value storage" enabled for this target.
//
// Domain mirrors/merges live in the `+<Domain>.swift` extensions. Dispatch and debounced
// pushes are in `+Push.swift`, full reconcile passes in `+Reconcile.swift`, the synced key
// registry in `+KeyRegistry.swift`, and lifecycle decisions in `KVSSyncLifecyclePolicy`.
@MainActor
final class iCloudSyncCoordinator {
    static let shared = iCloudSyncCoordinator()

    enum SyncState: String {
        case notStarted
        case downloading
        case ready
        case unavailable
        case quotaExceeded
    }

    let kvs = NSUbiquitousKeyValueStore.default
    let defaults = UserDefaults.standard

    private(set) var syncState: SyncState = .notStarted
    private(set) var lastErrorMessage: String?
    private(set) var lastSynchronizeSucceeded: Bool?
    private(set) var approximateCloudBytes: Int = 0
    private(set) var cloudKeyCount: Int = 0
    private(set) var lastReconciliationResult: String?
    private(set) var lastReconciliationDate: Date?
    private var initialSyncTask: Task<Void, Never>?
    private var metricsTask: Task<Void, Never>?
    private var hasCompletedInitialDownload = false
    /// When this launch (or the latest account change) began waiting for the cloud download.
    private var downloadWaitStart: Date?

    // One-time bootstrap flag so we push existing local values to KVS on first run after adding sync.
    let bootstrapFlagKey = "kvsBootstrapComplete_v1"

    // Track last push/merge timestamps (persisted so Settings can show across launches)
    private let lastPushKey = "kvsLastPushDate"
    private let lastMergeKey = "kvsLastMergeDate"
    // Setters are internal so the reset and reconcile extensions can stamp them.
    var lastPushDate: Date? {
        get { defaults.object(forKey: lastPushKey) as? Date }
        set { defaults.set(newValue, forKey: lastPushKey) }
    }
    var lastMergeDate: Date? {
        get { defaults.object(forKey: lastMergeKey) as? Date }
        set { defaults.set(newValue, forKey: lastMergeKey) }
    }

    // Debounced push machinery (MainActor-safe)
    var pendingKeys: Set<String> = []
    var debounceTask: Task<Void, Never>?
    let debounceInterval: TimeInterval = 1.0

    // Ensure start() is performed once per app run
    private var didStart = false

    // MARK: - Reset epoch for Bible stats/sessions

    let bibleStatsResetEpochKVSKey = "bibleStatsResetEpoch"          // in KVS
    let bibleStatsLastSeenEpochLocalKey = "bibleStatsLastSeenResetEpoch" // in local defaults

    // MARK: - Reset epoch for Game stats

    let gameStatsResetEpochKVSKey = "gameStatsResetEpoch"            // in KVS
    let gameStatsLastSeenEpochLocalKey = "gameStatsLastSeenResetEpoch" // in local defaults

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleKVSExternalChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvs
        )

        // Account changes (user logs in/out or switches accounts)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUbiquityIdentityChange),
            name: NSNotification.Name.NSUbiquityIdentityDidChange,
            object: nil
        )

        #if canImport(UIKit)
        // Opportunistic flush on background
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        #endif

    }

    // MARK: - Public API

    /// Whether the initial iCloud download has finished and local values may be published.
    var isInitialDownloadComplete: Bool { hasCompletedInitialDownload }

    func recordReconciliation(result: String, at date: Date = Date()) {
        lastReconciliationResult = result
        lastReconciliationDate = date
    }

    /// Starts sync once per launch (ContentView calls it). Later calls just refresh.
    func start() {
        if didStart {
            refreshNow()
            return
        }
        didStart = true
        syncState = .downloading
        recordSynchronizeResult(kvs.synchronize())

        // Apple recommends delaying writes while the initial KVS download is in
        // progress. A notification normally completes this early; the fallback
        // handles accounts whose cloud store is empty and produce no changed keys.
        scheduleInitialDownloadFallback(isAccountChange: false)
    }

    private func scheduleInitialDownloadFallback(isAccountChange: Bool) {
        let delay = KVSSyncLifecyclePolicy.initialDownloadFallbackDelay(
            bootstrapComplete: defaults.bool(forKey: bootstrapFlagKey),
            isAccountChange: isAccountChange
        )
        downloadWaitStart = Date()
        initialSyncTask?.cancel()
        initialSyncTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.completeInitialDownload()
        }
    }

    func refreshNow() {
        guard didStart else {
            start()
            return
        }
        let succeeded = kvs.synchronize()
        recordSynchronizeResult(succeeded)
        guard succeeded else { return }
        if hasCompletedInitialDownload {
            reconcileAllKeysFromKVS()
            BibleStatsStore.shared.compactReadingHistoryIfNeeded()
            updateStoreMetrics()
        }
    }

    private func completeInitialDownload() {
        guard !hasCompletedInitialDownload else { return }
        initialSyncTask?.cancel()
        initialSyncTask = nil
        hasCompletedInitialDownload = true
        downloadWaitStart = nil
        syncState = .ready

        // Cloud values are merged before any local value can be published.
        reconcileAllKeysFromKVS()

        switch KVSSyncLifecyclePolicy.initialDownloadAction(
            bootstrapComplete: defaults.bool(forKey: bootstrapFlagKey),
            pendingKeys: pendingKeys
        ) {
        case .bootstrapLocalDifferences:
            pushLocalDifferencesToKVS()
            defaults.set(true, forKey: bootstrapFlagKey)
        case .flushPendingWrites:
            let queuedKeys = pendingKeys
            pendingKeys.removeAll()
            for key in queuedKeys { mirrorLocalKeyToKVS(key) }
            enqueueKeysForSync(queuedKeys)
        case .mergeOnly:
            break
        }

        let repaired = normalizeGameCountersInvariant()
        let migrated = migrateRefMatchToVerseMatchIfNeeded()
        enqueueKeysForSync(repaired.union(migrated))

        // Join (or migrate into) the per-device game ledger now that cloud values are known.
        GameStatsLedger.shared.reconcile()
        if MissedGameQuestionStore.shared.takePendingMigrationPublish() {
            pushKey(MissedGameQuestionStore.storageKey)
        }
        // Fold reading history older than ~2 years into its archive, after merging, so
        // the archive is built from every device's days.
        BibleStatsStore.shared.compactReadingHistoryIfNeeded()
        updateStoreMetrics()
        AppDataChanges.shared.syncStatusChanged()
    }

    // Call after local writes if you want to eagerly push a specific key.
    func pushKey(_ key: String) {
        guard allKnownKeys.contains(key) else { return }

        // Game counters and maps sync through the per-device ledger.
        if GameStatsLedger.isManaged(key) {
            GameStatsLedger.shared.scheduleFlush()
            return
        }

        // Every local stats mutation gets a timestamp. This lets another device
        // choose the complete value from the most recent writer.
        if isTimestampedStatsKey(key) {
            writeLocalTimestampNow(for: key)
        }

        guard hasCompletedInitialDownload else {
            pendingKeys.insert(key)
            return
        }
        mirrorLocalKeyToKVS(key)
        enqueueKeyForSync(key)
    }

    // Optional: push all known keys now (useful on app background)
    // Completion is invoked on the main actor after the immediate synchronize finishes.
    func pushAllNow(completion: (() -> Void)? = nil) {
        guard hasCompletedInitialDownload else {
            pendingKeys.formUnion(allKnownKeys)
            completion?()
            return
        }
        GameStatsLedger.shared.reconcile()
        for key in allKnownKeys {
            mirrorLocalKeyToKVS(key)
        }
        // Perform a single immediate synchronize off-main and stamp lastPushDate.
        let _ = Task.detached {
            let succeeded = NSUbiquitousKeyValueStore.default.synchronize()
            await MainActor.run {
                iCloudSyncCoordinator.shared.recordSynchronizeResult(succeeded, isPush: true)
                completion?()
            }
        }
        // Intentionally do NOT enqueue a debounced sync here to avoid a near-duplicate sync shortly after.
    }

    // MARK: - KVS change handling

    @objc
    func handleKVSExternalChange(_ note: Notification) {
        // This notification can arrive on a background thread; ensure we run on main.
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.handleKVSExternalChange(note)
            }
            return
        }

        guard let userInfo = note.userInfo else { return }

        // Track failures explicitly; CloudKit account availability does not prove KVS health.
        let reasonRaw = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
        if let reason = reasonRaw {
            switch reason {
            case NSUbiquitousKeyValueStoreServerChange:
                break
            case NSUbiquitousKeyValueStoreInitialSyncChange:
                // This reason means the initial download is still in progress.
                // Merge what arrived, then wait for a quiet period before writes.
                reconcileAllKeysFromKVS()
                initialSyncTask?.cancel()
                initialSyncTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(2))
                    guard !Task.isCancelled else { return }
                    self?.completeInitialDownload()
                }
            case NSUbiquitousKeyValueStoreQuotaViolationChange:
                syncState = .quotaExceeded
                lastErrorMessage = "iCloud key-value storage exceeded its quota."
                AppDataChanges.shared.syncStatusChanged()
                return
            case NSUbiquitousKeyValueStoreAccountChange:
                restartForAccountChange()
                return
            default:
                break // unknown reason; proceed conservatively
            }
        }

        let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []

        // Another device published its game ledger; rebuild game totals.
        if changedKeys.contains(where: { $0.hasPrefix(GameStatsLedger.kvsKeyPrefix) }) {
            GameStatsLedger.shared.reconcile()
        }

        // If a reset-epoch changed, run a full reconcile so we clear local immediately.
        if changedKeys.contains(gameStatsResetEpochKVSKey) {
            reconcileAllKeysFromKVS()
            return
        }
        if changedKeys.contains(bibleStatsResetEpochKVSKey) {
            reconcileAllKeysFromKVS()
            return
        }

        // A timestamp and its value may arrive in separate notifications. Resolve
        // timestamp companion keys back to their data keys so neither update is lost.
        let keysToProcess = Set(changedKeys.compactMap { changedKey -> String? in
            if allKnownKeys.contains(changedKey) {
                return changedKey
            }
            let prefix = "__ts__"
            guard changedKey.hasPrefix(prefix) else { return nil }
            let dataKey = String(changedKey.dropFirst(prefix.count))
            return allKnownKeys.contains(dataKey) ? dataKey : nil
        })

        guard !keysToProcess.isEmpty else { return }

        var mergedGameKey = false

        for key in keysToProcess {
            if isGamesDomainKey(key) {
                mergedGameKey = true
            }
            // Merge only for domains we own in coordinator
            if allKnownKeys.contains(key) {
                mergeIncomingKVSValue(forKey: key)
            }
        }

        // Invalidate caches so subsequent reads reflect merged values
        BibleStatsStore.shared.resetCaches()

        // After merging any game keys, normalize impossible pairs once (answered >= correct)
        if mergedGameKey {
            let repairedKeys = normalizeGameCountersInvariant()
            if !repairedKeys.isEmpty {
                enqueueKeysForSync(repairedKeys)
            }
        }

        // Notify UI that stats may have changed (StatsView can refresh)
        DispatchQueue.main.async {
            AppDataChanges.shared.bibleStatsChanged()
        }

        // If any game keys merged or we repaired, notify interested views (scoreboard) as well
        if mergedGameKey {
            DispatchQueue.main.async {
                AppDataChanges.shared.gameStatsChanged()
            }
        }

        // Record last merge time
        lastMergeDate = Date()
        updateStoreMetrics()
    }

    @objc
    func handleUbiquityIdentityChange() {
        // This notification can arrive on a background thread; ensure we run on main.
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.handleUbiquityIdentityChange()
            }
            return
        }

        // Account changed: pull, merge, and repair. Do not blindly push local values first.
        restartForAccountChange()
    }

    #if canImport(UIKit)
    @objc
    func handleAppDidEnterBackground() {
        // A long first-sync wait must not strand a short session: once the download has had
        // the minimum time, settle so this launch's changes are published before suspension.
        if !hasCompletedInitialDownload,
           let waitStart = downloadWaitStart,
           KVSSyncLifecyclePolicy.shouldSettleOnBackground(waited: Date().timeIntervalSince(waitStart)) {
            completeInitialDownload()
        }

        // Begin a background task so the immediate synchronize has time to complete.
        let app = UIApplication.shared
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = app.beginBackgroundTask(withName: "KVSFlushOnBackground") {
            if bgTask != .invalid {
                app.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }

        // Mirror any differences and perform a single immediate synchronize.
        pushAllNow { [weak app] in
            if let app, bgTask != .invalid {
                app.endBackgroundTask(bgTask)
            }
        }
    }
    #endif

    // MARK: - Shared decode helper for extensions

    func decode<T: Decodable>(_ data: Data?, as type: T.Type) -> T? {
        guard let d = data else { return nil }
        return PersistedDecoding.decode(T.self, from: d, name: "iCloud \(String(describing: T.self))")
    }

    private func restartForAccountChange() {
        initialSyncTask?.cancel()
        let plan = KVSSyncLifecyclePolicy.accountChangePlan()
        hasCompletedInitialDownload = plan.initialDownloadComplete
        syncState = .downloading
        lastErrorMessage = nil
        // Do not re-bootstrap an established installation into a different
        // account. A genuinely fresh install already has a false bootstrap flag.
        pendingKeys = plan.pendingKeys
        recordSynchronizeResult(kvs.synchronize())
        scheduleInitialDownloadFallback(isAccountChange: true)
    }

    func recordSynchronizeResult(_ succeeded: Bool, isPush: Bool = false) {
        lastSynchronizeSucceeded = succeeded
        if succeeded {
            if syncState == .unavailable { syncState = .downloading }
            lastErrorMessage = nil
            if isPush { lastPushDate = Date() }
        } else {
            syncState = .unavailable
            lastErrorMessage = "iCloud key-value storage is unavailable for this build or account."
        }
        updateStoreMetrics()
        AppDataChanges.shared.syncStatusChanged()
    }

    /// Measures the iCloud store for the Settings usage line. Serializing every value is
    /// slow, so it runs off the main thread, once per burst of sync activity.
    private func updateStoreMetrics() {
        metricsTask?.cancel()
        metricsTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            let metrics = await Task.detached(priority: .utility) {
                Self.measureStore()
            }.value
            guard !Task.isCancelled, let self else { return }
            self.cloudKeyCount = metrics.keyCount
            self.approximateCloudBytes = metrics.bytes
            AppDataChanges.shared.syncStatusChanged()
        }
    }

    private nonisolated static func measureStore() -> (keyCount: Int, bytes: Int) {
        let representation = NSUbiquitousKeyValueStore.default.dictionaryRepresentation
        let bytes = representation.values.reduce(0) { partial, value in
            partial + ((try? PropertyListSerialization.data(
                fromPropertyList: value,
                format: .binary,
                options: 0
            ).count) ?? 0)
        }
        return (representation.count, bytes)
    }
}

extension Notification.Name {
    static let iCloudSyncStatusChanged = Notification.Name("iCloudSyncStatusChanged")
}
