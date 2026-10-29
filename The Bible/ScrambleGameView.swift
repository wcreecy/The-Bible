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

    enum SessionLength: Int, CaseIterable, Identifiable {
        case quick = 10
        case extended = 20

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
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
    @State private var didRecordStats = false
    @State private var timeRemaining = 0
    @State private var answerFeedback: AnswerFeedback?
    @State private var timerID = UUID()
    @State private var hintLevel = 0
    @State private var recentlyPlayedAnswers: [String] = []
    @State private var isTimerPaused = false
    @State private var pausesRemaining = 1
    @State private var timerOnLeft = false
    @State private var usesMutedTimerStyle = false
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
        guard let baseLimit = difficulty.timeLimit else { return nil }
        let reduction = max(0, (currentNumber - 1) / 5) * 2
        return max(difficulty == .hard ? 8 : 15, baseLimit - reduction)
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
                        isPaused: isTimerPaused,
                        wordsRemaining: deck.count + 1,
                        usesMutedStyle: $usesMutedTimerStyle,
                        onTogglePause: toggleTimerPause,
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
                    second: ("character.textbox", "Bible words", "People, places & books"),
                    third: ("timer", difficulty.timerLabel, "Per word")
                )
            }

            Spacer(minLength: 24)
        }
    }

    private func gameScreen(usesSplitLayout: Bool) -> some View {
        VStack(spacing: usesSplitLayout ? 18 : 20) {
            if !usesSplitLayout, let timeLimit = currentTimeLimit {
                ScrambleTimer(
                    timeRemaining: timeRemaining,
                    timeLimit: timeLimit,
                    tint: timerTint,
                    isPaused: isTimerPaused
                )
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
                    answer: typedAnswer,
                    answerLength: currentWord.answer.count,
                    isResolved: isCurrentWordResolved
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
                }

                if !isCurrentWordResolved {
                    HStack(spacing: 12) {
                        Button(hintLevel == 0 ? "Hint" : "Another Hint", systemImage: "lightbulb") {
                            showHint()
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)

                        if difficulty == .easy {
                            Button("Show Answer", systemImage: "eye") {
                                revealAnswer()
                            }
                            .buttonStyle(.bordered)
                            .tint(.secondary)
                        }
                    }

                    if let hintText {
                        ScrambleHintCard(text: hintText)
                    }

                    if currentTimeLimit != nil, pausesRemaining > 0 || isTimerPaused {
                        Button(isTimerPaused ? "Resume" : "Pause", systemImage: isTimerPaused ? "play.fill" : "pause.fill") {
                            toggleTimerPause()
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
            case .normal: word.level == .easy || word.level == .normal
            case .hard: true
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
        didRecordStats = false
        hintLevel = 0
        isTimerPaused = false
        pausesRemaining = 1
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
        hintLevel = 0
        isTimerPaused = false
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
        hintLevel = min(hintLevel + 1, currentWord.answer.count)
    }

    private func toggleTimerPause() {
        guard currentTimeLimit != nil else { return }
        if isTimerPaused {
            isTimerPaused = false
        } else if pausesRemaining > 0 {
            pausesRemaining -= 1
            isTimerPaused = true
        }
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
        advanceAfterFeedback()
    }

    private func revealAnswer() {
        guard difficulty == .easy, let currentWord, !isCurrentWordResolved else { return }
        typedAnswer = currentWord.answer
        selectedIndices = Array(shuffledLetters.indices)
        answeredCount += 1
        currentStreak = 0
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
            guard !isTimerPaused else { continue }

            timeRemaining -= 1
            if timeRemaining == 0 {
                answeredCount += 1
                currentStreak = 0
                answerFeedback = .timedOut
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
    let timeLimit: Int
    let tint: Color
    let isPaused: Bool

    var body: some View {
        HStack(spacing: 8) {
            ProgressView(value: Double(timeRemaining), total: Double(timeLimit))
                .tint(tint)
                .frame(maxWidth: 140)
            Label(
                isPaused ? "Paused" : "\(timeRemaining)s",
                systemImage: isPaused ? "pause.fill" : "timer"
            )
            .font(.headline.monospacedDigit())
            .foregroundStyle(isPaused ? .secondary : tint)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityLabel(isPaused ? "Timer paused" : "\(timeRemaining) seconds remaining")
    }
}

private struct ScrambleLargeTimerView: View {
    let timeRemaining: Int
    let timeLimit: Int?
    let tint: Color
    let isPaused: Bool
    let wordsRemaining: Int
    @Binding var usesMutedStyle: Bool
    let onTogglePause: () -> Void
    let onSwapSides: () -> Void

    private var isTimed: Bool { timeLimit != nil }

    private var displayTint: Color { tint }

    private var vividTextColor: Color { .white }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                Image(systemName: isPaused ? "pause.circle.fill" : (isTimed ? "timer" : "infinity"))
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor.opacity(0.85))

                Text(isTimed ? (isPaused ? "Paused" : "Time Remaining") : "Untimed Mode")
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor.opacity(0.85))

                Text(isTimed ? "\(timeRemaining)s" : "∞")
                    .font(.largeTitle.weight(.bold))
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor)

                if let timeLimit {
                    ProgressView(value: Double(timeRemaining), total: Double(timeLimit))
                        .tint(usesMutedStyle ? displayTint : vividTextColor)
                        .frame(maxWidth: 260)
                }

                Label("\(wordsRemaining) words remaining", systemImage: "textformat.abc")
                    .font(.headline)
                    .foregroundStyle(usesMutedStyle ? .secondary : vividTextColor.opacity(0.85))

                if isTimed {
                    Button(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill") {
                        onTogglePause()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(usesMutedStyle ? displayTint : vividTextColor)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isPaused ? "Timer paused" : (isTimed ? "\(timeRemaining) seconds remaining" : "No time limit"))

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("Swap Sides", systemImage: "arrow.left.arrow.right", action: onSwapSides)

                Button(
                    usesMutedStyle ? "Color Background" : "White Background",
                    systemImage: "circle.lefthalf.filled"
                ) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        usesMutedStyle.toggle()
                    }
                }
            }
            .buttonStyle(.glass(.clear))
            .controlSize(.small)
            .tint(usesMutedStyle ? displayTint : vividTextColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background {
            if usesMutedStyle {
                RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                    .fill(Color.white)
            } else {
                RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                    .fill(displayTint)
            }
        }
        .overlay {
            if !usesMutedStyle {
                RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(vividTextColor.opacity(0.22), lineWidth: 1)
            }
        }
        .shadow(color: usesMutedStyle ? .clear : displayTint.opacity(0.25), radius: 12, x: 0, y: 5)
        .padding(12)
        .animation(.easeInOut(duration: 0.25), value: timeRemaining)
    }
}

private struct ScramblePrompt: View {
    let category: LocalizedStringKey
    let reference: LocalizedStringKey?
    let answer: String
    let answerLength: Int
    let isResolved: Bool

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
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
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
    var isProminent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 42, height: 42)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isProminent ? Color.white : Color.pink)
        .background(isProminent ? Color.pink : Color.pink.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.pink.opacity(isProminent ? 0 : 0.45), lineWidth: 1)
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(accessibilityLabel)
    }
}
