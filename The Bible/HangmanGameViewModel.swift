import Foundation
import Observation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum HangmanTheme: String, CaseIterable, Identifiable {
    // Raw values are stored in settings and per-category stats.
    case all = "All"
    case people = "People"
    case places = "Places"
    case books = "Books"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .all: "Mixed"
        case .people: "People"
        case .places: "Places"
        case .books: "Books"
        }
    }

    var systemImage: String {
        switch self {
        case .people: "person.fill"
        case .places: "mappin.and.ellipse"
        case .books: "book.fill"
        case .all: "square.grid.2x2.fill"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .all: "People, places, and books"
        case .people: "Bible people"
        case .places: "Bible places"
        case .books: "Books of the Bible"
        }
    }
}

enum HangmanDifficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case normal = "Normal"   // was Medium
    case hard = "Hard"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }

    var maxWrong: Int {
        switch self {
        case .easy: 8
        case .normal: 6
        case .hard: 5
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .easy: "Well-known names, 8 mistakes, and a clue for every word."
        case .normal: "Adds less familiar names and allows 6 mistakes. A clue costs one mistake."
        case .hard: "Every name in the game, 5 mistakes, and no clues."
        }
    }

    var clueSummary: String {
        switch self {
        case .easy: String(localized: "Shown")
        case .normal: String(localized: "−1 mistake")
        case .hard: String(localized: "None")
        }
    }

    var statsDifficulty: GameStats.Difficulty {
        switch self {
        case .easy: .easy
        case .normal: .medium
        case .hard: .hard
        }
    }

    var experienceLevel: GameExperienceLevel {
        switch self {
        case .easy: .learn
        case .normal: .standard
        case .hard: .challenge
        }
    }

    init(experienceLevel: GameExperienceLevel) {
        self = switch experienceLevel {
        case .learn: .easy
        case .standard: .normal
        case .challenge: .hard
        }
    }

    /// Easy uses easy entries, Normal adds medium ones, and Hard uses everything.
    func includes(_ entryDifficulty: String) -> Bool {
        switch entryDifficulty.lowercased() {
        case "easy": true
        case "medium", "normal": self != .easy
        default: self == .hard
        }
    }
}

/// One puzzle: the name to guess plus what's revealed about it.
struct HangmanWord {
    let answer: String
    let category: HangmanTheme
    let clue: String
    /// The description in parentheses in the data, e.g. "son of Jacob". Not part of the puzzle.
    let qualifier: String?
    let reference: String?
}

@MainActor
@Observable
final class HangmanGameViewModel {
    enum Phase {
        case setup
        case playing
        case results
    }

    static let wordsPerGame = 10

    private static let themeKey = AppStorageKey.hangmanTheme
    private static let difficultyKey = AppStorageKey.hangmanDifficulty

    // MARK: - Settings

    var theme: HangmanTheme = HangmanTheme(
        rawValue: UserDefaults.standard.string(forKey: HangmanGameViewModel.themeKey) ?? ""
    ) ?? .all {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.themeKey) }
    }

    var difficulty: HangmanDifficulty = HangmanDifficulty(
        rawValue: UserDefaults.standard.string(forKey: HangmanGameViewModel.difficultyKey) ?? ""
    ) ?? .normal {
        didSet {
            UserDefaults.standard.set(difficulty.rawValue, forKey: Self.difficultyKey)
            session.syncSavedBest(from: persistentStreak)
        }
    }

    var experienceLevel: GameExperienceLevel {
        get { difficulty.experienceLevel }
        set { difficulty = HangmanDifficulty(experienceLevel: newValue) }
    }

    // MARK: - Data

    private var loadedPeople: [BibleCharacter] = []
    private var loadedPlaces: [BibleLocationChallenge] = []
    private var deck: [HangmanWord] = []

    // MARK: - Game state

    private(set) var phase: Phase = .setup
    private(set) var current: HangmanWord?
    private(set) var wordNumber = 0
    private(set) var totalWords = 0

    // Round
    private(set) var guessedLetters: Set<Character> = []
    private(set) var wrongGuesses = 0
    private(set) var clueRevealed = false
    private(set) var roundOver = false
    private(set) var didWin = false

    /// Score, streaks and best game; see `GameScore` for the rules.
    private(set) var session = GameScore()

    // MARK: - Derived state

    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "hangman", variant: difficulty.rawValue.lowercased())
    }

    private var bestGameScoreKey: String { "hangmanBestGameScore_\(difficulty.rawValue.lowercased())" }

    var isDataLoaded: Bool { !loadedPeople.isEmpty && !loadedPlaces.isEmpty }

    var maxWrong: Int { difficulty.maxWrong }

    private var answerLetters: Set<Character> {
        Set((current?.answer ?? "").uppercased().filter(\.isLetter))
    }

    var correctLetters: Set<Character> { guessedLetters.intersection(answerLetters) }
    var wrongLetters: Set<Character> { guessedLetters.subtracting(answerLetters) }

    var isLastWord: Bool { deck.isEmpty }

    var canRevealClue: Bool {
        difficulty == .normal && !clueRevealed && !roundOver && wrongGuesses < maxWrong - 1
    }

    var showsClue: Bool {
        difficulty == .easy || clueRevealed || roundOver
    }

    /// Letters found so far, with blanks for the rest; spaces and punctuation always show.
    private var displayWord: String {
        String((current?.answer ?? "").map { ch in
            guard ch.isLetter else { return ch }
            let upper = Character(String(ch).uppercased())
            return roundOver || guessedLetters.contains(upper) ? upper : "_"
        })
    }

    var spacedDisplayWord: String {
        displayWord.map { String($0) }.joined(separator: " ")
    }

    /// What VoiceOver reads for the word, e.g. "J, blank, S, blank".
    var spokenDisplayWord: String {
        let blank = String(localized: "blank")
        return displayWord.map { $0 == "_" ? blank : String($0) }.joined(separator: ", ")
    }

    // MARK: - Lifecycle

    func onAppear() {
        session.syncSavedBest(from: persistentStreak)
    }

    func onDisappear() {
        // Leaving after answering begins a new game on return.
        if phase != .setup && session.answered > 0 {
            resetToSetup()
        }
        session.clearStreak()
    }

    func loadData() async {
        if loadedPeople.isEmpty { loadedPeople = await GameDataLoaders.loadCharactersAsync() }
        if loadedPlaces.isEmpty { loadedPlaces = await GameDataLoaders.loadLocationChallengesAsync() }
    }

    // MARK: - Words

    /// Removes a trailing description in parentheses: "Jordan (river)" → ("Jordan", "river").
    private static func split(_ name: String) -> (answer: String, qualifier: String?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let open = trimmed.firstIndex(of: "("), trimmed.hasSuffix(")") else { return (trimmed, nil) }
        let answer = trimmed[..<open].trimmingCharacters(in: .whitespaces)
        let qualifier = trimmed[trimmed.index(after: open)..<trimmed.index(before: trimmed.endIndex)]
            .trimmingCharacters(in: .whitespaces)
        return (answer.isEmpty ? trimmed : answer, qualifier.isEmpty ? nil : qualifier)
    }

    private func peopleWords() -> [HangmanWord] {
        loadedPeople
            .filter { difficulty.includes($0.difficulty) }
            .map { entry in
                let parts = Self.split(entry.name)
                return HangmanWord(answer: parts.answer, category: .people, clue: entry.shortDescription,
                                   qualifier: parts.qualifier, reference: nil)
            }
    }

    private func placeWords() -> [HangmanWord] {
        loadedPlaces
            .filter { difficulty.includes($0.difficulty) }
            .map { entry in
                let parts = Self.split(entry.locationName)
                return HangmanWord(answer: parts.answer, category: .places, clue: entry.shortDescription,
                                   qualifier: parts.qualifier,
                                   reference: entry.scriptureMentioned.isEmpty ? nil : entry.scriptureMentioned)
            }
    }

    private func bookWords() -> [HangmanWord] {
        BibleCanon.canonicalOrder().map { name in
            let section = QuizVerseSection.containing(name)
            let testament = section?.isOldTestament == false
                ? String(localized: "New Testament")
                : String(localized: "Old Testament")
            let clue = section.map { "\(testament) · \(String(localized: $0.title))" } ?? testament
            return HangmanWord(answer: name, category: .books, clue: clue, qualifier: nil, reference: nil)
        }
    }

    /// Draws the game's words without repeats. Mixed picks a category for each word.
    private func makeDeck() -> [HangmanWord] {
        var pools: [HangmanTheme: [HangmanWord]] = [:]
        let themes: [HangmanTheme] = theme == .all ? [.people, .places, .books] : [theme]
        for item in themes {
            switch item {
            case .people: pools[item] = peopleWords().shuffled()
            case .places: pools[item] = placeWords().shuffled()
            case .books: pools[item] = bookWords().shuffled()
            case .all: break
            }
        }

        var words: [HangmanWord] = []
        var usedAnswers: Set<String> = []
        while words.count < Self.wordsPerGame {
            let available = themes.filter { !(pools[$0]?.isEmpty ?? true) }
            guard let pick = available.randomElement(), let word = pools[pick]?.popLast() else { break }
            // Same-named people or places ("Joseph", "Bethlehem") would look like repeats.
            guard usedAnswers.insert(word.answer.uppercased()).inserted else { continue }
            words.append(word)
        }
        return words
    }

    // MARK: - Game flow

    func startGame() {
        deck = makeDeck()
        guard !deck.isEmpty else { return }
        totalWords = deck.count
        wordNumber = 0
        session.beginGame(savedStreak: persistentStreak)
        phase = .playing
        nextWord()
    }

    func nextWord() {
        guard let word = deck.popLast() else {
            showResults()
            return
        }
        current = word
        wordNumber += 1
        guessedLetters = []
        wrongGuesses = 0
        clueRevealed = false
        roundOver = false
        didWin = false
    }

    private func showResults() {
        session.finishGame(bestScoreKey: bestGameScoreKey)
        current = nil
        phase = .results
    }

    func resetToSetup() {
        phase = .setup
        deck = []
        current = nil
        wordNumber = 0
        guessedLetters = []
        wrongGuesses = 0
        clueRevealed = false
        roundOver = false
        didWin = false
        session.clearGame()
    }

    func revealClue() {
        guard canRevealClue else { return }
        clueRevealed = true
        wrongGuesses += 1
    }

    func guess(_ ch: Character) {
        guard !roundOver else { return }
        let upper = Character(String(ch).uppercased())
        guard upper.isLetter, !guessedLetters.contains(upper) else { return }
        guessedLetters.insert(upper)

        if answerLetters.contains(upper) {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
            if answerLetters.isSubset(of: guessedLetters) {
                endRound(win: true)
            }
        } else {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            #endif
            wrongGuesses += 1
            if wrongGuesses >= maxWrong {
                endRound(win: false)
            }
        }
    }

    /// Debug-only shortcut that solves the current word.
    func debugWin() {
        guessedLetters.formUnion(answerLetters)
        endRound(win: true)
    }

    private func endRound(win: Bool) {
        guard !roundOver, let current else { return }
        roundOver = true
        didWin = win
        session.record(correct: win, savedStreak: persistentStreak)

        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(win ? .success : .error)
        #endif

        GameStats.shared.recordRound(
            game: .hangman,
            difficulty: difficulty.statsDifficulty,
            correct: win ? 1 : 0,
            answered: 1,
            currentBestStreak: session.savedBestStreak
        )
        // Per-category (People/Places/Books) accuracy
        GameStats.shared.recordHangmanCategory(
            category: current.category.rawValue,
            answered: 1,
            correct: win ? 1 : 0
        )
    }

    // MARK: - References

    /// Turns a reference like "Genesis 12:1" into a passage to preview.
    static func scriptureRef(from ref: String) -> ScriptureRef? {
        let attributed = BibleReferenceLinker.linkify(ref)
        for run in attributed.runs {
            if let url = run.attributes.link, let parsed = BibleReferenceLinker.parse(url: url) {
                return parsed
            }
        }

        let trimmed = ref.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split { $0.isWhitespace }
        guard let lastPart = parts.last else { return nil }
        var last = String(lastPart)
        last = last.replacingOccurrences(of: "\u{2013}", with: "-")
        last = last.replacingOccurrences(of: "\u{2014}", with: "-")
        last = last.trimmingCharacters(in: CharacterSet(charactersIn: ",;.)]”’\""))
        guard let colonIndex = last.firstIndex(of: ":") else { return nil }
        let chapterSlice = last[..<colonIndex]
        let verseSlice = last[last.index(after: colonIndex)...]
        let chapterDigits = chapterSlice.prefix { $0.isNumber }
        let verseDigits = verseSlice.prefix { $0.isNumber }
        guard let chapterNum = Int(chapterDigits), let verseNum = Int(verseDigits) else { return nil }
        let bookRaw = parts.dropLast().joined(separator: " ")

        if let book = BibleData.books.first(where: { $0.name.compare(bookRaw, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return ScriptureRef(bookName: book.name, chapter: chapterNum, startVerse: verseNum, endVerse: nil)
        }
        let collapsed = bookRaw.replacingOccurrences(of: " ", with: "")
        if let book = BibleData.books.first(where: { $0.name.replacingOccurrences(of: " ", with: "").compare(collapsed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return ScriptureRef(bookName: book.name, chapter: chapterNum, startVerse: verseNum, endVerse: nil)
        }
        let spacedLeading: String
        if let first = bookRaw.first, first.isNumber {
            let digits = String(bookRaw.prefix { $0.isNumber })
            let rest = String(bookRaw.drop { $0.isNumber })
            spacedLeading = digits + " " + rest
        } else {
            spacedLeading = bookRaw
        }
        if let book = BibleData.books.first(where: { $0.name.compare(spacedLeading, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            return ScriptureRef(bookName: book.name, chapter: chapterNum, startVerse: verseNum, endVerse: nil)
        }
        return nil
    }
}
