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

    let kvs = NSUbiquitousKeyValueStore.default
    let defaults = UserDefaults.standard

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

    // Simple availability hint for KVS (user signed into iCloud)
    var kvsAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // Debounced push machinery (MainActor-safe)
    var pendingKeys: Set<String> = []
    var debounceTask: Task<Void, Never>?
    let debounceInterval: TimeInterval = 1.0

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

        // Initial pull
        kvs.synchronize()
    }

    // MARK: - Public API

    func start() {
        // Pull -> merge -> normalize -> push repairs (debounced)
        reconcileAllKeysFromKVS()

        // One-time bootstrap: push local differences (no timestamp churn) after initial pull/merge
        if !defaults.bool(forKey: bootstrapFlagKey) {
            pushLocalDifferencesToKVS()
            defaults.set(true, forKey: bootstrapFlagKey)
        }

        // Normalize impossible pairs once at startup too (heals existing data even if no merge occurs this run)
        let repaired = normalizeGameCountersInvariant()
        if !repaired.isEmpty {
            enqueueKeysForSync(repaired)
            NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
        }
    }

    // Call after local writes if you want to eagerly push a specific key.
    func pushKey(_ key: String) {
        guard allKnownKeys.contains(key) else { return }
        // Mirror only if changed, then schedule synchronize (debounced).
        mirrorLocalKeyToKVS(key)
        enqueueKeyForSync(key)
    }

    // Optional: push all known keys now (useful on app background)
    func pushAllNow() {
        for key in allKnownKeys {
            mirrorLocalKeyToKVS(key)
        }
        enqueueKeysForSync(allKnownKeys)
    }

    // MARK: - Key sets (union)

    var allKnownKeys: Set<String> {
        Set(Self.bibleStatsKeys + Self.sessionKeys + Self.settingsKeys + Self.hangmanKeys + Self.beatClockKeys + Self.refMatchKeys + Self.quizKeys + Self.bookOrderKeys + Self.whoAmIKeys + Self.gameDailyAndLastPlayedKeys)
    }

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
        guard let userInfo = note.userInfo else { return }

        let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
        // Filter to known data keys; ignore our timestamp companion keys (handled inside domain helpers)
        let keysToProcess = changedKeys.filter { allKnownKeys.contains($0) }

        guard !keysToProcess.isEmpty else { return }

        var mergedGameKey = false

        for key in keysToProcess {
            if isGameCounterKey(key) || Self.gameDailyAndLastPlayedKeys.contains(key) { mergedGameKey = true }
            mergeIncomingKVSValue(forKey: key)
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
        NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)

        // If any game keys merged or we repaired, notify interested views (scoreboard) as well
        if mergedGameKey {
            NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
        }

        // Record last merge time
        lastMergeDate = Date()
    }

    @objc
    func handleUbiquityIdentityChange() {
        // Account changed: pull, merge, and repair. Do not blindly push local values first.
        kvs.synchronize()
        reconcileAllKeysFromKVS()
    }

    #if canImport(UIKit)
    @objc
    func handleAppDidEnterBackground() {
        // Mirror any differences and coalesce into a single synchronize
        pushAllNow()
    }
    #endif

    // MARK: - Local -> KVS dispatch

    func mirrorLocalKeyToKVS(_ key: String) {
        if Self.settingsKeys.contains(key) {
            mirrorSettingsKeyToKVS(key)
            return
        }
        if Self.gameDailyAndLastPlayedKeys.contains(key) || isGameCounterKey(key) {
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

    func scheduleDebouncedSynchronize() {
        // Nothing to do
        guard !pendingKeys.isEmpty else { return }

        // Cancel any pending task
        debounceTask?.cancel()

        // Clear pending set now (on MainActor)
        pendingKeys.removeAll()

        let delayNanos = UInt64(debounceInterval * 1_000_000_000)

        debounceTask = Task { [weak self] in
            // Debounce
            try? await Task.sleep(nanoseconds: delayNanos)
            guard self != nil else { return }

            // Perform synchronize off-main to avoid any chance of blocking UI.
            await withTaskCancellationHandler {
                // Do not capture self or self.kvs (both are MainActor-isolated / non-Sendable).
                let _ = Task.detached {
                    NSUbiquitousKeyValueStore.default.synchronize()
                    await MainActor.run {
                        iCloudSyncCoordinator.shared.lastPushDate = Date()
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
        if Self.gameDailyAndLastPlayedKeys.contains(key) || isGameCounterKey(key) {
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
        // After a synchronize, merge only keys that actually exist remotely.
        let remoteDict = kvs.dictionaryRepresentation

        var mergedGameKey = false
        var touchedAny = false

        for key in allKnownKeys {
            // Use object(forKey:) to detect presence reliably across types
            let hasRemote = (kvs.object(forKey: key) != nil) || (remoteDict.keys.contains(key))
            guard hasRemote else { continue }

            if isGameCounterKey(key) || Self.gameDailyAndLastPlayedKeys.contains(key) { mergedGameKey = true }
            mergeIncomingKVSValue(forKey: key)
            touchedAny = true
        }

        if touchedAny {
            BibleStatsStore.shared.resetCaches()
            if mergedGameKey {
                let repaired = normalizeGameCountersInvariant()
                if !repaired.isEmpty {
                    enqueueKeysForSync(repaired)
                }
                NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
            }
            NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
            lastMergeDate = Date()
        }
    }

    // MARK: - Shared decode helper for extensions

    func decode<T: Decodable>(_ data: Data?, as type: T.Type) -> T? {
        guard let d = data else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }
}
