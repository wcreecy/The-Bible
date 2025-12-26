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

    // Ensure start() is performed once per app run
    private var didStart = false

    // MARK: - Reset epoch for Bible stats/sessions

    private let bibleStatsResetEpochKVSKey = "bibleStatsResetEpoch"          // in KVS
    private let bibleStatsLastSeenEpochLocalKey = "bibleStatsLastSeenResetEpoch" // in local defaults

    // MARK: - Logging

    private func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("KVS:", message())
        #endif
    }

    private func isWordDailyKey(_ key: String) -> Bool {
        return Self.wordleSolvedMapKeys.contains(key)
            || Self.wordleDailyResultKeys.contains(key)
            || Self.wordleDailyFlagKeys.contains(key)
    }

    private func anyWordDailyKey<S: Sequence>(_ keys: S) -> Bool where S.Element == String {
        for k in keys {
            if isWordDailyKey(k) { return true }
        }
        return false
    }

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
        guard !didStart else { return }
        didStart = true

        log("start() called. KVS available: \(kvsAvailable ? "yes" : "no"). Synchronizing + reconciling…")

        // Pull -> merge -> normalize -> push repairs (debounced)
        reconcileAllKeysFromKVS()

        // One-time bootstrap: push local differences (no blind timestamp bumps) after initial pull/merge
        if !defaults.bool(forKey: bootstrapFlagKey) {
            log("Bootstrap not complete — pushing local differences to KVS…")
            pushLocalDifferencesToKVS()
            defaults.set(true, forKey: bootstrapFlagKey)
        }

        // Normalize impossible pairs once at startup too (heals existing data even if no merge occurs this run)
        let repaired = normalizeGameCountersInvariant()
        if !repaired.isEmpty {
            log("Repaired game invariants for keys: \(Array(repaired))")
            enqueueKeysForSync(repaired)
            // Post asynchronously to avoid interfering with any active keyboard session
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
            }
        }

        // NEW: Migrate legacy Reference Match -> Verse Match keys once if needed.
        let migrated = migrateRefMatchToVerseMatchIfNeeded()
        if !migrated.isEmpty {
            log("Migrated legacy refmatch -> versematch for keys: \(Array(migrated))")
            enqueueKeysForSync(migrated)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
            }
        }
    }

    // Call after local writes if you want to eagerly push a specific key.
    func pushKey(_ key: String) {
        guard allKnownKeys.contains(key) else { return }
        if isWordDailyKey(key) {
            log("pushKey(\(key)) — mirroring WORD daily key to KVS")
        }
        // Mirror only if changed, then schedule synchronize (debounced).
        mirrorLocalKeyToKVS(key)
        enqueueKeyForSync(key)
    }

    // Optional: push all known keys now (useful on app background)
    // Completion is invoked on the main actor after the immediate synchronize finishes.
    func pushAllNow(completion: (() -> Void)? = nil) {
        log("pushAllNow() — mirroring all known keys. Includes WORD daily: \(Self.wordleSolvedMapKeys + Self.wordleDailyResultKeys + Self.wordleDailyFlagKeys)")
        for key in allKnownKeys {
            mirrorLocalKeyToKVS(key)
        }
        // Perform a single immediate synchronize off-main and stamp lastPushDate.
        let _ = Task.detached {
            NSUbiquitousKeyValueStore.default.synchronize()
            await MainActor.run {
                iCloudSyncCoordinator.shared.lastPushDate = Date()
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
            BibleStatsStore.Defaults.keyVisitedChapters,
            BibleStatsStore.Defaults.keyLastRead,
            BibleStatsStore.Defaults.keySeenVersesByChapter,
            BibleStatsStore.Defaults.keyChapterCompletionDates,
            "readingSessions"
        ]
        for k in kvsKeysToRemove {
            kvs.removeObject(forKey: k)
        }

        // 3) Set/reset epoch in both KVS and local so older devices won’t re-populate
        let now = Date().timeIntervalSince1970
        kvs.set(now, forKey: bibleStatsResetEpochKVSKey)
        defaults.set(now, forKey: bibleStatsLastSeenEpochLocalKey)

        // 4) Flush to server (off-main) and notify UI
        let _ = Task.detached {
            NSUbiquitousKeyValueStore.default.synchronize()
            await MainActor.run {
                iCloudSyncCoordinator.shared.lastPushDate = Date()
                BibleStatsStore.shared.resetCaches()
                NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
            }
        }
    }

    // MARK: - Key sets (union)

    var allKnownKeys: Set<String> {
        Set(
            Self.bibleStatsKeys
            + Self.sessionKeys
            + Self.settingsKeys
            + Self.hangmanKeys
            + Self.beatClockKeys
            + Self.refMatchKeys
            + Self.verseMatchKeys
            + Self.quizKeys
            + Self.quizPerBookMapKeys    // NEW: include per-book quiz maps
            + Self.hangmanPerCategoryMapKeys // NEW: include Hangman per-category maps
            + Self.bookOrderKeys
            + Self.whoAmIKeys
            + Self.wordleKeys            // FIX: include Wordle keys so they mirror/merge
            + Self.gameDailyAndLastPlayedKeys
            // NEW: Include WORD daily status/result/flag keys so they reconcile/push and pass the change filter.
            + Self.wordleSolvedMapKeys
            + Self.wordleDailyResultKeys
            + Self.wordleDailyFlagKeys
            // NEW: Include per-game daily maps so second-row metrics sync
            + Self.perGameDailyMapKeys
        )
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
        // This notification can arrive on a background thread; ensure we run on main.
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.handleKVSExternalChange(note)
            }
            return
        }

        guard let userInfo = note.userInfo else { return }

        // Refine: react only to server/initial sync changes; log/skip quota/account changes.
        let reasonRaw = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
        if let reason = reasonRaw {
            switch reason {
            case NSUbiquitousKeyValueStoreServerChange,
                 NSUbiquitousKeyValueStoreInitialSyncChange:
                break // proceed
            case NSUbiquitousKeyValueStoreQuotaViolationChange:
                log("didChangeExternallyNotification — quota violation reported; skipping merge.")
                return
            case NSUbiquitousKeyValueStoreAccountChange:
                log("didChangeExternallyNotification — account change (handled via identity change); skipping merge.")
                return
            default:
                break // unknown reason; proceed conservatively
            }
        }

        let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
        if anyWordDailyKey(changedKeys) {
            let wordKeys = changedKeys.filter { isWordDailyKey($0) }
            log("didChangeExternallyNotification — WORD daily keys changed: \(wordKeys)")
        }

        // NEW: React immediately to a remote reset epoch while the app is open.
        if changedKeys.contains(bibleStatsResetEpochKVSKey) {
            let incoming = kvs.double(forKey: bibleStatsResetEpochKVSKey)
            if incoming > 0 {
                let lastSeen = defaults.double(forKey: bibleStatsLastSeenEpochLocalKey)
                if incoming > lastSeen {
                    log("KVS change: bibleStatsResetEpoch advanced (\(incoming) > \(lastSeen)) — clearing local Bible stats + sessions now")
                    // Clear sessions via API (updates caches/listeners and mirrors to KVS)
                    ReadingSessionsStore.shared.clearAll()
                    // Clear local Bible stats + caches
                    BibleStatsStore.shared.clearAllLocal()
                    // Record last-seen epoch locally to prevent re-clearing
                    defaults.set(incoming, forKey: bibleStatsLastSeenEpochLocalKey)
                    // Notify UI
                    BibleStatsStore.shared.resetCaches()
                    NotificationCenter.default.post(name: .bibleStatsExternallyUpdated, object: nil)
                }
            }
        }

        // Filter to known data keys; ignore our timestamp companion keys (handled inside domain helpers)
        let keysToProcess = changedKeys.filter { allKnownKeys.contains($0) || Self.lastReadWidgetKeys.contains($0) }

        guard !keysToProcess.isEmpty else { return }

        var mergedGameKey = false

        for key in keysToProcess {
            if isGameCounterKey(key)
                || Self.gameDailyAndLastPlayedKeys.contains(key)
                || Self.quizPerBookMapKeys.contains(key)
                || Self.hangmanPerCategoryMapKeys.contains(key)
                || Self.perGameDailyMapKeys.contains(key)
                || isWordDailyKey(key) {
                mergedGameKey = true
            }
            // Merge only for domains we own in coordinator
            if allKnownKeys.contains(key) {
                if isWordDailyKey(key) {
                    log("Merging incoming WORD daily key: \(key)")
                }
                mergeIncomingKVSValue(forKey: key)
            }
        }

        // Invalidate caches so subsequent reads reflect merged values
        BibleStatsStore.shared.resetCaches()

        // After merging any game keys, normalize impossible pairs once (answered >= correct)
        if mergedGameKey {
            let repairedKeys = normalizeGameCountersInvariant()
            if !repairedKeys.isEmpty {
                log("Post-merge invariant repair — enqueue: \(Array(repairedKeys))")
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

        // Special-case: Last Read widget keys are not in allKnownKeys (they live as raw KVS/app-group values for widgets).
        // If any of these arrived from the server, pull latest, mirror into the App Group store (for the widget),
        // and trigger a widget reload so device B shows the current bookmark.
        if keysToProcess.contains(where: { Self.lastReadWidgetKeys.contains($0) }) {
            // Ensure latest values are pulled to local KVS store
            kvs.synchronize()

            // Mirror KVS -> App Group UserDefaults read by the widget
            if let shared = UserDefaults(suiteName: "group.bible.app") {
                if let book = kvs.string(forKey: "lastReadBook") {
                    shared.set(book, forKey: "lastReadBook")
                }
                // Use NSNumber/object to detect presence; fall back to typed getters if needed
                if let chapObj = kvs.object(forKey: "lastReadChapter") as? NSNumber {
                    shared.set(chapObj.intValue, forKey: "lastReadChapter")
                } else {
                    let chap = Int(kvs.longLong(forKey: "lastReadChapter"))
                    if chap != 0 { shared.set(chap, forKey: "lastReadChapter") }
                }
                if let verseObj = kvs.object(forKey: "lastReadVerse") as? NSNumber {
                    shared.set(verseObj.intValue, forKey: "lastReadVerse")
                } else {
                    let verse = Int(kvs.longLong(forKey: "lastReadVerse"))
                    if verse != 0 { shared.set(verse, forKey: "lastReadVerse") }
                }
                if let text = kvs.string(forKey: "lastReadText") {
                    shared.set(text, forKey: "lastReadText")
                }
                // Force a sync to disk so the widget sees the updated values promptly
                shared.synchronize()
            }

            // Debounced reload of only the Last Read widget
            DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
        }
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

        log("Ubiquity identity changed — synchronizing and reconciling all keys…")

        // Account changed: pull, merge, and repair. Do not blindly push local values first.
        kvs.synchronize()
        reconcileAllKeysFromKVS()
    }

    #if canImport(UIKit)
    @objc
    func handleAppDidEnterBackground() {
        // Begin a background task so the immediate synchronize has time to complete.
        let app = UIApplication.shared
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = app.beginBackgroundTask(withName: "KVSFlushOnBackground") {
            // Expiration handler
            if bgTask != .invalid {
                app.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }

        log("App did enter background — pushAllNow() with background task")

        // Mirror any differences and perform a single immediate synchronize.
        pushAllNow { [weak app] in
            // End background task after the off-main synchronize finishes.
            if let app, bgTask != .invalid {
                app.endBackgroundTask(bgTask)
            }
        }
    }
    #endif

    // MARK: - Local -> KVS dispatch

    func mirrorLocalKeyToKVS(_ key: String) {
        if isWordDailyKey(key) {
            log("mirrorLocalKeyToKVS(\(key)) — WORD daily key")
        }
        if Self.settingsKeys.contains(key) {
            mirrorSettingsKeyToKVS(key)
            return
        }
        if Self.gameDailyAndLastPlayedKeys.contains(key)
            || isGameCounterKey(key)
            || Self.quizPerBookMapKeys.contains(key)
            || Self.hangmanPerCategoryMapKeys.contains(key)
            || Self.perGameDailyMapKeys.contains(key)
            || isWordDailyKey(key) {
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
        let toSync = pendingKeys
        pendingKeys.removeAll()

        if anyWordDailyKey(toSync) {
            let wordKeys = toSync.filter { isWordDailyKey($0) }
            log("Scheduling KVS synchronize (debounced) for keys: \(Array(wordKeys))")
        }

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
        if isWordDailyKey(key) {
            log("mergeIncomingKVSValue(\(key)) — WORD daily key")
        }
        if Self.settingsKeys.contains(key) {
            mergeSettingsIncoming(forKey: key)
            return
        }
        if Self.gameDailyAndLastPlayedKeys.contains(key)
            || isGameCounterKey(key)
            || Self.quizPerBookMapKeys.contains(key)
            || Self.hangmanPerCategoryMapKeys.contains(key)
            || Self.perGameDailyMapKeys.contains(key)
            || isWordDailyKey(key) {
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
        // After a synchronize, merge keys that exist remotely, AND clear local for certain domains if absent remotely.
        let remoteDict = kvs.dictionaryRepresentation

        var mergedGameKey = false
        var touchedAny = false

        // Check for a remote Bible stats reset epoch first; if newer than local, clear local data.
        let incomingEpoch = kvs.double(forKey: bibleStatsResetEpochKVSKey)
        if incomingEpoch > 0 {
            let lastSeen = defaults.double(forKey: bibleStatsLastSeenEpochLocalKey)
            if incomingEpoch > lastSeen {
                log("Reconcile: Detected newer bibleStatsResetEpoch (\(incomingEpoch) > \(lastSeen)) — clearing local Bible stats + sessions")
                // Clear sessions via API (updates caches/listeners and KVS)
                ReadingSessionsStore.shared.clearAll()
                // Clear Bible stats locally and caches
                BibleStatsStore.shared.clearAllLocal()
                touchedAny = true
                // Record last-seen epoch locally to prevent re-clearing
                defaults.set(incomingEpoch, forKey: bibleStatsLastSeenEpochLocalKey)
            }
        }

        // Log presence of WORD daily keys on the server for quick diagnosis
        do {
            let solved = remoteDict.keys.contains("wordleDailySolvedDays") || kvs.object(forKey: "wordleDailySolvedDays") != nil
            let result = remoteDict.keys.contains("wordleDailyResultMap") || kvs.object(forKey: "wordleDailyResultMap") != nil
            let completed = remoteDict.keys.contains("wordleDailyCompletedDay") || kvs.object(forKey: "wordleDailyCompletedDay") != nil
            let target = remoteDict.keys.contains("wordleDailyTarget") || kvs.object(forKey: "wordleDailyTarget") != nil
            log("reconcileAllKeysFromKVS — WORD presence -> solved:\(solved) result:\(result) completed:\(completed) target:\(target)")
        }

        for key in allKnownKeys {
            let hasRemote = (kvs.object(forKey: key) != nil) || (remoteDict.keys.contains(key))

            if hasRemote {
                if isGameCounterKey(key)
                    || Self.gameDailyAndLastPlayedKeys.contains(key)
                    || Self.quizPerBookMapKeys.contains(key)
                    || Self.hangmanPerCategoryMapKeys.contains(key)
                    || Self.perGameDailyMapKeys.contains(key)
                    || isWordDailyKey(key) {
                    mergedGameKey = true
                }
                if isWordDailyKey(key) {
                    log("Reconcile merging WORD daily key: \(key)")
                }
                mergeIncomingKVSValue(forKey: key)
                touchedAny = true
                continue
            }

            // Handle remote deletions for game daily maps and last played, per-book maps, per-game daily maps, and WORD daily keys.
            if Self.gameDailyAndLastPlayedKeys.contains(key) {
                // Clear local copy if present
                if defaults.object(forKey: key) != nil {
                    defaults.removeObject(forKey: key)
                    touchedAny = true
                    mergedGameKey = true

                    // If overall daily maps were removed remotely, also clear local per-game/per-mode daily maps
                    if key == "gamesDailyAnswered" || key == "gamesDailyCorrect" {
                        let perGameKeys = ["quiz","hangman","beatclock","versematch","bookorder","whoami","word"]
                        for g in perGameKeys {
                            defaults.removeObject(forKey: "gamesDailyAnswered_\(g)")
                            defaults.removeObject(forKey: "gamesDailyCorrect_\(g)")
                        }
                        for modeKey in ["word_normal", "word_hard"] {
                            defaults.removeObject(forKey: "gamesDailyAnswered_\(modeKey)")
                            defaults.removeObject(forKey: "gamesDailyCorrect_\(modeKey)")
                        }
                    }
                }
                continue
            }

            if Self.quizPerBookMapKeys.contains(key) || Self.hangmanPerCategoryMapKeys.contains(key) {
                if defaults.object(forKey: key) != nil {
                    defaults.removeObject(forKey: key)
                    touchedAny = true
                    mergedGameKey = true
                }
                continue
            }

            // NEW: Handle remote deletion for per-game daily maps (clear local)
            if Self.perGameDailyMapKeys.contains(key) {
                if defaults.object(forKey: key) != nil {
                    defaults.removeObject(forKey: key)
                    touchedAny = true
                    mergedGameKey = true
                }
                continue
            }

            // NEW: Handle remote deletion for WORD daily keys as well (clear local)
            if isWordDailyKey(key) {
                if defaults.object(forKey: key) != nil {
                    defaults.removeObject(forKey: key)
                    touchedAny = true
                    mergedGameKey = true
                    log("Reconcile: remote deletion detected for WORD key \(key) — cleared local")
                }
                continue
            }

            // NEW: Bible stats — treat absence remotely as deletion locally
            if Self.bibleStatsKeys.contains(key) {
                if defaults.object(forKey: key) != nil {
                    defaults.removeObject(forKey: key)
                    touchedAny = true
                }
                continue
            }

            // For other domains (e.g., counters), absence on KVS is not a delete signal; skip.
        }

        if touchedAny {
            BibleStatsStore.shared.resetCaches()

            if mergedGameKey {
                let repaired = normalizeGameCountersInvariant()
                if !repaired.isEmpty {
                    log("Reconcile invariant repair — enqueue: \(Array(repaired))")
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
    }

    // MARK: - Shared decode helper for extensions

    func decode<T: Decodable>(_ data: Data?, as type: T.Type) -> T? {
        guard let d = data else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }
}

// MARK: - Last Read widget keys (KVS/App Group)
private extension iCloudSyncCoordinator {
    static let lastReadWidgetKeys: Set<String> = [
        "lastReadBook",
        "lastReadChapter",
        "lastReadVerse",
        "lastReadText"
    ]
}
