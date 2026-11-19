import SwiftUI
import SwiftData

// Rows and cards on the Games tab.

struct GameCollectionCard: View {
    let groups: [GameLearningGroup]
    let reviewProgress: [ReviewRoundProgress]
    let usesExpandedLayout: Bool
    let progress: (GameRoute) -> GameProgress
    let recommendation: GameRecommendation
    let onSelect: (GameRoute) -> Void
    let onSelectReviewGame: (ReviewRoundDestination) -> Void
    let onSelectRecommendation: (GameRecommendationDestination) -> Void
    let pencilTracker: PencilHoverTracker<GameRoute>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Not just "Games", which the screen's title already says.
            Text("All Games")
                .font(usesExpandedLayout ? .title3.weight(.bold) : .headline)
                .padding(.bottom, usesExpandedLayout ? 12 : 8)

            GameRecommendationRow(recommendation: recommendation) {
                onSelectRecommendation(recommendation.destination)
            }
            .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.title)
                                .font(.subheadline.weight(.bold))
                            Text(group.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.bottom, 6)

                        ForEach(group.routes) { route in
                            VStack(spacing: 0) {
                                GameNavigationRow(
                                    route: route,
                                    progress: progress(route),
                                    usesExpandedLayout: usesExpandedLayout,
                                    pencilTracker: pencilTracker,
                                    onSelect: { onSelect(route) }
                                )

                                if route.id != group.routes.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .gameCatalogSectionCard()
                }

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Review")
                            .font(.subheadline.weight(.bold))
                        Text("Practice questions you missed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 6)

                    ReviewRoundStatusRow(
                        progress: reviewProgress,
                        usesExpandedLayout: usesExpandedLayout,
                        onSelectGame: onSelectReviewGame
                    )
                }
                .gameCatalogSectionCard()
            }
            .padding(.top, 10)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .topLeading
        )
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
    }
}

/// The sections sit inside the All Games card, so they get a soft fill rather than a second
/// bordered, shadowed card.
struct GameCatalogSectionCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct GameRecommendationRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let recommendation: GameRecommendation
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: recommendation.systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.purple)
                        .frame(width: 32, height: 32)
                        .background(Color.purple.opacity(0.12), in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Recommended")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(recommendation.title)
                            .font(.subheadline.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(recommendation.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Label("Play", systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 3)
                    .background(Color.purple, in: Capsule())
                    .foregroundStyle(.white)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(recommendation.destination.accessibilityHint)
        .accessibilityIdentifier("playNextGameButton")
    }
}

struct ReviewRoundStatusRow: View {
    let progress: [ReviewRoundProgress]
    let usesExpandedLayout: Bool
    let onSelectGame: (ReviewRoundDestination) -> Void

    private var hasEligibleGame: Bool { progress.contains { $0.isReady } }

    // The same icon column as the game rows above, so the titles line up.
    @ScaledMetric(relativeTo: .title3) private var iconWidth: CGFloat = 34
    @ScaledMetric(relativeTo: .title2) private var expandedIconWidth: CGFloat = 40

    /// Says whether a round is ready, rather than one fixed line that read as "active" even
    /// before any game had missed questions.
    private var statusText: LocalizedStringResource {
        hasEligibleGame
            ? "Ready: replay the questions you missed."
            : "Unlocks once a game has 10 missed questions."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.clockwise.heart.fill")
                    .font(usesExpandedLayout ? .title2 : .title3)
                    .foregroundStyle(.purple)
                    .frame(width: usesExpandedLayout ? expandedIconWidth : iconWidth)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Review Round")
                        .font(usesExpandedLayout ? .title3.weight(.semibold) : .headline)
                    Text(statusText)
                        .font(usesExpandedLayout ? .subheadline : .caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ForEach(progress) { item in
                HStack {
                    Text(item.title)
                        .font(.caption)
                    Spacer()
                    Text("\(item.count) / 10")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(item.isReady ? .purple : .secondary)

                    if item.isReady {
                        Button("Play") {
                            onSelectGame(.game(item.game.rawValue))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.small)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, usesExpandedLayout ? 9 : 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hasEligibleGame ? "Review Round, ready" : "Review Round, locked")
        .accessibilityHint("Requires 10 replayable missed questions in one game.")
        .accessibilityIdentifier(hasEligibleGame ? "reviewRoundReady" : "reviewRoundLocked")
    }
}

struct GameNavigationRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let route: GameRoute
    let progress: GameProgress
    let usesExpandedLayout: Bool
    let pencilTracker: PencilHoverTracker<GameRoute>
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    GameAccessibilityRow(route: route, progress: progress)
                } else {
                    GameStandardRow(
                        route: route,
                        progress: progress,
                        usesExpandedLayout: usesExpandedLayout
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : (usesExpandedLayout ? 9 : 4))
            // The shape belongs on the label: a plain button only responds where its label
            // draws, so on a wide iPad row the empty middle ignored taps.
            .contentShape(Rectangle())
            .background(
                route.tint.opacity(isHovering ? 0.14 : 0),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .onHover { isHovering in
            self.isHovering = isHovering
            if isHovering {
                Haptics.selection()
            }
            pencilTracker.hover(route, isHovering: isHovering)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("gameRoute-\(route.rawValue)")
    }
}

struct GameProgressSheet: View {
    @Environment(\.dismiss) private var dismiss

    let route: GameRoute
    let entry: GameStats.GameBreakdown.Entry?

    private var answered: Int { max(0, entry?.answered ?? 0) }
    private var correct: Int { max(0, entry?.correct ?? 0) }
    private var accuracy: Int {
        guard answered > 0 else { return 0 }
        return Int((Double(correct) / Double(answered) * 100).rounded())
    }
    private var bestStreak: Int { max(0, entry?.bestStreak ?? 0) }

    var body: some View {
        NavigationStack {
            Group {
                if answered == 0 {
                    ContentUnavailableView(
                        "No Progress Yet",
                        systemImage: route.systemImage,
                        description: Text("Play \(route.visibleName) to start tracking your progress.")
                    )
                } else {
                    List {
                        Section {
                            LabeledContent("Played", value: answered.formatted())
                            LabeledContent("Correct", value: correct.formatted())
                            LabeledContent("Accuracy", value: "\(accuracy)%")
                            LabeledContent("Best Streak", value: bestStreak.formatted())
                        }
                    }
                }
            }
            .navigationTitle(route.visibleName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct GameStandardRow: View {
    let route: GameRoute
    let progress: GameProgress
    let usesExpandedLayout: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GameRowIcon(route: route, usesExpandedLayout: usesExpandedLayout)

            VStack(alignment: .leading, spacing: 3) {
                Text(route.title)
                    .font(usesExpandedLayout ? .title3.weight(.semibold) : .headline)
                Text(route.subtitle)
                    .font(usesExpandedLayout ? .subheadline : .caption)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)

            Spacer(minLength: 8)

            GameProgressLabel(
                progress: progress,
                font: (usesExpandedLayout ? Font.footnote : Font.caption).weight(.medium)
            )
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: true, vertical: false)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }
}

struct GameAccessibilityRow: View {
    let route: GameRoute
    let progress: GameProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                GameRowIcon(route: route)

                Text(route.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                // Like the standard row, so the row still reads as something to open.
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }

            Text(route.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GameProgressLabel(progress: progress, font: .caption.weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GameProgressLabel: View {
    let progress: GameProgress
    let font: Font

    var body: some View {
        switch progress {
        case .standard(let text):
            Text(text)
                .font(font)
                .foregroundStyle(.secondary)
        case .dailyWord(let word, let won):
            HStack(spacing: 4) {
                Text(word)
                    .strikethrough(!won)

                Image(systemName: won ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .accessibilityHidden(true)
            }
            .font(font)
            .foregroundStyle(won ? .green : .red)
            .accessibilityLabel(won ? "Today's WORD: \(word), solved" : "Today's WORD: \(word), not solved")
        }
    }
}

struct GameRowIcon: View {
    let route: GameRoute
    var usesExpandedLayout = false

    // A fixed column, not a minimum, so a wide symbol (like Word's) doesn't push its title
    // out of line with the others. It grows with the text size like the symbol does.
    @ScaledMetric(relativeTo: .title3) private var width: CGFloat = 34
    @ScaledMetric(relativeTo: .title2) private var expandedWidth: CGFloat = 40

    var body: some View {
        Image(systemName: route.systemImage)
            .font(usesExpandedLayout ? .title2 : .title3)
            .foregroundStyle(route.tint)
            .frame(width: usesExpandedLayout ? expandedWidth : width)
            .accessibilityHidden(true)
    }
}

private extension View {
    func gameCatalogSectionCard() -> some View {
        modifier(GameCatalogSectionCardStyle())
    }
}
