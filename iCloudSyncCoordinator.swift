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

    // Silence legacy debug logs to reduce noise
    private func log(_ message: @autoclosure () -> String) {
        // no-op
    }

    // New, concise sync event logging with timestamps
    private static let tsFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private func logPushEvent(_ context: String) {
        let ts = Self.tsFormatter.string(from: Date())
        print("KVS PUSH [\(ts)] \(context)")
    }

    private func logMergeEvent(_ context: String) {
        let ts = Self.tsFormatter.string(from: Date())
        print("KVS MERGE [\(ts)] \(context)")
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

        // Pull -> merge -> normalize -> push repairs (debounced)
        reconcileAllKeysFromKVS()

        // One-time bootstrap: push local differences (no blind timestamp bumps) after initial pull/merge
        if !defaults.bool(forKey: bootstrapFlagKey) {
            pushLocalDifferencesToKVS()
            defaults.set(true, forKey: bootstrapFlagKey)
        }

        // Normalize impossible pairs once at startup too (heals existing data even if no merge occurs this run)
        let repaired = normalizeGameCountersInvariant()
        if !repaired.isEmpty {
            enqueueKeysForSync(repaired)
            // Post asynchronously to avoid interfering with any active keyboard session
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
            }
        }

        // NEW: Migrate legacy Reference Match -> Verse Match keys once if needed.
        let migrated = migrateRefMatchToVerseMatchIfNeeded()
        if !migrated.isEmpty {
            enqueueKeysForSync(migrated)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
            }
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
    // Completion is invoked on the main actor after the immediate synchronize finishes.
    func pushAllNow(completion: (() -> Void)? = nil) {
        for key in allKnownKeys {
            mirrorLocalKeyToKVS(key)
        }
        // Perform a single immediate synchronize off-main and stamp lastPushDate.
        let _ = Task.detached {
            NSUbiquitousKeyValueStore.default.synchronize()
            await MainActor.run {
                iCloudSyncCoordinator.shared.lastPushDate = Date()
                iCloudSyncCoordinator.shared.logPushEvent("pushAllNow (immediate synchronize)")
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
                iCloudSyncCoordinator.shared.logPushEvent("resetAllBibleStatsAndSessions (removed keys + set epoch)")
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
            + Self.quizPerBookMapKeys
            + Self.hangmanPerCategoryMapKeys
            + Self.bookOrderKeys
            + Self.whoAmIKeys
            + Self.wordleKeys
            + Self.gameDailyAndLastPlayedKeys
            + Self.wordleSolvedMapKeys
            + Self.wordleDailyResultKeys
            + Self.wordleDailyFlagKeys
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
                return
            case NSUbiquitousKeyValueStoreAccountChange:
                return
            default:
                break // unknown reason; proceed conservatively
            }
        }

        let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []

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
                || Self.wordleSolvedMapKeys.contains(key)
                || Self.wordleDailyResultKeys.contains(key)
                || Self.wordleDailyFlagKeys.contains(key) {
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

        // Record and log last merge time
        lastMergeDate = Date()
        logMergeEvent("didChangeExternallyNotification (merged \(keysToProcess.count) key(s))")

        // Special-case: Last Read widget keys are not in allKnownKeys (they live as raw KVS/app-group values for widgets).
        if keysToProcess.contains(where: { Self.lastReadWidgetKeys.contains($0) }) {
            // Ensure latest values are pulled to local KVS store
            kvs.synchronize()

            // Mirror KVS -> App Group UserDefaults read by the widget
            if let shared = UserDefaults(suiteName: "group.bible.app") {
                if let book = kvs.string(forKey: "lastReadBook") {
                    shared.set(book, forKey: "lastReadBook")
                }
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
                shared.synchronize()
            }

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
        if Self.gameDailyAndLastPlayedKeys.contains(key)
            || isGameCounterKey(key)
            || Self.quizPerBookMapKeys.contains(key)
            || Self.hangmanPerCategoryMapKeys.contains(key)
            || Self.perGameDailyMapKeys.contains(key)
            || Self.wordleSolvedMapKeys.contains(key)
            || Self.wordleDailyResultKeys.contains(key)
            || Self.wordleDailyFlagKeys.contains(key) {
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

        let delayNanos = UInt64(debounceInterval * 1_000_000_000)

        debounceTask = Task { [weak self] in
            // Debounce
            try? await Task.sleep(nanoseconds: delayNanos)
            guard self != nil else { return }

            // Perform synchronize off-main to avoid any chance of blocking UI.
            await withTaskCancellationHandler {
                let _ = Task.detached {
                    NSUbiquitousKeyValueStore.default.synchronize()
                    await MainActor.run {
                        iCloudSyncCoordinator.shared.lastPushDate = Date()
                        iCloudSyncCoordinator.shared.logPushEvent("debounced synchronize for \(toSync.count) key(s)")
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
        if Self.gameDailyAndLastPlayedKeys.contains(key)
            || isGameCounterKey(key)
            || Self.quizPerBookMapKeys.contains(key)
            || Self.hangmanPerCategoryMapKeys.contains(key)
            || Self.perGameDailyMapKeys.contains(key)
            || Self.wordleSolvedMapKeys.contains(key)
            || Self.wordleDailyResultKeys.contains(key)
            || Self.wordleDailyFlagKeys.contains(key) {
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
                // Clear sessions via API (updates caches/listeners and KVS)
                ReadingSessionsStore.shared.clearAll()
                // Clear Bible stats locally and caches
                BibleStatsStore.shared.clearAllLocal()
                touchedAny = true
                // Record last-seen epoch locally to prevent re-clearing
                defaults.set(incomingEpoch, forKey: bibleStatsLastSeenEpochLocalKey)
            }
        }

        for key in allKnownKeys {
            let hasRemote = (kvs.object(forKey: key) != nil) || (remoteDict.keys.contains(key))

            if hasRemote {
                if isGameCounterKey(key)
                    || Self.gameDailyAndLastPlayedKeys.contains(key)
                    || Self.quizPerBookMapKeys.contains(key)
                    || Self.hangmanPerCategoryMapKeys.contains(key)
                    || Self.perGameDailyMapKeys.contains(key)
                    || Self.wordleSolvedMapKeys.contains(key)
                    || Self.wordleDailyResultKeys.contains(key)
                    || Self.wordleDailyFlagKeys.contains(key) {
                    mergedGameKey = true
                }
                mergeIncomingKVSValue(forKey: key)
                touchedAny = true
                continue
            }

            // Handle remote deletions for game daily maps and last played, per-book maps, per-game daily maps, and WORD daily keys.
            if Self.gameDailyAndLastPlayedKeys.contains(key) {
                if defaults.object(forKey: key) != nil {
                    defaults.removeObject(forKey: key)
                    touchedAny = true
                    mergedGameKey = true

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

            if Self.perGameDailyMapKeys.contains(key) {
                if defaults.object(forKey: key) != nil {
                    defaults.removeObject(forKey: key)
                    touchedAny = true
                    mergedGameKey = true
                }
                continue
            }

            if Self.wordleSolvedMapKeys.contains(key)
                || Self.wordleDailyResultKeys.contains(key)
                || Self.wordleDailyFlagKeys.contains(key) {
                if defaults.object(forKey: key) != nil {
                    defaults.removeObject(forKey: key)
                    touchedAny = true
                    mergedGameKey = true
                }
                continue
            }

            // Bible stats — treat absence remotely as deletion locally
            if Self.bibleStatsKeys.contains(key) {
                if defaults.object(forKey: key) != nil {
                    defaults.removeObject(forKey: key)
                    touchedAny = true
                }
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
            logMergeEvent("reconcileAllKeysFromKVS (touched keys)")
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
