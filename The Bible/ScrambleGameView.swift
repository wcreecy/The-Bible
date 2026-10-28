import SwiftUI

struct ScrambleGameView: View {
    private enum Phase {
        case setup
        case playing
        case results
    }

    enum Difficulty: String, CaseIterable, Identifiable {
        case easy
        case normal
        case hard

        var id: Self { self }

        var experienceLevel: GameExperienceLevel {
            switch self {
            case .easy: .learn
            case .normal: .standard
            case .hard: .challenge
            }
        }

        init(experienceLevel: GameExperienceLevel) {
            switch experienceLevel {
            case .learn: self = .easy
            case .standard: self = .normal
            case .challenge: self = .hard
            }
        }

        var timeLimit: Int? {
            switch self {
            case .easy: nil
            case .normal: 30
            case .hard: 15
            }
        }

        var timerLabel: String {
            switch self {
            case .easy: String(localized: "No timer")
            case .normal: String(localized: "30 seconds")
            case .hard: String(localized: "15 seconds")
            }
        }

        var detail: LocalizedStringKey {
            switch self {
            case .easy: "Familiar words with no timer."
            case .normal: "A broader word list with 30 seconds per word."
            case .hard: "Tougher words with 15 seconds per word."
            }
        }

        var statsDifficulty: GameStats.Difficulty {
            switch self {
            case .easy: .easy
            case .normal: .normal
            case .hard: .hard
            }
        }
    }

    private struct ScrambleWord: Identifiable {
        enum Level: Int {
            case easy
            case normal
            case hard

            init?(difficulty: String) {
                switch difficulty.lowercased() {
                case "easy": self = .easy
                case "normal", "medium": self = .normal
                case "hard": self = .hard
                default: return nil
                }
            }
        }

        let answer: String
        let category: LocalizedStringKey
        let reference: LocalizedStringKey?
        let level: Level

        var id: String { answer }

        init?(_ entry: ScrambleWordEntry) {
            guard let level = Level(difficulty: entry.difficulty), !entry.answer.isEmpty else { return nil }
            let reference = entry.reference?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.answer = entry.answer
            self.category = LocalizedStringKey(entry.category)
            self.reference = reference.isEmpty ? nil : LocalizedStringKey(reference)
            self.level = level
        }
    }

    private static let wordsPerSession = 10

    @AppStorage("scrambleDifficulty") private var difficulty: Difficulty = .normal

    @State private var phase: Phase = .setup
    @State private var wordBank: [ScrambleWord] = []
    @State private var deck: [ScrambleWord] = []
    @State private var currentWord: ScrambleWord?
    @State private var shuffledLetters: [Character] = []
    @State private var selectedIndices: [Int] = []
    @State private var typedAnswer = ""
    @State private var currentNumber = 0
    @State private var correctCount = 0
    @State private var answeredCount = 0
    @State private var currentStreak = 0
    @State private var bestStreak = 0
    @State private var didRecordStats = false
    @State private var timeRemaining = 0
    @State private var answerFeedback: AnswerFeedback?
    @State private var timerID = UUID()
    @FocusState private var isAnswerFieldFocused: Bool
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private enum AnswerFeedback {
        case correct
        case incorrect
        case timedOut
        case revealed

        var message: LocalizedStringKey {
            switch self {
            case .correct: "Correct!"
            case .incorrect: "Try again."
            case .timedOut: "Time's up."
            case .revealed: "Answer shown."
            }
        }

        var tint: Color {
            switch self {
            case .correct: .green
            case .incorrect: .orange
            case .timedOut: .red
            case .revealed: .secondary
            }
        }
    }

    private var experienceLevel: Binding<GameExperienceLevel> {
        Binding(
            get: { difficulty.experienceLevel },
            set: { difficulty = Difficulty(experienceLevel: $0) }
        )
    }

    private var selectedAnswer: String {
        typedAnswer
    }

    private var isLastWord: Bool {
        deck.isEmpty
    }

    private var isCurrentWordResolved: Bool {
        switch answerFeedback {
        case .correct, .timedOut, .revealed: true
        case .incorrect, nil: false
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                switch phase {
                case .setup:
                    startScreen
                case .playing:
                    gameScreen
                case .results:
                    resultsScreen
                }
            }
            .padding()
        }
        .tabBarContentClearance()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if phase != .setup {
                    GameNavigationTitle(
                        title: "Scramble",
                        systemImage: "text.line.first.and.arrowtriangle.forward",
                        tint: .pink
                    )
                }
            }
        }
        .task {
            await loadWordBank()
        }
        .task(id: timerID) {
            await runTimer()
        }
        .task(id: currentNumber) {
            guard phase == .playing, !isCurrentWordResolved else { return }
            isAnswerFieldFocused = true
        }
        .onDisappear {
            if phase != .setup {
                phase = .setup
            }
        }
    }

    private var startScreen: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 24)

            Text("Unscramble Bible names, places, books, and terms.")
                .gameStartDescriptionStyle(
                    title: "Scramble",
                    systemImage: "text.line.first.and.arrowtriangle.forward",
                    tint: .pink
                )

            GameSplashLaunchLayout(
                tint: .pink,
                experienceLevel: experienceLevel,
                experienceDetails: GameExperienceDetails(
                    learn: "Familiar words with no timer.",
                    standard: "A broader word list with 30 seconds per word.",
                    challenge: "Tougher words with 15 seconds per word."
                ),
                startAction: startSession
            ) {
                GameLobbyPreview(kind: .scramble)
            } configuration: {
                Text("Build each answer from the scrambled letter tiles.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } facts: {
                GameSplashFacts(
                    first: ("number", "\(Self.wordsPerSession) words", "This session"),
                    second: ("character.textbox", "Bible words", "People, places & books"),
                    third: ("timer", difficulty.timerLabel, "Per word")
                )
            }

            Spacer(minLength: 24)
        }
    }

    private var gameScreen: some View {
        VStack(spacing: 20) {
            if difficulty.timeLimit != nil {
                ScrambleTimer(timeRemaining: timeRemaining)
            }

            GameScoreboardCard(
                currentCorrect: correctCount,
                currentAnswered: answeredCount,
                currentStreak: currentStreak,
                game: .scramble,
                style: horizontalSizeClass == .regular ? .dashboard : .compact
            )

            if let currentWord {
                ScramblePrompt(
                    category: currentWord.category,
                    reference: difficulty == .easy ? currentWord.reference : nil,
                    letters: shuffledLetters
                )

                ScrambleAnswerInput(
                    answer: $typedAnswer,
                    answerLength: currentWord.answer.count,
                    isFocused: $isAnswerFieldFocused,
                    isDisabled: isCurrentWordResolved,
                    onSubmit: checkAnswer
                )

                if let answerFeedback {
                    Text(answerFeedback.message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(answerFeedback.tint)
                }

                ScrambleLetterTray(
                    letters: shuffledLetters,
                    selectedIndices: selectedIndices,
                    onSelect: selectLetter
                )
                .disabled(isCurrentWordResolved)

                HStack(spacing: 12) {
                    Button("Clear", systemImage: "delete.left") {
                        selectedIndices.removeAll()
                        answerFeedback = nil
                    }
                    .buttonStyle(.bordered)
                    .disabled(typedAnswer.isEmpty || isCurrentWordResolved)

                    Button("Shuffle", systemImage: "shuffle") {
                        shuffleUnusedLetters()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isCurrentWordResolved || shuffledLetters.count - selectedIndices.count < 2)

                    if isCurrentWordResolved {
                        Button("Next Word", systemImage: "arrow.right") {
                            loadNextWord()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                    } else {
                        Button("Check Answer", systemImage: "checkmark") {
                            checkAnswer()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                        .disabled(typedAnswer.count != currentWord.answer.count)
                    }
                }
                .controlSize(.large)

                if difficulty == .easy, !isCurrentWordResolved {
                    Button("Show Answer", systemImage: "lightbulb") {
                        revealAnswer()
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                }
            }
        }
        .frame(maxWidth: 620)
        .padding(.top, 8)
    }

    private var resultsScreen: some View {
        ContentUnavailableView {
            Label("Session Complete", systemImage: "checkmark.seal.fill")
        } description: {
            Text("You solved \(correctCount) of \(Self.wordsPerSession) words.")
        } actions: {
            Button("Play Again", systemImage: "arrow.clockwise") {
                startSession()
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)

            Button("Change Settings") {
                phase = .setup
            }
        }
        .padding(.top, 72)
    }

    private func loadWordBank() async {
        guard wordBank.isEmpty else { return }
        wordBank = await GameDataLoaders.loadScrambleWordsAsync().compactMap(ScrambleWord.init)
    }

    private func startSession() {
        // Loading normally finishes while the start screen is showing; this covers an early tap.
        if wordBank.isEmpty {
            wordBank = GameDataLoaders.loadScrambleWords().compactMap(ScrambleWord.init)
        }

        let eligible = wordBank.filter { word in
            switch difficulty {
            case .easy: word.level == .easy
            case .normal: word.level == .easy || word.level == .normal
            case .hard: true
            }
        }

        guard !eligible.isEmpty else { return }

        deck = Array(eligible.shuffled().prefix(Self.wordsPerSession))
        currentNumber = 0
        correctCount = 0
        answeredCount = 0
        currentStreak = 0
        bestStreak = 0
        didRecordStats = false
        phase = .playing
        loadNextWord()
    }

    private func loadNextWord() {
        guard let next = deck.popLast() else {
            recordSessionStats()
            phase = .results
            timerID = UUID()
            return
        }

        currentWord = next
        currentNumber += 1
        shuffledLetters = scrambledLetters(for: next.answer)
        selectedIndices.removeAll()
        typedAnswer = ""
        answerFeedback = nil
        timeRemaining = difficulty.timeLimit ?? 0
        timerID = UUID()
    }

    private func selectLetter(_ index: Int) {
        guard !selectedIndices.contains(index),
              let currentWord,
              selectedIndices.count < currentWord.answer.count else {
            return
        }

        selectedIndices.append(index)
        typedAnswer.append(shuffledLetters[index])
        answerFeedback = nil
    }

    private func shuffleUnusedLetters() {
        let selected = Set(selectedIndices)
        let availableIndices = shuffledLetters.indices.filter { !selected.contains($0) }
        guard availableIndices.count > 1 else { return }

        let availableLetters = availableIndices.map { shuffledLetters[$0] }
        guard Set(availableLetters).count > 1 else { return }

        var rearranged = availableLetters.shuffled()
        if rearranged == availableLetters {
            rearranged = Array(availableLetters.dropFirst()) + [availableLetters[0]]
        }

        for (index, letter) in zip(availableIndices, rearranged) {
            shuffledLetters[index] = letter
        }
    }

    private func checkAnswer() {
        guard let currentWord, !isCurrentWordResolved else { return }

        guard selectedAnswer.uppercased() == currentWord.answer else {
            answerFeedback = .incorrect
            return
        }

        answeredCount += 1
        correctCount += 1
        currentStreak += 1
        bestStreak = max(bestStreak, currentStreak)
        answerFeedback = .correct
        isAnswerFieldFocused = false
        advanceAfterFeedback()
    }

    private func revealAnswer() {
        guard difficulty == .easy, let currentWord, !isCurrentWordResolved else { return }
        typedAnswer = currentWord.answer
        selectedIndices = Array(shuffledLetters.indices)
        answeredCount += 1
        currentStreak = 0
        answerFeedback = .revealed
        isAnswerFieldFocused = false
    }

    private func advanceAfterFeedback() {
        Task {
            try? await Task.sleep(for: .milliseconds(550))
            guard !Task.isCancelled, phase == .playing, !isCurrentWordResolved else { return }
            loadNextWord()
        }
    }

    private func runTimer() async {
        guard difficulty.timeLimit != nil, phase == .playing else { return }

        while !Task.isCancelled, phase == .playing, timeRemaining > 0 {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, phase == .playing else { return }

            timeRemaining -= 1
            if timeRemaining == 0 {
                answeredCount += 1
                currentStreak = 0
                answerFeedback = .timedOut
                isAnswerFieldFocused = false
                advanceAfterFeedback()
                return
            }
        }
    }

    private func recordSessionStats() {
        guard !didRecordStats else { return }
        didRecordStats = true
        GameStats.shared.recordRound(
            game: .scramble,
            difficulty: difficulty.statsDifficulty,
            correct: correctCount,
            answered: answeredCount,
            currentBestStreak: bestStreak
        )
    }

    private func scrambledLetters(for answer: String) -> [Character] {
        let letters = Array(answer)
        var result = letters.shuffled()

        while result == letters {
            result.shuffle()
        }

        return result
    }
}

private struct ScrambleTimer: View {
    let timeRemaining: Int

    var body: some View {
        Label("\(timeRemaining)s", systemImage: "timer")
            .font(.headline.monospacedDigit())
            .foregroundStyle(timeRemaining <= 5 ? .red : .secondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct ScramblePrompt: View {
    let category: LocalizedStringKey
    let reference: LocalizedStringKey?
    let letters: [Character]

    var body: some View {
        VStack(spacing: 10) {
            Text(category)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let reference {
                Label(reference, systemImage: "book.closed")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(String(letters).map(String.init).joined(separator: " "))
                .font(.title.weight(.bold).monospaced())
                .multilineTextAlignment(.center)
                .accessibilityLabel("Scrambled letters")
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color.pink.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ScrambleAnswerInput: View {
    @Binding var answer: String
    let answerLength: Int
    @FocusState.Binding var isFocused: Bool
    let isDisabled: Bool
    let onSubmit: () -> Void

    var body: some View {
        TextField("Type your answer", text: $answer)
            .font(.title2.weight(.semibold).monospaced())
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled(true)
            .submitLabel(.done)
            .focused($isFocused)
            .onSubmit(onSubmit)
            .onChange(of: answer) { _, newValue in
                let normalized = String(newValue.uppercased().filter(\.isLetter).prefix(answerLength))
                if normalized != newValue {
                    answer = normalized
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .textFieldStyle(.roundedBorder)
            .disabled(isDisabled)
            .accessibilityLabel("Answer")
            .accessibilityValue(answer.isEmpty ? "Empty" : answer)
    }
}

private struct ScrambleLetterTray: View {
    let letters: [Character]
    let selectedIndices: [Int]
    let onSelect: (Int) -> Void

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 52), spacing: 10)],
            spacing: 10
        ) {
            ForEach(letters.indices, id: \.self) { index in
                Button {
                    onSelect(index)
                } label: {
                    Text(String(letters[index]))
                        .font(.title3.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(.bordered)
                .tint(.pink)
                .disabled(selectedIndices.contains(index))
                .accessibilityLabel(String(letters[index]))
            }
        }
    }
}
