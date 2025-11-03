import Foundation

struct BibleName: Decodable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let firstReference: String?

    enum CodingKeys: String, CodingKey {
        case name
        case firstReference = "first_reference"
    }
}

struct BibleLocation: Decodable, Identifiable, Hashable {
    var id: String { location }
    let location: String
    let firstReference: String?

    enum CodingKeys: String, CodingKey {
        case location
        case firstReference = "first_reference"
    }
}

actor GameDataCache {
    static let shared = GameDataCache()
    private var names: [BibleName]? = nil
    private var locations: [BibleLocation]? = nil

    func getNames() -> [BibleName]? { names }
    func setNames(_ v: [BibleName]) { names = v }

    func getLocations() -> [BibleLocation]? { locations }
    func setLocations(_ v: [BibleLocation]) { locations = v }
}

enum GameDataLoaders {
    static func loadNames() -> [BibleName] {
        return loadArray([BibleName].self, resource: "biblenames") ?? []
    }

    static func loadLocations() -> [BibleLocation] {
        if let first: [BibleLocation] = tryLoadArray([BibleLocation].self, resource: "biblelocations") {
            return first
        }
        if let fallback: [BibleLocation] = tryLoadArray([BibleLocation].self, resource: "bibleplaces") {
            return fallback
        }
        print("⚠️ Neither biblelocations.json nor bibleplaces.json could be loaded.")
        return []
    }

    static func loadNamesAsync() async -> [BibleName] {
        let cache = GameDataCache.shared
        if let cached = await cache.getNames() { return cached }
        // Load off the main thread
        let loaded: [BibleName] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let arr = loadArray([BibleName].self, resource: "biblenames") ?? []
                continuation.resume(returning: arr)
            }
        }
        await cache.setNames(loaded)
        return loaded
    }

    static func loadLocationsAsync() async -> [BibleLocation] {
        let cache = GameDataCache.shared
        if let cached = await cache.getLocations() { return cached }
        // Load off the main thread, trying primary then fallback
        let loaded: [BibleLocation] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if let first: [BibleLocation] = tryLoadArray([BibleLocation].self, resource: "biblelocations") {
                    continuation.resume(returning: first)
                } else if let fallback: [BibleLocation] = tryLoadArray([BibleLocation].self, resource: "bibleplaces") {
                    continuation.resume(returning: fallback)
                } else {
                    print("⚠️ Neither biblelocations.json nor bibleplaces.json could be loaded.")
                    continuation.resume(returning: [])
                }
            }
        }
        await cache.setLocations(loaded)
        return loaded
    }

    private static func loadArray<T: Decodable>(_ type: T.Type, resource: String) -> T? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
            print("⚠️ \(resource).json not found in bundle.")
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
