import SwiftUI

// MARK: - Setup views

struct BeatTheClockSetupControls: View {
    @Binding var mode: BeatTheClockMode
    @Binding var category: BeatTheClockCategory

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
            GameChoiceSetting(
                title: "Mode",
                systemImage: "hourglass",
                tint: .indigo,
                selection: $mode,
                choices: BeatTheClockMode.allCases.map {
                    GameChoice(value: $0, title: $0.title, detail: $0.detail, icon: $0.systemImage)
                }
            )

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

/// Rapid Fire: the books found so far for the current name.
struct BeatTheClockFoundBooks: View {
    let foundBooks: [String]
    let totalBooks: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(foundBooks.count) of \(totalBooks) found", systemImage: "flame.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
                .contentTransition(.numericText())

            if !foundBooks.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], alignment: .leading, spacing: 6) {
                    ForEach(foundBooks, id: \.self) { book in
                        Label(book, systemImage: "checkmark")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.15), in: Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.snappy, value: foundBooks)
        .accessibilityElement(children: .combine)
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
    /// Rapid Fire's books found, or nil in Classic.
    let foundBooks: [String]?
    let earnedSpeedBonus: Bool
    let earnedLessKnownBonus: Bool
    let onShowAllAnswers: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(foundBooks == nil ? outcome.title : "Round Over", systemImage: foundBooks == nil ? outcome.systemImage : "flame.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(foundBooks == nil ? outcome.tint : .orange)
                if earnedSpeedBonus {
                    Label("+1 speed bonus", systemImage: "bolt.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                }
                if earnedLessKnownBonus {
                    Label("+1 less-known book", systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.purple)
                }
            }

            if let foundBooks {
                Text("You found \(foundBooks.count) of \(books.count) books that mention \(subjectName).")
                    .font(.subheadline)
            } else if outcome == .incorrect, let submittedBook {
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

            if books.count > 1 {
                Button("Show all \(books.count) books", systemImage: "books.vertical.fill", action: onShowAllAnswers)
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            (foundBooks == nil ? outcome.tint : .orange).opacity(0.1),
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

struct BeatTheClockDashboardPrompt: View {
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

struct BeatTheClockDashboardAnswer: View {
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

struct BeatTheClockLargeTimerView: View {
    let remainingSeconds: Int
    let tint: Color
    let isPulsing: Bool
    let isTimerDisabled: Bool
    let outcome: BeatTheClockRoundOutcome?
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
                }
            }
            .scaleEffect(isPulsing ? 1.04 : 1.0)
            .animation(.easeOut(duration: 0.18), value: isPulsing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(outcome?.title ?? (isTimerDisabled ? "Timer off" : "Time Remaining"))
            .accessibilityValue(isActive ? "\(remainingSeconds) seconds" : "")
            .contentShape(Rectangle())
            .onTapGesture {
                if isActive {
                    onToggleTimer()
                }
            }
            .accessibilityAddTraits(isActive ? .isButton : [])
            .accessibilityHint(
                isActive
                    ? (isTimerDisabled ? "Tap to turn the timer on." : "Tap to turn the timer off.")
                    : ""
            )

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                if isActive {
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
