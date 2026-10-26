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

actor GameDataCache {
    static let shared = GameDataCache()
    private var characters: [BibleCharacter]? = nil
    private var locationChallenges: [BibleLocationChallenge]? = nil
    private var whoQuestions: [WhoGameQuestion]? = nil

    func getCharacters() -> [BibleCharacter]? { characters }
    func setCharacters(_ v: [BibleCharacter]) { characters = v }

    func getLocationChallenges() -> [BibleLocationChallenge]? { locationChallenges }
    func setLocationChallenges(_ v: [BibleLocationChallenge]) { locationChallenges = v }

    func getWhoQuestions() -> [WhoGameQuestion]? { whoQuestions }
    func setWhoQuestions(_ v: [WhoGameQuestion]) { whoQuestions = v }
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

    private static func loadCatalog() -> GameAnswerCatalog? {
        tryLoadArray(GameAnswerCatalog.self, resource: "WhoAndHangmanCatalog")
    }

    static func loadCharactersAsync() async -> [BibleCharacter] {
        let cache = GameDataCache.shared
        if let cached = await cache.getCharacters() { return cached }

        let loaded: [BibleCharacter] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: loadCharacters())
            }
        }
        await cache.setCharacters(loaded)
        return loaded
    }

    static func loadLocationChallengesAsync() async -> [BibleLocationChallenge] {
        let cache = GameDataCache.shared
        if let cached = await cache.getLocationChallenges() { return cached }

        let loaded: [BibleLocationChallenge] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: loadLocationChallenges())
            }
        }
        await cache.setLocationChallenges(loaded)
        return loaded
    }

    static func loadWhoQuestionsAsync() async -> [WhoGameQuestion] {
        let cache = GameDataCache.shared
        if let cached = await cache.getWhoQuestions() { return cached }

        let loaded: [WhoGameQuestion] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: loadWhoQuestions())
            }
        }
        await cache.setWhoQuestions(loaded)
        return loaded
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
