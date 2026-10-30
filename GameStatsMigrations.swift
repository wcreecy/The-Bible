import Foundation

/// One-time upgrades of stored game stats, run once at launch. Each one is guarded by a flag in
/// `UserDefaults`, so it only ever runs a single time per install.
enum GameStatsMigrations {
    static func runAll() {
        migrateLegacyGameKeysIfNeeded()
        migrateQuizCombinedIfNeeded()
        migrateBookOrderCombinedIfNeeded()
        migrateHangmanCombinedIfNeeded() // backfill combined “_all” for Hangman
        migrateVerseMatchCombinedIfNeeded() // backfill combined “_all” for Verses
        migrateWhoAmICombinedIfNeeded() // backfill combined “_all” for Who?
    }

    private static let legacyWipeFlagKey = "didWipeLegacyUnsuffixedGameKeys_v1"
    private static let quizCombinedMigrationFlagKey = "didMigrateQuizCombinedAll_v1"
    private static let bookOrderCombinedMigrationFlagKey = "didMigrateBookOrderCombinedAll_v1"
    private static let hangmanCombinedMigrationFlagKey = "didMigrateHangmanCombinedAll_v1"
    private static let verseMatchCombinedMigrationFlagKey = "didMigrateVerseMatchCombinedAll_v1"
    private static let whoamiCombinedMigrationFlagKey = "didMigrateWhoAmICombinedAll_v1"

    private static func migrateLegacyGameKeysIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.legacyWipeFlagKey) else { return }

        let legacyKeys: [String] = [
            "quizAllTimeCorrect",
            "quizAllTimeAnswered",
            "quizAllTimeBestStreak",
            "hangmanAllTimeCorrect",
            "hangmanAllTimeAnswered",
            "hangmanAllTimeBestStreak",
            "beatclockAllTimeCorrect",
            "beatclockAllTimeAnswered",
            "beatclockAllTimeBestStreak",
            "refmatchAllTimeCorrect",
            "refmatchAllTimeAnswered",
            "refmatchAllTimeBestStreak"
        ]

        for key in legacyKeys {
            defaults.removeObject(forKey: key)
        }

        defaults.set(true, forKey: Self.legacyWipeFlagKey)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // One-time migration: combine existing per-difficulty Quiz stats into combined "_all" keys.
    private static func migrateQuizCombinedIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.quizCombinedMigrationFlagKey) else { return }

        // Sum across easy/normal/hard; also consider legacy unsuffixed as fallback
        func readInt(_ key: String) -> Int { max(0, defaults.integer(forKey: key)) }

        let cEasy = readInt("quizAllTimeCorrect_easy")
        let cNorm = readInt("quizAllTimeCorrect_normal")
        let cHard = readInt("quizAllTimeCorrect_hard")
        let aEasy = readInt("quizAllTimeAnswered_easy")
        let aNorm = readInt("quizAllTimeAnswered_normal")
        let aHard = readInt("quizAllTimeAnswered_hard")
        let bEasy = readInt("quizAllTimeBestStreak_easy")
        let bNorm = readInt("quizAllTimeBestStreak_normal")
        let bHard = readInt("quizAllTimeBestStreak_hard")

        let legacyC = readInt("quizAllTimeCorrect")
        let legacyA = readInt("quizAllTimeAnswered")
        let legacyB = readInt("quizAllTimeBestStreak")

        let sumCorrect = cEasy + cNorm + cHard + legacyC
        let sumAnswered = aEasy + aNorm + aHard + legacyA
        let bestStreak = max(bEasy, bNorm, bHard, legacyB)

        let existingAllC = readInt("quizAllTimeCorrect_all")
        let existingAllA = readInt("quizAllTimeAnswered_all")
        let existingAllB = readInt("quizAllTimeBestStreak_all")

        // Only write if the combined keys are currently zero to avoid clobbering user progress
        if existingAllC == 0 && sumCorrect > 0 {
            defaults.set(sumCorrect, forKey: "quizAllTimeCorrect_all")
            iCloudSyncCoordinator.shared.pushKey("quizAllTimeCorrect_all")
        }
        if existingAllA == 0 && sumAnswered > 0 {
            defaults.set(sumAnswered, forKey: "quizAllTimeAnswered_all")
            iCloudSyncCoordinator.shared.pushKey("quizAllTimeAnswered_all")
        }
        if existingAllB == 0 && bestStreak > 0 {
            defaults.set(bestStreak, forKey: "quizAllTimeBestStreak_all")
            iCloudSyncCoordinator.shared.pushKey("quizAllTimeBestStreak_all")
        }

        defaults.set(true, forKey: Self.quizCombinedMigrationFlagKey)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // One-time migration: combine existing per-difficulty Book Order stats into combined "_all" keys.
    private static func migrateBookOrderCombinedIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.bookOrderCombinedMigrationFlagKey) else { return }

        func readInt(_ key: String) -> Int { max(0, defaults.integer(forKey: key)) }

        let cEasy = readInt("bookorderAllTimeCorrect_easy")
        let cNorm = readInt("bookorderAllTimeCorrect_normal")
        let cHard = readInt("bookorderAllTimeCorrect_hard")
        let aEasy = readInt("bookorderAllTimeAnswered_easy")
        let aNorm = readInt("bookorderAllTimeAnswered_normal")
        let aHard = readInt("bookorderAllTimeAnswered_hard")
        let bEasy = readInt("bookorderAllTimeBestStreak_easy")
        let bNorm = readInt("bookorderAllTimeBestStreak_normal")
        let bHard = readInt("bookorderAllTimeBestStreak_hard")

        // Legacy unsuffixed fallback
        let legacyC = readInt("bookorderAllTimeCorrect")
        let legacyA = readInt("bookorderAllTimeAnswered")
        let legacyB = readInt("bookorderAllTimeBestStreak")

        let sumCorrect = cEasy + cNorm + cHard + legacyC
        let sumAnswered = aEasy + aNorm + aHard + legacyA
        let bestStreak = max(bEasy, bNorm, bHard, legacyB)

        let existingAllC = readInt("bookorderAllTimeCorrect_all")
        let existingAllA = readInt("bookorderAllTimeAnswered_all")
        let existingAllB = readInt("bookorderAllTimeBestStreak_all")

        if existingAllC == 0 && sumCorrect > 0 {
            defaults.set(sumCorrect, forKey: "bookorderAllTimeCorrect_all")
            iCloudSyncCoordinator.shared.pushKey("bookorderAllTimeCorrect_all")
        }
        if existingAllA == 0 && sumAnswered > 0 {
            defaults.set(sumAnswered, forKey: "bookorderAllTimeAnswered_all")
            iCloudSyncCoordinator.shared.pushKey("bookorderAllTimeAnswered_all")
        }
        if existingAllB == 0 && bestStreak > 0 {
            defaults.set(bestStreak, forKey: "bookorderAllTimeBestStreak_all")
            iCloudSyncCoordinator.shared.pushKey("bookorderAllTimeBestStreak_all")
        }

        defaults.set(true, forKey: Self.bookOrderCombinedMigrationFlagKey)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // One-time migration: combine existing per-difficulty Hangman stats into combined "_all" keys.
    private static func migrateHangmanCombinedIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.hangmanCombinedMigrationFlagKey) else { return }

        func readInt(_ key: String) -> Int { max(0, defaults.integer(forKey: key)) }

        // Include legacy “medium” mapped to “normal” era; sum all that exist.
        let cEasy = readInt("hangmanAllTimeCorrect_easy")
        let cNorm = readInt("hangmanAllTimeCorrect_normal")
        let cMed  = readInt("hangmanAllTimeCorrect_medium")
        let cHard = readInt("hangmanAllTimeCorrect_hard")

        let aEasy = readInt("hangmanAllTimeAnswered_easy")
        let aNorm = readInt("hangmanAllTimeAnswered_normal")
        let aMed  = readInt("hangmanAllTimeAnswered_medium")
        let aHard = readInt("hangmanAllTimeAnswered_hard")

        let bEasy = readInt("hangmanAllTimeBestStreak_easy")
        let bNorm = readInt("hangmanAllTimeBestStreak_normal")
        let bMed  = readInt("hangmanAllTimeBestStreak_medium")
        let bHard = readInt("hangmanAllTimeBestStreak_hard")

        // Legacy unsuffixed fallback
        let legacyC = readInt("hangmanAllTimeCorrect")
        let legacyA = readInt("hangmanAllTimeAnswered")
        let legacyB = readInt("hangmanAllTimeBestStreak")

        let sumCorrect = cEasy + cNorm + cMed + cHard + legacyC
        let sumAnswered = aEasy + aNorm + aMed + aHard + legacyA
        let bestStreak = max(bEasy, bNorm, bMed, bHard, legacyB)

        let existingAllC = readInt("hangmanAllTimeCorrect_all")
        let existingAllA = readInt("hangmanAllTimeAnswered_all")
        let existingAllB = readInt("hangmanAllTimeBestStreak_all")

        if existingAllC == 0 && sumCorrect > 0 {
            defaults.set(sumCorrect, forKey: "hangmanAllTimeCorrect_all")
            iCloudSyncCoordinator.shared.pushKey("hangmanAllTimeCorrect_all")
        }
        if existingAllA == 0 && sumAnswered > 0 {
            defaults.set(sumAnswered, forKey: "hangmanAllTimeAnswered_all")
            iCloudSyncCoordinator.shared.pushKey("hangmanAllTimeAnswered_all")
        }
        if existingAllB == 0 && bestStreak > 0 {
            defaults.set(bestStreak, forKey: "hangmanAllTimeBestStreak_all")
            iCloudSyncCoordinator.shared.pushKey("hangmanAllTimeBestStreak_all")
        }

        defaults.set(true, forKey: Self.hangmanCombinedMigrationFlagKey)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // One-time migration: combine existing per-difficulty Verses stats into combined "_all" keys.
    private static func migrateVerseMatchCombinedIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.verseMatchCombinedMigrationFlagKey) else { return }

        func readInt(_ key: String) -> Int { max(0, defaults.integer(forKey: key)) }

        // New Verses keys
        let cEasy = readInt("versematchAllTimeCorrect_easy")
        let cNorm = readInt("versematchAllTimeCorrect_normal")
        let cMed  = readInt("versematchAllTimeCorrect_medium")
        let cHard = readInt("versematchAllTimeCorrect_hard")

        let aEasy = readInt("versematchAllTimeAnswered_easy")
        let aNorm = readInt("versematchAllTimeAnswered_normal")
        let aMed  = readInt("versematchAllTimeAnswered_medium")
        let aHard = readInt("versematchAllTimeAnswered_hard")

        let bEasy = readInt("versematchAllTimeBestStreak_easy")
        let bNorm = readInt("versematchAllTimeBestStreak_normal")
        let bMed  = readInt("versematchAllTimeBestStreak_medium")
        let bHard = readInt("versematchAllTimeBestStreak_hard")

        // Legacy Reference Match fallback
        let legacyC = readInt("refmatchAllTimeCorrect")
        let legacyA = readInt("refmatchAllTimeAnswered")
        let legacyB = readInt("refmatchAllTimeBestStreak")

        let sumCorrect = cEasy + cNorm + cMed + cHard + legacyC
        let sumAnswered = aEasy + aNorm + aMed + aHard + legacyA
        let bestStreak = max(bEasy, bNorm, bMed, bHard, legacyB)

        let existingAllC = readInt("versematchAllTimeCorrect_all")
        let existingAllA = readInt("versematchAllTimeAnswered_all")
        let existingAllB = readInt("versematchAllTimeBestStreak_all")

        if existingAllC == 0 && sumCorrect > 0 {
            defaults.set(sumCorrect, forKey: "versematchAllTimeCorrect_all")
            iCloudSyncCoordinator.shared.pushKey("versematchAllTimeCorrect_all")
        }
        if existingAllA == 0 && sumAnswered > 0 {
            defaults.set(sumAnswered, forKey: "versematchAllTimeAnswered_all")
            iCloudSyncCoordinator.shared.pushKey("versematchAllTimeAnswered_all")
        }
        if existingAllB == 0 && bestStreak > 0 {
            defaults.set(bestStreak, forKey: "versematchAllTimeBestStreak_all")
            iCloudSyncCoordinator.shared.pushKey("versematchAllTimeBestStreak_all")
        }

        defaults.set(true, forKey: Self.verseMatchCombinedMigrationFlagKey)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }

    // One-time migration: combine existing per-difficulty Who? stats into combined "_all" keys.
    private static func migrateWhoAmICombinedIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.whoamiCombinedMigrationFlagKey) else { return }

        func readInt(_ key: String) -> Int { max(0, defaults.integer(forKey: key)) }

        let cEasy = readInt("whoamiAllTimeCorrect_easy")
        let cNorm = readInt("whoamiAllTimeCorrect_normal")
        let cHard = readInt("whoamiAllTimeCorrect_hard")

        let aEasy = readInt("whoamiAllTimeAnswered_easy")
        let aNorm = readInt("whoamiAllTimeAnswered_normal")
        let aHard = readInt("whoamiAllTimeAnswered_hard")

        let bEasy = readInt("whoamiAllTimeBestStreak_easy")
        let bNorm = readInt("whoamiAllTimeBestStreak_normal")
        let bHard = readInt("whoamiAllTimeBestStreak_hard")

        let sumCorrect = cEasy + cNorm + cHard
        let sumAnswered = aEasy + aNorm + aHard
        let bestStreak = max(bEasy, bNorm, bHard)

        let existingAllC = readInt("whoamiAllTimeCorrect_all")
        let existingAllA = readInt("whoamiAllTimeAnswered_all")
        let existingAllB = readInt("whoamiAllTimeBestStreak_all")

        if existingAllC == 0 && sumCorrect > 0 {
            defaults.set(sumCorrect, forKey: "whoamiAllTimeCorrect_all")
            iCloudSyncCoordinator.shared.pushKey("whoamiAllTimeCorrect_all")
        }
        if existingAllA == 0 && sumAnswered > 0 {
            defaults.set(sumAnswered, forKey: "whoamiAllTimeAnswered_all")
            iCloudSyncCoordinator.shared.pushKey("whoamiAllTimeAnswered_all")
        }
        if existingAllB == 0 && bestStreak > 0 {
            defaults.set(bestStreak, forKey: "whoamiAllTimeBestStreak_all")
            iCloudSyncCoordinator.shared.pushKey("whoamiAllTimeBestStreak_all")
        }

        defaults.set(true, forKey: Self.whoamiCombinedMigrationFlagKey)
        NotificationCenter.default.post(name: .gameStatsExternallyUpdated, object: nil)
    }
}
