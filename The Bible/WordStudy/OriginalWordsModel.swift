import SwiftUI

/// Loads the Hebrew or Greek words of one verse and steps through the verses around it.
@MainActor
@Observable
final class OriginalWordsModel {
    let bookName: String
    let translation: BibleTranslation
    private(set) var chapter: Int
    private(set) var verse: Int
    private(set) var words: [OriginalWord] = []
    private(set) var isLoading = true
    /// How often each word is used, by Strong's number, once looked up.
    private(set) var usage: [String: OriginalWordUsage] = [:]
    /// Who each name in the current verse is, by Strong's number and verse, once looked up.
    private(set) var names: [String: [OriginalName]] = [:]

    init(bookName: String, chapter: Int, verse: Int, translation: BibleTranslation) {
        self.bookName = bookName
        self.chapter = chapter
        self.verse = verse
        self.translation = translation
    }

    var language: OriginalLanguage {
        Canon.isOld(bookName) ? .hebrew : .greek
    }

    func load() async {
        isLoading = true
        // The reader has the Bible loaded already; this matters only when the sheet opens first.
        if BibleRepository.shared.cachedBooks.isEmpty {
            _ = await BibleRepository.shared.loadAllBooks()
        }
        words = await OriginalWordsRepository.shared.words(
            bookName: bookName,
            chapter: chapter,
            verse: verse,
            translation: translation
        )
        isLoading = false
    }

    /// Looks up how often a word is used, once. Words without a Strong's number have no count.
    func loadUsage(for word: OriginalWord) async {
        guard let strongs = word.strongsNumber, usage[strongs] == nil else { return }
        usage[strongs] = await OriginalWordsRepository.shared.usage(of: strongs, translation: translation)
    }

    /// Looks up who a name is in this verse, once. Most words aren't names and have none.
    func loadNames(for word: OriginalWord) async {
        guard let strongs = word.strongsNumber, names[nameKey(strongs)] == nil else { return }
        names[nameKey(strongs)] = await OriginalWordsRepository.shared.names(
            forStrongs: strongs,
            in: VerseLocation(bookName: bookName, chapter: chapter, verse: verse)
        )
    }

    /// Who the word is, if it's a name here: usually one person or place; several when the
    /// verse names more than one with the same number.
    func names(for word: OriginalWord) -> [OriginalName] {
        word.strongsNumber.flatMap { names[nameKey($0)] } ?? []
    }

    private func nameKey(_ strongs: String) -> String {
        "\(strongs)|\(chapter):\(verse)"
    }

    /// The English verse shown above the words: in the verse's own translation when it's in
    /// memory, otherwise in the reader's.
    var englishVerse: (text: String, translation: BibleTranslation)? {
        Self.verseText(
            VerseLocation(bookName: bookName, chapter: chapter, verse: verse),
            preferring: translation
        )
    }

    /// A verse's text in `translation` if it's in memory, otherwise in the reader's translation.
    static func verseText(
        _ location: VerseLocation,
        preferring translation: BibleTranslation
    ) -> (text: String, translation: BibleTranslation)? {
        let repository = BibleRepository.shared
        for candidate in [translation, repository.activeTranslation] {
            let match = repository.cachedBooks(for: candidate)
                .first { $0.name == location.bookName }?
                .chapters.first { $0.number == location.chapter }?
                .verses.first { $0.number == location.verse }
            if let match, !match.isOmitted {
                return (match.text, candidate)
            }
        }
        return nil
    }

    // MARK: Stepping

    /// The chapter and verse counts of the KJV's order, which every translation here follows.
    private var chapterVerseCounts: [Int] {
        BibleRepository.shared.cachedBooks
            .first { $0.name == bookName }?
            .chapters.map(\.verses.count) ?? []
    }

    var canStepBack: Bool { verse > 1 || chapter > 1 }

    var canStepForward: Bool {
        let counts = chapterVerseCounts
        guard chapter <= counts.count else { return false }
        return verse < counts[chapter - 1] || chapter < counts.count
    }

    func stepBack() {
        if verse > 1 {
            verse -= 1
        } else if chapter > 1 {
            chapter -= 1
            let counts = chapterVerseCounts
            verse = chapter <= counts.count ? max(counts[chapter - 1], 1) : 1
        }
    }

    func stepForward() {
        let counts = chapterVerseCounts
        guard chapter <= counts.count else { return }
        if verse < counts[chapter - 1] {
            verse += 1
        } else if chapter < counts.count {
            chapter += 1
            verse = 1
        }
    }
}
