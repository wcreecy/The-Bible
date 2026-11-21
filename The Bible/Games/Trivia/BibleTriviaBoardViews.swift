import Foundation
import Observation
import SwiftUI

// The Trivia question board, its answers, lifelines and reveal, and the large timer.

struct BibleTriviaCompactBoard: View {
    let model: BibleTriviaGameModel
    let timerTint: Color
    let outcome: BibleTriviaAnswerOutcome?
    let onShowPassage: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            GameScoreboardCard(
                currentCorrect: model.session.score,
                currentAnswered: model.session.answered,
                currentStreak: model.session.streak,
                game: .trivia
            )

            BibleTriviaQuestionBoard(
                model: model,
                showsTimer: true,
                timerTint: timerTint
            )

            if !model.isAnswered {
                BibleTriviaLifelineBar(model: model)

                if let hint = model.displayedVerse {
                    GameVerseCard(verse: hint)
                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            } else if let outcome {
                VStack(spacing: 12) {
                    BibleTriviaAnswerReveal(
                        outcome: outcome,
                        reference: model.currentQuestion?.reference ?? "",
                        passage: model.passage,
                        earnedSpeedBonus: model.earnedSpeedBonus
                    )

                    if let verse = model.displayedVerse {
                        GameVerseCard(verse: verse)
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                        if model.passage?.isTruncated == true {
                            BibleTriviaReadMoreButton(reference: model.currentQuestion?.reference ?? "", action: onShowPassage)
                        }
                    }
                }
                // Scrolled into view above the pinned Next button once answered.
                .id(BibleTriviaAnswerReveal.scrollID)
            }
        }
        .padding(.horizontal)
        .padding(.vertical)
        .animation(.snappy, value: model.displayedVerse)
    }
}

struct BibleTriviaDashboard: View {
    let model: BibleTriviaGameModel
    let outcome: BibleTriviaAnswerOutcome?
    let onShowPassage: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            GameScoreboardCard(
                currentCorrect: model.session.score,
                currentAnswered: model.session.answered,
                currentStreak: model.session.streak,
                game: .trivia,
                style: .dashboard
            )

            BibleTriviaQuestionBoard(
                model: model,
                showsTimer: false,
                timerTint: .cyan
            )

            if !model.isAnswered {
                BibleTriviaLifelineBar(model: model)
            }

            if model.isAnswered {
                if let outcome {
                    BibleTriviaAnswerReveal(
                        outcome: outcome,
                        reference: model.currentQuestion?.reference ?? "",
                        passage: model.passage,
                        earnedSpeedBonus: model.earnedSpeedBonus
                    )
                }

                // The verse itself is in the timer panel beside this one.
                if model.passage?.isTruncated == true {
                    BibleTriviaReadMoreButton(reference: model.currentQuestion?.reference ?? "", action: onShowPassage)
                }

                GameNextQuestionButton(isLastQuestion: model.isLastQuestion, tint: .cyan, action: model.advance)
                    .disabled(!model.canGoNext)
            }

            Spacer(minLength: 0)
        }
        .padding(AppDesignMetrics.cardPadding)
        .padding(.top, 12)
    }
}

struct BibleTriviaReadMoreButton: View {
    let reference: String
    let action: () -> Void

    var body: some View {
        Button("Read all of \(reference)", systemImage: "book.pages", action: action)
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.borderless)
    }
}

/// 50/50, Verse Hint and Extra Time. Each can be used once per round.
struct BibleTriviaLifelineBar: View {
    let model: BibleTriviaGameModel

    var body: some View {
        HStack(spacing: 8) {
            ForEach(BibleTriviaLifeline.allCases.filter(model.offers), id: \.self) { lifeline in
                let isUsed = model.usedLifelines.contains(lifeline)
                Button {
                    withAnimation(.snappy) { model.use(lifeline) }
                } label: {
                    Label(lifeline.title, systemImage: isUsed ? "checkmark" : lifeline.systemImage)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.gameHint(tint: .cyan))
                .disabled(!model.canUse(lifeline))
                .accessibilityHint(lifeline.accessibilityHint)
                .accessibilityValue(isUsed ? "Used" : "")
            }
        }
    }
}

struct BibleTriviaQuestionBoard: View {
    let model: BibleTriviaGameModel
    let showsTimer: Bool
    let timerTint: Color

    @Environment(\.preferredPencilSqueezeAction) private var preferredPencilSqueezeAction
    @Environment(\.showGamePencilMenu) private var showGamePencilMenu
    /// Where this view sits in the game, so the Pencil menu opens at the Pencil tip.
    @State private var originInGame: CGPoint = .zero
    /// Each answer's frame, so a Pencil squeeze while hovering can pick the answer under it.
    @State private var optionFrames: [String: CGRect] = [:]
    private static let coordinateSpace = "triviaQuestionBoard"

    var body: some View {
        let question = model.currentQuestion
        let options = model.options
        let isAnswered = model.isAnswered

        VStack(spacing: 16) {
            VStack(spacing: 10) {
                HStack {
                    if let practiceBook = model.practiceBook {
                        Label("Practicing \(practiceBook)", systemImage: "book.pages")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.cyan)
                    } else {
                        Label("Choose the correct answer", systemImage: "questionmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.cyan)
                    }

                    Spacer()

                    Text("Question \(model.currentIndex + 1) of \(model.roundCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text(question?.question ?? "")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous))

            if showsTimer, !isAnswered {
                GameTimerCard(
                    remainingSeconds: model.remainingSeconds,
                    tint: model.isTimerDisabled ? .secondary : timerTint,
                    isPulsing: false,
                    formattedTime: model.isTimerDisabled ? "Timer off" : nil,
                    isDisabled: model.isTimerDisabled,
                    onTap: model.toggleTimer
                )
            }

            // A Grid rather than a lazy grid, so both answers in a row share the taller one's height.
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                ForEach(Array(stride(from: 0, to: options.count, by: 2)), id: \.self) { start in
                    GridRow {
                        ForEach(start..<min(start + 2, options.count), id: \.self) { index in
                            let option = options[index]
                            BibleTriviaAnswerOption(
                                index: index,
                                title: option,
                                isCorrect: isAnswered && option == question?.correctAnswer,
                                isSelected: option == model.selectedAnswer,
                                isIncorrectSelection: isAnswered && option == model.selectedAnswer
                                    && option != question?.correctAnswer,
                                isRemoved: model.removedOptions.contains(option),
                                isDisabled: isAnswered
                            ) {
                                model.choose(option)
                            }
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .named(Self.coordinateSpace))
                            } action: { frame in
                                optionFrames[option] = frame
                            }
                        }
                    }
                }
            }
        }
        .coordinateSpace(.named(Self.coordinateSpace))
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .named(GamePencil.coordinateSpace)).origin } action: {
            originInGame = $0
        }
        // Squeezing while hovering over an answer chooses it; anywhere else opens the actions menu.
        .onPencilSqueeze { phase in
            guard preferredPencilSqueezeAction != .ignore, case .ended(let value) = phase else { return }
            if !model.isAnswered, let location = value.hoverPose?.location,
               let option = optionFrames.first(where: { options.contains($0.key) && $0.value.contains(location) })?.key,
               !model.removedOptions.contains(option) {
                model.choose(option)
            } else {
                showGamePencilMenu(at: value.hoverPose.map {
                    CGPoint(x: $0.location.x + originInGame.x, y: $0.location.y + originInGame.y)
                })
            }
        }
        .onChange(of: options) { _, _ in
            optionFrames = [:]
        }
    }
}

struct BibleTriviaAnswerOption: View {
    let index: Int
    let title: String
    let isCorrect: Bool
    let isSelected: Bool
    let isIncorrectSelection: Bool
    /// Taken away by 50/50.
    let isRemoved: Bool
    let isDisabled: Bool
    let action: () -> Void

    private var letter: String { GameAnswerLetter.letter(for: index) }

    private var backgroundColor: Color {
        guard isDisabled else { return .clear }
        if isCorrect { return .green.opacity(isSelected ? 0.3 : 0.12) }
        if isIncorrectSelection { return .red.opacity(0.3) }
        return .clear
    }

    private var strokeColor: Color {
        if isDisabled && isCorrect { return .green }
        if isIncorrectSelection { return .red }
        // Primary, not black, so the outline still shows in Dark Mode.
        return Color.primary.opacity(0.18)
    }

    private var accessibilityState: String {
        if isRemoved { return String(localized: "Removed") }
        guard isDisabled else { return "" }
        if isCorrect { return isSelected ? String(localized: "Your answer, correct") : String(localized: "Correct answer") }
        if isIncorrectSelection { return String(localized: "Your answer, incorrect") }
        return ""
    }

    var body: some View {
        Button {
            action()
        } label: {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .disabled(isDisabled || isRemoved)
        .opacity(isRemoved ? 0.35 : 1)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(strokeColor, lineWidth: isDisabled && (isCorrect || isIncorrectSelection) ? 3 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .hoverEffect(.lift)
        .font(.body)
        .accessibilityLabel("\(letter), \(title)")
        .accessibilityValue(accessibilityState)
    }
}

enum BibleTriviaAnswerOutcome {
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

struct BibleTriviaAnswerReveal: View {
    /// The game scrolls here once a question is answered, so the result is never left under the Next button.
    static let scrollID = "triviaAnswerReveal"

    let outcome: BibleTriviaAnswerOutcome
    let reference: String
    /// The loaded passage, so the verse menu works even before the reader has opened the Bible.
    let passage: GamePassage?
    let earnedSpeedBonus: Bool

    private var passageReference: PassageReference? {
        PassageReferenceParser.parse(reference)
    }

    private var verseActionReference: VerseActionReference? {
        guard let passage, let first = passage.verses.first else { return nil }
        return VerseActionReference(
            bookName: passage.bookName,
            chapterNumber: passage.chapter,
            verseNumber: first.number,
            verseText: first.text
        )
    }

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
                }

                if let passageReference {
                    // Primary rather than link blue, which is hard to read on the tinted glass.
                    // Smaller than the question, which stays the most prominent text.
                    Link(destination: passageReference.url) {
                        Label(reference, systemImage: "book")
                            .font(.headline)
                    }
                    // A link draws in its tint, whatever its label's style.
                    .tint(.primary)
                    .accessibilityHint("Shows a preview of the passage")
                } else if !reference.isEmpty {
                    Text(reference)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }

            Spacer(minLength: 8)

            if let verseActionReference {
                VerseActionMenu(verse: verseActionReference)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 64)
        .glassEffect(.regular.tint(outcome.tint.opacity(0.35)), in: .rect(cornerRadius: AppDesignMetrics.compactControlCornerRadius))
        .scripturePassagePreviews()
        .accessibilityElement(children: .contain)
    }
}

struct BibleTriviaLargeTimerView: View {
    let remainingSeconds: Int
    let tint: Color
    let isTimerDisabled: Bool
    let outcome: BibleTriviaAnswerOutcome?
    /// The verse hint, or the passage once answered, using the panel's spare room.
    let verse: GameVerse?
    @Binding var usesMutedStyle: Bool
    let onToggleTimer: () -> Void
    let onSwapSides: () -> Void

    private var displayTint: Color {
        isTimerDisabled && outcome == nil ? .secondary : outcome?.tint ?? tint
    }

    private var vividTextColor: Color {
        outcome == nil && tint == .yellow ? .black : .white
    }

    private var usesNeutralStyle: Bool {
        usesMutedStyle || isTimerDisabled
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                Image(systemName: outcome?.systemImage ?? (isTimerDisabled ? "timer.slash" : "timer"))
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(usesNeutralStyle ? displayTint : vividTextColor.opacity(0.85))

                Text(outcome?.title ?? (isTimerDisabled ? "Timer Off" : "Time Remaining"))
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(usesNeutralStyle ? displayTint : vividTextColor.opacity(0.85))

                if outcome == nil {
                    Text("\(remainingSeconds)s")
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(usesNeutralStyle ? displayTint : vividTextColor)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(outcome?.title ?? "Time Remaining")
            .accessibilityValue(outcome == nil ? "\(remainingSeconds) seconds" : "")
            .contentShape(Rectangle())
            .onTapGesture {
                if outcome == nil {
                    onToggleTimer()
                }
            }
            .accessibilityAddTraits(outcome == nil ? .isButton : [])
            .accessibilityHint(
                outcome == nil
                    ? (isTimerDisabled ? "Tap to turn the timer on." : "Tap to turn the timer off.")
                    : ""
            )

            Spacer(minLength: 0)

            if let verse {
                GameVerseCard(verse: verse)
                    .frame(maxWidth: 460)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }

            HStack(spacing: 12) {
                if outcome == nil {
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
        .animation(.snappy, value: verse)
    }
}
