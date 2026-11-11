import Foundation
import OSLog

private let todayChallengesLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "The Bible",
    category: "TodayChallenges"
)

struct TodayChallengeCatalog: Decodable {
    struct PrayerMinutes: Decodable {
        let minimum: Int
        let maximum: Int

        var range: ClosedRange<Int> {
            min(minimum, maximum)...max(minimum, maximum)
        }
    }

    struct ReflectionTask: Decodable {
        let title: String
        let detail: String
    }

    let gameNames: [String]
    let prayerMinutes: PrayerMinutes
    let prayerFocuses: [String]
    let reflectionTasks: [ReflectionTask]

    static func load() -> Self {
        guard let url = Bundle.main.url(forResource: "TodayChallengeCatalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = PersistedDecoding.decode(Self.self, from: data, name: "TodayChallengeCatalog.json"),
              !catalog.gameNames.isEmpty,
              !catalog.prayerFocuses.isEmpty,
              !catalog.reflectionTasks.isEmpty else {
            todayChallengesLogger.error("Today challenge catalog is missing, empty, or invalid; using the fallback catalog.")
            assertionFailure("TodayChallengeCatalog.json is missing or invalid.")
            return fallback
        }

        return catalog
    }

    private static let fallback = Self(
        gameNames: ["Quiz"],
        prayerMinutes: PrayerMinutes(minimum: 2, maximum: 20),
        prayerFocuses: ["peace"],
        reflectionTasks: [
            ReflectionTask(
                title: "Reflect on your blessings",
                detail: "Name three things you are grateful for."
            )
        ]
    )
}
