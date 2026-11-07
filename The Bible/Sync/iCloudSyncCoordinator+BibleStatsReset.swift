import Foundation

// MARK: - Reset helpers (public) — called by Settings

extension iCloudSyncCoordinator {
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
            BibleStatsStore.Defaults.keyReadingHistoryArchive,
            "readingSessions"
        ]
        for k in kvsKeysToRemove {
            kvs.removeObject(forKey: k)
        }

        // Prayer stats are shown under Reading Stats and reset with them.
        clearPrayerStats()

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
        AppDataChanges.shared.bibleStatsChanged()
        DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
        let _ = Task.detached {
            NSUbiquitousKeyValueStore.default.synchronize()
            await MainActor.run {
                iCloudSyncCoordinator.shared.lastPushDate = Date()
            }
        }
    }
}
