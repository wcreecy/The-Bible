import Foundation
import Testing
@testable import Bible

@MainActor
struct MissedGameQuestionStoreInitializationTests {
    @Test
    func migrationDefersPublishingUntilTheCoordinatorConsumesTheRequest() throws {
        let suiteName = "MissedGameQuestionStoreInitializationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let entry = MissedGameQuestionStore.Entry(
            id: UUID(),
            game: .bibleTrivia,
            bookNames: ["Genesis"],
            chapterNumber: 1,
            topic: "Creation",
            questionID: "legacy-question",
            date: Date()
        )
        defaults.set(try JSONEncoder().encode([entry]), forKey: MissedGameQuestionStore.storageKey)
        defaults.set(1, forKey: "missedGameQuestionHistory.triviaQuestionSetVersion")

        let store = MissedGameQuestionStore(defaults: defaults)

        #expect(store.needsMigrationPublish)
        #expect(store.cloudPayload().entries.first?.questionID == nil)
        #expect(store.takePendingMigrationPublish())
        #expect(!store.takePendingMigrationPublish())
    }

    @Test
    func currentStoreInitializationDoesNotRequestAPublish() throws {
        let suiteName = "MissedGameQuestionStoreInitializationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(3, forKey: "missedGameQuestionHistory.triviaQuestionSetVersion")

        let store = MissedGameQuestionStore(defaults: defaults)

        #expect(!store.needsMigrationPublish)
    }
}
