import SwiftUI

// MARK: - Setup views

/// One-tap shortcuts for the whole Bible or one Testament. Also used by Verses.
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

struct QuizAnswerReveal: View {
    let outcome: QuizOutcome
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: outcome.systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(outcome.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(outcome.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(outcome.tint)

                Text("\(bookName) \(chapterNumber):\(verseNumber)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 8)

            VerseActionMenu(
                verse: VerseActionReference(
                    bookName: bookName,
                    chapterNumber: chapterNumber,
                    verseNumber: verseNumber,
                    verseText: verseText
                )
            )
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 64)
        .glassEffect(.regular.tint(outcome.tint.opacity(0.35)), in: .rect(cornerRadius: AppDesignMetrics.compactControlCornerRadius))
        .accessibilityElement(children: .combine)
    }
}

struct QuizNavigationButtons: View {
    let canGoPrevious: Bool
    let canGoNext: Bool
    let isLastQuestion: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button("Previous", systemImage: "arrow.left", action: onPrevious)
                .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
                .disabled(!canGoPrevious)

            if isLastQuestion {
                Button("See Results", systemImage: "flag.checkered", action: onNext)
                    .buttonStyle(GameProminentButtonStyle(tint: .blue))
                    .disabled(!canGoNext)
            } else {
                Button("Next", systemImage: "arrow.right", action: onNext)
                    .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
                    .disabled(!canGoNext)
            }
        }
    }
}

struct QuizDashboardQuestion: View {
    let progressText: String
    let verseText: String
    let contextRow: QuizContextRow?
    let options: [String]
    let selectedOption: String?
    let correctBookName: String
    let isAnswered: Bool
    let isViewingPrevious: Bool
    let onSelectOption: (String) -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                HStack {
                    Label("Which book is this from?", systemImage: "text.book.closed.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tint)

                    Spacer()

                    Text(progressText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Text("“\(verseText)”")
                    .italic()
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                contextRow
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(options, id: \.self) { option in
                    Button {
                        onSelectOption(option)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: optionIcon(for: option))
                            Text(option)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                    }
                    .buttonStyle(.glass(optionGlass(for: option)))
                    .disabled(isAnswered || isViewingPrevious)
                }
            }
        }
    }

    private func optionGlass(for option: String) -> Glass {
        guard isAnswered else { return .clear }
        if option == correctBookName { return .regular.tint(.green.opacity(0.28)) }
        if option == selectedOption { return .regular.tint(.red.opacity(0.28)) }
        return .clear
    }

    private func optionIcon(for option: String) -> String {
        guard isAnswered else { return "book.closed.fill" }
        if option == correctBookName { return "checkmark.circle.fill" }
        if option == selectedOption { return "xmark.circle.fill" }
        return "book.closed.fill"
    }
}

struct QuizResultsCard: View {
    let score: Int
    let total: Int
    let bestStreak: Int
    let bestGameScore: Int
    let isNewBest: Bool
    let onPlayAgain: () -> Void
    let onChangeSettings: () -> Void

    private var accuracy: Int {
        guard total > 0 else { return 0 }
        return Int((Double(score) / Double(total) * 100).rounded())
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isNewBest ? "trophy.fill" : "flag.checkered")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(isNewBest ? Color.yellow : Color.blue)

            VStack(spacing: 6) {
                Text(isNewBest ? "New Best Game!" : "Game Over")
                    .font(.title.weight(.bold))

                Text("\(score) of \(total) correct")
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            GameSplashFacts(
                first: ("percent", "\(accuracy)%", String(localized: "Accuracy")),
                second: ("flame.fill", "\(bestStreak)", String(localized: "Best streak")),
                third: ("trophy", "\(bestGameScore)/\(total)", String(localized: "Best game"))
            )

            VStack(spacing: 10) {
                Button("Play Again", systemImage: "arrow.clockwise", action: onPlayAgain)
                    .buttonStyle(GameProminentButtonStyle(tint: .blue))

                Button("Change Settings", systemImage: "slider.horizontal.3", action: onChangeSettings)
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
            }
        }
        .padding(24)
        .frame(maxWidth: 520)
        .heroCardSurface()
    }
}

struct QuizLargeTimerView: View {
    let remainingSeconds: Int
    let tint: Color
    let isPulsing: Bool
    let isTimed: Bool
    let isTimerDisabled: Bool
    let outcome: QuizOutcome?
    @Binding var usesMutedStyle: Bool
    let onToggleTimer: () -> Void
    let onSwapSides: () -> Void

    private var isActive: Bool {
        isTimed && outcome == nil
    }

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

                if outcome == nil {
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
            .accessibilityValue(isActive ? "\(remainingSeconds) seconds" : outcome == nil ? "No time limit" : "")

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button("Swap card sides", systemImage: "arrow.left.arrow.right", action: onSwapSides)

                if isTimed, outcome == nil {
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
        .animation(.easeInOut(duration: 0.25), value: remainingSeconds)
    }

    private var statusTitle: LocalizedStringKey {
        if let outcome { return outcome.title }
        if isTimerDisabled { return "Timer Off" }
        return isTimed ? "Time Remaining" : "Untimed Mode"
    }

    private var statusSystemImage: String {
        if let outcome { return outcome.systemImage }
        if isTimerDisabled { return "timer.slash" }
        return isTimed ? "timer" : "infinity"
    }
}
