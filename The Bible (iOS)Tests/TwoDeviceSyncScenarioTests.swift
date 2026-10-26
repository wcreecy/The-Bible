import Foundation
import Testing
@testable import Bible

@MainActor
struct TwoDeviceSyncScenarioTests {
    private let gameEpoch = 42.0
    private let cutoff = "2025-01-01"

    private func gamePayload(
        epoch: Double,
        answered: Int,
        correct: Int,
        day: String = "2026-10-18"
    ) -> GameStatsLedger.Payload {
        GameStatsLedger.Payload(
            epoch: epoch,
            baseline: .init(),
            contributions: .init(
                counters: [
                    "quizAllTimeAnswered_all": answered,
                    "quizAllTimeCorrect_all": correct
                ],
                maps: [
                    "gamesDailyAnswered": [day: answered],
                    "gamesDailyCorrect": [day: correct]
                ]
            )
        )
    }

    @Test
    func concurrentGameRoundsFromTwoDevicesAreAddedExactlyOnce() {
        let phone = gamePayload(epoch: gameEpoch, answered: 4, correct: 3)
        let tablet = gamePayload(epoch: gameEpoch, answered: 5, correct: 4)

        let phoneThenTablet = GameStatsLedger.mergedTotals(
            payloads: [phone, tablet],
            epoch: gameEpoch,
            cutoff: cutoff
        )
        let tabletThenPhone = GameStatsLedger.mergedTotals(
            payloads: [tablet, phone],
            epoch: gameEpoch,
            cutoff: cutoff
        )

        #expect(phoneThenTablet == tabletThenPhone)
        #expect(phoneThenTablet.counters["quizAllTimeAnswered_all"] == 9)
        #expect(phoneThenTablet.counters["quizAllTimeCorrect_all"] == 7)
        #expect(phoneThenTablet.maps["gamesDailyAnswered"]?["2026-10-18"] == 9)
        #expect(phoneThenTablet.maps["gamesDailyCorrect"]?["2026-10-18"] == 7)
    }

    @Test
    func concurrentTriviaBookStatsFromTwoDevicesAreAddedExactlyOnce() {
        let day = "2026-10-18"
        let phone = GameStatsLedger.Payload(
            epoch: gameEpoch,
            baseline: .init(),
            contributions: .init(
                maps: [
                    "triviaPerBookAnsweredMap": ["John": 2],
                    "triviaPerBookCorrectMap": ["John": 1]
                ],
                nestedMaps: [
                    "triviaPerBookDailyAnswered": [day: ["John": 2]],
                    "triviaPerBookDailyCorrect": [day: ["John": 1]]
                ]
            )
        )
        let tablet = GameStatsLedger.Payload(
            epoch: gameEpoch,
            baseline: .init(),
            contributions: .init(
                maps: [
                    "triviaPerBookAnsweredMap": ["John": 3],
                    "triviaPerBookCorrectMap": ["John": 3]
                ],
                nestedMaps: [
                    "triviaPerBookDailyAnswered": [day: ["John": 3]],
                    "triviaPerBookDailyCorrect": [day: ["John": 3]]
                ]
            )
        )

        let totals = GameStatsLedger.mergedTotals(
            payloads: [phone, tablet],
            epoch: gameEpoch,
            cutoff: cutoff
        )

        #expect(GameStatsLedger.sumMapKeys.contains("triviaPerBookAnsweredMap"))
        #expect(GameStatsLedger.nestedMapKeys.contains("triviaPerBookDailyAnswered"))
        #expect(totals.maps["triviaPerBookAnsweredMap"]?["John"] == 5)
        #expect(totals.maps["triviaPerBookCorrectMap"]?["John"] == 4)
        #expect(totals.nestedMaps["triviaPerBookDailyAnswered"]?[day]?["John"] == 5)
        #expect(totals.nestedMaps["triviaPerBookDailyCorrect"]?[day]?["John"] == 4)
    }

    @Test
    func resetEpochExcludesStaleGamePayloadsFromAnOfflineDevice() {
        let preResetOfflinePhone = gamePayload(epoch: gameEpoch - 1, answered: 100, correct: 90)
        let postResetTablet = gamePayload(epoch: gameEpoch, answered: 2, correct: 2)

        let totals = GameStatsLedger.mergedTotals(
            payloads: [preResetOfflinePhone, postResetTablet],
            epoch: gameEpoch,
            cutoff: cutoff
        )

        #expect(totals.counters["quizAllTimeAnswered_all"] == 2)
        #expect(totals.counters["quizAllTimeCorrect_all"] == 2)
        #expect(totals.maps["gamesDailyAnswered"]?["2026-10-18"] == 2)
    }

    @Test
    func concurrentOfflineReadingEditsConvergeOnBothDevices() {
        let phone = ReadingHistoryArchive(
            cutoff: "2025-01-01",
            books: ["John": ["phone": 300]],
            years: ["2025": 300],
            streakRunAtCutoff: 4,
            bestStreak: 4
        )
        let tablet = ReadingHistoryArchive(
            cutoff: "2025-01-01",
            books: ["John": ["tablet": 180], "Acts": ["tablet": 120]],
            years: ["2025": 300],
            streakRunAtCutoff: 2,
            bestStreak: 5
        )

        var phoneContributions: ReadingHistoryArchive.Contributions = [:]
        var tabletContributions: ReadingHistoryArchive.Contributions = [:]
        let phoneAfterDelivery = ReadingHistoryArchive.merged(
            local: phone,
            remote: tablet,
            localContributions: &phoneContributions
        )
        let tabletAfterDelivery = ReadingHistoryArchive.merged(
            local: tablet,
            remote: phone,
            localContributions: &tabletContributions
        )

        #expect(phoneAfterDelivery == tabletAfterDelivery)
        #expect(phoneAfterDelivery.bookTotals == ["John": 480, "Acts": 120])
        // Year archives represent shared historical snapshots, so they merge by maximum
        // rather than summing the same history twice across devices.
        #expect(phoneAfterDelivery.years["2025"] == 300)
        #expect(phoneAfterDelivery.bestStreak == 5)
    }

    @Test
    func delayedInitialKVSDownloadDefersWritesUntilCloudMergeIsComplete() {
        let delayed = KVSSyncLifecyclePolicy.initialDownloadAction(
            bootstrapComplete: false,
            pendingKeys: ["readingSessions", "quizAllTimeAnswered_all"]
        )
        let establishedInstall = KVSSyncLifecyclePolicy.initialDownloadAction(
            bootstrapComplete: true,
            pendingKeys: ["readingSessions"]
        )
        let settledInstall = KVSSyncLifecyclePolicy.initialDownloadAction(
            bootstrapComplete: true,
            pendingKeys: []
        )

        #expect(delayed == .bootstrapLocalDifferences)
        #expect(establishedInstall == .flushPendingWrites)
        #expect(settledInstall == .mergeOnly)
    }

    @Test
    func accountChangeForcesRedownloadAndDropsQueuedWrites() {
        let plan = KVSSyncLifecyclePolicy.accountChangePlan()

        #expect(!plan.initialDownloadComplete)
        #expect(plan.pendingKeys.isEmpty)
        #expect(!plan.permitsBootstrap)
    }

    @Test
    func repeatedArchiveDeliveryIsIdempotent() {
        let phone = ReadingHistoryArchive(
            cutoff: "2025-01-01",
            books: ["John": ["phone": 300]],
            years: ["2025": 300],
            streakRunAtCutoff: 4,
            bestStreak: 4
        )
        let tablet = ReadingHistoryArchive(
            cutoff: "2025-01-01",
            books: ["Acts": ["tablet": 120]],
            years: ["2025": 300],
            streakRunAtCutoff: 2,
            bestStreak: 5
        )
        var contributions: ReadingHistoryArchive.Contributions = [:]

        let firstDelivery = ReadingHistoryArchive.merged(
            local: phone,
            remote: tablet,
            localContributions: &contributions
        )
        let duplicateDelivery = ReadingHistoryArchive.merged(
            local: firstDelivery,
            remote: tablet,
            localContributions: &contributions
        )

        #expect(duplicateDelivery == firstDelivery)
        #expect(duplicateDelivery.bookTotals == ["John": 300, "Acts": 120])
    }

    @Test
    func resetEpochOnlyAppliesOnceAndNeverForOlderCloudData() {
        #expect(KVSSyncLifecyclePolicy.shouldApplyReset(remoteEpoch: 100, lastSeenEpoch: 99))
        #expect(!KVSSyncLifecyclePolicy.shouldApplyReset(remoteEpoch: 100, lastSeenEpoch: 100))
        #expect(!KVSSyncLifecyclePolicy.shouldApplyReset(remoteEpoch: 99, lastSeenEpoch: 100))
        #expect(!KVSSyncLifecyclePolicy.shouldApplyReset(remoteEpoch: 0, lastSeenEpoch: -1))
    }
}
