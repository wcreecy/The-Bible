import Foundation
import OSLog

/// A named topic, event, or teaching ("Lord's Prayer", "Great Tribulation") and the passages
/// it refers to, from the bundled `BibleTerms.json`.
nonisolated struct BibleTerm: Identifiable, Hashable, Sendable, Decodable {
    struct Reference: Hashable, Sendable, Decodable {
        /// A passage such as "Matthew 6:9-13".
        let reference: String
        /// "primary" for the main passage, "related" for supporting ones.
        let type: String
    }

    let id: String
    let term: String
    let category: String
    let description: String
    let aliases: [String]
    let references: [Reference]
}

extension BibleTerm {
    /// The passage a tap opens: the first primary reference ("Matthew 6:9-13" for the
    /// Lord's Prayer), or the first reference when none is marked primary.
    @MainActor var primaryPassage: PassageReference? {
        let primary = references.first { $0.type == "primary" } ?? references.first
        return primary.flatMap { PassageReferenceParser.parse($0.reference) }
    }

    /// Every reference that names a real passage, in the catalog's order.
    @MainActor var passages: [PassageReference] {
        var seen = Set<String>()
        return references
            .compactMap { PassageReferenceParser.parse($0.reference) }
            .filter { seen.insert($0.id).inserted }
    }
}

/// Finds Bible terms by their name or a common alias. Matching ignores case, accents,
/// apostrophes, punctuation, and a leading "the", so "lords prayer", "Lord’s Prayer", and
/// "the lord's prayer" all find the same entry.
actor BibleTermSearch {
    static let shared = BibleTermSearch()

    private lazy var index: [BibleTermMatcher.IndexedTerm] = BibleTermMatcher.loadIndex()

    /// Terms matching `query`, best match first.
    func matches(for query: String) -> [BibleTerm] {
        BibleTermMatcher.matches(for: query, in: index)
    }
}

nonisolated enum BibleTermMatcher {
    struct IndexedTerm: Sendable {
        struct Name: Sendable {
            let normalized: String
            let words: [String]
            let isTitle: Bool
        }

        let term: BibleTerm
        let names: [Name]
    }

    /// Shorter queries ("lo", "g") would match most of the catalog by prefix.
    static let minimumQueryLength = 3

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "The Bible",
        category: "BibleTerms"
    )

    private struct Catalog: Decodable {
        let entries: [BibleTerm]
    }

    static func loadIndex(bundle: Bundle = .main) -> [IndexedTerm] {
        index(loadTerms(bundle: bundle))
    }

    /// Every term in `BibleTerms.json`, in catalog order.
    static func loadTerms(bundle: Bundle = .main) -> [BibleTerm] {
        guard let url = bundle.url(forResource: "BibleTerms", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = PersistedDecoding.decode(Catalog.self, from: data, name: "BibleTerms.json") else {
            logger.error("BibleTerms.json is missing or invalid; topic search is unavailable.")
            assertionFailure("BibleTerms.json is missing or invalid.")
            return []
        }
        return catalog.entries
    }

    static func index(_ terms: [BibleTerm]) -> [IndexedTerm] {
        terms.map { term in
            let names = ([term.term] + term.aliases).enumerated().map { offset, name in
                let normalized = normalized(name)
                return IndexedTerm.Name(
                    normalized: normalized,
                    words: normalized.split(separator: " ").map(String.init),
                    isTitle: offset == 0
                )
            }
            return IndexedTerm(term: term, names: names)
        }
    }

    /// Lowercased, accent-free words separated by single spaces. Apostrophes are removed
    /// rather than split on, so "Lord's" becomes "lords", and a leading "the" is dropped.
    static func normalized(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        var cleaned = ""
        cleaned.reserveCapacity(folded.count)
        for character in folded where !apostrophes.contains(character) {
            cleaned.append(character.isLetter || character.isNumber ? character : " ")
        }
        var words = cleaned.split(separator: " ")
        if words.count > 1, words.first == "the" {
            words.removeFirst()
        }
        return words.joined(separator: " ")
    }

    /// Words that carry no meaning in a topic query and shouldn't have to appear in a name.
    private static let fillerWords: Set<String> = [
        "a", "an", "and", "at", "by", "for", "from", "in", "of", "on", "the", "to", "with"
    ]

    private static let apostrophes: Set<Character> = ["'", "’", "‘", "ʼ", "`"]

    /// Whether `query` is exactly the term's title or one of its aliases, ignoring the same
    /// differences matching does.
    static func isExactMatch(_ term: BibleTerm, for query: String) -> Bool {
        let query = normalized(query)
        return ([term.term] + term.aliases).contains { normalized($0) == query }
    }

    /// How closely a name matches the query; lower is better.
    private enum Rank: Int, Comparable {
        case exactTitle, exactAlias, namePrefix, allWords

        static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    static func matches(for query: String, in index: [IndexedTerm]) -> [BibleTerm] {
        let query = normalized(query)
        guard query.count >= minimumQueryLength else { return [] }
        // Filler words are ignored so "paul in athens" finds "Paul at the Areopagus". A query
        // made only of filler words keeps them rather than matching everything.
        let allQueryWords = query.split(separator: " ")
        let significantWords = allQueryWords.filter { !fillerWords.contains(String($0)) }
        let queryWords = significantWords.isEmpty ? allQueryWords : significantWords

        var ranked: [(rank: Rank, nameLength: Int, order: Int, term: BibleTerm)] = []
        for (order, entry) in index.enumerated() {
            var best: (rank: Rank, nameLength: Int)?
            for name in entry.names {
                let rank: Rank
                if name.normalized == query {
                    rank = name.isTitle ? .exactTitle : .exactAlias
                } else if name.normalized.hasPrefix(query) {
                    rank = .namePrefix
                } else if queryWords.allSatisfy({ queryWord in
                    name.words.contains { $0.hasPrefix(queryWord) }
                }) {
                    rank = .allWords
                } else {
                    continue
                }
                let candidate = (rank, name.normalized.count)
                if best.map({ candidate < $0 }) ?? true {
                    best = candidate
                }
            }
            if let best {
                ranked.append((best.rank, best.nameLength, order, entry.term))
            }
        }

        // Best rank first; among equals, the shortest matching name is the most specific.
        return ranked
            .sorted { ($0.rank, $0.nameLength, $0.order) < ($1.rank, $1.nameLength, $1.order) }
            .map(\.term)
    }

    /// Keeps a topic visible when at least one of its references belongs to the requested scope.
    /// A nil set means the search covers the whole Bible.
    static func filtered(_ terms: [BibleTerm], to allowedBookNames: Set<String>?) -> [BibleTerm] {
        guard let allowedBookNames else { return terms }
        return terms.filter { term in
            term.references.contains { reference in
                allowedBookNames.contains { bookName in
                    reference.reference == bookName
                        || reference.reference.hasPrefix(bookName + " ")
                }
            }
        }
    }
}
