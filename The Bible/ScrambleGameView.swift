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
            case .easy: 45
            case .normal: 30
            case .hard: nil
            }
        }

        var timerLabel: String {
            switch self {
            case .easy: String(localized: "45 seconds")
            case .normal: String(localized: "30 seconds")
            case .hard: String(localized: "No timer")
            }
        }

        var hintLimit: Int {
            switch self {
            case .easy, .normal: 1
            case .hard: 2
            }
        }

        var hintLabel: String {
            switch hintLimit {
            case 1: String(localized: "1 hint")
            default: String(localized: "\(hintLimit) hints")
            }
        }

        var detail: LocalizedStringKey {
            switch self {
            case .easy: "Familiar words with 45 seconds per word."
            case .normal: "A broader word list with 30 seconds per word."
            case .hard: "Tougher words with no timer."
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
        let reference: String?
        let level: Level

        var id: String { answer }

        init?(_ entry: ScrambleWordEntry) {
            guard let level = Level(difficulty: entry.difficulty), !entry.answer.isEmpty else { return nil }
            let reference = entry.reference?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            self.answer = entry.answer
            self.category = LocalizedStringKey(entry.category)
            self.reference = reference.isEmpty ? nil : reference
            self.level = level
        }
    }

    enum SessionLength: Int, CaseIterable, Identifiable {
        case short = 5
        case quick = 10
        case extended = 20

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .short: "5 words"
            case .quick: "10 words"
            case .extended: "20 words"
            }
        }
    }

    @AppStorage("scrambleDifficulty") private var difficulty: Difficulty = .normal
    @AppStorage("scrambleSessionLength") private var sessionLength: SessionLength = .quick

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
    @State private var strikes = 0
    @State private var timeRemaining = 0
    @State private var answerFeedback: AnswerFeedback?
    @State private var timerID = UUID()
    @State private var hintLevel = 0
    @State private var recentlyPlayedAnswers: [String] = []
    @State private var isTimerDisabled = false
    @State private var timerOnLeft = false
    @State private var usesMutedTimerStyle = false
    @State private var selectedPassage: PassageReference?
    @State private var isRevealConfirmationPresented = false
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

    private var currentTimeLimit: Int? {
        difficulty.timeLimit
    }

    private var hintText: String? {
        guard hintLevel > 0, let currentWord else { return nil }
        let prefix = currentWord.answer.prefix(min(hintLevel, currentWord.answer.count))
        return "Starts with \(prefix)."
    }

    /// Matches Quiz: green above 60%, yellow down to 30%, then red.
    private var timerTint: Color {
        guard let timeLimit = currentTimeLimit else { return .secondary }
        let fractionRemaining = Double(timeRemaining) / Double(max(1, timeLimit))
        if fractionRemaining <= 0.3 { return .red }
        if fractionRemaining <= 0.6 { return .yellow }
        return .green
    }

    var body: some View {
        GeometryReader { geometry in
            let usesSplitLayout = phase == .playing && geometry.size.width >= 700

            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        switch phase {
                        case .setup:
                            startScreen
                        case .playing:
                            gameScreen(usesSplitLayout: usesSplitLayout)
                        case .results:
                            resultsScreen
                        }
                    }
                    .padding(.horizontal)
                }
                .tabBarContentClearance()
                .background {
                    if usesSplitLayout {
                        Color.clear
                            .heroCardSurface()
                            .padding(12)
                    }
                }
                .frame(width: usesSplitLayout ? geometry.size.width / 2 : geometry.size.width)
                .frame(
                    maxWidth: .infinity,
                    alignment: usesSplitLayout && timerOnLeft ? .trailing : .leading
                )

                if usesSplitLayout {
                    ScrambleLargeTimerView(
                        timeRemaining: timeRemaining,
                        timeLimit: currentTimeLimit,
                        tint: timerTint,
                        isTimerDisabled: isTimerDisabled,
                        usesMutedStyle: $usesMutedTimerStyle,
                        onToggleTimer: toggleTimer,
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
        .sheet(item: $selectedPassage) { reference in
            ScripturePassageSheet(reference: reference)
        }
        .confirmationDialog("Reveal answer?", isPresented: $isRevealConfirmationPresented, titleVisibility: .visible) {
            Button("Reveal & Next", role: .destructive) {
                revealAnswer()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The word will be marked incorrect, then the next word will begin.")
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
                    learn: "Familiar words with 45 seconds per word.",
                    standard: "A broader word list with 30 seconds per word.",
                    challenge: "Tougher words with no timer."
                ),
                startAction: startSession
            ) {
                GameLobbyPreview(kind: .scramble)
            } configuration: {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Build each answer from the scrambled letter tiles.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("Session length", selection: $sessionLength) {
                        ForEach(SessionLength.allCases) { length in
                            Text(length.title).tag(length)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } facts: {
                GameSplashFacts(
                    first: ("number", "\(sessionLength.rawValue) words", "This session"),
                    second: ("timer", difficulty.timerLabel, "Per word"),
                    third: ("lightbulb", difficulty.hintLabel, "Available"),
                    fourth: difficulty == .hard ? ("xmark.shield", "3 strikes", "Hard mode") : nil
                )
            }

            Spacer(minLength: 24)
        }
    }

    private func gameScreen(usesSplitLayout: Bool) -> some View {
        VStack(spacing: usesSplitLayout ? 18 : 20) {
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
                    reference: difficulty == .easy || isCurrentWordResolved ? currentWord.reference : nil,
                    answer: typedAnswer,
                    answerLength: currentWord.answer.count,
                    isResolved: isCurrentWordResolved,
                    timerTint: currentTimeLimit == nil || isTimerDisabled ? nil : timerTint,
                    onShowReference: showCurrentReference
                )

                if !usesSplitLayout, currentTimeLimit != nil {
                    GameTimerCard(
                        remainingSeconds: timeRemaining,
                        tint: isTimerDisabled ? .secondary : timerTint,
                        isPulsing: false,
                        formattedTime: isTimerDisabled ? "Timer off" : nil,
                        isDisabled: isTimerDisabled
                    )
                }

                if let answerFeedback {
                    Text(answerFeedback.message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(answerFeedback.tint)
                }

                if difficulty == .hard {
                    ScrambleStrikeIndicator(strikes: strikes, limit: 3)
                }

                ScrambleLetterTray(
                    letters: shuffledLetters,
                    selectedIndices: selectedIndices,
                    onSelect: selectLetter
                )
                .disabled(isCurrentWordResolved)

                if isCurrentWordResolved {
                    Button("Next Word", systemImage: "arrow.right") {
                        loadNextWord()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                } else {
                    HStack(spacing: 10) {
                        ScrambleActionButton(systemImage: "trash", accessibilityLabel: "Clear answer", isEnabled: !typedAnswer.isEmpty, action: clearAnswer)
                        ScrambleActionButton(systemImage: "delete.left", accessibilityLabel: "Remove last letter", isEnabled: !typedAnswer.isEmpty, action: removeLastLetter)
                        ScrambleActionButton(systemImage: "shuffle", accessibilityLabel: "Shuffle available letters", isEnabled: shuffledLetters.count - selectedIndices.count >= 2, action: shuffleUnusedLetters)
                        ScrambleActionButton(systemImage: "checkmark", accessibilityLabel: "Check answer", isEnabled: typedAnswer.count == currentWord.answer.count, isProminent: true, action: checkAnswer)
                    }
                    .padding(.top, 12)
                }

                if !isCurrentWordResolved {
                    HStack(spacing: 12) {
                        ScrambleGlassActionButton(
                            systemImage: "lightbulb.fill",
                            accessibilityLabel: hintLevel == 0 ? "Show hint" : "Show another hint",
                            isEnabled: hintLevel < min(difficulty.hintLimit, currentWord.answer.count),
                            tint: .yellow,
                            action: showHint
                        )

                        ScrambleGlassActionButton(
                            systemImage: "eye",
                            accessibilityLabel: "Show answer",
                            isEnabled: true,
                            tint: .blue,
                            action: { isRevealConfirmationPresented = true }
                        )
                    }
                    .padding(.top, 8)

                    if let hintText {
                        ScrambleHintCard(text: hintText)
                    }

                    if currentTimeLimit != nil {
                        Button(isTimerDisabled ? "Timer On" : "Timer Off", systemImage: isTimerDisabled ? "play.fill" : "pause.fill") {
                            toggleTimer()
                        }
                        .buttonStyle(.bordered)
                    }
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
            Text("You solved \(correctCount) of \(sessionLength.rawValue) words.")
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
            case .normal: word.level == .normal
            case .hard: word.level == .hard
            }
        }

        guard !eligible.isEmpty else { return }

        let unseen = eligible.filter { !recentlyPlayedAnswers.contains($0.answer) }
        let pool = unseen.count >= sessionLength.rawValue ? unseen : eligible
        deck = Array(pool.shuffled().prefix(sessionLength.rawValue))
        recentlyPlayedAnswers = Array((recentlyPlayedAnswers + deck.map(\.answer)).suffix(40))
        currentNumber = 0
        correctCount = 0
        answeredCount = 0
        currentStreak = 0
        bestStreak = 0
        strikes = 0
        hintLevel = 0
        isTimerDisabled = false
        phase = .playing
        loadNextWord()
    }

    private func loadNextWord() {
        guard let next = deck.popLast() else {
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
        hintLevel = 0
        strikes = 0
        timeRemaining = currentTimeLimit ?? 0
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

    private func removeLastLetter() {
        guard let index = selectedIndices.popLast() else { return }
        typedAnswer.removeLast()
        answerFeedback = nil
        _ = index
    }

    private func clearAnswer() {
        selectedIndices.removeAll()
        typedAnswer = ""
        answerFeedback = nil
    }

    private func showHint() {
        guard let currentWord, !isCurrentWordResolved else { return }
        hintLevel = min(hintLevel + 1, min(difficulty.hintLimit, currentWord.answer.count))
    }

    private func showCurrentReference() {
        guard let reference = currentWord?.reference else { return }
        selectedPassage = PassageReferenceParser.parse(reference)
    }

    private func toggleTimer() {
        guard currentTimeLimit != nil else { return }
        isTimerDisabled.toggle()
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
            if difficulty == .hard {
                strikes += 1
                if strikes >= 3 {
                    revealAnswerAfterStrikeLimit(for: currentWord)
                    return
                }
            }
            answerFeedback = .incorrect
            return
        }

        answeredCount += 1
        correctCount += 1
        currentStreak += 1
        bestStreak = max(bestStreak, currentStreak)
        recordWordResult(correct: true)
        answerFeedback = .correct
        advanceAfterFeedback()
    }

    private func revealAnswer() {
        guard let currentWord, !isCurrentWordResolved else { return }
        typedAnswer = currentWord.answer
        selectedIndices = Array(shuffledLetters.indices)
        answeredCount += 1
        currentStreak = 0
        recordWordResult(correct: false)
        answerFeedback = .revealed
    }

    private func revealAnswerAfterStrikeLimit(for word: ScrambleWord) {
        typedAnswer = word.answer
        selectedIndices = Array(shuffledLetters.indices)
        answeredCount += 1
        currentStreak = 0
        recordWordResult(correct: false)
        answerFeedback = .revealed
    }

    private func advanceAfterFeedback() {
        Task {
            try? await Task.sleep(for: .milliseconds(550))
            guard !Task.isCancelled, phase == .playing, !isCurrentWordResolved else { return }
            loadNextWord()
        }
    }

    private func runTimer() async {
        guard currentTimeLimit != nil, phase == .playing else { return }

        while !Task.isCancelled, phase == .playing, timeRemaining > 0 {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled, phase == .playing else { return }
            guard !isCurrentWordResolved else { return }
            guard !isTimerDisabled else { continue }

            timeRemaining -= 1
            if timeRemaining == 0 {
                revealTimedOutAnswer(for: currentWord)
                return
            }
        }
    }

    private func revealTimedOutAnswer(for word: ScrambleWord?) {
        guard let word else { return }
        typedAnswer = word.answer
        selectedIndices = Array(shuffledLetters.indices)
        answeredCount += 1
        currentStreak = 0
        recordWordResult(correct: false)
        answerFeedback = .timedOut
        advanceAfterFeedback()
    }

    private func recordWordResult(correct: Bool) {
        GameStats.shared.recordRound(
            game: .scramble,
            difficulty: difficulty.statsDifficulty,
            correct: correct ? 1 : 0,
            answered: 1,
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

private struct ScrambleLargeTimerView: View {
    let timeRemaining: Int
    let timeLimit: Int?
    let tint: Color
    let isTimerDisabled: Bool
    @Binding var usesMutedStyle: Bool
    let onToggleTimer: () -> Void
    let onSwapSides: () -> Void

    private var isTimed: Bool { timeLimit != nil }

    private var displayTint: Color { isTimerDisabled ? .secondary : tint }

    private var vividTextColor: Color { .white }

    private var usesNeutralStyle: Bool {
        usesMutedStyle || isTimerDisabled
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                Image(systemName: isTimerDisabled ? "timer.slash" : (isTimed ? "timer" : "infinity"))
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(usesNeutralStyle ? displayTint : vividTextColor.opacity(0.85))

                Text(isTimed ? (isTimerDisabled ? "Timer Off" : "Time Remaining") : "Untimed Mode")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(usesNeutralStyle ? displayTint : vividTextColor.opacity(0.85))

                Text(isTimed ? "\(timeRemaining)s" : "∞")
                    .font(.largeTitle.weight(.bold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(usesNeutralStyle ? displayTint : vividTextColor)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isTimerDisabled ? "Timer off" : (isTimed ? "\(timeRemaining) seconds remaining" : "No time limit"))

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("Swap card sides", systemImage: "arrow.left.arrow.right", action: onSwapSides)

                if isTimed {
                    Button(isTimerDisabled ? "Timer On" : "Timer Off", systemImage: isTimerDisabled ? "play.fill" : "pause.fill", action: onToggleTimer)
                }

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
            .tint(usesNeutralStyle ? displayTint : vividTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background {
            if usesNeutralStyle {
                Color.clear
                    .heroCardSurface()
            } else {
                RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                    .fill(displayTint)
            }
        }
        .overlay {
            if !usesNeutralStyle {
                RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(vividTextColor.opacity(0.22), lineWidth: 1)
            }
        }
        .shadow(color: usesNeutralStyle ? .clear : displayTint.opacity(0.25), radius: 12, x: 0, y: 5)
        .padding(12)
        .animation(.easeInOut(duration: 0.25), value: timeRemaining)
    }
}

private struct ScramblePrompt: View {
    let category: LocalizedStringKey
    let reference: String?
    let answer: String
    let answerLength: Int
    let isResolved: Bool
    let timerTint: Color?
    let onShowReference: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text(category)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if let reference {
                if isResolved {
                    Button(action: onShowReference) {
                        Label("Read \(reference)", systemImage: "book.closed")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.accentColor)
                    .accessibilityHint("Shows a preview of the source verse")
                } else {
                    Label(reference, systemImage: "book.closed")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text("Build the word from the letter tiles.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 28)

            ScrambleAnswerTiles(
                answer: answer,
                answerLength: answerLength,
                isResolved: isResolved
            )
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(UIColor.secondarySystemBackground), Color(UIColor.systemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(timerTint ?? Color.primary.opacity(0.12), lineWidth: timerTint == nil ? 1 : 2)
        }
    }
}

private struct ScrambleAnswerTiles: View {
    let answer: String
    let answerLength: Int
    let isResolved: Bool

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<answerLength, id: \.self) { index in
                let letter = index < answer.count ? String(answer[answer.index(answer.startIndex, offsetBy: index)]) : ""
                Text(letter)
                    .font(.title3.weight(.bold).monospaced())
                    .foregroundStyle(isResolved ? .secondary : .primary)
                    .frame(width: 42, height: 48)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(isResolved ? 0.08 : 0.15), lineWidth: 1)
                    }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Answer")
        .accessibilityValue(answer.isEmpty ? "Empty" : answer)
    }
}

private struct ScrambleHintCard: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(UIColor.secondarySystemBackground), Color(UIColor.systemBackground)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
            }
    }
}

private struct ScrambleStrikeIndicator: View {
    let strikes: Int
    let limit: Int

    var body: some View {
        HStack(spacing: 6) {
            Label("Strikes", systemImage: "xmark.shield")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(0..<limit, id: \.self) { index in
                Image(systemName: index < strikes ? "xmark.circle.fill" : "circle")
                    .foregroundStyle(index < strikes ? .red : .secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Strikes")
        .accessibilityValue("\(strikes) of \(limit) used")
    }
}

private struct ScrambleLetterTray: View {
    let letters: [Character]
    let selectedIndices: [Int]
    let onSelect: (Int) -> Void

    var body: some View {
        ScrambleLetterFlowLayout {
            ForEach(letters.indices.filter { !selectedIndices.contains($0) }, id: \.self) { index in
                Button {
                    onSelect(index)
                } label: {
                    Text(String(letters[index]))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 48, height: 48)
                }
                .buttonStyle(ScrambleLetterTileStyle())
                .accessibilityLabel("\(letters[index]), available")
                .accessibilityHint("Double tap to add this letter.")
            }
        }
        .frame(maxWidth: 360, alignment: .center)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

private struct ScrambleLetterFlowLayout: Layout {
    private let tileSize: CGFloat = 48
    private let spacing: CGFloat = 10
    private let maximumWidth: CGFloat = 360

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let width = min(proposal.width ?? maximumWidth, maximumWidth)
        let columns = columnCount(for: width)
        let rows = max(1, Int(ceil(Double(subviews.count) / Double(columns))))
        let height = CGFloat(rows) * tileSize + CGFloat(rows - 1) * spacing
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let columns = columnCount(for: bounds.width)

        for rowStart in stride(from: 0, to: subviews.count, by: columns) {
            let rowEnd = min(rowStart + columns, subviews.count)
            let count = rowEnd - rowStart
            let rowWidth = CGFloat(count) * tileSize + CGFloat(count - 1) * spacing
            let rowIndex = rowStart / columns
            let y = bounds.minY + CGFloat(rowIndex) * (tileSize + spacing)
            var x = bounds.midX - rowWidth / 2

            for index in rowStart..<rowEnd {
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: tileSize, height: tileSize)
                )
                x += tileSize + spacing
            }
        }
    }

    private func columnCount(for width: CGFloat) -> Int {
        max(1, Int((width + spacing) / (tileSize + spacing)))
    }
}

private struct ScrambleLetterTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.65 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

private struct ScrambleActionButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    let isEnabled: Bool
    var tint: Color = .pink
    var isProminent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? (isProminent ? Color.white : tint) : Color.secondary)
        .background(
            isEnabled ? (isProminent ? tint : tint.opacity(0.10)) : Color.secondary.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isEnabled ? tint.opacity(isProminent ? 0 : 0.45) : Color.secondary.opacity(0.25),
                    lineWidth: 1
                )
        }
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct ScrambleGlassActionButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    let isEnabled: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 50, height: 50)
        }
        .buttonStyle(.glass(.clear))
        .buttonBorderShape(.roundedRectangle(radius: 10))
        .foregroundStyle(isEnabled ? tint : .secondary)
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }
}
