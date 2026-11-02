import Foundation
import Testing
@testable import Bible

struct UserActivityIdleTests {
    private let base = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let timeout: TimeInterval = 300

    private func span(checkpoint: TimeInterval, now: TimeInterval, lastTouch: TimeInterval, activeSince: TimeInterval = -.infinity) -> UserActivityMonitor.CountedSpan {
        UserActivityMonitor.countedSpan(
            checkpoint: base.addingTimeInterval(checkpoint),
            now: base.addingTimeInterval(now),
            lastInteraction: base.addingTimeInterval(lastTouch),
            activeSince: activeSince.isFinite ? base.addingTimeInterval(activeSince) : .distantPast,
            timeout: timeout
        )
    }

    @Test
    func activeTimeCountsInFullAndKeepsTheFraction() {
        let result = span(checkpoint: 0, now: 15.6, lastTouch: 10)
        #expect(result.seconds == 15)
        #expect(result.start == base)
        #expect(result.nextCheckpoint == base.addingTimeInterval(15))
    }

    @Test
    func timeStopsCountingAtTheIdleLimit() {
        // Last touch at 100: only up to 400 counts, and the next measurement starts at now.
        let result = span(checkpoint: 390, now: 405, lastTouch: 100)
        #expect(result.seconds == 10)
        #expect(result.nextCheckpoint == base.addingTimeInterval(405))

        // Later measurements while still idle add nothing.
        let idle = span(checkpoint: 405, now: 420, lastTouch: 100)
        #expect(idle.seconds == 0)
        #expect(idle.nextCheckpoint == base.addingTimeInterval(420))
    }

    @Test
    func returningAfterIdleCountsFromTheReturningTouch() {
        // Idle measurements left the checkpoint at 990; the person touched again at 1000.
        let result = span(checkpoint: 990, now: 1_005, lastTouch: 1_000, activeSince: 1_000)
        #expect(result.start == base.addingTimeInterval(1_000))
        #expect(result.seconds == 5)
    }

    @MainActor
    @Test
    func touchesAfterTheIdleLimitStartANewActiveStretch() {
        let monitor = UserActivityMonitor.shared
        let start = monitor.lastInteraction.addingTimeInterval(1)
        monitor.recordInteraction(at: start)
        let sinceBefore = monitor.activeSince

        monitor.recordInteraction(at: start.addingTimeInterval(60))
        #expect(monitor.activeSince == sinceBefore)

        let returning = start.addingTimeInterval(60 + UserActivityMonitor.idleTimeout + 1)
        monitor.recordInteraction(at: returning)
        #expect(monitor.activeSince == returning)
        #expect(monitor.lastInteraction == returning)
    }

    @Test
    func studyTimeFromTwoDevicesAddsUpWithoutDoubleCounting() {
        let phone: StudyTimeTracker.Contributions = ["2026-11-02": ["phone": 120]]
        let iPad: StudyTimeTracker.Contributions = ["2026-11-02": ["ipad": 60], "2026-11-01": ["ipad": 30]]

        let merged = PrayerStatsStore.merged(phone, iPad)
        #expect(merged["2026-11-02"] == ["phone": 120, "ipad": 60])
        #expect(merged["2026-11-01"] == ["ipad": 30])

        // Merging again, or merging an older copy of one device, changes nothing.
        let older: StudyTimeTracker.Contributions = ["2026-11-02": ["phone": 90]]
        #expect(PrayerStatsStore.merged(merged, older) == merged)
        #expect(PrayerStatsStore.merged(merged, merged) == merged)
    }
}
