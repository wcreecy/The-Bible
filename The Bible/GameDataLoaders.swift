import Foundation

struct BibleName: Decodable, Identifiable, Hashable {
    var id: String { name }
    let name: String
    let firstReference: String?
    // NEW: description parsed from names.json plain-text blocks (lines 4+)
    let description: String?
    // NEW: full comma-separated references line from names.json (line 2)
    let referencesLine: String?

    enum CodingKeys: String, CodingKey {
        case name
        case firstReference = "first_reference"
        case description
        case referencesLine = "references" // optional if ever present in a JSON source
    }

    init(name: String, firstReference: String?, description: String? = nil, referencesLine: String? = nil) {
        self.name = name
        self.firstReference = firstReference
        self.description = description
        self.referencesLine = referencesLine
    }
}

struct BibleLocation: Decodable, Identifiable, Hashable {
    // Identity is the location name
    var id: String { location }

    // Required
    let location: String

    // NEW: full verses list and description from locations.json blocks
    let verses: [String]
    let description: String?

    // Back-compat: computed firstReference used by existing games
    var firstReference: String? { verses.first }

    // Back-compat decoding for legacy JSON arrays (which had only location + first_reference)
    // We accept either:
    // - { "location": "...", "first_reference": "Book X:Y" }
    // - or the new shape stored elsewhere; locations.json is parsed by our text parser.
    enum CodingKeys: String, CodingKey {
        case location
        case firstReference = "first_reference"
        case verses
        case description
    }

    init(location: String, verses: [String] = [], description: String? = nil) {
        self.location = location
        self.verses = verses
        self.description = description
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let loc = try container.decode(String.self, forKey: .location)

        // If legacy first_reference exists, use it as single verses[0]; else decode verses array if present; else empty.
        let legacyFirst = try container.decodeIfPresent(String.self, forKey: .firstReference)
        let decodedVerses = try container.decodeIfPresent([String].self, forKey: .verses)

        self.location = loc
        if let v = decodedVerses {
            self.verses = v.compactMap { s in
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                return t.isEmpty ? nil : t
            }
        } else if let legacy = legacyFirst?.trimmingCharacters(in: .whitespacesAndNewlines), !legacy.isEmpty {
            self.verses = [legacy]
        } else {
            self.verses = []
        }

        // Description is optional in all cases
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
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
        // Sole source: names.json (plain-text block format)
        if let fromNames = loadNamesFromNamesFile() {
            return fromNames
        }
        // If file missing or failed to parse, return empty (no legacy fallbacks)
        print("⚠️ names.json could not be loaded or parsed; returning empty names list.")
        return []
    }

    static func loadLocations() -> [BibleLocation] {
        // New preferred source: locations.json (plain-text blocks: name, verses, description)
        if let fromLocations = loadLocationsFromLocationsFile() {
            return fromLocations
        }
        // Legacy fallbacks (JSON arrays)
        if let first: [BibleLocation] = tryLoadArray([BibleLocation].self, resource: "biblelocations") {
            return first
        }
        if let fallback: [BibleLocation] = tryLoadArray([BibleLocation].self, resource: "bibleplaces") {
            return fallback
        }
        print("⚠️ Neither locations.json (blocks) nor biblelocations.json/bibleplaces.json could be loaded.")
        return []
    }

    static func loadNamesAsync() async -> [BibleName] {
        let cache = GameDataCache.shared
        if let cached = await cache.getNames() { return cached }
        // Load off the main thread; sole source is names.json
        let loaded: [BibleName] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if let fromNames = loadNamesFromNamesFile() {
                    continuation.resume(returning: fromNames)
                } else {
                    print("⚠️ names.json could not be loaded or parsed; returning empty names list.")
                    continuation.resume(returning: [])
                }
            }
        }
        await cache.setNames(loaded)
        return loaded
    }

    static func loadLocationsAsync() async -> [BibleLocation] {
        let cache = GameDataCache.shared
        if let cached = await cache.getLocations() { return cached }
        // Load off the main thread, trying new blocks file first, then legacy JSONs
        let loaded: [BibleLocation] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if let fromLocations = loadLocationsFromLocationsFile() {
                    continuation.resume(returning: fromLocations)
                } else if let first: [BibleLocation] = tryLoadArray([BibleLocation].self, resource: "biblelocations") {
                    continuation.resume(returning: first)
                } else if let fallback: [BibleLocation] = tryLoadArray([BibleLocation].self, resource: "bibleplaces") {
                    continuation.resume(returning: fallback)
                } else {
                    print("⚠️ Neither locations.json (blocks) nor biblelocations.json/bibleplaces.json could be loaded.")
                    continuation.resume(returning: [])
                }
            }
        }
        await cache.setLocations(loaded)
        return loaded
    }

    // MARK: - names.json (plain-text blocks) parser

    // Attempts to read and parse names.json as a text file with block entries:
    // Line 1: Name
    // Line 2: Comma-separated references
    // Line 3: Gender
    // Line 4+: Description (optional, captured)
    // Blank line separates entries.
    private static func loadNamesFromNamesFile() -> [BibleName]? {
        guard let url = Bundle.main.url(forResource: "names", withExtension: "json") else {
            print("⚠️ names.json not found in bundle.")
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            guard var text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
                print("⚠️ names.json: unable to decode text.")
                return nil
            }
            // Normalize newlines and strip BOM if present
            if text.hasPrefix("\u{feff}") { text.removeFirst() } // UTF-8 BOM
            text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")

            // Remove any leading header section (up to the first blank line), mirroring locations.json behavior
            let headerSplitLines = text.components(separatedBy: "\n")
            var idx = 0
            while idx < headerSplitLines.count && !headerSplitLines[idx].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                idx += 1
            }
            // Skip consecutive blank lines after header
            while idx < headerSplitLines.count && headerSplitLines[idx].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                idx += 1
            }
            let body = headerSplitLines.dropFirst(idx).joined(separator: "\n")

            // Split into blocks separated by 1+ blank lines
            let rawBlocks = body
                .components(separatedBy: CharacterSet.newlines)
                .split { line in line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { Array($0) }

            // Header tokens to ignore if they somehow slip through as a "name" line
            let headerBlacklist: Set<String> = [
                "name", "names",
                "bible verse(s)", "bible verses", "verses", "verse(s)",
                "gender",
                "description",
                "count",                 // NEW: ignore explicit Count column header
                "space (ignore)", "space", "ignore"
            ]

            // Helper: detect lines that look like a pure count (e.g., "12" or "1,234")
            func isCountLike(_ s: String) -> Bool {
                let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return false }
                // Only digits and commas
                for ch in t {
                    if ch != "," && !ch.isNumber { return false }
                }
                // At least one digit present
                return t.contains(where: { $0.isNumber })
            }

            // Each entry should be 3+ lines (name, references, gender, [description...])
            var out: [BibleName] = []
            for block in rawBlocks {
                // Join back contiguous lines to preserve multi-line descriptions if any
                let lines = block.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                // Keep empty lines out
                let nonEmpty = lines.filter { !$0.isEmpty }
                guard nonEmpty.count >= 3 else { continue }

                let name = nonEmpty[0]
                var referencesLine = nonEmpty[1]

                // Only include non-empty names and skip obvious header lines
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                let lowerName = trimmedName.lowercased()
                guard !trimmedName.isEmpty, !headerBlacklist.contains(lowerName) else { continue }

                // Normalize non-breaking / narrow spaces to regular spaces for the full references string
                for ch in ["\u{00A0}", "\u{202F}", "\u{2007}"] {
                    referencesLine = referencesLine.replacingOccurrences(of: ch, with: " ")
                }
                let fullRefs: String? = {
                    let t = referencesLine.trimmingCharacters(in: .whitespacesAndNewlines)
                    return t.isEmpty ? nil : t
                }()

                // Parse first reference from comma-separated references (if any)
                let firstRef: String? = {
                    let parts = referencesLine.split(separator: ",", omittingEmptySubsequences: true)
                    if let first = parts.first {
                        let trimmed = String(first).trimmingCharacters(in: .whitespacesAndNewlines)
                        return trimmed.isEmpty ? nil : trimmed
                    }
                    return nil
                }()

                // Description is from line 4 onward (index >= 3) if present.
                // Filter out placeholder/header-like tokens such as "space (ignore)" that may appear in the source,
                // and drop any lines that are just counts (e.g., "12" from a Count column).
                let desc: String? = {
                    guard nonEmpty.count >= 4 else { return nil }
                    let rest = nonEmpty.dropFirst(3)
                    let filtered = rest.filter { line in
                        let lower = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        // Exclude known headers and any pure count-like lines
                        return !lower.isEmpty && !headerBlacklist.contains(lower) && !isCountLike(line)
                    }
                    let joined = filtered.joined(separator: " ")
                    let t = joined.trimmingCharacters(in: .whitespacesAndNewlines)
                    return t.isEmpty ? nil : t
                }()

                out.append(BibleName(name: trimmedName, firstReference: firstRef, description: desc, referencesLine: fullRefs))
            }

            if out.isEmpty {
                print("⚠️ names.json parsed but produced no entries.")
                return nil
            }
            return out
        } catch {
            print("⚠️ Failed to read names.json: \(error)")
            return nil
        }
    }

    // MARK: - locations.json (plain-text blocks) parser

    // locations.json format (as provided):
    // Header lines:
    // Names
    // Bible Verse(s)
    // Description
    //
    // Then repeated entries separated by blank lines:
    // Line 1: Location name
    // Line 2: Comma-separated references
    // Line 3+: Description (optional; captured)
    private static func loadLocationsFromLocationsFile() -> [BibleLocation]? {
        guard let url = Bundle.main.url(forResource: "locations", withExtension: "json") else {
            return nil // Silent so legacy fallbacks can be attempted
        }
        do {
            let data = try Data(contentsOf: url)
            guard var text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16) else {
                print("⚠️ locations.json: unable to decode text.")
                return nil
            }
            // Strip BOM and normalize newlines
            if text.hasPrefix("\u{feff}") { text.removeFirst() }
            text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")

            // Remove any leading header section (up to the first blank line)
            let lines = text.components(separatedBy: "\n")
            var idx = 0
            while idx < lines.count && !lines[idx].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                idx += 1
            }
            // Skip consecutive blank lines after header
            while idx < lines.count && lines[idx].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                idx += 1
            }
            let body = lines.dropFirst(idx).joined(separator: "\n")

            // Split into blocks separated by 1+ blank lines
            let blocks = body
                .components(separatedBy: CharacterSet.newlines)
                .split { line in line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .map { Array($0) }

            var out: [BibleLocation] = []
            for block in blocks {
                // Trim each line
                let trimmed = block.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                guard trimmed.count >= 2 else { continue }
                let locName = trimmed[0]
                let versesLine = trimmed[1]

                // Parse full list of verses from comma-separated line
                let versesArr: [String] = versesLine
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                // Description is any remaining lines (3+), join with spaces to keep readable
                let desc: String? = {
                    guard trimmed.count >= 3 else { return nil }
                    let rest = trimmed.dropFirst(2)
                    let joined = rest.joined(separator: " ")
                    let t = joined.trimmingCharacters(in: .whitespacesAndNewlines)
                    return t.isEmpty ? nil : t
                }()

                let cleanName = locName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanName.isEmpty else { continue }
                out.append(BibleLocation(location: cleanName, verses: versesArr, description: desc))
            }

            if out.isEmpty {
                print("⚠️ locations.json parsed but produced no entries.")
                return nil
            }
            return out
        } catch {
            print("⚠️ Failed to read locations.json: \(error)")
            return nil
        }
    }

    // MARK: - Legacy JSON helpers (used for locations only)

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
