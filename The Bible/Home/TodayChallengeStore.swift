import SwiftUI
import Foundation
import Observation
import OSLog

private let todayChallengesLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "The Bible",
    category: "TodayChallenges"
)

private struct TodayChallengeSnapshot: Codable {
    let dayKey: String
    var challenges: [TodayChallenge]
    var lastModified: Date
}

@MainActor
@Observable
final class TodayChallengeStore {
    static let shared = TodayChallengeStore()

    private(set) var challenges: [TodayChallenge] = []

    private let storageKey = AppStorageKey.todayChallengesSnapshotV1
    private let cloudStorageKey = AppStorageKey.todayChallengesSnapshotV2
    let catalog = TodayChallengeCatalog.load()
    private let cloudStore = NSUbiquitousKeyValueStore.default
    @ObservationIgnored private var corpusWaitTask: Task<Void, Never>?
    @ObservationIgnored private var cloudChangeTask: Task<Void, Never>?
    /// Ignores iCloud churn that changes only snapshot metadata, not the actual tasks people see.
    @ObservationIgnored private var lastAppliedCloudSnapshot: TodayChallengeSnapshot?

    private init() {
        cloudChangeTask = NotificationCenter.observe(
            NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            for: self
        ) { store, notification in
            store.refreshForCloudChange(notification)
        }
        cloudStore.synchronize()
        todayChallengesLogger.debug("Initialized Today challenge store.")
        loadOrCreateForToday()
    }

    func refresh() {
        loadOrCreateForToday()
        // A chapter task is complete when every verse in it is recorded as read.
        syncCompletedReadingChallenges()
        syncGameProgress()
    }

    /// Reconciles only when iCloud reports that Today Challenge data changed. The key-value
    /// store also posts for unrelated synced settings and game data, which must not reload this card.
    func refreshForCloudChange(_ notification: Notification) {
        let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? []
        guard Self.shouldRefreshForCloudChange(changedKeys) else { return }
        guard let cloudSnapshotData = cloudStore.data(forKey: cloudStorageKey),
              let cloudSnapshot = snapshot(from: cloudSnapshotData),
              !Self.representsSameChallengeSet(cloudSnapshot, as: lastAppliedCloudSnapshot) else { return }
        refresh()
    }

    static func shouldRefreshForCloudChange(_ changedKeys: [String]) -> Bool {
        changedKeys.contains(AppStorageKey.todayChallengesSnapshotV2)
    }

    private static func representsSameChallengeSet(
        _ snapshot: TodayChallengeSnapshot,
        as previousSnapshot: TodayChallengeSnapshot?
    ) -> Bool {
        guard let previousSnapshot else { return false }
        return snapshot.dayKey == previousSnapshot.dayKey &&
            snapshot.challenges == previousSnapshot.challenges
    }

    func recordPrayerTimerCompletion(minutes: Int) {
        loadOrCreateForToday()

        updateChallenges { challenge in
            challenge.kind == .prayerTimer &&
            minutes >= (challenge.minimumMinutes ?? .max)
        }
    }

    func toggleManualChallenge(id: UUID) {
        loadOrCreateForToday()

        guard let index = challenges.firstIndex(where: { $0.id == id && $0.kind == .reflection }) else {
            return
        }

        challenges[index].isCompleted.toggle()
        save()
    }

    /// Marks today's favorite-verse task complete after a verse is successfully saved.
    func recordFavoriteVerseSaved() {
        loadOrCreateForToday()
        updateChallenges { $0.kind == .favoriteVerse }
    }

    /// Marks today's highlight task complete after a verse highlight is successfully saved.
    func recordVerseHighlightSaved() {
        loadOrCreateForToday()
        updateChallenges { $0.kind == .highlightVerse }
    }

    func completeStudyChallenge(id: UUID) {
        loadOrCreateForToday()

        guard let index = challenges.firstIndex(where: { $0.id == id && $0.kind == .studyChapter }),
              !challenges[index].isCompleted else {
            return
        }

        challenges[index].isCompleted = true
        save()
    }

    // MARK: - History

    private let historyKey = AppStorageKey.todayChallengesHistoryV1

    /// Combines this device's history with the synced copy, so tasks shown on another
    /// device count too.
    func loadHistory() -> TodayChallengeHistory {
        func decode(_ data: Data?, keepingUnreadableCopy: Bool) -> TodayChallengeHistory {
            guard let data else { return TodayChallengeHistory() }
            let history = keepingUnreadableCopy
                ? PersistedDecoding.decode(
                    TodayChallengeHistory.self,
                    from: data,
                    key: historyKey,
                    keepingUnreadableIn: .standard
                )
                : PersistedDecoding.decode(TodayChallengeHistory.self, from: data, name: "\(historyKey) (iCloud)")
            return history ?? TodayChallengeHistory()
        }
        return decode(UserDefaults.standard.data(forKey: historyKey), keepingUnreadableCopy: true)
            .merged(with: decode(cloudStore.data(forKey: historyKey), keepingUnreadableCopy: false))
    }

    /// Saved locally and to iCloud; the next snapshot publish synchronizes the store.
    func saveHistory(_ history: TodayChallengeHistory) {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
        cloudStore.set(data, forKey: historyKey)
    }

    #if DEBUG
    func regenerateForDebug() {
        challenges = makeChallenges()
        save()
    }
    #endif

    private func syncCompletedReadingChallenges() {
        updateChallenges { challenge in
            guard challenge.kind == .readChapter,
                  let bookName = challenge.bookName,
                  let chapterNumber = challenge.chapterNumber,
                  let book = BibleData.books.first(where: { $0.name == bookName }),
                  let chapter = book.chapters.first(where: { $0.number == chapterNumber }) else {
                return false
            }

            return BibleStatsStore.shared.isChapterComplete(
                bookName: bookName,
                chapter: chapterNumber,
                totalVerses: chapter.verses.count
            )
        }
    }

    private func syncGameProgress() {
        updateChallenges { challenge in
            guard challenge.kind == .playGame, let gameName = challenge.gameName else {
                return false
            }

            return (GameStats.shared.dailySeriesLast(days: 1, forDisplayName: gameName).last?.answered ?? 0) > 0
        }
    }

    private func loadOrCreateForToday() {
        let now = Date()
        let localSnapshot = snapshot(from: UserDefaults.standard.data(forKey: storageKey))
        let cloudSnapshotData = cloudStore.data(forKey: cloudStorageKey)
        let cloudSnapshot = snapshot(from: cloudSnapshotData)

        if let cloudSnapshot,
           !Self.needsNewChallenges(snapshotDayKey: cloudSnapshot.dayKey, on: now),
           cloudSnapshot.challenges.count == 3,
           !Self.containsRetiredBookmarkTask(in: cloudSnapshot.challenges) {
            let cloudChallenges = cloudSnapshot.challenges.map(Self.repairedChallenge)
            challenges = cloudChallenges
            lastAppliedCloudSnapshot = cloudSnapshot
            todayChallengesLogger.debug("Loaded Today challenges from the iCloud snapshot; count=\(cloudChallenges.count, privacy: .public).")
            persistLocally(lastModified: cloudSnapshot.lastModified)

            if cloudChallenges != cloudSnapshot.challenges {
                save()
            }
        } else if let localSnapshot,
                  !Self.needsNewChallenges(snapshotDayKey: localSnapshot.dayKey, on: now),
                  localSnapshot.challenges.count == 3,
                  !Self.containsRetiredBookmarkTask(in: localSnapshot.challenges) {
            challenges = localSnapshot.challenges.map(Self.repairedChallenge)
            todayChallengesLogger.debug("Loaded Today challenges from the local snapshot; count=\(self.challenges.count, privacy: .public).")
            if challenges != localSnapshot.challenges {
                save()
            } else {
                publishToCloud(localSnapshot)
            }
        } else if BibleData.books.isEmpty {
            // Reading challenges are drawn from the corpus, which loads asynchronously.
            // Creating them now would pick only from the small fallback corpus.
            createChallengesWhenCorpusLoads()
        } else {
            challenges = makeChallenges()
            todayChallengesLogger.notice("Generated a new Today challenge set; count=\(self.challenges.count, privacy: .public).")
            save()
        }
    }

    static func needsNewChallenges(snapshotDayKey: String, on date: Date) -> Bool {
        snapshotDayKey != GameStats.localDayKey(for: date)
    }

    private func createChallengesWhenCorpusLoads() {
        guard corpusWaitTask == nil else { return }
        corpusWaitTask = Task { [weak self] in
            _ = await BibleRepository.shared.loadAllBooks()
            guard let self else { return }
            corpusWaitTask = nil
            loadOrCreateForToday()
            syncCompletedReadingChallenges()
            syncGameProgress()
        }
    }

    private func updateChallenges(where shouldComplete: (TodayChallenge) -> Bool) {
        var didChange = false

        for index in challenges.indices where !challenges[index].isCompleted && shouldComplete(challenges[index]) {
            challenges[index].isCompleted = true
            didChange = true
        }

        if didChange {
            let completedCount = challenges.filter(\.isCompleted).count
            todayChallengesLogger.notice("Today challenge progress updated; completed=\(completedCount, privacy: .public).")
            save()
        }
    }

    private func save() {
        let snapshot = TodayChallengeSnapshot(
            dayKey: dayKey(for: Date()),
            challenges: challenges,
            lastModified: Date()
        )
        guard let data = try? JSONEncoder().encode(snapshot) else {
            todayChallengesLogger.error("Could not encode the Today challenge snapshot for local storage.")
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
        publishToCloud(snapshot)
    }

    private func snapshot(from data: Data?) -> TodayChallengeSnapshot? {
        guard let data else { return nil }
        return PersistedDecoding.decode(TodayChallengeSnapshot.self, from: data, name: "todayChallengeSnapshot")
    }

    private func persistLocally(lastModified: Date) {
        let snapshot = TodayChallengeSnapshot(
            dayKey: dayKey(for: Date()),
            challenges: challenges,
            lastModified: lastModified
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func publishToCloud(_ snapshot: TodayChallengeSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else {
            todayChallengesLogger.error("Could not encode the Today challenge snapshot for iCloud sync.")
            return
        }
        guard cloudStore.data(forKey: cloudStorageKey) != data else { return }
        cloudStore.set(data, forKey: cloudStorageKey)
        lastAppliedCloudSnapshot = snapshot
        todayChallengesLogger.debug("Published Today challenge snapshot to iCloud; count=\(snapshot.challenges.count, privacy: .public).")

        Task.detached {
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }

    func dayKey(for date: Date) -> String {
        GameStats.localDayKey(for: date)
    }

    static func repairedChallenge(_ challenge: TodayChallenge) -> TodayChallenge {
        var challenge = challenge

        switch challenge.kind {
        case .readChapter where challenge.title == "Read (book.name) (chapter)":
            if let bookName = challenge.bookName, let chapterNumber = challenge.chapterNumber {
                challenge = TodayChallenge(
                    id: challenge.id,
                    kind: challenge.kind,
                    title: "Read \(bookName) \(chapterNumber)",
                    detail: challenge.detail,
                    bookName: challenge.bookName,
                    chapterNumber: challenge.chapterNumber,
                    gameName: challenge.gameName,
                    minimumMinutes: challenge.minimumMinutes,
                    isCompleted: challenge.isCompleted
                )
            }
        case .playGame:
            if let gameName = challenge.gameName {
                challenge = TodayChallenge(
                    id: challenge.id,
                    kind: challenge.kind,
                    title: Self.gameChallengeTitle(for: gameName),
                    detail: challenge.detail,
                    bookName: challenge.bookName,
                    chapterNumber: challenge.chapterNumber,
                    gameName: GameStats.canonicalDisplayName(gameName),
                    minimumMinutes: challenge.minimumMinutes,
                    isCompleted: challenge.isCompleted
                )
            }
        case .prayerTimer where challenge.title == "Pray for (prayerMinutes) minutes":
            if let minimumMinutes = challenge.minimumMinutes {
                challenge = TodayChallenge(
                    id: challenge.id,
                    kind: challenge.kind,
                    title: "Pray for \(minimumMinutes) minutes",
                    detail: challenge.detail,
                    bookName: challenge.bookName,
                    chapterNumber: challenge.chapterNumber,
                    gameName: challenge.gameName,
                    minimumMinutes: challenge.minimumMinutes,
                    isCompleted: challenge.isCompleted
                )
            }
        default:
            break
        }

        return challenge
    }

}
