import SwiftUI

// MARK: - Setup views

struct BeatTheClockSetupControls: View {
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

    var body: some View {
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
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderless)
                .disabled(!canRequestHint)
            }
        }
    }
}

struct BeatTheClockRoundResultCard: View {
    let outcome: BeatTheClockRoundOutcome
    let subjectName: String
    let submittedBook: String?
    let acceptableBooks: [String]
    let scriptureReference: String?
    let onShowAllAnswers: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(outcome.title, systemImage: outcome.systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(outcome.tint)

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

            if acceptableBooks.count > 1 {
                Button("Show all \(acceptableBooks.count) books", systemImage: "books.vertical.fill", action: onShowAllAnswers)
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

    @ViewBuilder
    private var answerSummary: some View {
        let count = acceptableBooks.count
        if count == 0 {
            Text("No books are listed for this entry.")
        } else if outcome == .correct {
            if count == 1 {
                Text("That’s the only book that mentions \(subjectName).")
            } else {
                Text("\(subjectName) appears in ^[\(count) book](inflect: true).")
            }
        } else if count == 1, let onlyBook = acceptableBooks.first {
            Text("The answer was \(onlyBook).")
        } else {
            Text("Answers include \(Array(acceptableBooks.prefix(3)).formatted(.list(type: .and))).")
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
