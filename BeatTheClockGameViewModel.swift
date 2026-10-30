import Foundation
import Observation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

enum BeatTheClockDifficulty: String, CaseIterable, Identifiable {
    case easy
    case normal
    case hard

    /// Seconds a clue costs on Normal and Hard.
    static let hintCost = 3

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .easy: "Easy"
        case .normal: "Normal"
        case .hard: "Hard"
        }
    }

    var roundTime: Int {
        switch self {
        case .easy: 25
        case .normal: 15
        case .hard: 10
        }
    }

    /// Easy always shows each question's clue; the other levels charge time for it.
    var showsClueAutomatically: Bool { self == .easy }

    var detail: LocalizedStringResource {
        switch self {
        case .easy:
            "Well-known names, with a clue shown for each one."
        case .normal:
            "Adds less familiar names. A clue costs \(Self.hintCost) seconds."
        case .hard:
            "Every name in the game. A clue costs \(Self.hintCost) seconds."
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

enum BeatTheClockCategory: String, CaseIterable, Identifiable {
    case people = "People"
    case places = "Places"
    case both = "Both"

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .people: "People"
        case .places: "Places"
        case .both: "Mixed"
        }
    }
}

enum BeatTheClockRoundOutcome {
    case correct
    case incorrect
    case timedOut

    var title: LocalizedStringKey {
        switch self {
        case .correct: "Correct"
        case .incorrect: "Incorrect"
        case .timedOut: "Time’s Up"
        }
    }

    var systemImage: String {
        switch self {
        case .correct: "checkmark.circle.fill"
        case .incorrect: "xmark.circle.fill"
        case .timedOut: "hourglass.bottomhalf.filled"
        }
    }

    var tint: Color {
        self == .correct ? .green : .red
    }
}

struct BeatTheClockQuestion: Identifiable {
    enum Subject {
        case person
        case place
    }

    let id: String
    let subject: Subject
    let label: String
    let clue: String
    let acceptableBooks: Set<String>
    /// The verse the place entry was written from, shown when the round ends.
    let scriptureReference: String?
}

@MainActor
@Observable
final class BeatTheClockGameViewModel {
    enum Phase {
        case setup
        case playing
        case results
    }

    static let questionsPerGame = 10

    private static let difficultyKey = AppStorageKey.beatTheClockDifficulty
    private static let categoryKey = AppStorageKey.beatTheClockCategory

    /// Questions to replay from the missed-questions list; empty for a normal game.
    let reviewQuestionIDs: Set<String>

    init(reviewQuestionIDs: Set<String> = []) {
        self.reviewQuestionIDs = reviewQuestionIDs
    }

    // MARK: - Settings

    var difficulty: BeatTheClockDifficulty = BeatTheClockDifficulty(
        rawValue: UserDefaults.standard.string(forKey: BeatTheClockGameViewModel.difficultyKey) ?? ""
    ) ?? .normal {
        didSet {
            UserDefaults.standard.set(difficulty.rawValue, forKey: Self.difficultyKey)
            currentBestStreak = persistentStreak.best
        }
    }

    var category: BeatTheClockCategory = BeatTheClockCategory(
        rawValue: UserDefaults.standard.string(forKey: BeatTheClockGameViewModel.categoryKey) ?? ""
    ) ?? .people {
        didSet { UserDefaults.standard.set(category.rawValue, forKey: Self.categoryKey) }
    }

    var experienceLevel: GameExperienceLevel {
        get { difficulty.experienceLevel }
        set { difficulty = BeatTheClockDifficulty(experienceLevel: newValue) }
    }

    // MARK: - Data

    private var loadedPeople: [BibleCharacter] = []
    private var loadedPlaces: [BibleLocationChallenge] = []
    /// Every book whose text mentions each place, keyed by place ID. Nil until indexed.
    private var placeBooks: [Int: Set<String>]?
    private var questionDeck: [BeatTheClockQuestion] = []

    // MARK: - Game state

    private(set) var phase: Phase = .setup
    private(set) var currentQuestion: BeatTheClockQuestion?
    private(set) var questionNumber = 0
    private(set) var totalQuestions = 0
    /// Changes whenever a round starts, so the view can restart its timer task.
    private(set) var roundID = 0
    private(set) var remainingSeconds = 0
    private(set) var roundOutcome: BeatTheClockRoundOutcome?
    private(set) var submittedBook: String?
    private(set) var hintRevealed = false
    private(set) var isPulsing = false

    // Scoring
    private(set) var score = 0
    private(set) var answered = 0
    private(set) var sessionStreak = 0
    private(set) var sessionBestStreak = 0
    private(set) var currentBestStreak = 0
    private(set) var bestGameScore = 0
    private(set) var isNewBestGame = false

    // Answer entry
    var searchText = "" {
        didSet {
            if searchText != oldValue { inputMessage = nil }
        }
    }
    private(set) var inputMessage: String?

    // MARK: - Derived state

    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "beatclock", variant: difficulty.rawValue)
    }

    private var bestGameScoreKey: String { "beatclockBestGameScore_\(difficulty.rawValue)" }

    var selectionLocked: Bool { roundOutcome != nil }

    var isLoadingData: Bool {
        loadedPeople.isEmpty || loadedPlaces.isEmpty || placeBooks == nil
    }

    var filteredBooks: [String] {
        BibleBookNameMatcher.suggestions(for: searchText, in: BibleCanon.canonicalOrder())
    }

    var canSubmit: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !selectionLocked && !trimmed.isEmpty
    }

    var showsClue: Bool {
        difficulty.showsClueAutomatically || hintRevealed || selectionLocked
    }

    var canRequestHint: Bool {
        !selectionLocked && remainingSeconds > BeatTheClockDifficulty.hintCost
    }

    var sortedAcceptableBooks: [String] {
        guard let currentQuestion else { return [] }
        let order = Dictionary(uniqueKeysWithValues: BibleCanon.canonicalOrder().enumerated().map { ($1, $0) })
        return currentQuestion.acceptableBooks.sorted { (order[$0] ?? Int.max) < (order[$1] ?? Int.max) }
    }

    var isLastQuestion: Bool { questionDeck.isEmpty }

    var progressText: String {
        String(localized: "Question \(questionNumber) of \(totalQuestions)")
    }

    var targetType: String {
        currentQuestion?.subject == .place ? String(localized: "Place") : String(localized: "Person")
    }

    /// Green, then yellow, then red as the round runs down, scaled to the round length.
    var timerColor: Color {
        let fraction = Double(remainingSeconds) / Double(max(1, difficulty.roundTime))
        if fraction <= 0.3 { return .red }
        if fraction <= 0.6 { return .yellow }
        return .green
    }

    // MARK: - Lifecycle

    func onAppear() {
        currentBestStreak = persistentStreak.best
    }

    func onDisappear() {
        // Leaving after answering begins a new game session on return.
        if phase != .setup && answered > 0 {
            resetGameSession()
        }
    }

    func loadData() async {
        if loadedPeople.isEmpty {
            loadedPeople = await GameDataLoaders.loadCharactersAsync()
        }
        if loadedPlaces.isEmpty {
            loadedPlaces = await GameDataLoaders.loadLocationChallengesAsync()
        }
        if placeBooks == nil {
            let places = loadedPlaces.map { (id: $0.id, name: $0.locationName) }
            let books = await BibleRepository.shared.loadAllBooks()
            placeBooks = await Task.detached(priority: .userInitiated) {
                BeatTheClockAnswerIndex.booksMentioning(places, in: books)
            }.value
        }
    }

    /// Counts down the current round. Run from a task keyed on `roundID` so each
    /// round restarts it and the first second is a full second.
    func runTimer() async {
        while !Task.isCancelled, phase == .playing, roundOutcome == nil, remainingSeconds > 0 {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, phase == .playing, roundOutcome == nil else { return }
            tick()
        }
    }

    // MARK: - Questions

    private func matchesSelectedDifficulty(_ questionDifficulty: String) -> Bool {
        let normalizedDifficulty = questionDifficulty.lowercased()

        switch difficulty {
        case .easy:
            return normalizedDifficulty == "easy"
        case .normal:
            // The catalog currently uses "Medium" for the Normal tier.
            return normalizedDifficulty == "easy"
                || normalizedDifficulty == "normal"
                || normalizedDifficulty == "medium"
        case .hard:
            return true
        }
    }

    private func makeQuestionDeck() -> [BeatTheClockQuestion] {
        let sourcePeople = reviewQuestionIDs.isEmpty
            ? loadedPeople.filter { matchesSelectedDifficulty($0.difficulty) }
            : loadedPeople
        let sourcePlaces = reviewQuestionIDs.isEmpty
            ? loadedPlaces.filter { matchesSelectedDifficulty($0.difficulty) }
            : loadedPlaces
        let people = sourcePeople.map { entry in
            BeatTheClockQuestion(
                id: "person-\(entry.id)",
                subject: .person,
                label: entry.name,
                clue: entry.shortDescription,
                acceptableBooks: Set(entry.books),
                scriptureReference: nil
            )
        }
        let places = sourcePlaces.map { entry in
            // The reference book always counts, even when the KJV spells the name differently.
            var books = placeBooks?[entry.id] ?? []
            if let referenceBook = parseBookName(from: entry.scriptureMentioned) {
                books.insert(referenceBook)
            }
            return BeatTheClockQuestion(
                id: "place-\(entry.id)",
                subject: .place,
                label: entry.locationName,
                clue: entry.shortDescription,
                acceptableBooks: books,
                scriptureReference: entry.scriptureMentioned.isEmpty ? nil : entry.scriptureMentioned
            )
        }

        switch category {
        case .people:
            return people.shuffled()
        case .places:
            return places.shuffled()
        case .both:
            return (people + places).shuffled()
        }
    }

    private func parseBookName(from reference: String?) -> String? {
        guard let ref = reference, !ref.isEmpty else { return nil }
        let parts = ref.split { $0.isWhitespace }
        guard parts.count >= 2 else { return nil }
        let book = parts.dropLast().joined(separator: " ")
        return book
    }

    // MARK: - Game flow

    func startGame() {
        guard !isLoadingData else { return }
        let availableQuestions = reviewQuestionIDs.isEmpty
            ? makeQuestionDeck()
            : makeQuestionDeck().filter { reviewQuestionIDs.contains($0.id) }
        let deck = Array(availableQuestions.prefix(Self.questionsPerGame))
        guard !deck.isEmpty else { return }
        questionDeck = deck
        totalQuestions = deck.count
        questionNumber = 0
        score = 0
        answered = 0
        sessionStreak = 0
        sessionBestStreak = 0
        isNewBestGame = false
        currentBestStreak = persistentStreak.best
        phase = .playing
        nextRound()
    }

    func nextRound() {
        guard let question = questionDeck.popLast() else {
            showResults()
            return
        }

        currentQuestion = question
        questionNumber += 1
        roundOutcome = nil
        submittedBook = nil
        hintRevealed = false
        searchText = ""
        inputMessage = nil
        remainingSeconds = difficulty.roundTime
        isPulsing = false
        roundID += 1
    }

    private func showResults() {
        let previousBest = UserDefaults.standard.integer(forKey: bestGameScoreKey)
        isNewBestGame = score > previousBest
        bestGameScore = max(previousBest, score)
        if isNewBestGame {
            UserDefaults.standard.set(score, forKey: bestGameScoreKey)
        }
        currentQuestion = nil
        phase = .results
    }

    func resetGameSession() {
        phase = .setup
        roundOutcome = nil
        currentQuestion = nil
        remainingSeconds = 0
        questionDeck = []
        searchText = ""
        inputMessage = nil
    }

    private func tick() {
        guard remainingSeconds > 0 else { return }
        isPulsing = true
        #if canImport(UIKit)
        if remainingSeconds <= 5 {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        #endif
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            isPulsing = false
        }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            finishRound(.timedOut)
        }
    }

    func revealHint() {
        guard canRequestHint else { return }
        hintRevealed = true
        remainingSeconds -= BeatTheClockDifficulty.hintCost
    }

    // MARK: - Answers

    func clearInput() {
        searchText = ""
    }

    func submitCurrentEntry() {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !selectionLocked else { return }

        // Accept an exact name (or common variant), or the only suggestion left.
        let suggestions = filteredBooks
        guard let bookName = BibleBookNameMatcher.canonicalName(for: text, in: BibleCanon.canonicalOrder())
                ?? (suggestions.count == 1 ? suggestions.first : nil) else {
            inputMessage = String(localized: "“\(text)” isn’t a book of the Bible.")
            #if canImport(UIKit)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            #endif
            return
        }
        submit(bookName: bookName)
    }

    func submit(bookName: String) {
        guard !selectionLocked, let currentQuestion else { return }
        searchText = bookName
        let correct = currentQuestion.acceptableBooks.contains(bookName)
        finishRound(correct ? .correct : .incorrect, submittedBook: bookName)
    }

    /// Debug-only shortcut that counts the current round as correct.
    func debugWin() {
        finishRound(.correct)
    }

    /// Records the answer (or timeout) on the current question, so it can't be answered again.
    private func finishRound(_ outcome: BeatTheClockRoundOutcome, submittedBook: String? = nil) {
        guard !selectionLocked, let currentQuestion else { return }
        roundOutcome = outcome
        self.submittedBook = submittedBook
        answered += 1

        let correct = outcome == .correct
        if correct {
            score += 1
            sessionStreak += 1
            sessionBestStreak = max(sessionBestStreak, sessionStreak)
            // Persistent streak: extend on correct
            let streak = persistentStreak.recordWin()
            currentBestStreak = max(currentBestStreak, streak.best)
        } else {
            // Persistent streak: reset on incorrect or timeout
            sessionStreak = 0
            persistentStreak.reset()
        }

        GameStats.shared.recordRound(
            game: .beatclock,
            difficulty: difficulty.statsDifficulty,
            correct: correct ? 1 : 0,
            answered: 1,
            currentBestStreak: currentBestStreak
        )
        GameStats.shared.recordBeatClockType(
            type: currentQuestion.subject == .person ? "People" : "Places",
            answered: 1,
            correct: correct ? 1 : 0
        )
        if correct, !reviewQuestionIDs.isEmpty {
            MissedGameQuestionStore.shared.resolveReviewQuestion(game: .beatTheClock, questionID: currentQuestion.id)
        } else if !correct {
            let scriptureReference: ScriptureRef?
            if let referenceText = currentQuestion.scriptureReference {
                scriptureReference = BibleReferenceLinker.parse(referenceText)
            } else {
                scriptureReference = nil
            }
            MissedGameQuestionStore.shared.record(
                game: .beatTheClock,
                bookNames: scriptureReference.map { [$0.bookName] } ?? Array(currentQuestion.acceptableBooks),
                chapterNumber: scriptureReference?.chapter,
                topic: currentQuestion.subject == .person ? "Bible people" : "Bible places",
                questionID: currentQuestion.id
            )
        }

        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
        #endif
    }
}
