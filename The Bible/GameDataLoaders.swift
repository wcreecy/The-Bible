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
        // 1) Try new text-formatted file first (even though extension is .json)
        if let fromNew = loadNamesFromNewFile() {
            return fromNew
        }
        // 2) Fall back to legacy biblenames.json (array of {name, first_reference})
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
                // Prefer new file; if not available, fall back to old JSON
                if let fromNew = loadNamesFromNewFile() {
                    continuation.resume(returning: fromNew)
                    return
                }
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

    // MARK: - New names file (plain-text blocks) parser

    // Attempts to read and parse newbiblenames.json as a text file with block entries:
    // Line 1: Name
    // Line 2: Comma-separated references
    // Line 3: Gender
    // Line 4+: Description (optional)
    // Blank line separates entries.
    private static func loadNamesFromNewFile() -> [BibleName]? {
        guard let url = Bundle.main.url(forResource: "newbiblenames", withExtension: "json") else {
            return nil // not present
        }
        do {
            let data = try Data(contentsOf: url)
            guard var text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
                print("⚠️ newbiblenames.json: unable to decode text.")
                return nil
            }
            // Normalize newlines and strip BOM if present
            if text.hasPrefix("\u{feff}") { text.removeFirst() } // UTF-8 BOM
            text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")

            // Split into blocks separated by 1+ blank lines
            let rawBlocks = text
                .components(separatedBy: CharacterSet.newlines)
                .split { line in line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { Array($0) }

            // Each entry should be 3+ lines (name, references, gender, [description...])
            var out: [BibleName] = []
            for block in rawBlocks {
                // Join back contiguous lines to preserve multi-line descriptions if any
                let lines = block.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                guard lines.count >= 3 else { continue }

                let name = lines[0]
                let referencesLine = lines[1]

                // Parse first reference from comma-separated references (if any)
                let firstRef: String? = {
                    let parts = referencesLine.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
                    if let first = parts.first {
                        let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? nil : trimmed
                    }
                    return nil
                }()

                // Only include non-empty names
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else { continue }

                out.append(BibleName(name: trimmedName, firstReference: firstRef))
            }

            if out.isEmpty {
                print("⚠️ newbiblenames.json parsed but produced no entries; falling back.")
                return nil
            }
            return out
        } catch {
            print("⚠️ Failed to read newbiblenames.json: \(error)")
            return nil
        }
    }

    // MARK: - Legacy JSON helpers

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
