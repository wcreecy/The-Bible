import Foundation

enum QuizReversePool: String, CaseIterable, Identifiable {
    case wellKnown, favorites, any

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .wellKnown: "Well-known"
        case .favorites: "Favorites"
        case .any: "Any verse"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .wellKnown: "Popular passages"
        case .favorites: "Your saved verses"
        case .any: "Any eligible passage"
        }
    }

    var icon: String {
        switch self {
        case .wellKnown: "star.fill"
        case .favorites: "heart.fill"
        case .any: "shuffle"
        }
    }
}

/// A verse that can be asked or offered as a choice.
struct QuizVerse: Hashable {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String

    var reference: String { "\(bookName) \(chapterNumber):\(verseNumber)" }

    /// Lowercased letters only, so verses with the same words count as the same text.
    var normalizedText: String {
        verseText.lowercased().split { !$0.isLetter }.joined(separator: " ")
    }
}

/// The well-known verses shared with the lock-screen widget (`LockScreenVerses.json`).
private enum QuizWellKnownVerses {
    private struct Entry: Decodable {
        let book: String
        let chapter: Int
        let verse: Int
        let text: String
    }

    static func load() -> [QuizVerse] {
        guard let url = Bundle.main.url(forResource: "LockScreenVerses", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = PersistedDecoding.decode([Entry].self, from: data, name: "LockScreenVerses.json") else { return [] }
        // The file's text is KJV; the loaded Bible has the translation being read.
        let books = BibleData.books
        return entries.map { entry in
            let text = books.first { $0.name == entry.book }?
                .chapters.first { $0.number == entry.chapter }?
                .verses.first { $0.number == entry.verse }?
                .text
            return QuizVerse(
                bookName: entry.book,
                chapterNumber: entry.chapter,
                verseNumber: entry.verse,
                verseText: text.flatMap { $0.isEmpty ? nil : $0 } ?? entry.text
            )
        }
    }
}


/// Question data for Quiz's reverse mode. Game state and scoring live in QuizGameViewModel.
@MainActor
struct QuizReverseQuestionSource {
    static let maximumWords = 50
    static let questionsPerGame = QuizGameViewModel.questionsPerGame
    let difficulty: QuizDifficulty
    let pool: QuizReversePool
    let selectedSections: Set<QuizVerseSection>
    let favoriteVerses: [QuizVerse]
    private var wellKnownVerses: [QuizVerse] = []
    private var anyVersesByBook: [String: [QuizVerse]] = [:]
    private var poolBookNames: Set<String> { Set(selectedSections.flatMap(\.bookNames)) }

    mutating func prepare() {
        wellKnownVerses = QuizWellKnownVerses.load()
        anyVersesByBook = buildAnyVerses()
    }

    func reviewVerses() -> [QuizVerse] {
        uniqueByReference(wellKnownVerses + anyVersesByBook.values.flatMap { $0 } + favoriteVerses)
    }

    /// Saved verses within the chosen categories, without repeats.
    private var favoriteVersesInCategories: [QuizVerse] {
        let books = poolBookNames
        return uniqueByReference(favoriteVerses).filter { books.contains($0.bookName) }
    }

    /// The pool's own verses within the chosen categories, before any fill-in.
    private var preferredVerses: [QuizVerse] {
        let books = poolBookNames
        switch pool {
        case .wellKnown: return wellKnownVerses.filter { books.contains($0.bookName) }
        case .favorites: return favoriteVersesInCategories
        case .any: return []
        }
    }

    /// Whether the Favorites pool can be chosen: at least one saved verse is in the chosen
    /// categories. This doesn't depend on which pool is selected right now.
    var isFavoritesAvailable: Bool { !favoriteVersesInCategories.isEmpty }

    private func uniqueByReference(_ verses: [QuizVerse]) -> [QuizVerse] {
        var seen: Set<String> = []
        return verses.filter { seen.insert($0.reference).inserted }
    }

    /// Every fair verse, grouped by book: no lists, cross-book repeats, or very long verses.
    private func buildAnyVerses() -> [String: [QuizVerse]] {
        var result: [String: [QuizVerse]] = [:]
        for book in BibleData.books {
            result[book.name] = book.chapters.flatMap { chapter in
                chapter.verses.compactMap { verse -> QuizVerse? in
                    guard QuizVerseFilter.isQuizzable(book: book.name, chapter: chapter.number, verse: verse.number, difficulty: "normal"),
                          verse.text.split(separator: " ").count <= Self.maximumWords else { return nil }
                    return QuizVerse(bookName: book.name, chapterNumber: chapter.number,
                                           verseNumber: verse.number, verseText: verse.text)
                }
            }
        }
        return result
    }

    /// Verses to ask, drawn evenly across every verse rather than book by book.
    func buildQuestionBag() -> [QuizVerse] {
        let books = poolBookNames
        let anyVerses = anyVersesByBook.filter { books.contains($0.key) }.values.flatMap { $0 }
        switch pool {
        case .any:
            return anyVerses.shuffled()
        case .wellKnown, .favorites:
            let preferred = preferredVerses.shuffled()
            guard preferred.count < Self.questionsPerGame, pool == .wellKnown else { return preferred }
            // Few popular verses in these categories: top up with other verses, asked last.
            let used = Set(preferred.map(\.reference))
            let fill = anyVerses.filter { !used.contains($0.reference) }.shuffled()
                .prefix(Self.questionsPerGame - preferred.count)
            return Array(fill) + preferred
        }
    }

    /// Picks three wrong verses with different text, following the Quiz's rules for books:
    /// Easy uses other sections, Normal anywhere in your categories, Hard the same book.
    /// Verses from the chosen pool are tried before other verses.
    func wrongChoices(for target: QuizVerse) -> [QuizVerse] {
        let canon = BibleCanon.fallbackCanon
        let categories = poolBookNames
        let section = QuizVerseSection.containing(target.bookName)
        let isOld = section?.isOldTestament ?? true
        let sameTestament = canon.filter { QuizVerseSection.containing($0)?.isOldTestament == isOld }

        let bookTiers: [[String]]
        switch difficulty {
        case .easy:
            let otherSections = canon.filter { QuizVerseSection.containing($0) != section }
            bookTiers = [otherSections.filter(categories.contains), otherSections]
        case .normal:
            bookTiers = [canon.filter(categories.contains), sameTestament, canon]
        case .hard:
            // Fall back to the same section only if the book lacks three usable verses.
            let family = Set((section?.hardFamily ?? []).flatMap(\.bookNames))
            bookTiers = [[target.bookName], canon.filter(family.contains)]
        }
        let distinctBooks = difficulty != .hard
        let preferred = pool == .any ? [] : preferredVerses

        var picks: [QuizVerse] = []
        var usedTexts: Set<String> = [target.normalizedText]
        var usedBooks: Set<String> = distinctBooks ? [target.bookName] : []

        func add(_ verse: QuizVerse) {
            guard picks.count < 3, verse.reference != target.reference,
                  !usedBooks.contains(verse.bookName),
                  !usedTexts.contains(verse.normalizedText) else { return }
            usedTexts.insert(verse.normalizedText)
            if distinctBooks { usedBooks.insert(verse.bookName) }
            picks.append(verse)
        }

        for tier in bookTiers where picks.count < 3 {
            let tierBooks = Set(tier)
            for verse in preferred.shuffled() where tierBooks.contains(verse.bookName) {
                add(verse)
            }
            for book in tier.shuffled() where picks.count < 3 {
                let verses = anyVersesByBook[book] ?? []
                for verse in verses.shuffled().prefix(distinctBooks ? 3 : 30) {
                    add(verse)
                }
            }
        }
        return picks
    }
}
