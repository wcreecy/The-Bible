import SwiftUI

// MARK: - Setup views

/// One-tap shortcuts for the whole Bible or one Testament.
struct QuizCategoryQuickPicks: View {
    let tint: Color

    private enum Scope: CaseIterable, Identifiable {
        case wholeBible
        case oldTestament
        case newTestament

        var id: Self { self }

        var title: LocalizedStringResource {
            switch self {
            case .wholeBible: "Whole Bible"
            case .oldTestament: "Old Testament"
            case .newTestament: "New Testament"
            }
        }

        var detail: LocalizedStringResource {
            switch self {
            case .wholeBible: "All 66 books"
            case .oldTestament: "39 books"
            case .newTestament: "27 books"
            }
        }

        var icon: String {
            switch self {
            case .wholeBible: "books.vertical.fill"
            case .oldTestament: "scroll.fill"
            case .newTestament: "book.closed.fill"
            }
        }

        var sections: Set<QuizVerseSection> {
            switch self {
            case .wholeBible:
                Set(QuizVerseSection.allCases)
            case .oldTestament:
                Set(QuizVerseSection.allCases.filter(\.isOldTestament))
            case .newTestament:
                Set(QuizVerseSection.allCases.filter { !$0.isOldTestament })
            }
        }
    }

    @Binding var selection: Set<QuizVerseSection>

    /// The scope matching the current categories, or nil once they've been fine-tuned.
    private var scopeSelection: Binding<Scope?> {
        Binding(
            get: { Scope.allCases.first { $0.sections == selection } },
            set: { scope in
                if let scope { selection = scope.sections }
            }
        )
    }

    var body: some View {
        GameChoiceSetting(
            title: "Scope",
            systemImage: "books.vertical.fill",
            tint: tint,
            selection: scopeSelection,
            choices: Scope.allCases.map {
                GameChoice<Scope?>(value: $0, title: $0.title, detail: $0.detail, icon: $0.icon)
            },
            fallbackValue: "Custom"
        )
    }
}

// MARK: - Gameplay views

struct QuizContextRow: View {
    let contextText: String
    let isRevealed: Bool
    let cost: Int
    let canReveal: Bool
    let onReveal: () -> Void

    var body: some View {
        if isRevealed {
            VStack(alignment: .leading, spacing: 4) {
                Text("Previous verse")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(contextText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Button(action: onReveal) {
                Label {
                    if cost > 0 {
                        Text("Show previous verse (−\(cost) sec)")
                    } else {
                        Text("Show previous verse")
                    }
                } icon: {
                    Image(systemName: "text.alignleft")
                }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderless)
            .disabled(!canReveal)
            .frame(maxWidth: .infinity)
        }
    }
}

/// The verse or reference, the timer on iPhone, and the four answers. iPhone and iPad share it,
/// so both look and behave the same in either mode.
struct QuizQuestionPanel: View {
    let vm: QuizGameViewModel
    /// iPad shows the timer in its own panel instead.
    let showsTimer: Bool

    @Environment(\.preferredPencilSqueezeAction) private var preferredPencilSqueezeAction
    @Environment(\.showGamePencilMenu) private var showGamePencilMenu
    /// Where this view sits in the game, so the Pencil menu opens at the Pencil tip.
    @State private var originInGame: CGPoint = .zero
    /// Each answer's frame, so a Pencil squeeze while hovering can pick the answer under it.
    @State private var optionFrames: [String: CGRect] = [:]
    private static let coordinateSpace = "quizQuestionPanel"

    var body: some View {
        if let current = vm.current {
            VStack(spacing: 16) {
                promptCard(for: current)

                if current.mode == .lastBookStanding, !vm.isAnswered {
                    // The board is the clock, so it shows what a right tap is worth instead.
                    QuizBoardStatus(booksLeft: current.booksLeft, points: vm.boardPointsAvailable, tint: vm.timerColor)
                } else if showsTimer, vm.isTimed, !vm.isAnswered {
                    GameTimerCard(
                        remainingSeconds: vm.remainingSeconds,
                        tint: vm.isTimerDisabled ? .secondary : vm.timerColor,
                        isPulsing: vm.isTimerDisabled ? false : vm.isPulsing,
                        formattedTime: vm.isTimerDisabled ? "Timer off" : nil,
                        isDisabled: vm.isTimerDisabled,
                        onTap: vm.toggleTimer
                    )
                }

                if !vm.isAnswered {
                    Text(current.mode == .reverse ? "Which verse matches this reference?" : "Which book is this from?")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // The Section Hint, right above the answers where the eye goes next, in its own
                    // color so it doesn't read as another link in the question card.
                    if let sectionHint = vm.sectionHint {
                        sectionHintBanner(sectionHint)
                            .transition(.scale(scale: 0.9, anchor: .top).combined(with: .opacity))
                    }
                }

                if current.mode == .lastBookStanding {
                    lastBookBoard(for: current)
                } else {
                    answerGrid(for: current)
                }
            }
            .coordinateSpace(.named(Self.coordinateSpace))
            .onGeometryChange(for: CGPoint.self) { $0.frame(in: .named(GamePencil.coordinateSpace)).origin } action: {
                originInGame = $0
            }
            // Squeezing while hovering over an answer chooses it; anywhere else opens the actions menu.
            .onPencilSqueeze { phase in
                guard preferredPencilSqueezeAction != .ignore, case .ended(let value) = phase else { return }
                if !vm.isAnswered, let location = value.hoverPose?.location,
                   let option = optionFrames.first(where: { current.options.contains($0.key) && $0.value.contains(location) })?.key,
                   !current.removedOptions.contains(option) {
                    vm.selectOption(option)
                } else {
                    showGamePencilMenu(at: value.hoverPose.map {
                    CGPoint(x: $0.location.x + originInGame.x, y: $0.location.y + originInGame.y)
                })
                }
            }
            .onChange(of: current.id) { _, _ in
                optionFrames = [:]
            }
            // With VoiceOver, say how many books are left rather than which one went.
            .onChange(of: current.booksLeft) { _, booksLeft in
                guard current.mode == .lastBookStanding, !vm.isAnswered, UIAccessibility.isVoiceOverRunning else { return }
                AccessibilityNotification.Announcement(String(localized: "\(booksLeft) books left")).post()
            }
        }
    }

    /// Last Book Standing's board. A book that leaves keeps its space, so the others never
    /// move under a finger that's about to tap.
    private func lastBookBoard(for current: QuizQuestion) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(current.options, id: \.self) { option in
                let isGone = current.removedOptions.contains(option)
                QuizBoardTile(
                    title: "\(GameAnswerLetter.letter(for: current.options.firstIndex(of: option) ?? 0)). \(option)",
                    isAnswered: vm.isAnswered,
                    isCorrect: option == current.correctAnswer,
                    isSelected: option == current.selected
                ) {
                    vm.selectOption(option)
                }
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named(Self.coordinateSpace))
                } action: { frame in
                    optionFrames[option] = frame
                }
                .opacity(isGone ? 0 : 1)
                .scaleEffect(isGone ? 0.8 : 1)
                .allowsHitTesting(!isGone && !vm.isAnswered)
                .accessibilityHidden(isGone)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .animation(.easeOut(duration: 0.3), value: current.removedOptions)
    }

    @ViewBuilder
    private func answerGrid(for current: QuizQuestion) -> some View {
        // 50/50 takes the two wrong answers out, so the two left close up (side by side in
        // Standard). Each keeps its original letter, so the shortcuts still match.
        let remaining = Array(current.options.enumerated())
            .filter { !current.removedOptions.contains($0.element) }
        LazyVGrid(columns: columns(for: current), spacing: 12) {
            ForEach(remaining, id: \.element) { index, option in
                QuizAnswerOption(
                    index: index,
                    title: option,
                    isAnswered: vm.isAnswered,
                    isCorrect: option == current.correctAnswer,
                    isSelected: option == current.selected,
                    isRemoved: false,
                    verse: vm.isAnswered ? current.optionVerses.first { $0.verseText == option } : nil
                ) {
                    vm.selectOption(option)
                }
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named(Self.coordinateSpace))
                } action: { frame in
                    optionFrames[option] = frame
                }
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        // Only as tall as the answers need, never stretched to fill spare iPad height.
        .fixedSize(horizontal: false, vertical: true)
        .animation(.snappy, value: current.removedOptions)
    }

    private func columns(for question: QuizQuestion) -> [GridItem] {
        question.mode == .reverse
            ? [GridItem(.flexible())]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    private func sectionHintBanner(_ hint: String) -> some View {
        Label {
            Text(hint)
                .font(.headline)
        } icon: {
            Image(systemName: "books.vertical.fill")
                // One bounce as the hint appears (skipped when Reduce Motion is on).
                .symbolEffect(.bounce, value: hint)
        }
        .foregroundStyle(.orange)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.5), lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hint: \(hint)")
        .onAppear { AccessibilityNotification.Announcement(hint).post() }
    }

    private func promptCard(for current: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Text(vm.progressText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
            }

            Text(current.prompt)
                .italic(current.mode.asksForBook)
                .font(current.mode == .reverse ? .title2.weight(.bold) : .title3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)

            if let contextText = current.contextText {
                QuizContextRow(
                    contextText: contextText,
                    isRevealed: current.contextRevealed || current.outcome != nil,
                    cost: vm.difficulty.contextCost,
                    canReveal: vm.canRevealContext,
                    onReveal: vm.revealContext
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
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
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    vm.isTimerRunning ? vm.timerColor : Color.primary.opacity(0.12),
                    lineWidth: vm.isTimerRunning ? 2 : 1
                )
        )
        .animation(.easeInOut(duration: 0.25), value: vm.remainingSeconds)
    }
}

/// One multiple-choice answer: a book in Standard, a verse's text in Reverse. Once answered,
/// a Reverse answer also shows its reference and verse actions.
struct QuizAnswerOption: View {
    let index: Int
    let title: String
    let isAnswered: Bool
    let isCorrect: Bool
    let isSelected: Bool
    /// Taken away by 50/50.
    let isRemoved: Bool
    let verse: QuizVerse?
    let action: () -> Void

    private var letter: String { GameAnswerLetter.letter(for: index) }

    private var isIncorrectSelection: Bool { isAnswered && isSelected && !isCorrect }

    private var backgroundColor: Color {
        guard isAnswered else { return .clear }
        if isCorrect { return .green.opacity(isSelected ? 0.3 : 0.12) }
        if isIncorrectSelection { return .red.opacity(0.3) }
        return .clear
    }

    private var strokeColor: Color {
        if isAnswered && isCorrect { return .green }
        if isIncorrectSelection { return .red }
        // Primary, not black, so the outline still shows in Dark Mode.
        return Color.primary.opacity(0.18)
    }

    private var accessibilityState: String {
        if isRemoved { return String(localized: "Removed") }
        guard isAnswered else { return "" }
        if isCorrect { return isSelected ? String(localized: "Your answer, correct") : String(localized: "Correct answer") }
        if isIncorrectSelection { return String(localized: "Your answer, incorrect") }
        return ""
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(letter)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.primary.opacity(0.08), in: Circle())

                    Text(title)
                        .strikethrough(isRemoved)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .frame(maxWidth: .infinity, minHeight: 52)
                .foregroundStyle(.primary)
                .contentShape(Rectangle())
            }
            .disabled(isAnswered || isRemoved)
            .hoverEffect(.lift)
            .accessibilityLabel("\(letter), \(title)")
            .accessibilityValue(accessibilityState)

            if let verse {
                HStack {
                    Text(verse.reference)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    VerseActionMenu(
                        verse: VerseActionReference(
                            bookName: verse.bookName,
                            chapterNumber: verse.chapterNumber,
                            verseNumber: verse.verseNumber,
                            verseText: verse.verseText
                        )
                    )
                    .accessibilityLabel("Actions for \(verse.reference)")
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .opacity(isRemoved ? 0.35 : 1)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(strokeColor, lineWidth: isAnswered && (isCorrect || isIncorrectSelection) ? 3 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .font(.body)
    }
}

/// One book on a Last Book Standing board: compact, so twelve fit on an iPhone.
struct QuizBoardTile: View {
    let title: String
    let isAnswered: Bool
    let isCorrect: Bool
    let isSelected: Bool
    let action: () -> Void

    private var tint: Color? {
        guard isAnswered else { return nil }
        if isCorrect { return .green }
        return isSelected ? .red : nil
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(
                    (tint ?? .blue).opacity(tint == nil ? 0.07 : 0.22),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint ?? Color.primary.opacity(0.18), lineWidth: tint == nil ? 1 : 2.5)
                )
                .opacity(isAnswered && tint == nil ? 0.45 : 1)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .hoverEffect(.lift)
        .accessibilityValue(
            !isAnswered ? Text("") : isCorrect ? Text(isSelected ? "Your answer, correct" : "Correct answer")
                : isSelected ? Text("Your answer, incorrect") : Text("")
        )
    }
}

/// How many books are left on a Last Book Standing board, and what a right tap scores now.
struct QuizBoardStatus: View {
    let booksLeft: Int
    let points: Int
    let tint: Color

    var body: some View {
        HStack {
            Label("\(booksLeft) books left", systemImage: "square.grid.3x3.topleft.filled")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            // Primary, not the tint: yellow text on a yellow wash is hard to read.
            Text(points == 1 ? "Worth 1 point" : "Worth \(points) points")
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.6), lineWidth: 1.5)
        )
        .animation(.snappy, value: points)
        .accessibilityElement(children: .combine)
    }
}

/// 50/50 and the section hint. Each can be used once per round.
struct QuizLifelineBar: View {
    let vm: QuizGameViewModel

    var body: some View {
        // A used lifeline leaves the row, and the row goes once none are left.
        HStack(spacing: 8) {
            ForEach(vm.availableLifelines, id: \.self) { lifeline in
                Button {
                    withAnimation(.snappy) { vm.use(lifeline) }
                } label: {
                    Label(lifeline.title, systemImage: lifeline.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.gameHint(tint: .blue))
                .disabled(!vm.canUse(lifeline))
                .accessibilityHint(lifeline.accessibilityHint)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: vm.availableLifelines)
    }
}

extension QuizLifeline {
    /// The lifeline's name as plain text, for the start screen.
    var name: String {
        switch self {
        case .fiftyFifty: "50/50"
        case .sectionHint: String(localized: "Section Hint")
        case .extraTime: String(localized: "+\(Self.extraSeconds) Seconds")
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .fiftyFifty: "50/50"
        case .sectionHint: "Section Hint"
        case .extraTime: "+\(Self.extraSeconds) Seconds"
        }
    }

    var systemImage: String {
        switch self {
        case .fiftyFifty: "circle.lefthalf.filled"
        case .sectionHint: "books.vertical"
        case .extraTime: "timer"
        }
    }

    var accessibilityHint: LocalizedStringKey {
        switch self {
        case .fiftyFifty: "Removes two wrong answers. Once per game."
        case .sectionHint: "Tells you which part of the Bible the verse is from. Once per game."
        case .extraTime: "Adds ten seconds to this question's clock. Once per game."
        }
    }
}

/// The result and the chapter bonus, once a question is answered.
struct QuizAfterAnswer: View {
    /// The game scrolls here once a question is answered, so it's never left under the Next button.
    static let scrollID = "quizAfterAnswer"

    let vm: QuizGameViewModel

    var body: some View {
        if let current = vm.current, let outcome = current.outcome {
            VStack(spacing: 12) {
                QuizAnswerReveal(
                    outcome: outcome,
                    bookName: current.correctBook,
                    chapterNumber: current.chapter,
                    verseNumber: current.verse,
                    verseText: current.verseText,
                    closeGuessNote: vm.closeGuessNote,
                    earnedSpeedBonus: current.earnedSpeedBonus,
                    boardPoints: current.mode == .lastBookStanding && outcome == .correct ? current.boardPoints : nil,
                    hidesChapter: vm.isChapterBonusOpen
                )

                if !current.chapterOptions.isEmpty {
                    QuizChapterBonus(question: current, onGuess: vm.guessChapter)
                }
            }
            .animation(.snappy, value: current.chapterGuess)
        }
    }
}

/// After a correct book on Normal or Hard: which chapter, for a bonus point.
struct QuizChapterBonus: View {
    let question: QuizQuestion
    let onGuess: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let guess = question.chapterGuess {
                let isRight = guess == question.chapter
                // Says whether the chapter was right, since the card above only names the verse.
                Label(
                    isRight
                        ? "Correct! Chapter \(question.chapter). +1 chapter bonus"
                        : "Not quite. You chose chapter \(guess); it was chapter \(question.chapter).",
                    systemImage: isRight ? "star.fill" : "xmark.circle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isRight ? Color.orange : Color.red)
            } else {
                Label("Bonus: which chapter of \(question.correctBook)?", systemImage: "star")
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 8) {
                    ForEach(Array(question.chapterOptions.enumerated()), id: \.element) { index, chapter in
                        Button {
                            onGuess(chapter)
                        } label: {
                            Text(chapter, format: .number)
                                .font(.headline.monospacedDigit())
                                .frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.glass)
                        .tint(.orange)
                        .accessibilityLabel("\(GameAnswerLetter.letter(for: index)), chapter \(chapter)")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            (question.chapterGuess.map { $0 == question.chapter ? Color.orange : Color.red } ?? Color.orange).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }
}

struct QuizAnswerReveal: View {
    let outcome: QuizOutcome
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String
    /// "Right section: Gospels" for a close wrong guess.
    var closeGuessNote: String?
    var earnedSpeedBonus = false
    /// What a right Last Book Standing tap scored; nil in the other modes.
    var boardPoints: Int?
    /// True while the chapter bonus is waiting, so the card names the book without giving
    /// away the chapter and verse (or the menu that opens them).
    var hidesChapter = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: outcome.systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(outcome.tint)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(outcome.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(outcome.tint)

                    if earnedSpeedBonus {
                        Label("+1 speed bonus", systemImage: "bolt.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    }

                    if let boardPoints {
                        Label(boardPoints == 1 ? "+1 point" : "+\(boardPoints) points", systemImage: "square.grid.3x3.topleft.filled")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }

                Text(hidesChapter
                    ? bookName
                    : "\(bookName) \(chapterNumber):\(verseNumber) \(BibleRepository.shared.activeTranslation.abbreviation)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                if let closeGuessNote {
                    Text(closeGuessNote)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if !hidesChapter {
                VerseActionMenu(
                    verse: VerseActionReference(
                        bookName: bookName,
                        chapterNumber: chapterNumber,
                        verseNumber: verseNumber,
                        verseText: verseText
                    )
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 64)
        .glassEffect(.regular.tint(outcome.tint.opacity(0.35)), in: .rect(cornerRadius: AppDesignMetrics.compactControlCornerRadius))
        .accessibilityElement(children: .combine)
    }
}

struct QuizLargeTimerView: View {
    let remainingSeconds: Int
    let tint: Color
    let isPulsing: Bool
    let isTimed: Bool
    let isTimerDisabled: Bool
    let outcome: QuizOutcome?
    /// What a right tap scores now in Last Book Standing, shown instead of seconds; nil otherwise.
    var boardPoints: Int?
    @Binding var usesMutedStyle: Bool
    let onToggleTimer: () -> Void
    let onSwapSides: () -> Void

    private var isActive: Bool {
        isTimed && outcome == nil
    }

    /// The board is Last Book Standing's clock, so its timer can't be turned off.
    private var canToggle: Bool { isActive && boardPoints == nil }

    private var displayTint: Color {
        isTimerDisabled && outcome == nil ? .secondary : outcome?.tint ?? tint
    }

    private var vividTextColor: Color {
        isActive && tint == .yellow ? .black : .white
    }

    private var usesNeutralStyle: Bool {
        usesMutedStyle || isTimerDisabled
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                Image(systemName: statusSystemImage)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(usesNeutralStyle ? displayTint : vividTextColor.opacity(0.85))

                Text(statusTitle)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(usesNeutralStyle ? displayTint : vividTextColor.opacity(0.85))

                if outcome == nil, let boardPoints {
                    Text(boardPoints == 1 ? "1 pt" : "\(boardPoints) pts")
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(usesNeutralStyle ? displayTint : vividTextColor)
                        .contentTransition(.numericText())
                } else if outcome == nil {
                    Text(isTimed ? "\(remainingSeconds)s" : "∞")
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(usesNeutralStyle ? displayTint : vividTextColor)
                }
            }
            .scaleEffect(isPulsing ? 1.04 : 1)
            .animation(.easeOut(duration: 0.18), value: isPulsing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(statusTitle)
            .accessibilityValue(
                boardPoints.map { Text("\($0) points") }
                    ?? (isActive ? Text("\(remainingSeconds) seconds") : outcome == nil ? Text("No time limit") : Text(""))
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if canToggle {
                    onToggleTimer()
                }
            }
            .accessibilityAddTraits(canToggle ? .isButton : [])
            .accessibilityHint(
                canToggle
                    ? (isTimerDisabled ? "Tap to turn the timer on." : "Tap to turn the timer off.")
                    : ""
            )

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                if canToggle {
                    Button(
                        isTimerDisabled ? "Turn timer on" : "Turn timer off",
                        systemImage: isTimerDisabled ? "timer" : "timer.slash",
                        action: onToggleTimer
                    )
                }

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
        .animation(.easeInOut(duration: 0.25), value: remainingSeconds)
    }

    private var statusTitle: LocalizedStringKey {
        if let outcome { return outcome.title }
        if boardPoints != nil { return "Worth" }
        if isTimerDisabled { return "Timer Off" }
        return isTimed ? "Time Remaining" : "Untimed Mode"
    }

    private var statusSystemImage: String {
        if let outcome { return outcome.systemImage }
        if boardPoints != nil { return "square.grid.3x3.topleft.filled" }
        if isTimerDisabled { return "timer.slash" }
        return isTimed ? "timer" : "infinity"
    }
}
