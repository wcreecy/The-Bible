import SwiftUI

// MARK: - Setup views

struct BeatTheClockSetupControls: View {
    @Binding var mode: BeatTheClockMode
    @Binding var category: BeatTheClockCategory
    /// A review picks its mode from the modes ready for review instead.
    @Environment(\.reviewRoundContext) private var reviewRound

    private func icon(for category: BeatTheClockCategory) -> String {
        switch category {
        case .people: "person.fill"
        case .places: "mappin.and.ellipse"
        case .both: "square.grid.2x2.fill"
        }
    }

    private func detail(for category: BeatTheClockCategory) -> LocalizedStringResource {
        switch category {
        case .people: "Questions about people in the Bible."
        case .places: "Questions about Biblical places."
        case .both: "A mixed round of people and places."
        }
    }

    var body: some View {
        GameSettingsGroup {
            if reviewRound == nil {
                GameChoiceSetting(
                    title: "Mode",
                    systemImage: "hourglass",
                    tint: .indigo,
                    selection: $mode,
                    choices: BeatTheClockMode.allCases.map {
                        GameChoice(value: $0, title: $0.title, detail: $0.detail, icon: $0.systemImage)
                    }
                )
            }

            GameChoiceSetting(
                title: "Question subject",
                systemImage: "person.2.fill",
                tint: .indigo,
                selection: $category,
                choices: BeatTheClockCategory.allCases.map {
                    GameChoice(value: $0, title: $0.title, detail: detail(for: $0), icon: icon(for: $0))
                }
            )
        }
    }
}

// MARK: - Gameplay views

struct BeatTheClockClueRow: View {
    let clue: String
    let isRevealed: Bool
    let canRequestHint: Bool
    let onRequestHint: () -> Void
    let testamentHint: String
    let offersTestamentHint: Bool
    let showsTestamentHint: Bool
    let canRequestTestamentHint: Bool
    let onRequestTestamentHint: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !clue.isEmpty {
                if isRevealed {
                    Label(clue, systemImage: "lightbulb.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Button(
                        "Show clue (−\(BeatTheClockDifficulty.hintCost) sec)",
                        systemImage: "lightbulb",
                        action: onRequestHint
                    )
                    .buttonStyle(.gameHint(tint: .indigo))
                    .disabled(!canRequestHint)
                }
            }

            if offersTestamentHint {
                if showsTestamentHint {
                    Label(testamentHint, systemImage: "books.vertical.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Button(
                        "Which Testament? (−\(BeatTheClockDifficulty.testamentHintCost) sec)",
                        systemImage: "books.vertical",
                        action: onRequestTestamentHint
                    )
                    .buttonStyle(.gameHint(tint: .indigo))
                    .disabled(!canRequestTestamentHint)
                }
            }
        }
    }
}

/// Four books to tap. Once answered, the right one turns green, a wrong pick red, and the
/// rest fade.
struct BeatTheClockChoiceGrid: View {
    let books: [String]
    let answer: String
    let chosen: String?
    let isLocked: Bool
    let tint: Color
    let onChoose: (String) -> Void

    private enum TileState {
        case open
        case right
        case wrong
        case faded
    }

    private func state(for book: String) -> TileState {
        guard isLocked else { return .open }
        if book == answer { return .right }
        return book == chosen ? .wrong : .faded
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(books, id: \.self) { book in
                let state = state(for: book)
                Button {
                    onChoose(book)
                } label: {
                    tile("\(GameAnswerLetter.letter(for: books.firstIndex(of: book) ?? 0)). \(book)", state: state)
                }
                .buttonStyle(.plain)
                // Not `.disabled`, which would fade the green and red the answer is shown in.
                .allowsHitTesting(!isLocked)
                .hoverEffect(.lift)
                .accessibilityValue(accessibilityValue(for: state))
            }
        }
        .animation(.snappy, value: isLocked)
    }

    private func tile(_ book: String, state: TileState) -> some View {
        let color: Color = switch state {
        case .open, .faded: tint
        case .right: .green
        case .wrong: .red
        }
        return HStack(spacing: 8) {
            Text(book)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            if state == .right {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if state == .wrong {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(
            color.opacity(state == .open || state == .faded ? 0.08 : 0.18),
            in: RoundedRectangle(cornerRadius: AppDesignMetrics.compactControlCornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppDesignMetrics.compactControlCornerRadius, style: .continuous)
                .strokeBorder(color.opacity(state == .faded ? 0.12 : 0.45), lineWidth: state == .open ? 1 : 2)
        }
        .opacity(state == .faded ? 0.5 : 1)
        .contentShape(RoundedRectangle(cornerRadius: AppDesignMetrics.compactControlCornerRadius, style: .continuous))
    }

    private func accessibilityValue(for state: TileState) -> Text {
        switch state {
        case .open, .faded: Text("")
        case .right: Text("Right answer")
        case .wrong: Text("Your answer, wrong")
        }
    }
}

/// Higher or Lower's two names. Once one is picked, both show how many books they're in.
struct BeatTheClockPairBoard: View {
    let first: BeatTheClockQuestion
    let second: BeatTheClockQuestion
    let winnerID: String?
    let chosenID: String?
    let isLocked: Bool
    let tint: Color
    let onChoose: (String) -> Void

    var body: some View {
        HStack(spacing: 12) {
            card(first)
            card(second)
        }
        .animation(.snappy, value: isLocked)
    }

    private func card(_ question: BeatTheClockQuestion) -> some View {
        let isWinner = question.id == winnerID
        let color: Color = !isLocked ? tint : (isWinner ? .green : (question.id == chosenID ? .red : .secondary))
        let count = question.acceptableBooks.count
        return Button {
            onChoose(question.id)
        } label: {
            VStack(spacing: 10) {
                Image(systemName: question.subject == .place ? "mappin.and.ellipse" : "person.fill")
                    .font(.title2)
                    .foregroundStyle(color)
                Text(question.label)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                if isLocked {
                    Text(count == 1 ? "1 book" : "\(count) books")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(color)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 150)
            .background(
                color.opacity(isLocked ? 0.16 : 0.08),
                in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
                    .strokeBorder(color.opacity(0.45), lineWidth: isLocked ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        // Not `.disabled`, which would fade the green and red the answer is shown in.
        .allowsHitTesting(!isLocked)
        .hoverEffect(.lift)
        .accessibilityValue(isLocked ? Text(count == 1 ? "1 book" : "\(count) books") : Text(""))
    }
}

/// Every accepted book, most mentions first, each linking to its first mention.
struct BeatTheClockBooksList: View {
    let books: [(book: String, verses: Int)]
    let foundBooks: Set<String>
    let firstMention: (String) -> String?
    let onOpen: (String) -> Void

    var body: some View {
        List(books, id: \.book) { entry in
            let reference = firstMention(entry.book)
            Button {
                if let reference { onOpen(reference) }
            } label: {
                HStack {
                    if foundBooks.contains(entry.book) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .accessibilityLabel("Found")
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.book)
                            .foregroundStyle(.primary)
                        if let reference {
                            Text("First mentioned in \(reference)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if entry.verses > 0 {
                        Text(entry.verses == 1 ? "1 verse" : "\(entry.verses) verses")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(reference == nil)
        }
        .listStyle(.insetGrouped)
    }
}

struct BeatTheClockRoundResultCard: View {
    let outcome: BeatTheClockRoundOutcome
    let subjectName: String
    let submittedBook: String?
    /// The accepted books, most mentions first.
    let books: [(book: String, verses: Int)]
    let scriptureReference: String?
    /// First Appearance's answer and its first verse, or nil in Classic.
    let firstAppearance: (book: String, reference: String?)?
    let earnedSpeedBonus: Bool
    let onShowAllAnswers: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(outcome.title, systemImage: outcome.systemImage)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(outcome.tint)
                if earnedSpeedBonus {
                    Label("+1 speed bonus", systemImage: "bolt.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                }
            }

            if let firstAppearance {
                if outcome == .incorrect, let submittedBook {
                    Text("\(submittedBook) mentions \(subjectName), but not first.")
                        .font(.subheadline)
                }
                Text("\(subjectName) first appears in \(firstAppearance.book).")
                    .font(.subheadline.weight(.semibold))
                if let reference = firstAppearance.reference {
                    Label("First mentioned in \(reference)", systemImage: "book.closed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
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
            }

            if books.count > 1 {
                Button("Show all \(books.count) books", systemImage: "books.vertical.fill", action: onShowAllAnswers)
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

    /// The books with the most mentions, e.g. "1 Samuel (42) · 2 Samuel (31) · 1 Kings (12)".
    private var topBooks: String {
        books.prefix(4)
            .map { $0.verses > 0 ? "\($0.book) (\($0.verses))" : $0.book }
            .joined(separator: " · ")
    }

    @ViewBuilder
    private var answerSummary: some View {
        let count = books.count
        if count == 0 {
            Text("No books are listed for this entry.")
        } else if count == 1, let onlyBook = books.first?.book {
            Text(outcome == .correct
                ? "That’s the only book that mentions \(subjectName)."
                : "The answer was \(onlyBook).")
        } else {
            Text("Mentioned most in \(topBooks)\(count > 4 ? " …" : "")")
        }
    }
}

struct BeatTheClockActions: View {
    let isLocked: Bool
    let isLastQuestion: Bool
    let showsDebugWin: Bool
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
            } else if showsDebugWin {
                Button("Win this round", systemImage: "checkmark.seal.fill", action: onDebugWin)
                    .buttonStyle(.glass(.regular.tint(.red)))
            }
        }
    }
}

struct BeatTheClockDashboardPrompt: View {
    let targetType: String
    let isPlace: Bool
    let progressText: String
    let title: String
    /// What to do with the board; nil when the title already asks it.
    let instruction: String?
    let clueRow: BeatTheClockClueRow?
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

            Text(title)
                .font(.largeTitle.weight(.bold))
                .fontDesign(.rounded)
                .lineLimit(2)

            if let instruction {
                Text(instruction)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let clueRow {
                clueRow
            }
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

struct BeatTheClockLargeTimerView: View {
    let remainingSeconds: Int
    let tint: Color
    let isPulsing: Bool
    let isTimerDisabled: Bool
    let outcome: BeatTheClockRoundOutcome?
    /// False on a game clock, which can't be switched off.
    let canToggleTimer: Bool
    @Binding var usesMutedStyle: Bool
    let onToggleTimer: () -> Void
    let onSwapSides: () -> Void

    private var timerTextColor: Color {
        tint == .yellow ? .black : .white
    }

    private var isActive: Bool { outcome == nil }

    private var displayTint: Color {
        isTimerDisabled && outcome == nil ? .secondary : outcome?.tint ?? tint
    }

    private var vividTextColor: Color {
        isActive ? timerTextColor : .white
    }

    private var canToggle: Bool { isActive && canToggleTimer }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                Image(systemName: outcome?.systemImage ?? (isTimerDisabled ? "timer.slash" : "timer"))
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor.opacity(0.85))

                Text(outcome?.title ?? (isTimerDisabled ? "Timer Off" : "Time Remaining"))
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor.opacity(0.85))

                if isActive {
                    Text("\(remainingSeconds)s")
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(usesMutedStyle ? displayTint : vividTextColor)
                        .contentTransition(.numericText())
                }
            }
            .scaleEffect(isPulsing ? 1.04 : 1.0)
            .animation(.easeOut(duration: 0.18), value: isPulsing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(outcome?.title ?? (isTimerDisabled ? "Timer off" : "Time Remaining"))
            .accessibilityValue(isActive ? "\(remainingSeconds) seconds" : "")
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
