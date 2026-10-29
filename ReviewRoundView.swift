import SwiftUI

struct ReviewRoundView: View {
    private let availableGames: [MissedGameQuestionStore.Entry.Game]
    private let selectedGame: MissedGameQuestionStore.Entry.Game?

    init(reviewGameRawValue: String? = nil) {
        let availableGames = MissedGameQuestionStore.shared.reviewableGames()
        self.availableGames = availableGames

        if let reviewGameRawValue,
           let game = MissedGameQuestionStore.Entry.Game(rawValue: reviewGameRawValue),
           availableGames.contains(game) {
            selectedGame = game
        } else {
            selectedGame = nil
        }
    }

    var body: some View {
        Group {
            if let selectedGame {
                destination(for: selectedGame)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ReviewRoundHeader()

                        LazyVStack(spacing: 12) {
                            ForEach(availableGames, id: \.rawValue) { game in
                                NavigationLink {
                                    destination(for: game)
                                } label: {
                                    ReviewRoundGameCard(
                                        title: game.title,
                                        detail: "\(MissedGameQuestionStore.shared.reviewCount(for: game)) missed questions available",
                                        systemImage: game.systemImage,
                                        tint: game.tint
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding()
                }
                .background(AppBackgroundView(tab: .games))
                .navigationTitle("Review Round")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    @ViewBuilder
    private func destination(for game: MissedGameQuestionStore.Entry.Game) -> some View {
        let questionIDs = Set(MissedGameQuestionStore.shared.questionIDsForReview(game: game))
        switch game {
        case .beatTheClock:
            BeatTheClockGameView(reviewQuestionIDs: questionIDs)
        case .bibleQuiz:
            QuizView(reviewQuestionIDs: questionIDs)
        case .bibleTrivia:
            BibleTriviaGameView(reviewQuestionIDs: questionIDs)
        case .verseMatch:
            VerseMatchGameView(reviewQuestionIDs: questionIDs)
        case .whoAmI:
            WhoAmIGameView(reviewQuestionIDs: questionIDs)
        }
    }
}

private struct ReviewRoundHeader: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.clockwise.heart.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.purple)
            Text("Review missed questions")
                .font(.title2.weight(.bold))
            Text("Choose a game to practice ten questions you have previously missed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

private struct ReviewRoundGameCard: View {
    let title: LocalizedStringResource
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            tint.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        }
    }
}

private extension MissedGameQuestionStore.Entry.Game {
    var title: LocalizedStringResource {
        switch self {
        case .beatTheClock: "Countdown"
        case .bibleQuiz: "Quiz"
        case .bibleTrivia: "Trivia"
        case .verseMatch: "Verses"
        case .whoAmI: "Who?"
        }
    }

    var systemImage: String {
        switch self {
        case .beatTheClock: "hourglass"
        case .bibleQuiz: "questionmark.circle.fill"
        case .bibleTrivia: "questionmark.text.page.fill"
        case .verseMatch: "text.quote"
        case .whoAmI: "person.text.rectangle"
        }
    }

    var tint: Color {
        switch self {
        case .beatTheClock: .indigo
        case .bibleQuiz: .blue
        case .bibleTrivia: .cyan
        case .verseMatch: .orange
        case .whoAmI: .brown
        }
    }
}
