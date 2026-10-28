import Foundation
import OSLog

private let gameDataLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "The Bible",
    category: "GameData"
)

struct BibleCharacter: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let books: [String]
    let shortDescription: String
    let difficulty: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case books
        case shortDescription = "short_description"
        case difficulty
    }

    func matchesDifficulty(_ selectedDifficulty: String) -> Bool {
        switch selectedDifficulty.lowercased() {
        case "easy":
            return difficulty.caseInsensitiveCompare("Easy") == .orderedSame
        case "normal", "medium":
            return difficulty.caseInsensitiveCompare("Medium") == .orderedSame
                || difficulty.caseInsensitiveCompare("Normal") == .orderedSame
        case "hard":
            return difficulty.caseInsensitiveCompare("Hard") == .orderedSame
        default:
            return true
        }
    }
}

struct BibleLocationChallenge: Decodable, Identifiable, Hashable {
    let id: Int
    let locationName: String
    let scriptureMentioned: String
    let shortDescription: String
    let difficulty: String

    enum CodingKeys: String, CodingKey {
        case id
        case locationName = "location_name"
        case scriptureMentioned = "scripture_mentioned"
        case shortDescription = "short_description"
        case difficulty
    }
}

/// A curated Who? question with six authored distractors. The game selects
/// three of those distractors at random for each round.
struct WhoGameQuestion: Decodable, Identifiable, Hashable {
    enum Mode: String, Decodable, Hashable {
        case personToFact = "person_to_fact"
        case factToPerson = "fact_to_person"
    }

    let id: String
    let mode: Mode
    let difficulty: String
    let question: String
    let correctAnswer: String
    let incorrectAnswers: [String]
    let reference: String
    let sourcePersonID: Int

    enum CodingKeys: String, CodingKey {
        case id
        case mode
        case difficulty
        case question
        case correctAnswer = "correct_answer"
        case incorrectAnswers = "incorrect_answers"
        case reference
        case sourcePersonID = "source_person_id"
    }
}

/// The editable source of truth for Who? and Hangman answers.
private struct GameAnswerCatalog: Decodable {
    private struct WhoGameCatalog: Decodable {
        let questions: [WhoGameQuestion]
    }

    private enum EntryType: String, Decodable {
        case person = "Person"
        case place = "Place"
    }

    private struct Entry: Decodable {
        let type: EntryType
        let id: Int
        let name: String
        let books: [String]?
        let scriptureMentioned: String?
        let shortDescription: String
        let difficulty: String

        enum CodingKeys: String, CodingKey {
            case type
            case id
            case name
            case books
            case scriptureMentioned = "scripture_mentioned"
            case shortDescription = "short_description"
            case difficulty
        }
    }

    private let entries: [Entry]
    private let whoGame: WhoGameCatalog?

    enum CodingKeys: String, CodingKey {
        case entries
        case whoGame = "who_game"
    }

    var characters: [BibleCharacter] {
        entries.compactMap { entry in
            guard entry.type == .person, let books = entry.books else { return nil }
            return BibleCharacter(
                id: entry.id,
                name: entry.name,
                books: books,
                shortDescription: entry.shortDescription,
                difficulty: entry.difficulty
            )
        }
    }

    var locations: [BibleLocationChallenge] {
        entries.compactMap { entry in
            guard entry.type == .place, let scriptureMentioned = entry.scriptureMentioned else {
                return nil
            }
            return BibleLocationChallenge(
                id: entry.id,
                locationName: entry.name,
                scriptureMentioned: scriptureMentioned,
                shortDescription: entry.shortDescription,
                difficulty: entry.difficulty
            )
        }
    }

    var whoQuestions: [WhoGameQuestion] {
        whoGame?.questions ?? []
    }
}

/// Holds the decoded catalog. The lock stays held while decoding, so callers that arrive
/// during a decode wait for it instead of starting their own. A failed load isn't kept,
/// so the next call tries again.
private nonisolated final class DecodedCatalogCache: @unchecked Sendable {
    private let lock = NSLock()
    private var decoded: GameAnswerCatalog?

    func catalog(load: () -> GameAnswerCatalog?) -> GameAnswerCatalog? {
        lock.lock()
        defer { lock.unlock() }
        if let decoded { return decoded }
        decoded = load()
        return decoded
    }
}

/// Keeps one load per catalog. Callers that ask while a load is running wait on that same
/// task, so the catalog is never decoded twice at once.
actor GameDataCache {
    static let shared = GameDataCache()
    private var loads: [String: Any] = [:]

    func load<T: Sendable>(_ key: String, _ work: @escaping @Sendable () async -> T) -> Task<T, Never> {
        if let existing = loads[key] as? Task<T, Never> { return existing }
        let task = Task { await work() }
        loads[key] = task
        return task
    }
}

enum GameDataLoaders {
    static func loadCharacters() -> [BibleCharacter] {
        guard let catalog = loadCatalog() else {
            gameDataLogger.error("The Who? and Hangman catalog could not be loaded or decoded.")
            return []
        }
        return catalog.characters
    }

    static func loadLocationChallenges() -> [BibleLocationChallenge] {
        guard let catalog = loadCatalog() else {
            gameDataLogger.error("The Who? and Hangman catalog could not be loaded or decoded.")
            return []
        }
        return catalog.locations
    }

    static func loadWhoQuestions() -> [WhoGameQuestion] {
        guard let catalog = loadCatalog() else {
            gameDataLogger.error("The Who? question catalog could not be loaded or decoded.")
            return []
        }
        return catalog.whoQuestions
    }

    /// Characters, places, and Who? questions all come from one file, so it is decoded once
    /// and shared rather than once per loader.
    private nonisolated static let catalogCache = DecodedCatalogCache()

    private static func loadCatalog() -> GameAnswerCatalog? {
        catalogCache.catalog {
            tryLoadArray(GameAnswerCatalog.self, resource: "WhoAndHangmanCatalog")
        }
    }

    static func loadCharactersAsync() async -> [BibleCharacter] {
        await GameDataCache.shared.load("characters") {
            await loadOffMainThread { loadCharacters() }
        }.value
    }

    static func loadLocationChallengesAsync() async -> [BibleLocationChallenge] {
        await GameDataCache.shared.load("locationChallenges") {
            await loadOffMainThread { loadLocationChallenges() }
        }.value
    }

    static func loadWhoQuestionsAsync() async -> [WhoGameQuestion] {
        await GameDataCache.shared.load("whoQuestions") {
            await loadOffMainThread { loadWhoQuestions() }
        }.value
    }

    private static func loadOffMainThread<T: Sendable>(_ work: @escaping () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: work())
            }
        }
    }

    // MARK: - JSON helper

    private static func tryLoadArray<T: Decodable>(_ type: T.Type, resource: String) -> T? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
            gameDataLogger.error("A game catalog resource is missing.")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            gameDataLogger.error("A game catalog could not be decoded. Error: \(String(describing: error), privacy: .public)")
            return nil
        }
    }
}
