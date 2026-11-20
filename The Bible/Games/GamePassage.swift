import Foundation

/// The opening verses of a cited passage, for the games that show the verse behind a question
/// (Trivia's verse hint and answers, Countdown's round results).
struct GamePassage: Equatable, Sendable {
    struct Verse: Equatable, Sendable {
        let number: Int
        let text: String
    }

    let bookName: String
    let chapter: Int
    /// Up to three verses from the start of the reference.
    let verses: [Verse]
    /// True when the reference runs past the verses shown.
    let isTruncated: Bool

    /// "Genesis 6:13–15" for the verses shown.
    var title: String {
        guard let first = verses.first, let last = verses.last else { return "\(bookName) \(chapter)" }
        return first.number == last.number
            ? "\(bookName) \(chapter):\(first.number)"
            : "\(bookName) \(chapter):\(first.number)–\(last.number)"
    }

    /// The verses run together, each after its number.
    var text: String {
        verses.count == 1
            ? verses[0].text
            : verses.map { "\($0.number) \($0.text)" }.joined(separator: " ")
    }
}

extension GamePassage {
    /// Up to the first three verses of `reference`, in the reader's translation.
    static func load(for reference: String) async -> GamePassage? {
        // The reference parser matches against the loaded Bible's book names.
        _ = await BibleRepository.shared.loadAllBooks()
        guard let parsed = PassageReferenceParser.parse(reference) else { return nil }
        let start = parsed.startVerse ?? 1
        let lastVerse = parsed.isSingleChapter ? parsed.endVerse : nil
        let shownEnd = lastVerse.map { min($0, start + 2) } ?? start
        let scriptureRef = ScriptureRef(
            bookName: parsed.bookName,
            chapter: parsed.startChapter,
            startVerse: start,
            endVerse: shownEnd == start ? nil : shownEnd
        )
        guard let loaded = BibleReferenceLinker.loadVerses(for: scriptureRef) else { return nil }
        let verses = loaded.verses
            .filter { !$0.isOmitted }
            .map { GamePassage.Verse(number: $0.number, text: $0.text) }
        guard !verses.isEmpty else { return nil }
        let runsPastShown = !parsed.isSingleChapter || (lastVerse ?? start) > shownEnd || parsed.startVerse == nil
        return GamePassage(
            bookName: parsed.bookName,
            chapter: parsed.startChapter,
            verses: verses,
            isTruncated: runsPastShown
        )
    }
}
