import Foundation
import Testing
@testable import Bible

struct MindfulMinutesTrackingTests {
    @Test(arguments: [
        (false, false, false),
        (false, true, false),
        (true, false, false),
        (true, true, true)
    ])
    func trackingRequiresTheSettingAndHealthAuthorization(
        isEnabled: Bool,
        isAuthorized: Bool,
        expected: Bool
    ) {
        #expect(
            MindfulMinutesSessionCoordinator.shouldTrack(
                isEnabled: isEnabled,
                isAuthorized: isAuthorized
            ) == expected
        )
    }

    @Test
    func singleSourceClosesItsMindfulSessionWhenActivityEnds() {
        var coordinator = MindfulMinutesSessionCoordinator()
        let start = Date(timeIntervalSince1970: 1_000)
        let end = start.addingTimeInterval(90)

        coordinator.start(.bibleTab, at: start)
        let session = coordinator.stop(.bibleTab, at: end)

        #expect(session?.start == start)
        #expect(session?.end == end)
    }

    @Test
    func overlappingSourcesProduceOneCombinedSession() {
        var coordinator = MindfulMinutesSessionCoordinator()
        let start = Date(timeIntervalSince1970: 2_000)
        let gameStart = start.addingTimeInterval(15)
        let bibleEnd = start.addingTimeInterval(30)
        let gameEnd = start.addingTimeInterval(60)

        coordinator.start(.bibleTab, at: start)
        coordinator.start(.game, at: gameStart)

        #expect(coordinator.stop(.bibleTab, at: bibleEnd) == nil)
        let session = coordinator.stop(.game, at: gameEnd)

        #expect(session?.start == start)
        #expect(session?.end == gameEnd)
    }

    @Test
    func repeatedSourceStartDoesNotRestartTheSession() {
        var coordinator = MindfulMinutesSessionCoordinator()
        let start = Date(timeIntervalSince1970: 3_000)
        let repeatedStart = start.addingTimeInterval(30)
        let end = start.addingTimeInterval(60)

        coordinator.start(.prayerTimer, at: start)
        coordinator.start(.prayerTimer, at: repeatedStart)
        let session = coordinator.stop(.prayerTimer, at: end)

        #expect(session?.start == start)
        #expect(session?.end == end)
    }
}
