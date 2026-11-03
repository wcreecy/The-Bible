import SwiftUI

struct ScrambleGameView: View {
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
            case .hard: 30
            }
        }

        var timerLabel: String {
            switch self {
            case .easy: String(localized: "45 seconds")
            case .normal: String(localized: "30 seconds")
            case .hard: String(localized: "30 seconds")
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
            case .hard: "Tougher words with 30 seconds per word."
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

    @State private var timerOnLeft = false
    @State private var usesMutedTimerStyle = false
    @State private var selectedPassage: PassageReference?
    @State private var isRevealConfirmationPresented = false
    @State private var vm = ScrambleGameViewModel()
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isIncorrectAnswer: Bool {
        if case .incorrect = vm.answerFeedback {
            return true
        }
        return false
    }
    @FocusState private var isKeyboardFocused: Bool

    private var experienceLevel: Binding<GameExperienceLevel> {
        Binding(
            get: { vm.difficulty.experienceLevel },
            set: { vm.difficulty = Difficulty(experienceLevel: $0) }
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let usesSplitLayout = vm.phase == .playing && geometry.size.width >= 700

            ZStack {
                ScrollView {
                    VStack(spacing: 16) {
                        switch vm.phase {
                        case .setup:
                            startScreen
                        case .playing:
                            if vm.isPaused {
                                GamePausedView(tint: .pink, remainingSeconds: vm.timeRemaining) {
                                    vm.isPaused = false
                                }
                                .frame(maxWidth: 620)
                            } else {
                                gameScreen(usesSplitLayout: usesSplitLayout)
                            }
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
                        timeRemaining: vm.timeRemaining,
                        timeLimit: vm.currentTimeLimit,
                        tint: vm.timerTint,
                        isTimerDisabled: vm.isTimerDisabled,
                        usesMutedStyle: $usesMutedTimerStyle,
                        onToggleTimer: vm.toggleTimer,
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
            .focusable()
            .focused($isKeyboardFocused)
            .onKeyPress(phases: .down) { keyPress in
                handleKeyboardPress(keyPress)
            }
            .onChange(of: vm.phase) { _, phase in
                isKeyboardFocused = phase == .playing
            }
        }
        .background(AppBackgroundView(tab: .games))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if vm.phase != .setup {
                    GameNavigationTitle(
                        title: "Scramble",
                        systemImage: "text.line.first.and.arrowtriangle.forward",
                        tint: .pink
                    )
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if vm.canPause {
                    GamePauseButton { vm.isPaused = true }
                }
            }
        }
        // A call, another app, or locking the phone pauses the word until Resume.
        .onAppActiveChange { isActive in
            if !isActive, vm.canPause { vm.isPaused = true }
        }
        .task {
            await vm.loadWordBank()
        }
        // Restarts with each word, and on resume, so the first second is a full second.
        .task(id: ScrambleTimerRun(id: vm.timerID, isPaused: vm.isPaused)) {
            await vm.runTimer()
        }
        .sheet(item: $selectedPassage) { reference in
            ScripturePassageSheet(reference: reference)
        }
        .confirmationDialog("Reveal answer?", isPresented: $isRevealConfirmationPresented, titleVisibility: .visible) {
            Button("Reveal & Next", role: .destructive) {
                vm.revealAnswer()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The word will be marked incorrect, then the next word will begin.")
        }
        .onAppear {
            vm.session.syncSavedBest(from: vm.persistentStreak)
        }
        .onChange(of: vm.difficulty) { _, _ in
            vm.session.syncSavedBest(from: vm.persistentStreak)
        }
        .onDisappear {
            if vm.phase != .setup {
                vm.resetToSetup()
            }
            vm.session.clearStreak()
        }
    }

    private func handleKeyboardPress(_ keyPress: KeyPress) -> KeyPress.Result {
        guard vm.phase == .playing,
              !vm.isPaused,
              !vm.isCurrentWordResolved,
              let currentWord = vm.currentWord else {
            return .ignored
        }

        if keyPress.key == .delete || keyPress.characters == "\u{8}" {
            vm.removeLastLetter()
            return .handled
        }

        if keyPress.key == .return || keyPress.characters == "\r" || keyPress.characters == "\n" {
            guard vm.typedAnswer.count == currentWord.answer.count else { return .handled }
            vm.checkAnswer()
            return .handled
        }

        guard keyPress.modifiers.isEmpty,
              let character = keyPress.characters.first,
              character.isLetter,
              vm.selectLetter(matching: character) else {
            return .ignored
        }

        return .handled
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
                    challenge: "Tougher words with 30 seconds per word."
                ),
                isStartEnabled: vm.wordBankStatus == .ready,
                startAction: vm.startSession
            ) {
                GameLobbyPreview(kind: .scramble)
            } configuration: {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Build each answer from the scrambled letter tiles.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if vm.wordBankStatus == .unavailable {
                        Label("The word list couldn’t be loaded. Close the game and try again.", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }

                    Picker("Session length", selection: $vm.sessionLength) {
                        ForEach(SessionLength.allCases) { length in
                            Text(length.title).tag(length)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            } facts: {
                GameSplashFacts(
                    first: ("number", "\(vm.sessionLength.rawValue) words", "This session"),
                    second: ("timer", vm.difficulty.timerLabel, "Per word"),
                    third: ("lightbulb", vm.difficulty.hintLabel, "Available"),
                    fourth: vm.difficulty == .easy ? nil : ("xmark.shield", "3 strikes", "Limited attempts")
                )
            }

            Spacer(minLength: 24)
        }
    }

    private func gameScreen(usesSplitLayout: Bool) -> some View {
        VStack(spacing: usesSplitLayout ? 18 : 20) {
            GameScoreboardCard(
                currentCorrect: vm.session.score,
                currentAnswered: vm.session.answered,
                currentStreak: vm.session.streak,
                game: .scramble,
                style: horizontalSizeClass == .regular ? .dashboard : .compact
            )

            if let currentWord = vm.currentWord {
                ScramblePrompt(
                    category: currentWord.category,
                    categoryName: currentWord.categoryName,
                    reference: vm.difficulty == .easy || vm.isCurrentWordResolved ? currentWord.reference : nil,
                    answer: vm.typedAnswer,
                    answerLength: currentWord.answer.count,
                    hintedLetters: vm.hintedLetters,
                    isResolved: vm.isCurrentWordResolved,
                    isIncorrect: isIncorrectAnswer,
                    timerTint: vm.currentTimeLimit == nil || vm.isTimerDisabled ? nil : vm.timerTint,
                    onShowReference: showCurrentReference
                )

                if !usesSplitLayout, vm.currentTimeLimit != nil {
                    GameTimerCard(
                        remainingSeconds: vm.timeRemaining,
                        tint: vm.isTimerDisabled ? .secondary : vm.timerTint,
                        isPulsing: false,
                        formattedTime: vm.isTimerDisabled ? "Timer off" : nil,
                        isDisabled: vm.isTimerDisabled,
                        onTap: vm.toggleTimer
                    )
                }

                if let answerFeedback = vm.answerFeedback {
                    Label(answerFeedback.message, systemImage: answerFeedback.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(answerFeedback.tint)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                if vm.difficulty != .easy {
                    ScrambleStrikeIndicator(strikes: vm.strikes, limit: 3)
                }

                ScrambleLetterTray(
                    letters: vm.shuffledLetters,
                    selectedIndices: vm.selectedIndices,
                    onSelect: vm.selectLetter
                )
                .disabled(vm.isCurrentWordResolved)

                if vm.isCurrentWordResolved {
                    Button(
                        vm.isLastWord ? "See Results" : "Next Word",
                        systemImage: vm.isLastWord ? "flag.checkered" : "arrow.right"
                    ) {
                        vm.loadNextWord()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                } else {
                    HStack(spacing: 10) {
                        ScrambleActionButton(systemImage: "trash", accessibilityLabel: "Clear answer", isEnabled: !vm.typedAnswer.isEmpty, action: vm.clearAnswer)
                        ScrambleActionButton(systemImage: "delete.left", accessibilityLabel: "Remove last letter", isEnabled: !vm.typedAnswer.isEmpty, action: vm.removeLastLetter)
                        ScrambleActionButton(systemImage: "shuffle", accessibilityLabel: "Shuffle available letters", isEnabled: vm.shuffledLetters.count - vm.selectedIndices.count >= 2, action: vm.shuffleUnusedLetters)
                        ScrambleActionButton(
                            systemImage: "checkmark.circle.fill",
                            accessibilityLabel: "Check answer",
                            isEnabled: vm.typedAnswer.count == currentWord.answer.count,
                            isProminent: true,
                            isIncorrect: isIncorrectAnswer,
                            action: vm.checkAnswer
                        )
                    }
                    .padding(.top, 12)
                }

                if !vm.isCurrentWordResolved {
                    HStack(spacing: 12) {
                        ScrambleGlassActionButton(
                            systemImage: "lightbulb.fill",
                            accessibilityLabel: vm.hintLevel == 0 ? "Show hint" : "Show another hint",
                            isEnabled: vm.hintLevel < vm.maxHintLevel,
                            tint: .yellow,
                            action: vm.showHint
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

                }
            }
        }
        .frame(maxWidth: 620)
        .padding(.top, 8)
    }

    private var resultsScreen: some View {
        GameRoundSummaryView(
            summary: GameRoundSummary(score: vm.session),
            tint: .pink,
            unit: .words,
            canTimeOut: vm.currentTimeLimit != nil,
            onPlayAgain: vm.startSession,
            onChangeSettings: vm.resetToSetup
        )
    }

    private func showCurrentReference() {
        guard let reference = vm.currentWord?.reference else { return }
        selectedPassage = PassageReferenceParser.parse(reference)
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
            .contentShape(Rectangle())
            .onTapGesture {
                if isTimed {
                    onToggleTimer()
                }
            }
            .accessibilityAddTraits(isTimed ? .isButton : [])
            .accessibilityHint(
                isTimed
                    ? (isTimerDisabled ? "Tap to turn the timer on." : "Tap to turn the timer off.")
                    : ""
            )

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
    let categoryName: String
    let reference: String?
    let answer: String
    let answerLength: Int
    let hintedLetters: [Character?]
    let isResolved: Bool
    let isIncorrect: Bool
    let timerTint: Color?
    let onShowReference: () -> Void

    private var categorySymbol: String {
        switch categoryName {
        case "Actions & Movement": "figure.walk"
        case "Animals & Creatures": "pawprint.fill"
        case "Bible book": "book.closed.fill"
        case "Body & Health": "heart.fill"
        case "Descriptions & Qualities": "sparkles"
        case "Directions & Positions": "arrow.up.left.and.arrow.down.right"
        case "Everyday word": "textformat"
        case "Faith & Worship": "hands.sparkles.fill"
        case "Family & Relationships": "person.2.circle.fill"
        case "Feelings & Character": "heart.text.square.fill"
        case "Food & Drink": "fork.knife"
        case "Law & Conflict": "exclamationmark.shield.fill"
        case "Nature & Weather": "cloud.sun.fill"
        case "Objects & Materials": "shippingbox.fill"
        case "People & Roles": "person.2.fill"
        case "Person": "person.fill"
        case "Place": "mappin.and.ellipse"
        case "Places & Structures": "building.2.fill"
        case "Plants & Farming": "leaf.fill"
        case "Speech & Learning": "text.bubble.fill"
        case "Time & Numbers": "clock.fill"
        default: "tag.fill"
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            Label(category, systemImage: categorySymbol)
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
                hintedLetters: hintedLetters,
                isResolved: isResolved,
                isIncorrect: isIncorrect
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
    let hintedLetters: [Character?]
    let isResolved: Bool
    let isIncorrect: Bool
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let tileCount = max(answerLength, 1)
            let maximumSpacing = 7.0
            let minimumTileWidth = 24.0
            let spacing = min(
                maximumSpacing,
                max(
                    3,
                    (proxy.size.width - CGFloat(tileCount) * minimumTileWidth)
                        / CGFloat(max(tileCount - 1, 1))
                )
            )
            let tileWidth = max(
                1,
                min(
                    42,
                    (proxy.size.width - spacing * CGFloat(max(tileCount - 1, 0)))
                        / CGFloat(tileCount)
                )
            )
            let tileHeight = min(48, max(30, tileWidth + 6))

            HStack(spacing: spacing) {
                ForEach(0..<answerLength, id: \.self) { index in
                    let letter = index < answer.count ? String(answer[answer.index(answer.startIndex, offsetBy: index)]) : ""
                    let hint = index >= answer.count && index < hintedLetters.count ? hintedLetters[index].map(String.init) ?? "" : ""
                    Text(letter.isEmpty ? hint : letter)
                        .font(.title3.weight(.bold).monospaced())
                        .foregroundStyle(
                            letter.isEmpty && !hint.isEmpty
                                ? Color.secondary.opacity(0.55)
                                : (isResolved ? .secondary : .primary)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(width: tileWidth, height: tileHeight)
                        .background(
                            isIncorrect ? Color.orange.opacity(0.10) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    isIncorrect ? Color.orange : Color.primary.opacity(isResolved ? 0.08 : 0.15),
                                    lineWidth: isIncorrect ? 2 : 1
                                )
                        }
                        .offset(x: shakeOffset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 48)
        .task(id: isIncorrect) {
            guard isIncorrect else { return }

            for _ in 0..<3 {
                withAnimation(.easeInOut(duration: 0.08)) {
                    shakeOffset = 8
                }
                try? await Task.sleep(for: .milliseconds(80))
                withAnimation(.easeInOut(duration: 0.08)) {
                    shakeOffset = -8
                }
                try? await Task.sleep(for: .milliseconds(80))
            }

            withAnimation(.easeInOut(duration: 0.08)) {
                shakeOffset = 0
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
                .accessibilityLabel("\(String(letters[index])), available")
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
    var isIncorrect = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isIncorrect ? "exclamationmark.circle.fill" : systemImage)
                .font(.body.weight(.semibold))
                .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            isEnabled
                ? (isIncorrect ? Color.white : (isProminent ? Color.white : tint))
                : Color.secondary
        )
        .background(
            isEnabled
                ? (isIncorrect ? Color.orange : (isProminent ? Color.indigo : tint.opacity(0.10)))
                : Color.secondary.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    isEnabled
                        ? (isIncorrect ? Color.orange : (isProminent ? Color.indigo : tint.opacity(0.45)))
                        : Color.secondary.opacity(0.25),
                    lineWidth: isIncorrect ? 2 : 1
                )
        }
        .disabled(!isEnabled)
        .accessibilityLabel(isIncorrect ? "Try again" : accessibilityLabel)
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

/// Identifies one run of the Scramble timer: a new word or a resume starts a new run.
private struct ScrambleTimerRun: Hashable {
    let id: UUID
    let isPaused: Bool
}
