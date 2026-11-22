import SwiftUI

// Subviews for BookOrderGameView: the setup controls, Tap in Order's tiles and row of placed
// books, and the quick rounds (Before or After?, Missing Book, Which Section?).

struct BookOrderSetupControls: View {
    @Binding var mode: BookOrderMode
    let modes: [BookOrderMode]
    @Binding var source: BookSourceScope
    @Binding var difficulty: BookOrderDifficulty

    private static let sectionOptions = BookSourceScope.allCases.filter { !$0.isCategory }
        + BookSourceScope.allCases.filter(\.isCategory)

    /// Classic on iPhone plays as Tap in Order, so that's what the picker shows.
    private var modeSelection: Binding<BookOrderMode> {
        Binding(
            get: { modes.contains(mode) ? mode : .tapInOrder },
            set: { mode = $0 }
        )
    }

    private var shownMode: BookOrderMode { modeSelection.wrappedValue }

    private var isFullBibleMode: Bool {
        shownMode == .classic && difficulty == .fullBible
    }

    /// Classic only: the full 66-book round, or the shorter section rounds.
    private var fullBibleSelection: Binding<Bool> {
        Binding(
            get: { isFullBibleMode },
            set: { isFull in
                if isFull {
                    source = .both
                    difficulty = .fullBible
                } else {
                    difficulty = .normal
                }
            }
        )
    }

    var body: some View {
        GameSettingsGroup {
            GameChoiceSetting(
                title: "Game Type",
                systemImage: "list.number",
                tint: .purple,
                selection: modeSelection,
                choices: modes.map {
                    GameChoice(value: $0, title: $0.title, detail: $0.detail, icon: $0.systemImage)
                }
            )

            if shownMode == .classic {
                GameChoiceSetting(
                    title: "Round Type",
                    systemImage: "rectangle.3.group.fill",
                    tint: .purple,
                    selection: fullBibleSelection,
                    choices: [
                        GameChoice(value: false, title: "Quick Rounds", detail: "Select section of the Bible.", icon: "arrow.triangle.2.circlepath"),
                        GameChoice(value: true, title: "Full Bible Order", detail: "Arrange all 66 books.", icon: "books.vertical.fill")
                    ]
                )
            }

            // Which Section? always uses the whole Bible.
            if !isFullBibleMode, shownMode != .whichSection {
                GameChoiceSetting(
                    title: "Part of the Bible",
                    systemImage: "books.vertical.fill",
                    tint: .purple,
                    selection: $source,
                    choices: Self.sectionOptions.map {
                        GameChoice(value: $0, title: $0.title, detail: "\($0.bookNames.count) books", icon: icon(for: $0))
                    }
                )
            }
        }
    }

    private func icon(for option: BookSourceScope) -> String {
        switch option {
        case .both: "books.vertical.fill"
        case .ot: "scroll.fill"
        case .nt: "book.closed.fill"
        default: "book.fill"
        }
    }
}

// MARK: - Tap in Order

/// One book to tap. Placed books stay in the grid, dimmed with a check, so the others don't move.
struct BookOrderTile: View {
    let book: String
    let isPlaced: Bool
    /// Tapped too early at some point, so it counts as missed.
    let wasMissed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isPlaced {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(wasMissed ? .orange : .green)
                }
                Text(book)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 8)
            .foregroundStyle(isPlaced ? .secondary : .primary)
            .background(
                isPlaced ? Color.secondary.opacity(0.08) : Color.purple.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isPlaced ? Color.primary.opacity(0.08) : Color.purple.opacity(0.35), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isPlaced)
        .hoverEffect(.lift)
        .accessibilityValue(isPlaced ? String(localized: "Placed") : "")
        .accessibilityHint(isPlaced ? "" : String(localized: "Double tap if this is the next book."))
    }
}

/// The books tapped so far, in order, with a slot for the next one.
struct BookOrderPlacedRow: View {
    let placed: [String]
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(placed.count) of \(total) in order", systemImage: "list.number")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], alignment: .leading, spacing: 6) {
                ForEach(Array(placed.enumerated()), id: \.element) { index, book in
                    Text("\(index + 1). \(book)")
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.15), in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                }
                if placed.count < total {
                    Text("\(placed.count + 1). ?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Books in order")
        .accessibilityValue(placed.isEmpty ? String(localized: "None yet") : placed.formatted(.list(type: .and)))
    }
}

// MARK: - Quick rounds

/// Before or After?, Missing Book and Which Section?: one question at a time.
struct BookOrderQuickRoundView: View {
    let round: BookOrderQuickRound

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                if let question = round.current {
                    switch question.kind {
                    case .beforeAfter(let first, let second):
                        beforeAfter(first: first, second: second, question: question)
                    case .missingBook(let run):
                        missingBook(run: run, question: question)
                    case .whichSection(let book):
                        whichSection(book: book, question: question)
                    }
                }
            }
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .padding()
        }
        // A hardware keyboard answers with 1–8 or A–D (or ← → for Before or After?), and Return goes on.
        .gameKeyboardInput(isActive: !round.isFinished, onKey: handleKeyPress)
    }

    private var header: some View {
        HStack {
            Label(round.mode.title, systemImage: round.mode.systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.purple)
            Spacer()
            if round.isTimed {
                Label("\(round.remainingSeconds)s", systemImage: "timer")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(round.remainingSeconds <= 10 ? .red : .primary)
                    .contentTransition(.numericText())
            }
            Text(round.progressText)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Before or After?

    private func beforeAfter(first: String, second: String, question: BookOrderQuickQuestion) -> some View {
        VStack(spacing: 16) {
            Text("Which comes first?")
                .font(.title3.weight(.semibold))

            HStack(spacing: 12) {
                ForEach([first, second], id: \.self) { book in
                    Button {
                        round.choose(book)
                    } label: {
                        Text(book)
                            .font(.title3.weight(.bold))
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, minHeight: 110)
                            .padding(.horizontal, 8)
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(round.isAnswered)
                    .background(
                        round.isAnswered ? fill(for: book, in: question) : Color.purple.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                round.isAnswered ? stroke(for: book, in: question) : Color.purple.opacity(0.4),
                                lineWidth: round.isAnswered && book == question.correctAnswer ? 2 : 1
                            )
                    }
                    .hoverEffect(.lift)
                    .accessibilityValue(accessibilityState(for: book, in: question))
                }
            }

            // A review asks one pair at a time, and waits for Next like the other rounds.
            afterAnswer(for: question)

            if let feedback = round.lastFeedback {
                Label(feedback.text, systemImage: feedback.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(feedback.isCorrect ? .green : .red)
                    .id(round.currentIndex)
                    .transition(.opacity)
            }
        }
        .animation(.snappy, value: round.currentIndex)
    }

    // MARK: Missing Book

    private func missingBook(run: [String?], question: BookOrderQuickQuestion) -> some View {
        VStack(spacing: 16) {
            Text("Which book is missing?")
                .font(.title3.weight(.semibold))

            HStack(spacing: 6) {
                ForEach(Array(run.enumerated()), id: \.offset) { _, book in
                    Text(book ?? (round.isAnswered ? question.correctAnswer : "?"))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .padding(.horizontal, 4)
                        .foregroundStyle(book == nil ? Color.purple : Color.primary)
                        .background(
                            book == nil ? Color.purple.opacity(0.12) : Color.secondary.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay {
                            if book == nil {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.purple, style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                            }
                        }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(round.prompt(for: question).replacing("___", with: String(localized: "blank")))

            answerGrid(for: question, columns: 2)
            afterAnswer(for: question)
        }
    }

    // MARK: Which Section?

    private func whichSection(book: String, question: BookOrderQuickQuestion) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text(book)
                    .font(.largeTitle.weight(.bold))
                    .fontDesign(.rounded)
                Text("Which part of the Bible is it in?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            answerGrid(for: question, columns: 2)

            if round.isAnswered {
                let books = BookOrderQuickRound.books(inSection: question.correctAnswer)
                VStack(alignment: .leading, spacing: 6) {
                    Label(question.correctAnswer, systemImage: "books.vertical.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(books.formatted(.list(type: .and)))
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            afterAnswer(for: question)
        }
    }

    // MARK: Shared

    private func answerGrid(for question: BookOrderQuickQuestion, columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
            ForEach(Array(question.options.enumerated()), id: \.element) { index, option in
                Button {
                    round.choose(option)
                } label: {
                    HStack(spacing: 8) {
                        Text(GameAnswerLetter.letter(for: index))
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.secondary)
                            .frame(width: 22, height: 22)
                            .background(Color.primary.opacity(0.08), in: Circle())
                        Text(option)
                            .font(.body.weight(.semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(round.isAnswered)
                .background(fill(for: option, in: question), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(stroke(for: option, in: question), lineWidth: round.isAnswered && option == question.correctAnswer ? 2 : 1)
                }
                .hoverEffect(.lift)
                .accessibilityLabel("\(GameAnswerLetter.letter(for: index)), \(option)")
                .accessibilityValue(accessibilityState(for: option, in: question))
            }
        }
    }

    @ViewBuilder
    private func afterAnswer(for question: BookOrderQuickQuestion) -> some View {
        if round.isAnswered {
            let isCorrect = round.selectedAnswer == question.correctAnswer
            Label(isCorrect ? "Correct" : "The answer is \(question.correctAnswer)",
                  systemImage: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.headline)
                .foregroundStyle(isCorrect ? .green : .red)

            Button(round.isLastQuestion ? "See Results" : "Next Question",
                   systemImage: round.isLastQuestion ? "flag.checkered" : "arrow.right",
                   action: round.next)
                .buttonStyle(GameProminentButtonStyle(tint: .purple))
        }
    }

    private func fill(for option: String, in question: BookOrderQuickQuestion) -> Color {
        guard round.isAnswered else { return Color(.secondarySystemBackground) }
        if option == question.correctAnswer { return .green.opacity(0.22) }
        if option == round.selectedAnswer { return .red.opacity(0.22) }
        return Color(.secondarySystemBackground)
    }

    private func stroke(for option: String, in question: BookOrderQuickQuestion) -> Color {
        guard round.isAnswered else { return Color.primary.opacity(0.15) }
        if option == question.correctAnswer { return .green }
        if option == round.selectedAnswer { return .red }
        return Color.primary.opacity(0.15)
    }

    private func accessibilityState(for option: String, in question: BookOrderQuickQuestion) -> String {
        guard round.isAnswered else { return "" }
        if option == question.correctAnswer {
            return option == round.selectedAnswer ? String(localized: "Your answer, correct") : String(localized: "Correct answer")
        }
        return option == round.selectedAnswer ? String(localized: "Your answer, incorrect") : ""
    }

    private func handleKeyPress(_ keyPress: GameKeyboardPress) -> GameKeyboardPress.Result {
        guard let question = round.current else { return .ignored }

        if keyPress.key == .return || keyPress.characters == "\r" || keyPress.characters == "\n" {
            guard round.isAnswered else { return .ignored }
            round.next()
            return .handled
        }

        if case .beforeAfter = question.kind {
            switch keyPress.key {
            case .leftArrow: round.choose(question.options[0]); return .handled
            case .rightArrow: round.choose(question.options[1]); return .handled
            default: break
            }
        }

        guard !round.isAnswered, keyPress.modifiers.intersection([.command, .control, .option]).isEmpty else { return .ignored }
        // Which Section? has eight answers, so it also takes 5–8.
        let index: Int? = if let number = keyPress.characters.first?.wholeNumberValue, (1...question.options.count).contains(number) {
            number - 1
        } else {
            GameAnswerLetter.index(forKey: keyPress.characters)
        }
        guard let index, question.options.indices.contains(index) else { return .ignored }
        round.choose(question.options[index])
        return .handled
    }
}
