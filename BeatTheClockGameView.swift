import SwiftUI
import UIKit

struct BeatTheClockGameView: View {
    enum Difficulty: String, CaseIterable, Identifiable {
        case easy
        case normal
        case hard

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
                "Adds less familiar names. A clue costs \(BeatTheClockGameView.hintCost) seconds."
            case .hard:
                "Every name in the game. A clue costs \(BeatTheClockGameView.hintCost) seconds."
            }
        }
    }

    enum Category: String, CaseIterable, Identifiable {
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

    static let questionsPerGame = 10
    static let hintCost = 3

    private let reviewQuestionIDs: Set<String>

    init(reviewQuestionIDs: Set<String> = []) {
        self.reviewQuestionIDs = reviewQuestionIDs
    }

    private enum Phase {
        case setup
        case playing
        case results
    }

    private struct Question: Identifiable {
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

    @State private var phase: Phase = .setup
    @AppStorage("beatTheClockDifficulty") private var difficulty: Difficulty = .normal
    @AppStorage("beatTheClockCategory") private var category: Category = .people

    private var experienceLevel: Binding<GameExperienceLevel> {
        Binding(
            get: {
                switch difficulty {
                case .easy: .learn
                case .normal: .standard
                case .hard: .challenge
                }
            },
            set: { level in
                difficulty = switch level {
                case .learn: .easy
                case .standard: .normal
                case .challenge: .hard
                }
            }
        )
    }

    // Global Auto‑Win debug toggle
    @AppStorage("debugAutoWinEnabled") private var debugAutoWinEnabled: Bool = false

    // Data
    @State private var loadedPeople: [BibleCharacter] = []
    @State private var loadedPlaces: [BibleLocationChallenge] = []
    /// Every book whose text mentions each place, keyed by place ID. Nil until indexed.
    @State private var placeBooks: [Int: Set<String>]?
    @State private var questionDeck: [Question] = []

    // Current round
    @State private var currentQuestion: Question?
    @State private var questionNumber: Int = 0
    @State private var totalQuestions: Int = 0
    @State private var roundID: Int = 0
    @State private var remainingSeconds: Int = 0
    @State private var roundOutcome: BeatTheClockRoundOutcome?
    @State private var submittedBook: String?
    @State private var hintRevealed: Bool = false

    // Scoring
    @State private var score: Int = 0
    @State private var answered: Int = 0
    @State private var sessionStreak: Int = 0
    @State private var sessionBestStreak: Int = 0
    @State private var currentBestStreak: Int = 0
    @State private var bestGameScore: Int = 0
    @State private var isNewBestGame: Bool = false

    // Answer entry
    @State private var searchText: String = ""
    @State private var inputMessage: String?
    @FocusState private var searchFieldFocused: Bool
    @State private var showAnswers: Bool = false
    @State private var pulse: Bool = false
    @State private var timerOnLeft: Bool = false
    @State private var usesMutedTimerStyle: Bool = false

    private var selectionLocked: Bool { roundOutcome != nil }

    private var isLoadingData: Bool {
        loadedPeople.isEmpty || loadedPlaces.isEmpty || placeBooks == nil
    }

    private var peopleForSelectedDifficulty: [BibleCharacter] {
        loadedPeople.filter { matchesSelectedDifficulty($0.difficulty) }
    }

    private var placesForSelectedDifficulty: [BibleLocationChallenge] {
        loadedPlaces.filter { matchesSelectedDifficulty($0.difficulty) }
    }

    private var filteredBooks: [String] {
        BibleBookNameMatcher.suggestions(for: searchText, in: BibleCanon.canonicalOrder())
    }

    private var canSubmit: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !selectionLocked && !trimmed.isEmpty
    }

    private var showsClue: Bool {
        difficulty.showsClueAutomatically || hintRevealed || selectionLocked
    }

    private var canRequestHint: Bool {
        !selectionLocked && remainingSeconds > Self.hintCost
    }

    private var sortedAcceptableBooks: [String] {
        guard let currentQuestion else { return [] }
        let order = Dictionary(uniqueKeysWithValues: BibleCanon.canonicalOrder().enumerated().map { ($1, $0) })
        return currentQuestion.acceptableBooks.sorted { (order[$0] ?? Int.max) < (order[$1] ?? Int.max) }
    }

    private var isLastQuestion: Bool { questionDeck.isEmpty }

    // MARK: - Persistent streak (per difficulty)
    private var persistentStreak: PersistentGameStreak {
        PersistentGameStreak(game: "beatclock", variant: difficulty.rawValue)
    }

    private var bestGameScoreKey: String { "beatclockBestGameScore_\(difficulty.rawValue)" }

    var body: some View {
        GeometryReader { geometry in
            let usesSplitLayout = phase == .playing && geometry.size.width >= 700

            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        switch phase {
                        case .setup:
                            setupContent
                        case .playing:
                            if usesSplitLayout {
                                dashboard(availableHeight: geometry.size.height - 32)
                            } else {
                                compactGameContent
                            }
                        case .results:
                            Spacer(minLength: 32)
                            BeatTheClockResultsCard(
                                score: score,
                                total: totalQuestions,
                                bestStreak: sessionBestStreak,
                                bestGameScore: bestGameScore,
                                isNewBest: isNewBestGame,
                                onPlayAgain: startGame,
                                onChangeSettings: resetGameSession
                            )
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                }
                .tabBarContentClearance()
                .frame(width: usesSplitLayout ? geometry.size.width / 2 : geometry.size.width)
                .frame(
                    maxWidth: .infinity,
                    alignment: usesSplitLayout && timerOnLeft ? .trailing : .leading
                )

                if usesSplitLayout {
                    BeatTheClockLargeTimerView(
                        remainingSeconds: remainingSeconds,
                        tint: timerColor,
                        isPulsing: pulse,
                        outcome: roundOutcome,
                        usesMutedStyle: $usesMutedTimerStyle,
                        onSwapSides: {
                            withAnimation(.snappy) {
                                timerOnLeft.toggle()
                            }
                        }
                    )
                    .frame(width: geometry.size.width / 2)
                    .frame(maxWidth: .infinity, alignment: timerOnLeft ? .leading : .trailing)
                }
            }
        }
        .background(AppBackgroundView(tab: .games))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if phase != .setup {
                    GameNavigationTitle(title: "Countdown", systemImage: "hourglass", tint: .indigo)
                }
            }
        }
        .task {
            await loadData()
        }
        .onAppear {
            currentBestStreak = persistentStreak.best
        }
        .onChange(of: difficulty) { _, _ in
            currentBestStreak = persistentStreak.best
        }
        .onChange(of: searchText) { _, _ in
            inputMessage = nil
        }
        .onDisappear {
            // Leaving after answering begins a new game session on return.
            if phase != .setup && answered > 0 {
                resetGameSession()
            }
        }
        // Restarts with each round so the first second is a full second.
        .task(id: roundID) {
            while !Task.isCancelled, phase == .playing, roundOutcome == nil, remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, phase == .playing, roundOutcome == nil else { return }
                tick()
            }
        }
        .sheet(isPresented: $showAnswers) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    if sortedAcceptableBooks.isEmpty {
                        Text("No matches found in the Bible text for this entry.")
                            .foregroundStyle(.secondary)
                    } else {
                        List(sortedAcceptableBooks, id: \.self) { name in
                            Text(name)
                        }
                        .listStyle(.insetGrouped)
                    }
                    Spacer(minLength: 0)
                }
                .padding()
                .navigationTitle("Acceptable Books")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showAnswers = false } } }
            }
        }
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupContent: some View {
        Spacer(minLength: 32)
        Text("Type a Bible book that mentions the shown person or place before the timer runs out.")
            .gameStartDescriptionStyle(title: "Countdown", systemImage: "hourglass", tint: .indigo)

        GameSplashLaunchLayout(
            tint: .indigo,
            experienceLevel: experienceLevel,
            experienceDetails: GameExperienceDetails(
                learn: "Known names • 25 sec.",
                standard: "More names • 15 sec.",
                challenge: "All names • 10 sec."
            ),
            experienceTitle: reviewQuestionIDs.isEmpty ? "How you’ll play" : "Timer",
            isConfigurationEnabled: reviewQuestionIDs.isEmpty,
            isStartEnabled: !isLoadingData,
            startAction: startGame
        ) {
            GameLobbyPreview(kind: .beatTheClock)
        } configuration: {
            BeatTheClockSetupControls(category: $category)
                .frame(maxWidth: 620)
                .padding(.horizontal)

            if isLoadingData {
                Label("Loading questions…", systemImage: "hourglass")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        } facts: {
            GameSplashFacts(
                first: ("number", "\(Self.questionsPerGame)", String(localized: "Questions")),
                second: ("timer", "\(difficulty.roundTime) sec", String(localized: "Per question")),
                third: (
                    "lightbulb",
                    difficulty.showsClueAutomatically ? String(localized: "Shown") : String(localized: "−\(Self.hintCost) sec"),
                    String(localized: "Clues")
                )
            )
        }

        Spacer(minLength: 32)
    }

    // MARK: - Gameplay layouts

    private var progressText: String {
        String(localized: "Question \(questionNumber) of \(totalQuestions)")
    }

    private var targetType: String {
        currentQuestion?.subject == .place ? String(localized: "Place") : String(localized: "Person")
    }

    private var clueRow: BeatTheClockClueRow {
        BeatTheClockClueRow(
            clue: currentQuestion?.clue ?? "",
            isRevealed: showsClue,
            canRequestHint: canRequestHint,
            onRequestHint: revealHint
        )
    }

    @ViewBuilder
    private var roundResult: some View {
        if let roundOutcome, let currentQuestion {
            BeatTheClockRoundResultCard(
                outcome: roundOutcome,
                subjectName: currentQuestion.label,
                submittedBook: submittedBook,
                acceptableBooks: sortedAcceptableBooks,
                scriptureReference: currentQuestion.scriptureReference,
                onShowAllAnswers: { showAnswers = true }
            )
        }
    }

    @ViewBuilder
    private var compactGameContent: some View {
        GameScoreboardCard(
            currentCorrect: score,
            currentAnswered: answered,
            currentStreak: sessionStreak,
            game: .beatclock
        )

        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(targetType) · \(progressText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(currentQuestion?.label ?? "")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                clueRow
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    selectionLocked ? Color.primary.opacity(0.12) : timerColor,
                    lineWidth: selectionLocked ? 1 : 2
                )
        )
        .animation(.easeInOut(duration: 0.25), value: remainingSeconds)

        if selectionLocked {
            roundResult
        } else {
            GameTimerCard(
                remainingSeconds: remainingSeconds,
                tint: timerColor,
                isPulsing: pulse
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Type a Bible book")
                    .font(.headline)
                HStack(spacing: 8) {
                    TextField("Start typing…", text: $searchText)
                        .textInputAutocapitalization(.words)
                        .disableAutocorrection(true)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { submitCurrentEntry() }
                        .focused($searchFieldFocused)

                    Button(action: clearInput) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.secondary : Color.red)
                    .disabled(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Clear input")
                }

                if let inputMessage {
                    Label(inputMessage, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                if !filteredBooks.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(filteredBooks.prefix(8), id: \.self) { name in
                            Button {
                                submit(bookName: name)
                            } label: {
                                Text(name)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .contentShape(Rectangle())
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(.secondarySystemBackground))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }

        BeatTheClockActions(
            isLocked: selectionLocked,
            canSubmit: canSubmit,
            isLastQuestion: isLastQuestion,
            showsDebugWin: debugAutoWinEnabled,
            onSubmit: submitCurrentEntry,
            onNext: nextRound,
            onDebugWin: { finishRound(.correct) }
        )
    }

    private func dashboard(availableHeight: CGFloat) -> some View {
        VStack(spacing: 18) {
            GameScoreboardCard(
                currentCorrect: score,
                currentAnswered: answered,
                currentStreak: sessionStreak,
                game: .beatclock,
                style: .dashboard
            )

            BeatTheClockDashboardPrompt(
                targetType: targetType,
                isPlace: currentQuestion?.subject == .place,
                progressText: progressText,
                targetLabel: currentQuestion?.label ?? "",
                clueRow: clueRow,
                tint: timerColor,
                isLocked: selectionLocked
            )

            if selectionLocked {
                roundResult
            } else {
                BeatTheClockDashboardAnswer(
                    searchText: $searchText,
                    searchFieldFocused: $searchFieldFocused,
                    filteredBooks: Array(filteredBooks.prefix(8)),
                    inputMessage: inputMessage,
                    onClear: clearInput,
                    onSubmit: submitCurrentEntry,
                    onSelectBook: { submit(bookName: $0) }
                )
            }

            Spacer(minLength: 0)

            BeatTheClockActions(
                isLocked: selectionLocked,
                canSubmit: canSubmit,
                isLastQuestion: isLastQuestion,
                showsDebugWin: debugAutoWinEnabled,
                onSubmit: submitCurrentEntry,
                onNext: nextRound,
                onDebugWin: { finishRound(.correct) }
            )
        }
        .padding(.horizontal, AppDesignMetrics.cardPadding)
        .padding(.bottom, AppDesignMetrics.cardPadding)
        .padding(.top, AppDesignMetrics.cardPadding + 12)
        .frame(maxWidth: .infinity, minHeight: availableHeight, alignment: .top)
        .heroCardSurface()
    }

    /// Green, then yellow, then red as the round runs down, scaled to the round length.
    private var timerColor: Color {
        let fraction = Double(remainingSeconds) / Double(max(1, difficulty.roundTime))
        if fraction <= 0.3 { return .red }
        if fraction <= 0.6 { return .yellow }
        return .green
    }

    // MARK: - Data

    private func loadData() async {
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

    // MARK: - Game flow

    private func startGame() {
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

    private func nextRound() {
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
        pulse = false
        roundID += 1
        DispatchQueue.main.async {
            self.searchFieldFocused = true
        }
    }

    private func showResults() {
        let previousBest = UserDefaults.standard.integer(forKey: bestGameScoreKey)
        isNewBestGame = score > previousBest
        bestGameScore = max(previousBest, score)
        if isNewBestGame {
            UserDefaults.standard.set(score, forKey: bestGameScoreKey)
        }
        currentQuestion = nil
        searchFieldFocused = false
        phase = .results
    }

    private func resetGameSession() {
        phase = .setup
        roundOutcome = nil
        currentQuestion = nil
        remainingSeconds = 0
        questionDeck = []
        searchText = ""
        inputMessage = nil
        searchFieldFocused = false
    }

    private func tick() {
        guard remainingSeconds > 0 else { return }
        pulse = true
        if remainingSeconds <= 5 {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            pulse = false
        }
        remainingSeconds -= 1
        if remainingSeconds == 0 {
            finishRound(.timedOut)
        }
    }

    private func revealHint() {
        guard canRequestHint else { return }
        hintRevealed = true
        remainingSeconds -= Self.hintCost
    }

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

    private func makeQuestionDeck() -> [Question] {
        let sourcePeople = reviewQuestionIDs.isEmpty ? peopleForSelectedDifficulty : loadedPeople
        let sourcePlaces = reviewQuestionIDs.isEmpty ? placesForSelectedDifficulty : loadedPlaces
        let people = sourcePeople.map { entry in
            Question(
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
            return Question(
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

    // MARK: - Answers

    private func clearInput() {
        searchText = ""
        searchFieldFocused = true
    }

    private func submitCurrentEntry() {
        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !selectionLocked else { return }

        // Accept an exact name (or common variant), or the only suggestion left.
        let suggestions = filteredBooks
        guard let bookName = BibleBookNameMatcher.canonicalName(for: text, in: BibleCanon.canonicalOrder())
                ?? (suggestions.count == 1 ? suggestions.first : nil) else {
            inputMessage = String(localized: "“\(text)” isn’t a book of the Bible.")
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        submit(bookName: bookName)
    }

    private func submit(bookName: String) {
        guard !selectionLocked, let currentQuestion else { return }
        searchText = bookName
        let correct = currentQuestion.acceptableBooks.contains(bookName)
        finishRound(correct ? .correct : .incorrect, submittedBook: bookName)
    }

    private func finishRound(_ outcome: BeatTheClockRoundOutcome, submittedBook: String? = nil) {
        guard !selectionLocked, let currentQuestion else { return }
        roundOutcome = outcome
        self.submittedBook = submittedBook
        searchFieldFocused = false
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
            difficulty: mapDifficulty(difficulty),
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

        UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
    }

    private func parseBookName(from reference: String?) -> String? {
        guard let ref = reference, !ref.isEmpty else { return nil }
        let parts = ref.split { $0.isWhitespace }
        guard parts.count >= 2 else { return nil }
        let book = parts.dropLast().joined(separator: " ")
        return book
    }

    private func mapDifficulty(_ d: Difficulty) -> GameStats.Difficulty {
        switch d {
        case .easy: return .easy
        case .normal: return .normal
        case .hard: return .hard
        }
    }
}

private enum BeatTheClockRoundOutcome {
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

// MARK: - Answer matching

/// Turns typed text into a canonical book name and ranks autocomplete suggestions.
enum BibleBookNameMatcher {
    private static let ordinalPrefixes: [String: String] = [
        "i": "1", "1st": "1", "first": "1",
        "ii": "2", "2nd": "2", "second": "2",
        "iii": "3", "3rd": "3", "third": "3"
    ]

    /// Common alternate names, keyed and valued by normalized form.
    private static let aliases: [String: String] = [
        "psalm": "psalms",
        "songofsongs": "songofsolomon",
        "canticles": "songofsolomon",
        "revelations": "revelation",
        "actsoftheapostles": "acts"
    ]

    /// Lowercases, turns a leading "I", "II", "First", etc. into a digit, and drops spaces and punctuation.
    static func normalized(_ text: String) -> String {
        var words = text.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
        if words.count > 1, let digit = ordinalPrefixes[words[0]] {
            words[0] = digit
        }
        return words.joined()
    }

    static func canonicalName(for input: String, in bookNames: [String]) -> String? {
        var key = normalized(input)
        guard !key.isEmpty else { return nil }
        key = aliases[key] ?? key
        return bookNames.first { normalized($0) == key }
    }

    /// Books matching the typed text in canonical order: names that start with it,
    /// then names with a word that starts with it, then names that contain it.
    static func suggestions(for input: String, in bookNames: [String]) -> [String] {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = normalized(text)
        guard !key.isEmpty else { return [] }
        let lowercasedText = text.lowercased()

        var startsWith: [String] = []
        var wordStartsWith: [String] = []
        var contains: [String] = []
        for name in bookNames {
            if normalized(name).hasPrefix(key) {
                startsWith.append(name)
            } else if name.lowercased().split(separator: " ").contains(where: { $0.hasPrefix(lowercasedText) }) {
                wordStartsWith.append(name)
            } else if name.localizedCaseInsensitiveContains(text) {
                contains.append(name)
            }
        }
        return startsWith + wordStartsWith + contains
    }
}

/// Finds every book whose text mentions a place by name.
nonisolated enum BeatTheClockAnswerIndex {
    /// Drops a description in parentheses, e.g. "Jordan (river)" → "Jordan", then
    /// splits into lowercased words. Hyphenated names also get a joined form because
    /// the KJV usually writes them as one word ("Kadesh-barnea" → "kadeshbarnea").
    static func searchPhrases(for name: String) -> [[String]] {
        let base = name.components(separatedBy: " (").first ?? name
        var phrases = [words(in: base)]
        if base.contains("-") {
            phrases.append(words(in: base.replacingOccurrences(of: "-", with: "")))
        }
        return phrases.filter { !$0.isEmpty }
    }

    static func words(in text: String) -> [String] {
        text.lowercased().split { !$0.isLetter }.map(String.init)
    }

    static func booksMentioning(_ places: [(id: Int, name: String)], in books: [Book]) -> [Int: Set<String>] {
        let phrasesByPlace = places.map { place in
            (id: place.id, phrases: searchPhrases(for: place.name).map { $0.joined(separator: " ") })
        }
        let allPhrases = phrasesByPlace.flatMap(\.phrases)
        let maxLength = allPhrases.map { $0.split(separator: " ").count }.max() ?? 1
        // Only phrases that begin with one of these words can match, which keeps the index small.
        let firstWords = Set(allPhrases.compactMap { $0.split(separator: " ").first.map(String.init) })

        var result: [Int: Set<String>] = [:]
        for book in books {
            let bookWords = book.chapters.flatMap { chapter in
                chapter.verses.flatMap { words(in: $0.text) }
            }

            var bookPhrases: Set<String> = []
            for start in bookWords.indices where firstWords.contains(bookWords[start]) {
                var phrase = bookWords[start]
                bookPhrases.insert(phrase)
                for offset in 1..<maxLength where start + offset < bookWords.count {
                    phrase += " " + bookWords[start + offset]
                    bookPhrases.insert(phrase)
                }
            }

            for place in phrasesByPlace where place.phrases.contains(where: bookPhrases.contains) {
                result[place.id, default: []].insert(book.name)
            }
        }
        return result
    }
}

// MARK: - Setup views

private struct BeatTheClockConfigurationCard: View {
    @Binding var difficulty: BeatTheClockGameView.Difficulty
    @Binding var category: BeatTheClockGameView.Category
    let minimumHeight: CGFloat?

    init(
        difficulty: Binding<BeatTheClockGameView.Difficulty>,
        category: Binding<BeatTheClockGameView.Category>,
        minimumHeight: CGFloat? = nil
    ) {
        _difficulty = difficulty
        _category = category
        self.minimumHeight = minimumHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BeatTheClockSetupControls(category: $category)

            Spacer(minLength: 0)

            Divider()

            HStack(spacing: 8) {
                BeatTheClockGameFact(
                    icon: "number",
                    value: Text("\(BeatTheClockGameView.questionsPerGame)"),
                    label: "Questions"
                )

                BeatTheClockGameFact(
                    icon: "timer",
                    value: Text("\(difficulty.roundTime) sec"),
                    label: "Per question"
                )

                BeatTheClockGameFact(
                    icon: "lightbulb",
                    value: difficulty.showsClueAutomatically
                        ? Text("Shown")
                        : Text("−\(BeatTheClockGameView.hintCost) sec"),
                    label: "Clues"
                )
            }
        }
        .padding(16)
        .frame(
            maxWidth: .infinity,
            minHeight: minimumHeight,
            alignment: .topLeading
        )
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
    }
}

private struct BeatTheClockGameFact: View {
    let icon: String
    let value: Text
    let label: LocalizedStringResource

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.tint)

            value
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .background(
            Color.secondary.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct BeatTheClockSetupControls: View {
    @Binding var category: BeatTheClockGameView.Category

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Question Subject", systemImage: "person.2.fill")
                .font(.headline)
                .foregroundStyle(.indigo)

            HStack(alignment: .top, spacing: 8) {
                ForEach(BeatTheClockGameView.Category.allCases) { option in
                    BeatTheClockSubjectOption(
                        category: option,
                        isSelected: category == option
                    ) {
                        category = option
                    }
                }
            }
        }
    }
}

private struct BeatTheClockSubjectOption: View {
    let category: BeatTheClockGameView.Category
    let isSelected: Bool
    let action: () -> Void

    private var systemImage: String {
        switch category {
        case .people: "person.fill"
        case .places: "mappin.and.ellipse"
        case .both: "square.grid.2x2.fill"
        }
    }

    private var detail: LocalizedStringKey {
        switch category {
        case .people: "Questions about people in the Bible."
        case .places: "Questions about Biblical places."
        case .both: "A mixed round of people and places."
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                Image(systemName: systemImage)
                    .foregroundStyle(isSelected ? .white : .indigo)
                Text(category.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .gameSplashOptionCardSize()
            .background(
                isSelected ? Color.indigo : Color.indigo.opacity(0.09),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.indigo : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct BeatTheClockStartButton: View {
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                } else {
                    Image(systemName: "play.fill")
                        .font(.largeTitle)
                }
                Text("Start Game")
                    .font(.title2.weight(.semibold))
                Text(isLoading ? "Loading questions…" : "Begin your timed challenge.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(24)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(
            Color.indigo.gradient,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .opacity(isLoading ? 0.7 : 1)
        .disabled(isLoading)
        .accessibilityLabel("Start Game")
        .accessibilityHint("Begins a Countdown game")
    }
}

// MARK: - Gameplay views

private struct BeatTheClockClueRow: View {
    let clue: String
    let isRevealed: Bool
    let canRequestHint: Bool
    let onRequestHint: () -> Void

    var body: some View {
        if !clue.isEmpty {
            if isRevealed {
                Label(clue, systemImage: "lightbulb.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Button(
                    "Show clue (−\(BeatTheClockGameView.hintCost) sec)",
                    systemImage: "lightbulb",
                    action: onRequestHint
                )
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderless)
                .disabled(!canRequestHint)
            }
        }
    }
}

private struct BeatTheClockRoundResultCard: View {
    let outcome: BeatTheClockRoundOutcome
    let subjectName: String
    let submittedBook: String?
    let acceptableBooks: [String]
    let scriptureReference: String?
    let onShowAllAnswers: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(outcome.title, systemImage: outcome.systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(outcome.tint)

            if outcome == .incorrect, let submittedBook {
                Text("\(submittedBook) doesn’t mention \(subjectName).")
                    .font(.subheadline)
            }

            answerSummary
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            if let scriptureReference {
                Label("See \(scriptureReference)", systemImage: "book.closed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if acceptableBooks.count > 1 {
                Button("Show all \(acceptableBooks.count) books", systemImage: "books.vertical.fill", action: onShowAllAnswers)
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            outcome.tint.opacity(0.1),
            in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var answerSummary: some View {
        let count = acceptableBooks.count
        if count == 0 {
            Text("No books are listed for this entry.")
        } else if outcome == .correct {
            if count == 1 {
                Text("That’s the only book that mentions \(subjectName).")
            } else {
                Text("\(subjectName) appears in ^[\(count) book](inflect: true).")
            }
        } else if count == 1, let onlyBook = acceptableBooks.first {
            Text("The answer was \(onlyBook).")
        } else {
            Text("Answers include \(Array(acceptableBooks.prefix(3)).formatted(.list(type: .and))).")
        }
    }
}

private struct BeatTheClockActions: View {
    let isLocked: Bool
    let canSubmit: Bool
    let isLastQuestion: Bool
    let showsDebugWin: Bool
    let onSubmit: () -> Void
    let onNext: () -> Void
    let onDebugWin: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if isLocked {
                if isLastQuestion {
                    Button("See Results", systemImage: "flag.checkered", action: onNext)
                        .buttonStyle(GameProminentButtonStyle(tint: .indigo))
                } else {
                    Button("Next Question", systemImage: "arrow.right", action: onNext)
                        .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
                }
            } else {
                Button("Submit", systemImage: "paperplane.fill", action: onSubmit)
                    .buttonStyle(GameProminentButtonStyle(tint: .green))
                    .disabled(!canSubmit)
            }

            if showsDebugWin && !isLocked {
                Button("Win this round", systemImage: "checkmark.seal.fill", action: onDebugWin)
                    .buttonStyle(.glass(.regular.tint(.red)))
            }
        }
    }
}

private struct BeatTheClockDashboardPrompt: View {
    let targetType: String
    let isPlace: Bool
    let progressText: String
    let targetLabel: String
    let clueRow: BeatTheClockClueRow
    let tint: Color
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(targetType, systemImage: isPlace ? "mappin.and.ellipse" : "person.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .textCase(.uppercase)

                Spacer()

                Text(progressText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(targetLabel)
                .font(.largeTitle.weight(.bold))
                .fontDesign(.rounded)
                .lineLimit(2)

            Text("Name a Bible book that mentions this \(targetType.lowercased()).")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            clueRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(tint.opacity(isLocked ? 0.05 : 0.11), in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                .strokeBorder(isLocked ? Color.primary.opacity(0.12) : tint.opacity(0.8), lineWidth: isLocked ? 1 : 2)
        }
        .animation(.easeInOut(duration: 0.25), value: tint)
    }
}

private struct BeatTheClockDashboardAnswer: View {
    @Binding var searchText: String
    let searchFieldFocused: FocusState<Bool>.Binding
    let filteredBooks: [String]
    let inputMessage: String?
    let onClear: () -> Void
    let onSubmit: () -> Void
    let onSelectBook: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Your Answer", systemImage: "square.and.pencil")
                .font(.headline.weight(.bold))

            HStack(spacing: 10) {
                Image(systemName: "book.closed.fill")
                    .foregroundStyle(.tint)

                TextField("Type a Bible book…", text: $searchText)
                    .font(.title3.weight(.medium))
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .textFieldStyle(.plain)
                    .focused(searchFieldFocused)
                    .onSubmit(onSubmit)

                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Clear answer", systemImage: "xmark.circle.fill", action: onClear)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.red)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 58)
            .glassEffect(.regular, in: .rect(cornerRadius: AppDesignMetrics.compactControlCornerRadius))

            if let inputMessage {
                Label(inputMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            if !filteredBooks.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(filteredBooks, id: \.self) { name in
                        Button {
                            onSelectBook(name)
                        } label: {
                            Text(name)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 42)
                                .contentShape(Rectangle())
                                .background(
                                    .primary.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct BeatTheClockResultsCard: View {
    let score: Int
    let total: Int
    let bestStreak: Int
    let bestGameScore: Int
    let isNewBest: Bool
    let onPlayAgain: () -> Void
    let onChangeSettings: () -> Void

    private var accuracy: Int {
        guard total > 0 else { return 0 }
        return Int((Double(score) / Double(total) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isNewBest ? "trophy.fill" : "flag.checkered")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(isNewBest ? Color.yellow : Color.indigo)

            VStack(spacing: 6) {
                Text(isNewBest ? "New Best Game!" : "Game Over")
                    .font(.title.weight(.bold))

                Text("\(score) of \(total) correct")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                BeatTheClockGameFact(icon: "percent", value: Text("\(accuracy)%"), label: "Accuracy")
                BeatTheClockGameFact(icon: "flame.fill", value: Text("\(bestStreak)"), label: "Best streak")
                BeatTheClockGameFact(icon: "trophy", value: Text("\(bestGameScore)/\(total)"), label: "Best game")
            }

            VStack(spacing: 10) {
                Button("Play Again", systemImage: "arrow.clockwise", action: onPlayAgain)
                    .buttonStyle(GameProminentButtonStyle(tint: .indigo))

                Button("Change Settings", systemImage: "slider.horizontal.3", action: onChangeSettings)
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
            }
        }
        .padding(24)
        .frame(maxWidth: 520)
        .heroCardSurface()
    }
}

private struct BeatTheClockLargeTimerView: View {
    let remainingSeconds: Int
    let tint: Color
    let isPulsing: Bool
    let outcome: BeatTheClockRoundOutcome?
    @Binding var usesMutedStyle: Bool
    let onSwapSides: () -> Void

    private var timerTextColor: Color {
        tint == .yellow ? .black : .white
    }

    private var isActive: Bool { outcome == nil }

    private var displayTint: Color {
        outcome?.tint ?? tint
    }

    private var vividTextColor: Color {
        isActive ? timerTextColor : .white
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                Image(systemName: outcome?.systemImage ?? "timer")
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor.opacity(0.85))

                Text(outcome?.title ?? "Time Remaining")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor.opacity(0.85))

                if isActive {
                    Text("\(remainingSeconds)s")
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor)
                }
            }
            .scaleEffect(isPulsing ? 1.04 : 1.0)
            .animation(.easeOut(duration: 0.18), value: isPulsing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(outcome?.title ?? "Time Remaining")
            .accessibilityValue(isActive ? "\(remainingSeconds) seconds" : "")

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("Swap card sides", systemImage: "arrow.left.arrow.right", action: onSwapSides)

                Button(
                    usesMutedStyle ? "Use vivid timer background" : "Use muted timer background",
                    systemImage: "circle.lefthalf.filled"
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        usesMutedStyle.toggle()
                    }
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass(.clear))
            .controlSize(.small)
            .tint(usesMutedStyle ? displayTint : vividTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(
            usesMutedStyle ? Color.clear : displayTint,
            in: RoundedRectangle(
                cornerRadius: AppDesignMetrics.cardCornerRadius,
                style: .continuous
            )
        )
        .heroCardSurface()
        .padding(12)
        .animation(.easeInOut(duration: 0.25), value: remainingSeconds)
    }
}
