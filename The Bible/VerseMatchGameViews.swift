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
        if showsSwapButton {
            largeCard
        } else {
            compactHeader
        }
    }

    /// iPad: a tall card beside the answers, with a button to swap sides.
    private var largeCard: some View {
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

            Button(action: onSwap) {
                Image(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Swap card sides")
            .accessibilityHint("Moves the reference and answers cards to opposite sides.")
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
    }

    /// iPhone: a short header, so the four verses need less scrolling.
    private var compactHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(reference)
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            Text(progressText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, AppDesignMetrics.cardPadding)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .heroCardSurface()
        .accessibilityElement(children: .combine)
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
                .glassEffect(answerGlass(for: index), in: .rect(cornerRadius: 12))
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

    private func answerGlass(for index: Int) -> Glass {
        guard let selectedIndex else {
            return .regular
        }
        if index == correctIndex {
            return .regular.tint(.green.opacity(0.35))
        }
        if index == selectedIndex, selectedIndex != correctIndex {
            return .regular.tint(.red.opacity(0.35))
        }
        return .regular
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
