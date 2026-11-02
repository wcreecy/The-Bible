import Foundation

/// Selects verses that read well on their own while preserving variety across the chosen scope.
/// The editorial ranges handle passages that text heuristics cannot identify reliably; the
/// remaining verses receive a weight based on how self-contained they appear to be.
nonisolated enum VerseOfDaySelector {
    enum Scope: String, Sendable {
        case old
        case new
        case whole
        case book
    }

    struct Selection: Sendable, Equatable {
        let bookName: String
        let chapterNumber: Int
        let verseNumber: Int
        let text: String

        /// Identifies the verse in the recent-history list.
        var historyKey: String { "\(bookName)|\(chapterNumber)|\(verseNumber)" }
    }

    /// The weighted verses of one scope. Scoring every verse in the Bible is slow, so it is done
    /// once; picking a verse from the result is a single random number and a binary search.
    struct Pool: Sendable {
        /// Identifies the scope the pool was built for; see `VerseOfDaySelector.poolKey`.
        let key: String
        private let entries: [Selection]
        /// Running total of the weights: `cumulativeWeights[i]` is the sum through `entries[i]`.
        private let cumulativeWeights: [Int]

        fileprivate init(key: String, entries: [Selection], cumulativeWeights: [Int]) {
            self.key = key
            self.entries = entries
            self.cumulativeWeights = cumulativeWeights
        }

        var count: Int { entries.count }

        /// A weighted random verse that `isExcluded` doesn't reject, or nil if it rejects them all.
        func pick(avoiding isExcluded: (Selection) -> Bool = { _ in false }) -> Selection? {
            guard let total = cumulativeWeights.last, total > 0 else { return nil }

            for _ in 0..<12 {
                let candidate = entries[firstIndex(above: Int.random(in: 0..<total))]
                if !isExcluded(candidate) { return candidate }
            }

            // Nearly everything is excluded (a small scope), so walk from a random start instead.
            let start = Int.random(in: 0..<entries.count)
            for offset in 0..<entries.count {
                let candidate = entries[(start + offset) % entries.count]
                if !isExcluded(candidate) { return candidate }
            }
            return nil
        }

        /// The first entry whose running total is above `target`.
        private func firstIndex(above target: Int) -> Int {
            var low = 0
            var high = cumulativeWeights.count - 1
            while low < high {
                let middle = (low + high) / 2
                if cumulativeWeights[middle] > target {
                    high = middle
                } else {
                    low = middle + 1
                }
            }
            return low
        }
    }

    /// The verses shown most recently, newest last, so a verse doesn't come back within days.
    /// It lives in the app group so the widget's refresh intent shares it with the app.
    enum History {
        static let capacity = 60
        private static let storageKey = "verseOfDayRecentVerses"

        static var defaults: UserDefaults {
            UserDefaults(suiteName: "group.bible.app") ?? .standard
        }

        static func recent(in defaults: UserDefaults = History.defaults) -> [String] {
            defaults.stringArray(forKey: storageKey) ?? []
        }

        static func record(_ selection: Selection, in defaults: UserDefaults = History.defaults) {
            var keys = recent(in: defaults).filter { $0 != selection.historyKey }
            keys.append(selection.historyKey)
            defaults.set(Array(keys.suffix(capacity)), forKey: storageKey)
        }
    }

    private struct Passage: Sendable {
        let bookName: String
        let chapterRange: ClosedRange<Int>
        let verseRange: ClosedRange<Int>?

        init(_ bookName: String, _ chapters: ClosedRange<Int>, verses: ClosedRange<Int>? = nil) {
            self.bookName = bookName
            self.chapterRange = chapters
            self.verseRange = verses
        }

        init(_ bookName: String, chapter: Int, verses: ClosedRange<Int>? = nil) {
            self.init(bookName, chapter...chapter, verses: verses)
        }

        func contains(bookName: String, chapter: Int, verse: Int) -> Bool {
            self.bookName == bookName
                && chapterRange.contains(chapter)
                && (verseRange?.contains(verse) ?? true)
        }
    }

    private static let oldTestamentBooks: Set<String> = [
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
        "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel",
        "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra",
        "Nehemiah", "Esther", "Job", "Psalms", "Proverbs",
        "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations",
        "Ezekiel", "Daniel", "Hosea", "Joel", "Amos", "Obadiah", "Jonah",
        "Micah", "Nahum", "Habakkuk", "Zephaniah", "Haggai", "Zechariah", "Malachi"
    ]

    // Reviewable, intentionally conservative exclusions for genealogies, census/name lists,
    // tribal boundaries, and sustained tabernacle/temple measurements.
    private static let editorialExclusions: [Passage] = [
        Passage("Genesis", chapter: 5),
        Passage("Genesis", chapter: 10),
        Passage("Genesis", chapter: 11, verses: 10...32),
        Passage("Genesis", chapter: 36),
        Passage("Genesis", chapter: 46, verses: 8...27),
        Passage("Exodus", chapter: 6, verses: 14...25),
        Passage("Exodus", 25...30),
        Passage("Exodus", 35...40),
        Passage("Numbers", 1...4),
        Passage("Numbers", chapter: 7),
        Passage("Numbers", chapter: 26),
        Passage("Numbers", chapter: 33),
        Passage("Joshua", chapter: 15, verses: 20...63),
        Passage("Joshua", chapter: 18, verses: 11...28),
        Passage("Joshua", chapter: 19),
        Passage("1 Kings", 6...7),
        Passage("1 Chronicles", 1...9),
        Passage("2 Chronicles", 3...4),
        Passage("Ezra", chapter: 2),
        Passage("Ezra", chapter: 8, verses: 1...14),
        Passage("Nehemiah", chapter: 7),
        Passage("Nehemiah", chapter: 10, verses: 1...27),
        Passage("Nehemiah", chapter: 11, verses: 3...36),
        Passage("Nehemiah", chapter: 12, verses: 1...26),
        Passage("Ezekiel", 40...48),
        Passage("Matthew", chapter: 1, verses: 1...17),
        Passage("Luke", chapter: 3, verses: 23...38)
    ]

    private static let contextDependentOpenings = [
        "and he said unto them",
        "and he said unto him",
        "and they said unto him",
        "and he answered and said",
        "then said he unto them",
        "and it came to pass",
        "and these are",
        "now these are",
        "these are the"
    ]

    private static let fragmentOpenings: Set<String> = [
        "and", "but", "then", "so", "now", "for", "also", "moreover", "therefore", "wherefore"
    ]

    private static let measurementWords: Set<String> = [
        "cubit", "cubits", "socket", "sockets", "board", "boards", "curtain", "curtains",
        "chapiter", "chapiters", "fillet", "fillets", "taches", "loops", "knops"
    ]

    /// Scans the whole scope for one verse. This is the slow path; `makePool` is for repeated picks.
    static func select(
        from allBooks: [Book],
        scopeRaw: String,
        specificBook: String,
        avoiding isExcluded: (Selection) -> Bool = { _ in false }
    ) -> Selection? {
        let scope = Scope(rawValue: scopeRaw) ?? .whole
        let books = books(in: scope, specificBook: specificBook, from: allBooks)

        var selected: Selection?
        var totalWeight = 0

        forEachWeightedVerse(in: books) { candidate, weight in
            guard !isExcluded(candidate) else { return }
            totalWeight += weight
            if Int.random(in: 0..<totalWeight) < weight {
                selected = candidate
            }
        }

        return selected
    }

    /// Scores every verse in the scope once, so later picks don't have to.
    static func makePool(from allBooks: [Book], scopeRaw: String, specificBook: String) -> Pool {
        let scope = Scope(rawValue: scopeRaw) ?? .whole
        let books = books(in: scope, specificBook: specificBook, from: allBooks)

        var entries: [Selection] = []
        var cumulativeWeights: [Int] = []
        var totalWeight = 0

        forEachWeightedVerse(in: books) { candidate, weight in
            totalWeight += weight
            entries.append(candidate)
            cumulativeWeights.append(totalWeight)
        }

        return Pool(
            key: poolKey(scopeRaw: scopeRaw, specificBook: specificBook),
            entries: entries,
            cumulativeWeights: cumulativeWeights
        )
    }

    /// Two settings give the same pool when they give the same key.
    static func poolKey(scopeRaw: String, specificBook: String) -> String {
        let scope = Scope(rawValue: scopeRaw) ?? .whole
        return scope == .book ? "book|\(specificBook)" : scope.rawValue
    }

    private static func forEachWeightedVerse(in books: [Book], _ body: (Selection, Int) -> Void) {
        for book in books {
            for chapter in book.chapters {
                for verse in chapter.verses {
                    let weight = suitabilityWeight(
                        bookName: book.name,
                        chapter: chapter.number,
                        verse: verse.number,
                        text: verse.text
                    )
                    guard weight > 0 else { continue }

                    body(
                        Selection(
                            bookName: book.name,
                            chapterNumber: chapter.number,
                            verseNumber: verse.number,
                            text: verse.text
                        ),
                        weight
                    )
                }
            }
        }
    }

    static func suitabilityWeight(bookName: String, chapter: Int, verse: Int, text: String) -> Int {
        if editorialExclusions.contains(where: {
            $0.contains(bookName: bookName, chapter: chapter, verse: verse)
        }) {
            return 0
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercase = trimmed.lowercased()
        let words = lowercase.split { !$0.isLetter }.map(String.init)

        guard words.count >= 3, !trimmed.hasSuffix(":"), !trimmed.hasSuffix(";") else {
            return 0
        }

        if lowercase.contains(" begat ")
            || lowercase.hasPrefix("the sons of ")
            || lowercase.hasPrefix("and the sons of ")
            || lowercase.hasPrefix("the children of ")
            || lowercase.hasPrefix("and the children of ") {
            return 0
        }

        let measurementCount = words.reduce(into: 0) { count, word in
            if measurementWords.contains(word) { count += 1 }
        }
        if measurementCount >= 2 { return 0 }

        // A very short line that opens with a connective is a fragment ("And he died."), not a
        // saying that stands alone like "Pray without ceasing."
        if words.count < 6, fragmentOpenings.contains(words[0]) { return 0 }

        if contextDependentOpenings.contains(where: lowercase.hasPrefix) {
            return words.count < 20 ? 1 : 3
        }

        // Length is a weak signal, so the curve is flat; context dependence is handled above.
        switch words.count {
        case 3..<6:
            return 4
        case 6..<10:
            return 5
        case 10..<16:
            return 6
        case 16...55:
            return 10
        case 56...75:
            return 6
        default:
            return 3
        }
    }

    private static func books(in scope: Scope, specificBook: String, from allBooks: [Book]) -> [Book] {
        switch scope {
        case .old:
            allBooks.filter { oldTestamentBooks.contains($0.name) }
        case .new:
            allBooks.filter { !oldTestamentBooks.contains($0.name) }
        case .whole:
            allBooks
        case .book:
            allBooks.first(where: { $0.name == specificBook }).map { [$0] } ?? allBooks
        }
    }
}
