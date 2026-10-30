import SwiftUI

// MARK: - Setup views

struct VerseMatchSetupControls: View {
    @Binding var pool: VerseMatchPool
    let isFavoritesAvailable: Bool

    var body: some View {
        GameChoiceSetting(
            title: "Verses",
            systemImage: "text.quote",
            tint: .orange,
            selection: $pool,
            choices: VerseMatchPool.allCases.map {
                GameChoice(
                    value: $0,
                    title: $0.title,
                    detail: $0 == .favorites && !isFavoritesAvailable
                        ? "Save a favorite verse to unlock this."
                        : $0.detail,
                    icon: $0.icon,
                    isEnabled: $0 != .favorites || isFavoritesAvailable
                )
            }
        )
    }
}

// MARK: - Gameplay views

struct VerseMatchBoard: View {
    let reference: String
    let progressText: String
    let options: [VerseMatchVerse]
    let selectedIndex: Int?
    let correctIndex: Int
    let isLocked: Bool
    let usesSideBySideLayout: Bool
    @Binding var referenceOnLeading: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        if usesSideBySideLayout {
            HStack(alignment: .top, spacing: 20) {
                if referenceOnLeading {
                    referenceCard
                    answersCard
                } else {
                    answersCard
                    referenceCard
                }
            }
            .animation(.easeInOut(duration: 0.2), value: referenceOnLeading)
        } else {
            VStack(spacing: 16) {
                referenceCard
                answersCard
            }
        }
    }

    private var referenceCard: some View {
        VerseMatchReferenceCard(
            reference: reference,
            progressText: progressText,
            showsSwapButton: usesSideBySideLayout,
            onSwap: { referenceOnLeading.toggle() }
        )
        .frame(maxWidth: .infinity)
    }

    private var answersCard: some View {
        VerseMatchAnswersCard(
            options: options,
            selectedIndex: selectedIndex,
            correctIndex: correctIndex,
            isLocked: isLocked,
            onSelect: onSelect
        )
        .frame(maxWidth: .infinity)
    }
}

private struct VerseMatchReferenceCard: View {
    let reference: String
    let progressText: String
    let showsSwapButton: Bool
    let onSwap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Text(progressText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer(minLength: 12)

                Text(reference)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 12)
            }

            if showsSwapButton {
                Button(action: onSwap) {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Swap card sides")
                .accessibilityHint("Moves the reference and answers cards to opposite sides.")
            }
        }
        .frame(maxWidth: .infinity, minHeight: showsSwapButton ? 280 : 160)
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
    }
}

private struct VerseMatchAnswersCard: View {
    let options: [VerseMatchVerse]
    let selectedIndex: Int?
    let correctIndex: Int
    let isLocked: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Potential Answers", systemImage: "text.page")
                .font(.headline)

            Text("Which verse matches this reference?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        onSelect(index)
                    } label: {
                        Text("“\(option.verseText)”")
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked)
                    .accessibilityValue(accessibilityState(for: index))

                    if selectedIndex != nil {
                        HStack(spacing: 8) {
                            Text(option.reference)
                                .font(.caption.weight(index == correctIndex ? .bold : .regular))
                                .foregroundStyle(index == correctIndex ? Color.green : Color.secondary)

                            Spacer()

                            VerseActionMenu(
                                verse: VerseActionReference(
                                    bookName: option.bookName,
                                    chapterNumber: option.chapterNumber,
                                    verseNumber: option.verseNumber,
                                    verseText: option.verseText
                                )
                            )
                        }
                    }
                }
                .padding()
                .background(backgroundColor(for: index))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(borderColor(for: index), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let selectedIndex {
                Label(
                    selectedIndex == correctIndex ? "Correct!" : "Not quite",
                    systemImage: selectedIndex == correctIndex ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(selectedIndex == correctIndex ? .green : .red)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
    }

    private func accessibilityState(for index: Int) -> String {
        guard let selectedIndex else { return "" }
        if index == correctIndex { return String(localized: "Correct answer") }
        if index == selectedIndex { return String(localized: "Your answer, incorrect") }
        return ""
    }

    private func backgroundColor(for index: Int) -> Color {
        guard let selectedIndex else {
            return Color(.secondarySystemBackground)
        }
        if index == correctIndex {
            return Color.green.opacity(0.18)
        }
        if index == selectedIndex, selectedIndex != correctIndex {
            return Color.red.opacity(0.18)
        }
        return Color(.secondarySystemBackground)
    }

    private func borderColor(for index: Int) -> Color {
        guard let selectedIndex else {
            return Color.black.opacity(0.12)
        }
        if index == correctIndex {
            return Color.green.opacity(0.6)
        }
        if index == selectedIndex, selectedIndex != correctIndex {
            return Color.red.opacity(0.6)
        }
        return Color.black.opacity(0.12)
    }
}

struct VerseMatchNavigationButtons: View {
    let canGoPrevious: Bool
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
                    .buttonStyle(GameProminentButtonStyle(tint: .orange))
            } else {
                Button("Next", systemImage: "arrow.right", action: onNext)
                    .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
            }
        }
    }
}

struct VerseMatchResultsCard: View {
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
                .foregroundStyle(isNewBest ? Color.yellow : Color.orange)

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
                    .buttonStyle(GameProminentButtonStyle(tint: .orange))

                Button("Change Settings", systemImage: "slider.horizontal.3", action: onChangeSettings)
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
            }
        }
        .padding(24)
        .frame(maxWidth: 520)
        .heroCardSurface()
    }
}
