import Foundation

// KVS -> Local: routes incoming values to their domain merge and runs full reconcile passes.
extension iCloudSyncCoordinator {

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
        if Self.prayerStatsKeys.contains(key) {
            mergePrayerStatsIncoming(forKey: key)
            return
        }
        if Self.missedQuestionKeys.contains(key) {
            mergeMissedQuestionsIncoming(forKey: key)
            return
        }
    }

    // MARK: - One-shot reconcile pass at startup/identity change

    func reconcileAllKeysFromKVS() {
        AppPerformance.measure("SyncReconciliation") {
            reconcileAllKeysFromKVSImpl()
        }
    }

    private func reconcileAllKeysFromKVSImpl() {
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
            if KVSSyncLifecyclePolicy.shouldApplyReset(remoteEpoch: incomingEpoch, lastSeenEpoch: lastSeen) {
                // Clear sessions via API (updates caches/listeners and KVS)
                ReadingSessionsStore.shared.clearAll()
                // Clear Bible stats locally and caches
                BibleStatsStore.shared.clearAllLocal()
                for key in Self.bibleStatsKeys + Self.sessionKeys {
                    kvs.removeObject(forKey: key)
                }
                clearPrayerStats()
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

        // Check for a remote Game stats reset epoch; if newer than local, clear local game data only.
        let incomingGameEpoch = kvs.double(forKey: gameStatsResetEpochKVSKey)
        if incomingGameEpoch > 0 {
            let lastSeenGame = defaults.double(forKey: gameStatsLastSeenEpochLocalKey)
            if KVSSyncLifecyclePolicy.shouldApplyReset(remoteEpoch: incomingGameEpoch, lastSeenEpoch: lastSeenGame) {
                // Purge local game data without writing back to KVS (remote reset is authoritative)
                clearAllGameDataLocalOnly()
                for key in allKnownGameDataKeys {
                    kvs.removeObject(forKey: key)
                    kvs.removeObject(forKey: tsKey(for: key))
                }
                for key in Self.missedQuestionKeys {
                    kvs.removeObject(forKey: key)
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
            if appliedBibleReset && (Self.bibleStatsKeys.contains(key)
                || Self.sessionKeys.contains(key)
                || Self.prayerStatsKeys.contains(key)) {
                continue
            }
            if appliedGameReset
                && (allKnownGameDataKeys.contains(key) || Self.missedQuestionKeys.contains(key)) {
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
                    AppDataChanges.shared.gameStatsChanged()
                }
            }

            DispatchQueue.main.async {
                AppDataChanges.shared.bibleStatsChanged()
            }
            lastMergeDate = Date()
        }

        if isInitialDownloadComplete {
            GameStatsLedger.shared.reconcile()
        }
        if appliedBibleReset || appliedGameReset {
            recordReconciliation(result: "Applied a remote reset")
        } else if touchedAny {
            recordReconciliation(result: "Applied remote changes")
        } else {
            recordReconciliation(result: "Up to date")
        }
        AppDataChanges.shared.syncStatusChanged()
    }
}
