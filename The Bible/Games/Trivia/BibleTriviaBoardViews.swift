import Foundation
import Observation
import SwiftUI

// The Trivia question board, its answers and reveal, and the large timer.

struct BibleTriviaCompactBoard: View {
    let question: String
    let correctAnswer: String
    let options: [String]
    let questionNumber: Int
    let questionCount: Int
    let score: Int
    let answered: Int
    let currentStreak: Int
    let remainingSeconds: Int
    let timerTint: Color
    let isTimerDisabled: Bool
    let outcome: BibleTriviaAnswerOutcome?
    let reference: String
    let selectedAnswer: String?
    let isAnswered: Bool
    let onChoose: (String) -> Void
    let onToggleTimer: () -> Void
    let canGoNext: Bool
    let isLastQuestion: Bool
    let onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            GameScoreboardCard(
                currentCorrect: score,
                currentAnswered: answered,
                currentStreak: currentStreak,
                game: .trivia
            )

            BibleTriviaQuestionBoard(
                question: question,
                correctAnswer: correctAnswer,
                questionNumber: questionNumber,
                questionCount: questionCount,
                options: options,
                remainingSeconds: isAnswered ? nil : remainingSeconds,
                timerTint: timerTint,
                isTimerDisabled: isTimerDisabled,
                selectedAnswer: selectedAnswer,
                isAnswered: isAnswered,
                onChoose: onChoose,
                onToggleTimer: onToggleTimer
            )

            if isAnswered {
                if let outcome {
                    BibleTriviaAnswerReveal(outcome: outcome, reference: reference)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical)
    }
}

struct BibleTriviaDashboard: View {
    let question: String
    let correctAnswer: String
    let options: [String]
    let questionNumber: Int
    let questionCount: Int
    let score: Int
    let answered: Int
    let currentStreak: Int
    let outcome: BibleTriviaAnswerOutcome?
    let reference: String
    let selectedAnswer: String?
    let isAnswered: Bool
    let onChoose: (String) -> Void
    let canGoNext: Bool
    let isLastQuestion: Bool
    let onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            GameScoreboardCard(
                currentCorrect: score,
                currentAnswered: answered,
                currentStreak: currentStreak,
                game: .trivia,
                style: .dashboard
            )

            BibleTriviaQuestionBoard(
                question: question,
                correctAnswer: correctAnswer,
                questionNumber: questionNumber,
                questionCount: questionCount,
                options: options,
                remainingSeconds: nil,
                timerTint: .cyan,
                isTimerDisabled: false,
                selectedAnswer: selectedAnswer,
                isAnswered: isAnswered,
                onChoose: onChoose,
                onToggleTimer: nil
            )

            if isAnswered {
                if let outcome {
                    BibleTriviaAnswerReveal(outcome: outcome, reference: reference)
                }

                GameNextQuestionButton(isLastQuestion: isLastQuestion, tint: .cyan, action: onAdvance)
                    .disabled(!canGoNext)
            }

            Spacer(minLength: 0)
        }
        .padding(AppDesignMetrics.cardPadding)
        .padding(.top, 12)
    }
}

struct BibleTriviaQuestionBoard: View {
    let question: String
    let correctAnswer: String
    let questionNumber: Int
    let questionCount: Int
    let options: [String]
    let remainingSeconds: Int?
    let timerTint: Color
    let isTimerDisabled: Bool
    let selectedAnswer: String?
    let isAnswered: Bool
    let onChoose: (String) -> Void
    let onToggleTimer: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                HStack {
                    Label("Choose the correct answer", systemImage: "questionmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.cyan)

                    Spacer()

                    Text("Question \(questionNumber) of \(questionCount)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text(question)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(.cyan.opacity(0.08), in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous))

            if let remainingSeconds, !isAnswered {
                GameTimerCard(
                    remainingSeconds: remainingSeconds,
                    tint: isTimerDisabled ? .secondary : timerTint,
                    isPulsing: false,
                    formattedTime: isTimerDisabled ? "Timer off" : nil,
                    isDisabled: isTimerDisabled,
                    onTap: onToggleTimer
                )
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(options, id: \.self) { option in
                    BibleTriviaAnswerOption(
                        title: option,
                        isCorrect: isAnswered && option == correctAnswer,
                        isSelected: option == selectedAnswer,
                        isIncorrectSelection: isAnswered && option == selectedAnswer && option != correctAnswer,
                        isDisabled: isAnswered
                    ) {
                        onChoose(option)
                    }
                }
            }
        }
    }

}

struct BibleTriviaAnswerOption: View {
    let title: String
    let isCorrect: Bool
    let isSelected: Bool
    let isIncorrectSelection: Bool
    let isDisabled: Bool
    let action: () -> Void

    private var backgroundColor: Color {
        guard isDisabled, isSelected else { return .clear }
        if isCorrect { return .green.opacity(0.3) }
        if isIncorrectSelection { return .red.opacity(0.3) }
        return .clear
    }

    var body: some View {
        Button {
            action()
        } label: {
            Text(title)
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundStyle(.primary)
        }
        .disabled(isDisabled)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isCorrect && isDisabled ? Color.green : Color.black.opacity(0.15),
                    lineWidth: isCorrect && isDisabled ? 3 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .font(.body)
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
    let outcome: BibleTriviaAnswerOutcome
    let reference: String

    private var passageReference: PassageReference? {
        PassageReferenceParser.parse(reference)
    }

    private var verseActionReference: VerseActionReference? {
        guard let parsedReference = BibleReferenceLinker.parse(reference),
              let verseText = BibleData.books
                .first(where: { $0.name == parsedReference.bookName })?
                .chapters.first(where: { $0.number == parsedReference.chapter })?
                .verses.first(where: { $0.number == parsedReference.startVerse })?
                .text else {
            return nil
        }

        return VerseActionReference(
            bookName: parsedReference.bookName,
            chapterNumber: parsedReference.chapter,
            verseNumber: parsedReference.startVerse,
            verseText: verseText
        )
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: outcome.systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(outcome.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(outcome.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(outcome.tint)

                if let passageReference {
                    Link(destination: passageReference.url) {
                        Label(reference, systemImage: "book")
                            .font(.title3.weight(.bold))
                    }
                    .accessibilityHint("Shows a preview of the passage")
                } else if !reference.isEmpty {
                    Text(reference)
                        .font(.title3.weight(.bold))
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
    }
}
