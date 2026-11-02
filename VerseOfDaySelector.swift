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

    private static let measurementWords: Set<String> = [
        "cubit", "cubits", "socket", "sockets", "board", "boards", "curtain", "curtains",
        "chapiter", "chapiters", "fillet", "fillets", "taches", "loops", "knops"
    ]

    static func select(from allBooks: [Book], scopeRaw: String, specificBook: String) -> Selection? {
        let scope = Scope(rawValue: scopeRaw) ?? .whole
        let books = books(in: scope, specificBook: specificBook, from: allBooks)

        var selected: Selection?
        var totalWeight = 0

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

                    totalWeight += weight
                    if Int.random(in: 0..<totalWeight) < weight {
                        selected = Selection(
                            bookName: book.name,
                            chapterNumber: chapter.number,
                            verseNumber: verse.number,
                            text: verse.text
                        )
                    }
                }
            }
        }

        return selected
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

        guard words.count >= 6, !trimmed.hasSuffix(":"), !trimmed.hasSuffix(";") else {
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

        if contextDependentOpenings.contains(where: lowercase.hasPrefix) {
            return words.count < 20 ? 1 : 3
        }

        switch words.count {
        case 6..<10:
            return 1
        case 10..<16:
            return 4
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
