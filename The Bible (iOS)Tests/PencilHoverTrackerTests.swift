import Foundation
import Testing
@testable import Bible

@MainActor
struct PencilHoverTrackerTests {
    @Test
    func selectsTheMostRecentlyHoveredRow() {
        let clock = PencilTestClock(Date(timeIntervalSinceReferenceDate: 1_000))
        let tracker = PencilHoverTracker<String>(grace: 1.5, now: { clock.date })

        tracker.hover("Genesis", isHovering: true)
        tracker.hover("Exodus", isHovering: true)

        #expect(tracker.target == "Exodus")
    }

    @Test
    func keepsTheLastHoveredRowDuringTheActionGracePeriod() {
        let clock = PencilTestClock(Date(timeIntervalSinceReferenceDate: 1_000))
        let tracker = PencilHoverTracker<String>(grace: 1.5, now: { clock.date })

        tracker.hover("Genesis", isHovering: true)
        tracker.hover("Genesis", isHovering: false)
        clock.date.addTimeInterval(1.49)

        #expect(tracker.target == "Genesis")
    }

    @Test
    func clearsTheLastHoveredRowAfterTheActionGracePeriod() {
        let clock = PencilTestClock(Date(timeIntervalSinceReferenceDate: 1_000))
        let tracker = PencilHoverTracker<String>(grace: 1.5, now: { clock.date })

        tracker.hover("Genesis", isHovering: true)
        tracker.hover("Genesis", isHovering: false)
        clock.date.addTimeInterval(1.5)

        #expect(tracker.target == nil)
    }
}

@MainActor
private final class PencilTestClock {
    var date: Date

    init(_ date: Date) {
        self.date = date
    }
}
