import Foundation

struct BibleName: Decodable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let firstReference: String

    enum CodingKeys: String, CodingKey {
        case name
        case firstReference = "first_reference"
    }
}

struct BibleLocation: Decodable, Identifiable, Hashable {
    var id: String { location }
    let location: String
    let firstReference: String

    enum CodingKeys: String, CodingKey {
        case location
        case firstReference = "first_reference"
    }
}

enum GameDataLoaders {
    static func loadNames() -> [BibleName] {
        loadArray([BibleName].self, resource: "biblenames")
    }

    static func loadLocations() -> [BibleLocation] {
        loadArray([BibleLocation].self, resource: "biblelocations")
    }

    private static func loadArray<T: Decodable>(_ type: T.Type, resource: String) -> T {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json") else {
            print("⚠️ \(resource).json not found in bundle.")
            return [] as! T
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            print("⚠️ Failed to decode \(resource).json: \(error)")
            return [] as! T
        }
    }
}
