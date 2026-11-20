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
                ReviewRoundSession(game: selectedGame)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ReviewRoundHeader()

                        LazyVStack(spacing: 12) {
                            ForEach(availableGames, id: \.rawValue) { game in
                                NavigationLink {
                                    ReviewRoundSession(game: game)
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
}

/// What a game's results screen needs to know when it's showing a review round.
struct ReviewRoundContext {
    let game: MissedGameQuestionStore.Entry.Game
    /// Starts another review of this game's missed questions.
    let reviewAgain: () -> Void
}

extension EnvironmentValues {
    /// Set while a game is playing a review round, so its results show what the review cleared.
    @Entry var reviewRoundContext: ReviewRoundContext? = nil
}

/// One game's review rounds. Review Again draws a fresh set of missed questions and starts
/// the game over with them.
private struct ReviewRoundSession: View {
    let game: MissedGameQuestionStore.Entry.Game
    @State private var questionIDs: Set<String>
    /// Changes for each new round, so the game starts fresh rather than keeping its old state.
    @State private var round = 0

    init(game: MissedGameQuestionStore.Entry.Game) {
        self.game = game
        _questionIDs = State(initialValue: Set(MissedGameQuestionStore.shared.questionIDsForReview(game: game)))
    }

    var body: some View {
        destination
            .id(round)
            .environment(\.reviewRoundContext, ReviewRoundContext(game: game) {
                questionIDs = Set(MissedGameQuestionStore.shared.questionIDsForReview(game: game))
                round += 1
            })
    }

    @ViewBuilder
    private var destination: some View {
        switch game {
        case .beatTheClock:
            BeatTheClockGameView(reviewQuestionIDs: questionIDs)
        case .bibleQuiz:
            QuizView(reviewQuestionIDs: questionIDs)
        case .bibleTrivia:
            BibleTriviaGameView(reviewQuestionIDs: questionIDs)
        case .quizReverse:
            QuizView(reviewQuestionIDs: questionIDs, mode: .reverse)
        case .whoAmI:
            WhoAmIGameView(reviewQuestionIDs: questionIDs)
        case .hangman:
            HangmanGameView(reviewQuestionIDs: questionIDs)
        case .scramble:
            ScrambleGameView(reviewQuestionIDs: questionIDs)
        case .bookOrder:
            // Book Order misses are book names; the review asks a Missing Book question about each.
            BookOrderGameView(reviewBooks: Array(questionIDs))
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
            Text("Choose a game to practice \(MissedGameQuestionStore.reviewRoundSize) questions you have previously missed.")
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

extension MissedGameQuestionStore.Entry.Game {
    var title: LocalizedStringResource {
        switch self {
        case .beatTheClock: "Countdown"
        case .bibleQuiz: "Quiz"
        case .bibleTrivia: "Trivia"
        case .quizReverse: "Quiz — Reverse"
        case .whoAmI: "Who?"
        case .hangman: "Hangman"
        case .scramble: "Scramble"
        case .bookOrder: "Book Order"
        }
    }

    var systemImage: String {
        switch self {
        case .beatTheClock: "hourglass"
        case .bibleQuiz: "questionmark.circle.fill"
        case .bibleTrivia: "questionmark.text.page.fill"
        case .quizReverse: "text.quote"
        case .whoAmI: "person.text.rectangle"
        case .hangman: "text.word.spacing"
        case .scramble: "text.line.first.and.arrowtriangle.forward"
        case .bookOrder: "list.number"
        }
    }

    var tint: Color {
        switch self {
        case .beatTheClock: .indigo
        case .bibleQuiz: .blue
        case .bibleTrivia: .cyan
        case .quizReverse: .orange
        case .whoAmI: .brown
        case .hangman: .teal
        case .scramble: .pink
        case .bookOrder: .purple
        }
    }
}
