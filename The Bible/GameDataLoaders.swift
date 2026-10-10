import Foundation

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

actor GameDataCache {
    static let shared = GameDataCache()
    private var characters: [BibleCharacter]? = nil
    private var locationChallenges: [BibleLocationChallenge]? = nil

    func getCharacters() -> [BibleCharacter]? { characters }
    func setCharacters(_ v: [BibleCharacter]) { characters = v }

    func getLocationChallenges() -> [BibleLocationChallenge]? { locationChallenges }
    func setLocationChallenges(_ v: [BibleLocationChallenge]) { locationChallenges = v }
}

enum GameDataLoaders {
    static func loadCharacters() -> [BibleCharacter] {
        if let characters: [BibleCharacter] = tryLoadArray(
            [BibleCharacter].self,
            resource: "Bible_Characters_Game_Clues_With_Difficulty"
        ) {
            return characters
        }
        print("⚠️ Bible_Characters_Game_Clues_With_Difficulty.json could not be loaded or decoded.")
        return []
    }

    static func loadLocationChallenges() -> [BibleLocationChallenge] {
        if let locations: [BibleLocationChallenge] = tryLoadArray(
            [BibleLocationChallenge].self,
            resource: "bible_locations"
        ) {
            return locations
        }
        print("⚠️ bible_locations.json could not be loaded or decoded.")
        return []
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

    // MARK: - JSON helper

    private static func tryLoadArray<T: Decodable>(_ type: T.Type, resource: String) -> T? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            print("⚠️ Failed to decode \(resource).json: \(error)")
            return nil
        }
    }
}
