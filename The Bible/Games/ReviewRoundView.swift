import SwiftUI

// MARK: - The games and modes a review can replay

/// A game on the review list. Its misses are counted, and replayed, in each of its modes;
/// a game is ready to review once any one mode has a full round of misses.
enum ReviewGame: String, CaseIterable, Identifiable {
    case quiz
    case trivia
    case countdown
    case whoAmI
    case hangman
    case scramble
    case bookOrder
    case word

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .quiz: "Quiz"
        case .trivia: "Trivia"
        case .countdown: "Countdown"
        case .whoAmI: "Who?"
        case .hangman: "Hangman"
        case .scramble: "Scramble"
        case .bookOrder: "Book Order"
        case .word: "WORD"
        }
    }

    var systemImage: String {
        switch self {
        case .quiz: "questionmark.circle.fill"
        case .trivia: "questionmark.text.page.fill"
        case .countdown: "hourglass"
        case .whoAmI: "person.text.rectangle"
        case .hangman: "text.word.spacing"
        case .scramble: "text.line.first.and.arrowtriangle.forward"
        case .bookOrder: "list.number"
        case .word: "textformat.abc"
        }
    }

    var tint: Color {
        switch self {
        case .quiz: .blue
        case .trivia: .cyan
        case .countdown: .indigo
        case .whoAmI: .brown
        case .hangman: .teal
        case .scramble: .pink
        case .bookOrder: .purple
        case .word: .mint
        }
    }

    /// Every mode the game is played in, in the order its start page lists them. A game with
    /// one way to play has a single mode named after the game.
    var modes: [ReviewGameMode] {
        switch self {
        case .quiz:
            [
                ReviewGameMode(game: .bibleQuiz, title: QuizMode.standard.title, detail: "Verse text → book", icon: "book.closed"),
                ReviewGameMode(game: .quizReverse, title: QuizMode.reverse.title, detail: "Reference → verse text", icon: "text.quote")
            ]
        case .trivia:
            [ReviewGameMode(game: .bibleTrivia, title: title, icon: systemImage)]
        case .countdown:
            BeatTheClockMode.allCases.map {
                ReviewGameMode(game: .beatTheClock, mode: $0.rawValue, title: $0.title, detail: $0.detail, icon: $0.systemImage)
            }
        case .whoAmI:
            WhoAmIGameViewModel.Mode.allCases.map {
                ReviewGameMode(game: .whoAmI, mode: $0.rawValue, title: $0.title, detail: $0.detail, icon: $0.icon)
            }
        case .hangman:
            [ReviewGameMode(game: .hangman, title: title, icon: systemImage)]
        case .scramble:
            [ReviewGameMode(game: .scramble, title: title, icon: systemImage)]
        case .bookOrder:
            BookOrderMode.allCases.map {
                ReviewGameMode(game: .bookOrder, mode: $0.rawValue, title: $0.title, detail: $0.detail, icon: $0.systemImage)
            }
        case .word:
            WordleView.Mode.allCases.map {
                ReviewGameMode(
                    game: .word,
                    mode: $0.rawValue,
                    title: $0.title,
                    detail: $0 == .daily ? "Daily words you didn't solve." : "Practice words you didn't solve.",
                    icon: $0.icon
                )
            }
        }
    }

    /// The modes with a full round of misses, read fresh from the store.
    var readyModes: [ReviewGameMode] {
        modes.filter { MissedGameQuestionStore.shared.isReviewReady($0.reviewMode) }
    }
}

/// One mode of a review game: where its misses are stored, and how its start page names it.
struct ReviewGameMode: Identifiable, Hashable {
    let reviewMode: MissedGameQuestionStore.ReviewMode
    let title: LocalizedStringResource
    var detail: LocalizedStringResource?
    let icon: String

    init(
        game: MissedGameQuestionStore.Entry.Game,
        mode: String? = nil,
        title: LocalizedStringResource,
        detail: LocalizedStringResource? = nil,
        icon: String
    ) {
        reviewMode = MissedGameQuestionStore.ReviewMode(game: game, mode: mode)
        self.title = title
        self.detail = detail
        self.icon = icon
    }

    var id: MissedGameQuestionStore.ReviewMode { reviewMode }

    // The stored game and mode identify it; the text is only how it's shown.
    static func == (lhs: ReviewGameMode, rhs: ReviewGameMode) -> Bool { lhs.reviewMode == rhs.reviewMode }
    func hash(into hasher: inout Hasher) { hasher.combine(reviewMode) }
}

// MARK: - Review list

struct ReviewRoundView: View {
    private let selectedGame: ReviewGame?
    @State private var progress: [ReviewRoundProgress] = []
    @State private var expandedGames: Set<ReviewGame> = []
    @State private var playingGame: ReviewGame?

    init(reviewGameRawValue: String? = nil) {
        if let reviewGameRawValue,
           let game = ReviewGame(rawValue: reviewGameRawValue),
           !game.readyModes.isEmpty {
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
                            ForEach(progress) { item in
                                ReviewGameRow(
                                    progress: item,
                                    isExpanded: expansion(for: item.game),
                                    usesExpandedLayout: true,
                                    onPlay: { playingGame = item.game }
                                )
                                .padding(16)
                                .background(
                                    item.game.tint.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(item.game.tint.opacity(0.22), lineWidth: 1)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .background(AppBackgroundView(tab: .games))
                .navigationTitle("Review Round")
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(item: $playingGame) { game in
                    ReviewRoundSession(game: game)
                }
                // Counts change after a review, so they're read again on return.
                .onAppear { progress = ReviewRoundProgress.all() }
            }
        }
    }

    private func expansion(for game: ReviewGame) -> Binding<Bool> {
        Binding(
            get: { expandedGames.contains(game) },
            set: { isExpanded in
                if isExpanded { expandedGames.insert(game) } else { expandedGames.remove(game) }
            }
        )
    }
}

/// One game on a review list: its name and Play while collapsed, and each mode's missed
/// questions toward a round once expanded. Play is on once any mode has a full round.
struct ReviewGameRow: View {
    let progress: ReviewRoundProgress
    @Binding var isExpanded: Bool
    let usesExpandedLayout: Bool
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.snappy) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        Image(systemName: progress.game.systemImage)
                            .foregroundStyle(progress.game.tint)
                        Text(progress.game.title)
                            .font(usesExpandedLayout ? .headline : .subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(progress.game.title))
                .accessibilityValue(progress.isReady ? Text("Ready") : Text("Not ready"))
                .accessibilityHint(isExpanded ? Text("Hides the modes.") : Text("Shows each mode's missed questions."))

                Button("Play", action: onPlay)
                    .buttonStyle(.glassProminent)
                    .tint(progress.game.tint)
                    .controlSize(.small)
                    .disabled(!progress.isReady)
                    .accessibilityLabel(Text("Play \(progress.game.title) review"))
                    .accessibilityHint(progress.isReady
                        ? Text("Opens the start page.")
                        : Text("Needs \(MissedGameQuestionStore.reviewRoundSize) missed questions in one mode."))
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(progress.modeCounts, id: \.mode) { item in
                        let isReady = item.count >= MissedGameQuestionStore.reviewRoundSize
                        HStack {
                            Text(item.mode.title)
                                .font(usesExpandedLayout ? .subheadline : .caption)
                            Spacer()
                            Text("\(min(item.count, MissedGameQuestionStore.reviewRoundSize)) / \(MissedGameQuestionStore.reviewRoundSize)")
                                .font((usesExpandedLayout ? Font.subheadline : .caption).monospacedDigit().weight(isReady ? .semibold : .regular))
                                .foregroundStyle(isReady ? progress.game.tint : .secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.leading, 26)
                .transition(.opacity)
            }
        }
    }
}

// MARK: - A game's review session

/// What a game needs to know while it's playing a review round.
struct ReviewRoundContext {
    let game: ReviewGame
    /// The mode being reviewed.
    let mode: ReviewGameMode
    /// The modes the start page offers: those with a full round, and the one being reviewed.
    let modes: [ReviewGameMode]
    /// Switches the review to another mode, with that mode's missed questions.
    let selectMode: (ReviewGameMode) -> Void
    /// Starts another review of this mode's missed questions.
    let reviewAgain: () -> Void

    /// Whether another full round of this mode's misses is left.
    var canReviewAgain: Bool { MissedGameQuestionStore.shared.isReviewReady(mode.reviewMode) }
}

extension EnvironmentValues {
    /// Set while a game is playing a review round, so its start page offers only the modes
    /// ready for review, and its results show what the review cleared.
    @Entry var reviewRoundContext: ReviewRoundContext? = nil
}

/// One game's review rounds. The game opens on its start page in the first ready mode;
/// choosing another mode there, or Review Again, draws a fresh set of missed questions and
/// starts the game over with them.
private struct ReviewRoundSession: View {
    let game: ReviewGame
    @State private var mode: ReviewGameMode
    @State private var questionIDs: Set<String>
    /// Changes for each new round, so the game starts fresh rather than keeping its old state.
    @State private var round = 0

    init(game: ReviewGame) {
        self.game = game
        let mode = game.readyModes.first ?? game.modes[0]
        _mode = State(initialValue: mode)
        _questionIDs = State(initialValue: Set(MissedGameQuestionStore.shared.questionIDsForReview(mode.reviewMode)))
    }

    var body: some View {
        let ready = game.readyModes
        destination
            .id(round)
            .environment(\.reviewRoundContext, ReviewRoundContext(
                game: game,
                mode: mode,
                modes: game.modes.filter { ready.contains($0) || $0 == mode },
                selectMode: start,
                reviewAgain: { start(mode) }
            ))
    }

    private func start(_ newMode: ReviewGameMode) {
        mode = newMode
        questionIDs = Set(MissedGameQuestionStore.shared.questionIDsForReview(newMode.reviewMode))
        round += 1
    }

    @ViewBuilder
    private var destination: some View {
        let modeName = mode.reviewMode.mode ?? ""
        switch game {
        case .quiz:
            QuizView(reviewQuestionIDs: questionIDs, mode: mode.reviewMode.game == .quizReverse ? .reverse : .standard)
        case .trivia:
            BibleTriviaGameView(reviewQuestionIDs: questionIDs)
        case .countdown:
            BeatTheClockGameView(reviewQuestionIDs: questionIDs, reviewMode: BeatTheClockMode(rawValue: modeName) ?? .classic)
        case .whoAmI:
            WhoAmIGameView(reviewQuestionIDs: questionIDs, reviewMode: WhoAmIGameViewModel.Mode(rawValue: modeName) ?? .clueToName)
        case .hangman:
            HangmanGameView(reviewQuestionIDs: questionIDs)
        case .scramble:
            ScrambleGameView(reviewQuestionIDs: questionIDs)
        case .bookOrder:
            // Book Order misses are book names.
            BookOrderGameView(reviewBooks: Array(questionIDs), reviewMode: BookOrderMode(rawValue: modeName) ?? .missingBook)
        case .word:
            WordleView(reviewWords: Array(questionIDs), reviewMode: WordleView.Mode(rawValue: modeName) ?? .practice)
        }
    }
}

/// The review's mode on a game's start page, offering only the modes ready for review.
/// Each game hides its own mode setting during a review. Nothing shows for a game with one
/// way to play.
struct ReviewModeSetting: View {
    @Environment(\.reviewRoundContext) private var reviewRound

    var body: some View {
        if let reviewRound, reviewRound.game.modes.count > 1 {
            GameSettingsGroup {
                GameChoiceSetting(
                    title: "Review mode",
                    systemImage: "arrow.clockwise.heart.fill",
                    tint: reviewRound.game.tint,
                    selection: Binding(get: { reviewRound.mode }, set: { reviewRound.selectMode($0) }),
                    choices: reviewRound.modes.map {
                        GameChoice(value: $0, title: $0.title, detail: $0.detail, icon: $0.icon)
                    }
                )
            }
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
            Text("Each game mode unlocks a review once it has \(MissedGameQuestionStore.reviewRoundSize) missed questions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
