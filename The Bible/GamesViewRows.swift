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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Games")
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
                        }
                        .padding(.bottom, 6)

                        ForEach(group.routes) { route in
                            VStack(spacing: 0) {
                                GameNavigationRow(
                                    route: route,
                                    progress: progress(route),
                                    usesExpandedLayout: usesExpandedLayout,
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

struct GameCatalogSectionCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .heroCardSurface()
    }
}

struct GameRecommendationRow: View {
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
                        Text("Play next")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(recommendation.title)
                            .font(.subheadline.weight(.bold))
                        Text(recommendation.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Label("Play next", systemImage: "play.fill")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.clockwise.heart.fill")
                    .font(usesExpandedLayout ? .title2 : .title3)
                    .foregroundStyle(.purple)
                    .frame(minWidth: usesExpandedLayout ? 36 : 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Review Round")
                        .font(usesExpandedLayout ? .title3.weight(.semibold) : .headline)
                    Text("Active with 10 missed questions.")
                        .font(usesExpandedLayout ? .subheadline : .caption)
                        .foregroundStyle(.secondary)
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
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
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
        .contentShape(Rectangle())
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("gameRoute-\(route.rawValue)")
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

    var body: some View {
        Image(systemName: route.systemImage)
            .font(usesExpandedLayout ? .title2 : .title3)
            .foregroundStyle(route.tint)
            .frame(minWidth: usesExpandedLayout ? 36 : 28)
            .accessibilityHidden(true)
    }
}

private extension View {
    func gameCatalogSectionCard() -> some View {
        modifier(GameCatalogSectionCardStyle())
    }
}
