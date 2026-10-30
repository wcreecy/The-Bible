import Foundation
import Observation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum VerseMatchDifficulty: String, CaseIterable, Identifiable {
    case easy, normal, hard

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .easy: "Wrong choices come from other parts of the Bible."
        case .normal: "Wrong choices come from anywhere in your categories."
        case .hard: "Every choice comes from the same book as the reference."
        }
    }

    var statsDifficulty: GameStats.Difficulty {
        switch self {
        case .easy: .easy
        case .normal: .normal
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
}

enum VerseMatchPool: String, CaseIterable, Identifiable {
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
struct VerseMatchVerse: Hashable {
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

struct VerseMatchQuestion {
    let verse: VerseMatchVerse
    let options: [VerseMatchVerse]
    let correctIndex: Int
    var selectedIndex: Int?
}

/// The well-known verses shared with the lock-screen widget (`LockScreenVerses.json`).
private enum VerseMatchWellKnownVerses {
    private struct Entry: Decodable {
        let book: String
        let chapter: Int
        let verse: Int
        let text: String
    }

    static func load() -> [VerseMatchVerse] {
        guard let url = Bundle.main.url(forResource: "LockScreenVerses", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = PersistedDecoding.decode([Entry].self, from: data, name: "LockScreenVerses.json") else { return [] }
        return entries.map {
            VerseMatchVerse(bookName: $0.book, chapterNumber: $0.chapter, verseNumber: $0.verse, verseText: $0.text)
        }
    }
}

@MainActor
@Observable
final class VerseMatchGameViewModel {
    enum Phase {
        case setup
        case playing
        case results
    }

    static let questionsPerGame = 10
    /// "Any verse" skips longer verses so four choices stay readable.
    static let maximumWords = 50

    private static let difficultyKey = AppStorageKey.verseMatchDifficulty
    private static let poolKey = AppStorageKey.verseMatchPool
    private static let sectionsKey = AppStorageKey.verseMatchSections
    /// Replaced by the category quick picks; read once to carry an old choice over.
    private static let legacyScopeKey = AppStorageKey.verseMatchScope

    /// Verses to replay from the missed-questions list; empty for a normal game.
    let reviewQuestionIDs: Set<String>

    init(reviewQuestionIDs: Set<String> = []) {
        self.reviewQuestionIDs = reviewQuestionIDs
    }

    // MARK: - Settings

    var difficulty: VerseMatchDifficulty = VerseMatchDifficulty(
        rawValue: UserDefaults.standard.string(forKey: VerseMatchGameViewModel.difficultyKey) ?? ""
    ) ?? .normal {
        didSet {
            UserDefaults.standard.set(difficulty.rawValue, forKey: Self.difficultyKey)
            session.syncSavedBest(from: persistentStreak)
        }
    }

    var experienceLevel: GameExperienceLevel {
        get { difficulty.experienceLevel }
        set { difficulty = VerseMatchDifficulty(experienceLevel: newValue) }
    }

    var pool: VerseMatchPool = VerseMatchPool(
        rawValue: UserDefaults.standard.string(forKey: VerseMatchGameViewModel.poolKey) ?? ""
    ) ?? .wellKnown {
        didSet { UserDefaults.standard.set(pool.rawValue, forKey: Self.poolKey) }
    }

    private var sectionsRaw: String = UserDefaults.standard.string(forKey: VerseMatchGameViewModel.sectionsKey) ?? "" {
        didSet { UserDefaults.standard.set(sectionsRaw, forKey: Self.sectionsKey) }
    }

    private var storedSections: Set<QuizVerseSection> {
        Set(sectionsRaw.split(separator: ",").compactMap { QuizVerseSection(rawValue: String($0)) })
    }

    /// The chosen categories. An empty stored selection means every category, and
    /// clearing every category is ignored.
    var selectedSections: Set<QuizVerseSection> {
        get { storedSections.isEmpty ? Set(QuizVerseSection.allCases) : storedSections }
        set {
            guard !newValue.isEmpty else { return }
            if newValue == Set(QuizVerseSection.allCases) {
                sectionsRaw = ""
            } else {
                sectionsRaw = QuizVerseSection.allCases
                    .filter { newValue.contains($0) }
                    .map(\.rawValue)
                    .joined(separator: ",")
            }
        }
    }

    private var poolBookNames: Set<String> {
        Set(selectedSections.flatMap(\.bookNames))
    }

    // MARK: - Data

    private var wellKnownVerses: [VerseMatchVerse] = []
    /// Fair verses (no lists, repeats, or very long verses) by book, for "Any verse" and fill-in choices.
    private var anyVersesByBook: [String: [VerseMatchVerse]] = [:]
    /// The saved verses. Favorites come from SwiftData, so the view keeps this up to date.
    var favoriteVerses: [VerseMatchVerse] = []
    private var questionBag: [VerseMatchVerse] = []

    // MARK: - Game state

    private(set) var phase: Phase = .setup
    private(set) var isFilterReady = QuizVerseFilter.isReady
    private(set) var history: [VerseMatchQuestion] = []
    private(set) var currentIndex: Int = -1
    private(set) var totalQuestions: Int = 0

    /// Score, streaks and best game; see `GameScore` for the rules.
    private(set) var session = GameScore()

    // MARK: - Derived state

    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "versematch", variant: difficulty.rawValue)
    }

    private var bestGameScoreKey: String { "versematchBestGameScore_\(difficulty.rawValue)" }

    /// Saved verses within the chosen categories, without repeats.
    private var favoriteVersesInCategories: [VerseMatchVerse] {
        let books = poolBookNames
        return uniqueByReference(favoriteVerses).filter { books.contains($0.bookName) }
    }

    /// The pool's own verses within the chosen categories, before any fill-in.
    private var preferredVerses: [VerseMatchVerse] {
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

    var canStart: Bool {
        isFilterReady && (pool != .favorites || !preferredVerses.isEmpty)
    }

    var current: VerseMatchQuestion? {
        history.indices.contains(currentIndex) ? history[currentIndex] : nil
    }

    var isViewingPrevious: Bool { currentIndex < history.count - 1 }

    var isAnswered: Bool { current?.selectedIndex != nil }

    var isOnLastQuestion: Bool { !isViewingPrevious && history.count >= totalQuestions }

    var canGoPrevious: Bool { currentIndex > 0 }

    var progressText: String {
        String(localized: "Question \(currentIndex + 1) of \(totalQuestions)")
    }

    // MARK: - Lifecycle

    func onAppear() {
        migrateLegacyScope()
        session.syncSavedBest(from: persistentStreak)
        if wellKnownVerses.isEmpty {
            wellKnownVerses = VerseMatchWellKnownVerses.load()
        }
    }

    /// Sorts out list and repeated verses while the start screen is showing.
    func prepareFilter() async {
        await QuizVerseFilter.prepare()
        isFilterReady = true
    }

    func onDisappear() {
        // Leaving after answering begins a new game on return.
        if phase != .setup && session.answered > 0 {
            resetToSetup()
        }
        session.clearStreak()
    }

    /// The Testament picker was folded into the categories; apply an old choice once.
    private func migrateLegacyScope() {
        let defaults = UserDefaults.standard
        let legacyScope = defaults.string(forKey: Self.legacyScopeKey) ?? "whole"
        guard legacyScope == "old" || legacyScope == "new" else { return }
        let testamentSections = Set(QuizVerseSection.allCases.filter { $0.isOldTestament == (legacyScope == "old") })
        let kept = storedSections.intersection(testamentSections)
        selectedSections = kept.isEmpty ? testamentSections : kept
        defaults.set("whole", forKey: Self.legacyScopeKey)
    }

    // MARK: - Game flow

    func startGame() {
        guard canStart else { return }
        anyVersesByBook = buildAnyVerses()
        questionBag = buildQuestionBag()
        if !reviewQuestionIDs.isEmpty {
            let reviewPool = uniqueByReference(
                wellKnownVerses + buildAnyVerses().values.flatMap { $0 }
            )
            questionBag = reviewPool.filter { reviewQuestionIDs.contains($0.reference) }.shuffled()
        }
        guard !questionBag.isEmpty else { return }
        totalQuestions = min(Self.questionsPerGame, questionBag.count)
        history = []
        currentIndex = -1
        session.beginGame(savedStreak: persistentStreak)
        phase = .playing
        appendNextQuestion()
    }

    /// Back to the start screen. The streak is kept so the next game can continue it.
    func resetToSetup() {
        phase = .setup
        history = []
        currentIndex = -1
        questionBag = []
        session.clearGame()
    }

    func showPrevious() {
        guard canGoPrevious else { return }
        currentIndex -= 1
    }

    func showNext() {
        if isViewingPrevious {
            currentIndex += 1
        } else if history.count >= totalQuestions {
            showResults()
        } else {
            appendNextQuestion()
        }
    }

    private func appendNextQuestion() {
        while let verse = questionBag.popLast() {
            let wrong = wrongChoices(for: verse)
            guard wrong.count == 3 else { continue }
            let options = (wrong + [verse]).shuffled()
            guard let correctIndex = options.firstIndex(of: verse) else { continue }
            history.append(VerseMatchQuestion(verse: verse, options: options, correctIndex: correctIndex))
            currentIndex = history.count - 1
            return
        }
        // Ran out of usable verses early; end with what was played.
        totalQuestions = history.count
        showResults()
    }

    private func showResults() {
        session.finishGame(bestScoreKey: bestGameScoreKey)
        phase = .results
    }

    func select(_ index: Int) {
        guard !isViewingPrevious, let current, current.selectedIndex == nil else { return }
        history[currentIndex].selectedIndex = index

        let isCorrect = index == current.correctIndex
        session.record(correct: isCorrect, savedStreak: persistentStreak)

        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(isCorrect ? .success : .error)
        #endif

        GameStats.shared.recordRound(
            game: .versematch,
            difficulty: difficulty.statsDifficulty,
            correct: isCorrect ? 1 : 0,
            answered: 1,
            currentBestStreak: session.savedBestStreak
        )
        GameStats.shared.recordVerseMatchPerBook(bookName: current.verse.bookName, answered: 1, correct: isCorrect ? 1 : 0)
        if isCorrect, !reviewQuestionIDs.isEmpty {
            MissedGameQuestionStore.shared.resolveReviewQuestion(
                game: .verseMatch,
                questionID: current.verse.reference
            )
        } else if !isCorrect {
            MissedGameQuestionStore.shared.record(
                game: .verseMatch,
                bookNames: [current.verse.bookName],
                chapterNumber: current.verse.chapterNumber,
                topic: "Verse matching",
                questionID: current.verse.reference
            )
        }
    }

    // MARK: - Verses

    private func uniqueByReference(_ verses: [VerseMatchVerse]) -> [VerseMatchVerse] {
        var seen: Set<String> = []
        return verses.filter { seen.insert($0.reference).inserted }
    }

    /// Every fair verse, grouped by book: no lists, cross-book repeats, or very long verses.
    private func buildAnyVerses() -> [String: [VerseMatchVerse]] {
        var result: [String: [VerseMatchVerse]] = [:]
        for book in BibleData.books {
            result[book.name] = book.chapters.flatMap { chapter in
                chapter.verses.compactMap { verse -> VerseMatchVerse? in
                    guard QuizVerseFilter.isQuizzable(book: book.name, chapter: chapter.number, verse: verse.number, difficulty: "normal"),
                          verse.text.split(separator: " ").count <= Self.maximumWords else { return nil }
                    return VerseMatchVerse(bookName: book.name, chapterNumber: chapter.number,
                                           verseNumber: verse.number, verseText: verse.text)
                }
            }
        }
        return result
    }

    /// Verses to ask, drawn evenly across every verse rather than book by book.
    private func buildQuestionBag() -> [VerseMatchVerse] {
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
    private func wrongChoices(for target: VerseMatchVerse) -> [VerseMatchVerse] {
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

        var picks: [VerseMatchVerse] = []
        var usedTexts: Set<String> = [target.normalizedText]
        var usedBooks: Set<String> = distinctBooks ? [target.bookName] : []

        func add(_ verse: VerseMatchVerse) {
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
