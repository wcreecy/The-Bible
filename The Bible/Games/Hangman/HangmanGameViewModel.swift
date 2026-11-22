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
    case bibleWords = "Bible Words"
    case books = "Books"
    /// Bible Words, guessed from a verse with the word blanked out.
    case verses = "Verses"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .all: "Mixed"
        case .people: "People"
        case .places: "Places"
        case .bibleWords: "Bible Words"
        case .books: "Books"
        case .verses: "Verses"
        }
    }

    var systemImage: String {
        switch self {
        case .people: "person.fill"
        case .places: "mappin.and.ellipse"
        case .bibleWords: "text.book.closed.fill"
        case .books: "book.fill"
        case .verses: "text.quote"
        case .all: "square.grid.2x2.fill"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .all: "People, places, Bible words, and books"
        case .people: "Bible people"
        case .places: "Bible places"
        case .bibleWords: "Familiar words from the Bible"
        case .books: "Books of the Bible"
        case .verses: "Fill in the missing word from a verse"
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
        case .easy: "Well-known answers, 8 mistakes, and a clue for every word."
        case .normal: "Adds less familiar answers and allows 6 mistakes. Clues and letter hints cost one mistake."
        case .hard: "Every answer in the game, 5 mistakes, and only a verse clue, which costs two."
        }
    }

    var clueSummary: String {
        switch self {
        case .easy: String(localized: "Shown")
        // Worded like the in-game button, "Show clue (costs 1 mistake)".
        case .normal: String(localized: "Costs 1 mistake")
        case .hard: String(localized: "Verse only")
        }
    }

    /// Mistakes the verse clue costs. Easy gives every clue away free.
    var verseClueCost: Int {
        switch self {
        case .easy: 0
        case .normal: 1
        case .hard: 2
        }
    }

    /// Hard has no letter hints; elsewhere one costs a mistake.
    var allowsLetterHints: Bool { self != .hard }

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

    /// Easy uses easy entries, Normal adds normal entries (and legacy medium ones), and Hard uses everything.
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

    /// The answer blanked out of `text`. Names are matched as whole words (EVE, not EVEN);
    /// other words also take their endings (PRAY in PRAYED), so the clue can't give them away.
    /// Words of a name shorter than three letters (the I in HEROD AGRIPPA I) and joining words
    /// are left in.
    func blankingOut(in text: String) -> String {
        let isName = category == .people || category == .places
        let skipped: Set<String> = ["the", "of", "and"]
        let parts = answer.split(whereSeparator: { !$0.isLetter && $0 != "'" })
            .map(String.init)
            .filter { $0.count >= 3 && !skipped.contains($0.lowercased()) }

        var result = text
        for part in parts {
            let escaped = NSRegularExpression.escapedPattern(for: part)
            let pattern = isName ? "\\b\(escaped)\\b" : "\\b\(escaped)[a-z]*"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            var updated = result
            for match in regex.matches(in: result, range: range).reversed() {
                guard let matchRange = Range(match.range, in: updated) else { continue }
                updated.replaceSubrange(matchRange, with: String(repeating: "_", count: updated[matchRange].count))
            }
            result = updated
        }
        return result
    }
}

/// A verse that may quote a Hangman answer.
struct HangmanVerse: Equatable, Sendable {
    let reference: String
    let text: String
}

/// What happened when a letter was guessed.
enum HangmanGuessResult {
    case correct
    case wrong
    case alreadyGuessed
    /// Not a letter, or the round is over.
    case ignored
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
    private let reviewQuestionIDs: Set<String>
    /// Where missed words are recorded; tests pass a store that never touches disk or iCloud.
    private let missedQuestions: MissedGameQuestionStore
    /// Looks up the verses a reference points to; tests pass fixed verses.
    @ObservationIgnored private let loadVerses: (String) async -> [HangmanVerse]

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
            // A review plays at its own difficulty without changing the game's saved difficulty.
            if !isReviewRound {
                UserDefaults.standard.set(difficulty.rawValue, forKey: Self.difficultyKey)
            }
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
    private var loadedBibleWords: [BibleWordChallenge] = []
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
    /// Letters filled in by a letter hint rather than guessed.
    private(set) var hintedLetters: Set<Character> = []
    /// A verse quoting the answer, once loaded. Nil while loading, or when none quotes it.
    private(set) var verse: HangmanVerse?
    private(set) var isVerseLoaded = false
    private(set) var isVerseClueShown = false
    private(set) var roundOver = false
    private(set) var didWin = false
    private(set) var lastCorrectGuess: Character?

    /// Score, streaks and best game; see `GameScore` for the rules.
    private(set) var session = GameScore()

    /// `missedQuestions` and `loadVerses` default to the shared store and the Bible text. They're
    /// resolved here rather than as default arguments, which would be evaluated outside the main actor.
    init(
        reviewQuestionIDs: Set<String> = [],
        missedQuestions: MissedGameQuestionStore? = nil,
        loadVerses: ((String) async -> [HangmanVerse])? = nil
    ) {
        self.reviewQuestionIDs = reviewQuestionIDs
        self.missedQuestions = missedQuestions ?? .shared
        self.loadVerses = loadVerses ?? { await Self.versesInBible(for: $0) }
    }

    // MARK: - Derived state

    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "hangman", variant: difficulty.rawValue.lowercased())
    }

    private var bestGameScoreKey: String { "hangmanBestGameScore_\(difficulty.rawValue.lowercased())" }

    var isDataLoaded: Bool {
        !loadedPeople.isEmpty && !loadedPlaces.isEmpty && !loadedBibleWords.isEmpty
    }

    var maxWrong: Int { difficulty.maxWrong }

    private var answerLetters: Set<Character> {
        Set((current?.answer ?? "").uppercased().filter(\.isLetter))
    }

    var correctLetters: Set<Character> { guessedLetters.intersection(answerLetters) }
    var wrongLetters: Set<Character> { guessedLetters.subtracting(answerLetters) }

    var isLastWord: Bool { deck.isEmpty }

    var isReviewRound: Bool { !reviewQuestionIDs.isEmpty }

    var isOneGuessRemaining: Bool {
        !roundOver && wrongGuesses == maxWrong - 1
    }

    /// A clue or hint may cost mistakes, but never the last one.
    private func canAfford(_ cost: Int) -> Bool {
        !roundOver && wrongGuesses + cost < maxWrong
    }

    var canRevealClue: Bool {
        difficulty == .normal && !clueRevealed && canAfford(1)
    }

    var showsClue: Bool {
        difficulty == .easy || clueRevealed || roundOver || isVersePromptUnavailable
    }

    /// A Verses word whose verse doesn't name it falls back to its description, free.
    private var isVersePromptUnavailable: Bool {
        isVersePrompt && isVerseLoaded && verse == nil
    }

    /// The Verses theme's words are guessed from their verse, so it's shown from the start.
    var isVersePrompt: Bool {
        current?.category == .verses
    }

    var canShowVerseClue: Bool {
        verse != nil && !isVerseClueShown && !isVersePrompt && canAfford(difficulty.verseClueCost)
    }

    /// Answer letters not found yet.
    private var unguessedLetters: Set<Character> {
        answerLetters.subtracting(guessedLetters)
    }

    /// A letter hint can't finish the word for the player.
    var canRevealLetter: Bool {
        difficulty.allowsLetterHints && unguessedLetters.count >= 2 && canAfford(1)
    }

    /// The description clue, letter hints and the verse clue, for the round summary.
    var hintsUsed: Int {
        (clueRevealed ? 1 : 0) + hintedLetters.count + (isVerseClueShown ? 1 : 0)
    }

    /// The verse with the answer blanked out while the word is being guessed, and whole after.
    var displayedVerse: GameVerse? {
        guard let current, let verse else { return nil }
        if roundOver {
            return GameVerse(text: verse.text, reference: verse.reference, isClue: false)
        }
        guard isVerseClueShown || isVersePrompt else { return nil }
        return GameVerse(text: current.blankingOut(in: verse.text), reference: verse.reference, isClue: true)
    }

    /// One square per character of the answer. Spaces split words; other punctuation always shows.
    var displayLetters: [HangmanDisplayLetter] {
        (current?.answer ?? "").map { character in
            guard character.isLetter else { return HangmanDisplayLetter(character: character, state: .punctuation) }
            let upper = Character(String(character).uppercased())
            let state: HangmanDisplayLetter.State
            if hintedLetters.contains(upper) {
                state = .hinted
            } else if guessedLetters.contains(upper) {
                state = .found
            } else {
                state = roundOver ? .missed : .hidden
            }
            return HangmanDisplayLetter(character: upper, state: state)
        }
    }

    /// What VoiceOver reads for the word, e.g. "J, blank, S, blank".
    var spokenDisplayWord: String {
        let blank = String(localized: "blank")
        return displayLetters.map { letter in
            switch letter.state {
            case .hidden: blank
            case .punctuation where letter.character == " ": String(localized: "space")
            default: String(letter.character)
            }
        }
        .joined(separator: ", ")
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
        if loadedBibleWords.isEmpty { loadedBibleWords = await GameDataLoaders.loadBibleWordsAsync() }
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

    private static func nonEmpty(_ reference: String?) -> String? {
        guard let reference, !reference.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return reference
    }

    private func peopleWords() -> [HangmanWord] {
        loadedPeople
            .filter { isReviewRound || difficulty.includes($0.difficulty) }
            .map { entry in
                let parts = Self.split(entry.name)
                return HangmanWord(answer: parts.answer, category: .people, clue: entry.shortDescription,
                                   qualifier: parts.qualifier, reference: Self.nonEmpty(entry.scriptureReferences))
            }
    }

    private func placeWords() -> [HangmanWord] {
        loadedPlaces
            .filter { isReviewRound || difficulty.includes($0.difficulty) }
            .map { entry in
                let parts = Self.split(entry.locationName)
                return HangmanWord(answer: parts.answer, category: .places, clue: entry.shortDescription,
                                   qualifier: parts.qualifier, reference: Self.nonEmpty(entry.scriptureMentioned))
            }
    }

    private func bibleWords(as category: HangmanTheme = .bibleWords) -> [HangmanWord] {
        loadedBibleWords
            .filter { isReviewRound || difficulty.includes($0.difficulty) }
            .map { entry in
                HangmanWord(
                    answer: entry.name,
                    category: category,
                    clue: entry.shortDescription,
                    qualifier: nil,
                    reference: Self.nonEmpty(entry.scriptureReferences)
                )
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

    /// Draws the game's words without repeats, including words used in recent rounds.
    private func makeDeck() -> [HangmanWord] {
        // Verses is its own way to play Bible Words, so Mixed and review rounds leave it out.
        let themes: [HangmanTheme] = isReviewRound || theme == .all ? [.people, .places, .bibleWords, .books] : [theme]
        let allWords = themes.flatMap { item -> [HangmanWord] in
            switch item {
            case .people: peopleWords()
            case .places: placeWords()
            case .bibleWords: bibleWords()
            case .verses: bibleWords(as: .verses).filter { $0.reference != nil }
            case .books: bookWords()
            case .all: []
            }
        }

        var uniqueWords: [HangmanWord] = []
        var usedAnswers: Set<String> = []
        for word in allWords where usedAnswers.insert(word.answer.uppercased()).inserted {
            uniqueWords.append(word)
        }

        let eligible = isReviewRound
            ? uniqueWords.filter { reviewQuestionIDs.contains($0.answer.uppercased()) }
            : uniqueWords
        return RecentGameQuestionStore.shared.select(
            from: eligible.shuffled(),
            game: "hangman",
            count: Self.wordsPerGame,
            cooldown: Self.wordsPerGame * 7,
            id: { $0.answer.uppercased() }
        )
    }

    // MARK: - Game flow

    func startGame() {
        startGame(with: makeDeck())
    }

    /// Starts a game with these words, last one first. Tests pass their own.
    func startGame(with words: [HangmanWord]) {
        deck = words
        guard !deck.isEmpty else { return }
        totalWords = deck.count
        wordNumber = 0
        session.beginGame(savedStreak: persistentStreak, isTimed: false)
        phase = .playing
        nextWord()
    }

    func nextWord() {
        guard let word = deck.popLast() else {
            showResults()
            return
        }
        current = word
        RecentGameQuestionStore.shared.record(word, game: "hangman", id: { $0.answer.uppercased() })
        wordNumber += 1
        resetRound()
        session.startQuestion()
    }

    private func resetRound() {
        guessedLetters = []
        wrongGuesses = 0
        clueRevealed = false
        hintedLetters = []
        verse = nil
        isVerseLoaded = false
        isVerseClueShown = false
        roundOver = false
        didWin = false
        lastCorrectGuess = nil
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
        resetRound()
        session.clearGame()
    }

    func revealClue() {
        guard canRevealClue else { return }
        clueRevealed = true
        wrongGuesses += 1
    }

    /// Fills in every place one unfound letter appears, for one mistake.
    func revealLetter() {
        guard canRevealLetter, let letter = unguessedLetters.randomElement() else { return }
        guessedLetters.insert(letter)
        hintedLetters.insert(letter)
        lastCorrectGuess = letter
        wrongGuesses += 1
        Haptics.selection()
    }

    func showVerseClue() {
        guard canShowVerseClue else { return }
        isVerseClueShown = true
        wrongGuesses += difficulty.verseClueCost
    }

    @discardableResult
    func guess(_ ch: Character) -> HangmanGuessResult {
        guard !roundOver else { return .ignored }
        let upper = Character(String(ch).uppercased())
        guard upper.isLetter else { return .ignored }
        guard !guessedLetters.contains(upper) else {
            Haptics.selection()
            return .alreadyGuessed
        }
        guessedLetters.insert(upper)

        if answerLetters.contains(upper) {
            lastCorrectGuess = upper
            Haptics.selection()
            if answerLetters.isSubset(of: guessedLetters) {
                endRound(win: true)
            }
            return .correct
        }

        Haptics.warning()
        wrongGuesses += 1
        if wrongGuesses >= maxWrong {
            endRound(win: false)
        }
        return .wrong
    }

    func giveUp() {
        guard !roundOver else { return }
        endRound(win: false)
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
        let answer = [current.answer, current.qualifier.map { "(\($0))" }].compactMap(\.self).joined(separator: " ")
        session.record(
            GameRoundEntry(
                prompt: current.clue,
                outcome: win ? .correct : .wrong,
                givenAnswer: nil,
                correctAnswer: answer,
                category: String(localized: current.category.title),
                reference: verse?.reference ?? current.reference,
                hintCount: hintsUsed
            ),
            savedStreak: persistentStreak
        )

        if win { Haptics.success() } else { Haptics.error() }

        GameStats.shared.recordRound(
            game: .hangman,
            difficulty: difficulty.statsDifficulty,
            correct: win ? 1 : 0,
            answered: 1,
            currentBestStreak: session.savedBestStreak
        )
        // Per-category accuracy, by the category's stored name.
        GameStats.shared.recordHangmanCategory(
            category: current.category.rawValue,
            answered: 1,
            correct: win ? 1 : 0
        )
        let questionID = current.answer.uppercased()
        if win, isReviewRound {
            missedQuestions.resolveReviewQuestion(game: .hangman, questionID: questionID)
        } else if !win {
            missedQuestions.record(
                game: .hangman,
                bookNames: [],
                topic: String(localized: current.category.title),
                questionID: questionID
            )
        }
    }

    // MARK: - Verses

    /// Finds a verse quoting the current answer, for the verse clue (or the Verses prompt) and
    /// for showing once the round is over. A verse that doesn't name the answer isn't used.
    func loadVerse() async {
        guard let word = current, !isVerseLoaded else { return }
        guard let reference = word.reference else {
            isVerseLoaded = true
            return
        }
        let verses = await loadVerses(reference)
        // The player may have moved on while the Bible loaded.
        guard current?.answer == word.answer else { return }
        verse = verses.first { word.blankingOut(in: $0.text) != $0.text }
        isVerseLoaded = true
    }

    /// The verses of the first passage in `reference` ("Exodus 4:14–16; 28:1" reads Exodus
    /// 4:14–16), up to three, in the reader's translation.
    static func versesInBible(for reference: String) async -> [HangmanVerse] {
        guard let passage = PassageReferenceParser.firstPassage(in: reference), let startVerse = passage.startVerse else { return [] }
        let endVerse = passage.isSingleChapter ? passage.endVerse.map { min($0, startVerse + 2) } : nil
        let scriptureRef = ScriptureRef(
            bookName: passage.bookName,
            chapter: passage.startChapter,
            startVerse: startVerse,
            endVerse: endVerse
        )
        guard let loaded = await BibleReferenceLinker.loadVersesEnsuringLoaded(for: scriptureRef) else { return [] }
        return loaded.verses
            .filter { !$0.isOmitted }
            .map { HangmanVerse(reference: "\(passage.bookName) \(passage.startChapter):\($0.number)", text: $0.text) }
    }
}

/// One square of the word on screen.
struct HangmanDisplayLetter: Equatable {
    enum State: Equatable {
        case hidden
        case found
        /// Filled in by a letter hint.
        case hinted
        /// Never found; shown once the round is lost.
        case missed
        /// A space or punctuation mark, which is never guessed.
        case punctuation
    }

    let character: Character
    let state: State
}
