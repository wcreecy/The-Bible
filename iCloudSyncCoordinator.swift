import Foundation

#if canImport(UIKit)
import UIKit
#endif

// iCloud Key-Value sync coordinator for small aggregates and reading stats.
// Mirrors selected UserDefaults keys to NSUbiquitousKeyValueStore and merges incoming changes.
// Add iCloud capability with "Key-Value storage" enabled for this target.
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
    private var initialSyncTask: Task<Void, Never>?
    private var metricsTask: Task<Void, Never>?
    private var hasCompletedInitialDownload = false

    // One-time bootstrap flag so we push existing local values to KVS on first run after adding sync.
    let bootstrapFlagKey = "kvsBootstrapComplete_v1"

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

    // Debounced push machinery (MainActor-safe)
    var pendingKeys: Set<String> = []
    var debounceTask: Task<Void, Never>?
    let debounceInterval: TimeInterval = 1.0

    // Ensure start() is performed once per app run
    private var didStart = false

    // MARK: - Reset epoch for Bible stats/sessions

    private let bibleStatsResetEpochKVSKey = "bibleStatsResetEpoch"          // in KVS
    private let bibleStatsLastSeenEpochLocalKey = "bibleStatsLastSeenResetEpoch" // in local defaults

    // MARK: - Reset epoch for Game stats (NEW)

    private let gameStatsResetEpochKVSKey = "gameStatsResetEpoch"            // in KVS
    private let gameStatsLastSeenEpochLocalKey = "gameStatsLastSeenResetEpoch" // in local defaults

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
        initialSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
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
            updateStoreMetrics()
        }
    }

    private func completeInitialDownload() {
        guard !hasCompletedInitialDownload else { return }
        initialSyncTask?.cancel()
        initialSyncTask = nil
        hasCompletedInitialDownload = true
        syncState = .ready

        // Cloud values are merged before any local value can be published.
        reconcileAllKeysFromKVS()

        if !defaults.bool(forKey: bootstrapFlagKey) {
            pushLocalDifferencesToKVS()
            defaults.set(true, forKey: bootstrapFlagKey)
        } else if !pendingKeys.isEmpty {
            let queuedKeys = pendingKeys
            pendingKeys.removeAll()
            for key in queuedKeys { mirrorLocalKeyToKVS(key) }
            enqueueKeysForSync(queuedKeys)
        }

        let repaired = normalizeGameCountersInvariant()
        let migrated = migrateRefMatchToVerseMatchIfNeeded()
        enqueueKeysForSync(repaired.union(migrated))

        // Join (or migrate into) the per-device game ledger now that cloud values are known.
        GameStatsLedger.shared.reconcile()
        updateStoreMetrics()
        NotificationCenter.default.post(name: .iCloudSyncStatusChanged, object: nil)
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

    // MARK: - Reset helpers (public) — called by Settings

    func resetAllBibleStatsAndSessions() {
        // 1) Clear local stores (sessions via API so caches/listeners update)
        ReadingSessionsStore.shared.clearAll()
        BibleStatsStore.shared.clearAllLocal()

        // 2) Remove KVS copies for Bible stats + sessions keys
        let kvsKeysToRemove: [String] = [
            BibleStatsStore.Defaults.keyTotals,
            BibleStatsStore.Defaults.keyDailyTotals,
            BibleStatsStore.Defaults.keyDailyTotalsByBook,
            BibleStatsStore.Defaults.keyReadingContributions,
            BibleStatsStore.Defaults.keyVisitedChapters,
            BibleStatsStore.Defaults.keyLastRead,
            BibleStatsStore.Defaults.keySeenVersesByChapter,
            BibleStatsStore.Defaults.keyChapterCompletionDates,
            BibleStatsStore.Defaults.keyChapterResetDates,
            BibleStatsStore.Defaults.keySeenVersesUpdatedAt,
            "readingSessions"
        ]
        for k in kvsKeysToRemove {
            kvs.removeObject(forKey: k)
        }

        // Last Read is also mirrored outside the stats store for the widget.
        for key in Self.lastReadWidgetKeys {
            kvs.removeObject(forKey: key)
        }
        if let shared = UserDefaults(suiteName: "group.bible.app") {
            for key in Self.lastReadWidgetKeys {
                shared.removeObject(forKey: key)
            }
        }

        // 3) Set/reset epoch in both KVS and local so older devices won’t re-populate
        let now = Date().timeIntervalSince1970
        kvs.set(now, forKey: bibleStatsResetEpochKVSKey)
        defaults.set(now, forKey: bibleStatsLastSeenEpochLocalKey)

        // 4) Refresh the UI immediately, then flush the deletion to iCloud off-main.
        BibleStatsStore.shared.resetCaches()
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
        DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
        let _ = Task.detached {
            NSUbiquitousKeyValueStore.default.synchronize()
            await MainActor.run {
                iCloudSyncCoordinator.shared.lastPushDate = Date()
            }
        }
    }

    // MARK: - Key sets (union)

    /// Every key this coordinator syncs. The lists are fixed, so the set is built once.
    var allKnownKeys: Set<String> { Self.allKnownKeySet }

    private static let allKnownKeySet: Set<String> = {
        Set(
            bibleStatsKeys
            + sessionKeys
            + settingsKeys
            + gamePlayTimeCounterKeys
            + gamePlayTimeMapKeys
            + hangmanKeys
            + beatClockKeys
            + refMatchKeys
            + verseMatchKeys
            + quizKeys
            + quizPerBookMapKeys
            + quizPerBookDailyMapKeys
            + verseMatchPerBookDailyMapKeys
            + verseMatchPerBookMapKeys
            + hangmanPerCategoryMapKeys
            + beatClockPerTypeMapKeys
            + bookOrderKeys
            + whoAmIKeys
            + wordleKeys
            + wordSearchKeys
            + gameDailyAndLastPlayedKeys
            + wordleSolvedMapKeys
            + wordleDailyResultKeys
            + wordleDailyFlagKeys
            + perGameDailyMapKeys
            + allPersistentStreakKeys
        )
    }()

    // MARK: - Bootstrap helpers

    // Push only differences between local defaults and KVS (no blind timestamp bumps)
    func pushLocalDifferencesToKVS() {
        for key in allKnownKeys {
            mirrorLocalKeyToKVS(key)
        }
        enqueueKeysForSync(allKnownKeys)
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
                NotificationCenter.default.post(name: .iCloudSyncStatusChanged, object: nil)
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
            NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
        }

        // If any game keys merged or we repaired, notify interested views (scoreboard) as well
        if mergedGameKey {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
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

    // MARK: - Local -> KVS dispatch

    func mirrorLocalKeyToKVS(_ key: String) {
        if Self.settingsKeys.contains(key) {
            mirrorSettingsKeyToKVS(key)
            return
        }
        if isGamesDomainKey(key) {
            mirrorGamesKeyToKVS(key)
            return
        }
        if Self.bibleStatsKeys.contains(key) {
            mirrorBibleStatsKeyToKVS(key)
            return
        }
        if Self.sessionKeys.contains(key) {
            mirrorSessionsKeyToKVS(key)
            return
        }
        // Unknown keys are ignored
    }

    // MARK: - Debounced synchronize (MainActor-safe)

    func enqueueKeyForSync(_ key: String) {
        enqueueKeysForSync([key])
    }

    func enqueueKeysForSync<S: Sequence>(_ keys: S) where S.Element == String {
        for k in keys where allKnownKeys.contains(k) {
            pendingKeys.insert(k)
        }
        scheduleDebouncedSynchronize()
    }

    /// Schedules a synchronize for values written directly to the store, such as ledgers.
    func requestSynchronize() {
        pendingKeys.insert(Self.synchronizeRequestKey)
        scheduleDebouncedSynchronize()
    }

    private static let synchronizeRequestKey = "__synchronizeRequest__"

    func scheduleDebouncedSynchronize() {
        // Nothing to do
        guard !pendingKeys.isEmpty else { return }

        // Cancel any pending task
        debounceTask?.cancel()

        // Clear pending set now (on MainActor)
        _ = pendingKeys
        pendingKeys.removeAll()

        let delayNanos = UInt64(debounceInterval * 1_000_000_000)

        debounceTask = Task { [weak self] in
            // Debounce
            try? await Task.sleep(nanoseconds: delayNanos)
            guard self != nil else { return }

            // Perform synchronize off-main to avoid any chance of blocking UI.
            await withTaskCancellationHandler {
                let _ = Task.detached {
                    let succeeded = NSUbiquitousKeyValueStore.default.synchronize()
                    await MainActor.run {
                        iCloudSyncCoordinator.shared.recordSynchronizeResult(succeeded, isPush: true)
                    }
                }
            } onCancel: {
                // no-op
            }
        }
    }

    // MARK: - KVS -> Local dispatch

    func mergeIncomingKVSValue(forKey key: String) {
        if Self.settingsKeys.contains(key) {
            mergeSettingsIncoming(forKey: key)
            return
        }
        if isGamesDomainKey(key) {
            mergeGamesIncoming(forKey: key)
            return
        }
        if Self.bibleStatsKeys.contains(key) {
            mergeBibleStatsIncoming(forKey: key)
            return
        }
        if Self.sessionKeys.contains(key) {
            mergeSessionsIncoming(forKey: key)
            return
        }
    }

    // MARK: - One-shot reconcile pass at startup/identity change

    func reconcileAllKeysFromKVS() {
        // Merge only values that actually exist remotely. Missing keys are ambiguous
        // during downloads and outages; explicit reset epochs are the sole deletion signal.
        let remoteDict = kvs.dictionaryRepresentation

        var mergedGameKey = false
        var touchedAny = false
        var appliedBibleReset = false
        var appliedGameReset = false

        // Check for a remote Bible stats reset epoch first; if newer than local, clear local data.
        let incomingEpoch = kvs.double(forKey: bibleStatsResetEpochKVSKey)
        if incomingEpoch > 0 {
            let lastSeen = defaults.double(forKey: bibleStatsLastSeenEpochLocalKey)
            if incomingEpoch > lastSeen {
                // Clear sessions via API (updates caches/listeners and KVS)
                ReadingSessionsStore.shared.clearAll()
                // Clear Bible stats locally and caches
                BibleStatsStore.shared.clearAllLocal()
                for key in Self.bibleStatsKeys + Self.sessionKeys {
                    kvs.removeObject(forKey: key)
                }
                for key in Self.lastReadWidgetKeys {
                    kvs.removeObject(forKey: key)
                }
                if let shared = UserDefaults(suiteName: "group.bible.app") {
                    for key in Self.lastReadWidgetKeys {
                        shared.removeObject(forKey: key)
                    }
                }
                appliedBibleReset = true
                touchedAny = true
                // Record last-seen epoch locally to prevent re-clearing
                defaults.set(incomingEpoch, forKey: bibleStatsLastSeenEpochLocalKey)
            }
        }

        // NEW: Check for a remote Game stats reset epoch; if newer than local, clear local game data only.
        let incomingGameEpoch = kvs.double(forKey: gameStatsResetEpochKVSKey)
        if incomingGameEpoch > 0 {
            let lastSeenGame = defaults.double(forKey: gameStatsLastSeenEpochLocalKey)
            if incomingGameEpoch > lastSeenGame {
                // Purge local game data without writing back to KVS (remote reset is authoritative)
                clearAllGameDataLocalOnly()
                for key in allKnownGameDataKeys {
                    kvs.removeObject(forKey: key)
                    kvs.removeObject(forKey: tsKey(for: key))
                }
                appliedGameReset = true
                touchedAny = true
                mergedGameKey = true
                // Stamp last-seen epoch locally to prevent re-clearing
                defaults.set(incomingGameEpoch, forKey: gameStatsLastSeenEpochLocalKey)
                GameStatsLedger.shared.resetForNewEpoch()
            }
        }

        for key in allKnownKeys {
            // A reset epoch is authoritative. Don't merge stale values that arrived in
            // the same KVS snapshot after the local stores were just cleared.
            if appliedBibleReset && (Self.bibleStatsKeys.contains(key) || Self.sessionKeys.contains(key)) {
                continue
            }
            if appliedGameReset && allKnownGameDataKeys.contains(key) {
                continue
            }
            let hasRemote = (kvs.object(forKey: key) != nil) || (remoteDict.keys.contains(key))

            if hasRemote {
                if isGamesDomainKey(key) {
                    mergedGameKey = true
                }
                mergeIncomingKVSValue(forKey: key)
                touchedAny = true
                continue
            }
        }

        if touchedAny {
            BibleStatsStore.shared.resetCaches()

            if mergedGameKey {
                let repaired = normalizeGameCountersInvariant()
                if !repaired.isEmpty {
                    enqueueKeysForSync(repaired)
                }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
                }
            }

            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
            }
            lastMergeDate = Date()
        }

        if hasCompletedInitialDownload {
            GameStatsLedger.shared.reconcile()
        }
    }

    // MARK: - Shared decode helper for extensions

    func decode<T: Decodable>(_ data: Data?, as type: T.Type) -> T? {
        guard let d = data else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }

    private func restartForAccountChange() {
        initialSyncTask?.cancel()
        hasCompletedInitialDownload = false
        syncState = .downloading
        lastErrorMessage = nil
        // Do not re-bootstrap an established installation into a different
        // account. A genuinely fresh install already has a false bootstrap flag.
        pendingKeys.removeAll()
        recordSynchronizeResult(kvs.synchronize())
        initialSyncTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.completeInitialDownload()
        }
    }

    private func recordSynchronizeResult(_ succeeded: Bool, isPush: Bool = false) {
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
        NotificationCenter.default.post(name: .iCloudSyncStatusChanged, object: nil)
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
            NotificationCenter.default.post(name: .iCloudSyncStatusChanged, object: nil)
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

// MARK: - Last Read widget keys
// The widget copy is written by ReadingPositionStore; resets also clear values older
// versions wrote directly to iCloud.
private extension iCloudSyncCoordinator {
    static let lastReadWidgetKeys: Set<String> = [
        "lastReadBook",
        "lastReadChapter",
        "lastReadVerse",
        "lastReadText"
    ]
}
