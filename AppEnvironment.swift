import Foundation
import SwiftUI

/// The application-level dependency container.
///
/// Keep this container small and add capabilities to the service protocols only when a
/// feature is migrated away from direct singleton access.
@MainActor
struct AppEnvironment {
    let readingStatistics: any ReadingStatisticsStore
    let readingSessions: any ReadingSessionStore
    let gameStatistics: any GameStatisticsStore
    let cloudSync: any CloudSyncService
    let readingTimeTracker: any ReadingTimeTracking

    init(
        readingStatistics: any ReadingStatisticsStore,
        readingSessions: any ReadingSessionStore,
        gameStatistics: any GameStatisticsStore,
        cloudSync: any CloudSyncService,
        readingTimeTracker: any ReadingTimeTracking
    ) {
        self.readingStatistics = readingStatistics
        self.readingSessions = readingSessions
        self.gameStatistics = gameStatistics
        self.cloudSync = cloudSync
        self.readingTimeTracker = readingTimeTracker
    }

    static let live = AppEnvironment(
        readingStatistics: BibleStatsStore.shared,
        readingSessions: ReadingSessionsStore.shared,
        gameStatistics: GameStats.shared,
        cloudSync: iCloudSyncCoordinator.shared,
        readingTimeTracker: ReadingTimeTracker.shared
    )
}

extension EnvironmentValues {
    @Entry var appEnvironment: AppEnvironment = .live
}

extension View {
    func appEnvironment(_ environment: AppEnvironment) -> some View {
        self.environment(\.appEnvironment, environment)
    }
}

// MARK: - Reading

@MainActor
protocol ReadingStatisticsStore: AnyObject {
    func markVersesSeen(_ updates: Set<SeenVerseUpdate>, date: Date)
    func loadSeenVerses(bookName: String, chapter: Int) -> Set<Int>
    func markVisited(bookName: String, chapterNumber: Int)
    func saveLastRead(bookName: String, chapterNumber: Int, date: Date)
    func addReadingTime(bookName: String, seconds: Int, on date: Date, calendar: Calendar)
    func resetCaches()
}

extension BibleStatsStore: ReadingStatisticsStore {}

@MainActor
protocol ReadingSessionStore: AnyObject {
    func appendSession(_ session: ReadingSessionsStore.Session)
    func allSessions() -> [ReadingSessionsStore.Session]
    func sessions(
        inLastDays days: Int,
        now: Date,
        calendar: Calendar
    ) -> [ReadingSessionsStore.Session]
    func sessions(
        inMonthContaining date: Date,
        calendar: Calendar
    ) -> [ReadingSessionsStore.Session]
    func clearAll()
}

extension ReadingSessionsStore: ReadingSessionStore {}

@MainActor
protocol ReadingTimeTracking: AnyObject {
    var isPaused: Bool { get }

    func start(bookName: String, chapter: Int?)
    func changeBook(to bookName: String, chapter: Int?)
    func setCurrentLocation(bookName: String, chapter: Int)
    func stopAndFlush()
    func pause()
    func resume()
}

extension ReadingTimeTracker: ReadingTimeTracking {}

// MARK: - Games

@MainActor
protocol GameStatisticsStore: AnyObject {
    var version: Int { get }

    func snapshot() -> GameStats.Snapshot
    func breakdownSnapshot() -> GameStats.GameBreakdown
    func recordRound(
        game: GameStats.GameID,
        difficulty: GameStats.Difficulty,
        correct: Int,
        answered: Int,
        currentBestStreak: Int
    )
}

extension GameStats: GameStatisticsStore {}

// MARK: - Synchronization

@MainActor
protocol CloudSyncService: AnyObject {
    func start()
    func refreshNow()
    func pushKey(_ key: String)
    func pushAllNow(completion: (() -> Void)?)
}

extension iCloudSyncCoordinator: CloudSyncService {}
