import SwiftUI

/// The end-of-round screen shared by the question and word games: a score ring, the
/// right/wrong/time breakdown, the saved streak, book and category results, and a review
/// of every answer. Each section only appears when the game supplied data for it.
struct GameRoundSummaryView: View {
    /// What the game counts, which sets the wording of the score.
    enum Unit {
        case questions
        case words
    }

    /// How far the player is through a game's question pool, e.g. Trivia's catalog.
    struct PoolProgress {
        let title: String
        let seen: Int
        let total: Int
    }

    let summary: GameRoundSummary
    let tint: Color
    var unit: Unit = .questions
    /// Shown only when the round had a timer, since untimed games can't run out of time.
    var canTimeOut = true
    var poolProgress: PoolProgress?
    var resultNote: String?
    let onPlayAgain: () -> Void
    let onChangeSettings: () -> Void

    @State private var selectedPassage: PassageReference?

    var body: some View {
        VStack(spacing: 16) {
            GameRoundSummaryHeader(summary: summary, tint: tint, unit: unit)

            if let resultNote {
                Label(resultNote, systemImage: "lightbulb.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            GameRoundSummaryBreakdown(summary: summary, unit: unit, showsTimedOut: canTimeOut || summary.timedOutCount > 0)

            GameRoundSummaryStreakCard(summary: summary)

            if hasBookResults {
                GameRoundSummaryBooksCard(summary: summary, tint: tint)
                if summary.entries.contains(where: { $0.relatedBookNames.count > 1 }) {
                    Text("People can appear in several books. Each answer counts toward every related book and once per Bible section or Testament.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !summary.categoryTallies.isEmpty {
                GameRoundSummaryTallyCard(
                    title: "By Type",
                    systemImage: "square.grid.2x2.fill",
                    tallies: summary.categoryTallies,
                    tint: tint
                )
            }

            if let poolProgress {
                GameRoundSummaryPoolCard(progress: poolProgress, tint: tint)
            }

            if !summary.entries.isEmpty {
                GameRoundSummaryReviewList(
                    entries: summary.entries,
                    unit: unit,
                    onOpenReference: { selectedPassage = PassageReferenceParser.parse($0) }
                )
            }

            actions
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .sheet(item: $selectedPassage) { reference in
            ScripturePassageSheet(reference: reference)
        }
    }

    private var hasBookResults: Bool {
        !summary.bookTallies.isEmpty
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button("Play Again", systemImage: "arrow.clockwise", action: onPlayAgain)
                .buttonStyle(GameProminentButtonStyle(tint: tint))

            Button("Change Settings", systemImage: "slider.horizontal.3", action: onChangeSettings)
                .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
        }
        .padding(.top, 4)
    }
}

// MARK: - Header

private struct GameRoundSummaryHeader: View {
    let summary: GameRoundSummary
    let tint: Color
    let unit: GameRoundSummaryView.Unit

    private var title: LocalizedStringKey {
        switch summary.grade {
        case .perfect: "Perfect Round"
        case .great: "Great Round"
        case .good: "Round Complete"
        case .keepPracticing: "Keep Practicing"
        }
    }

    private var systemImage: String {
        switch summary.grade {
        case .perfect: "star.fill"
        case .great: "hands.clap.fill"
        case .good: "flag.checkered"
        case .keepPracticing: "book.fill"
        }
    }

    private var ringTint: Color {
        summary.grade == .perfect ? .yellow : tint
    }

    private var scoreText: String {
        switch unit {
        case .questions:
            String(localized: "\(summary.correctCount) of \(summary.total) correct")
        case .words:
            String(localized: "\(summary.correctCount) of \(summary.total) words solved")
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            ProgressRing(progress: summary.accuracy, lineWidth: 12, size: 132, tint: ringTint) {
                VStack(spacing: 2) {
                    Text(summary.accuracy, format: .percent.precision(.fractionLength(0)))
                        .font(.title.weight(.bold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                    Image(systemName: systemImage)
                        .font(.headline)
                        .foregroundStyle(ringTint)
                }
            }
            .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(title)
                    .font(.title.weight(.bold))
                Text(scoreText)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(summary.accuracy, format: .percent.precision(.fractionLength(0))))
    }
}

// MARK: - Breakdown

private struct GameRoundSummaryBreakdown: View {
    let summary: GameRoundSummary
    let unit: GameRoundSummaryView.Unit
    let showsTimedOut: Bool

    private var facts: [GameSplashFacts.Fact] {
        var facts: [GameSplashFacts.Fact] = [
            ("checkmark.circle.fill", "\(summary.correctCount)", unit == .words ? String(localized: "Solved") : String(localized: "Correct")),
            ("xmark.circle.fill", "\(summary.wrongCount)", unit == .words ? String(localized: "Missed") : String(localized: "Wrong"))
        ]
        if showsTimedOut {
            facts.append(("hourglass.bottomhalf.filled", "\(summary.timedOutCount)", String(localized: "Out of time")))
        }
        facts.append((
            summary.isTimed ? "stopwatch" : "timer.slash",
            summary.roundDuration.map(Self.format) ?? "–",
            summary.isTimed ? String(localized: "Round time") : String(localized: "Untimed")
        ))
        return facts
    }

    private var paceText: String? {
        guard let average = summary.averageAnswerTime else { return nil }
        let averageText = String(localized: "Average answer \(Self.format(average))")
        guard let fastest = summary.fastestCorrectAnswer else { return averageText }
        return averageText + " · " + String(localized: "Fastest \(Self.format(fastest))")
    }

    var body: some View {
        VStack(spacing: 8) {
            let facts = facts
            GameSplashFacts(
                first: facts[0],
                second: facts[1],
                third: facts[2],
                fourth: facts.count > 3 ? facts[3] : nil
            )

            if let paceText {
                Text(paceText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    /// "8s" for short times, "1m 42s" once a minute has passed.
    nonisolated static func format(_ duration: Duration) -> String {
        GameTimeFormat.short(duration)
    }
}

// MARK: - Streak

private struct GameRoundSummaryStreakCard: View {
    let summary: GameRoundSummary

    var body: some View {
        GameRoundSummaryCard(title: "Streak", systemImage: "flame.fill", tint: .orange) {
            HStack(spacing: 0) {
                stat(value: summary.currentStreak, label: "Current")
                Divider().padding(.vertical, 4)
                stat(value: summary.bestStreak, label: "All-time best")
                Divider().padding(.vertical, 4)
                stat(value: summary.longestRunThisRound, label: "This round")
            }

            if summary.isNewBestStreak {
                Label("New best streak!", systemImage: "trophy.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)
            } else if summary.currentStreak > 0 {
                Text("Your streak carries into the next round.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func stat(value: Int, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.weight(.bold))
                .fontDesign(.rounded)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Books

private struct GameRoundSummaryBooksCard: View {
    let summary: GameRoundSummary
    let tint: Color

    var body: some View {
        GameRoundSummaryCard(title: "Books", systemImage: "books.vertical.fill", tint: tint) {
            VStack(alignment: .leading, spacing: 10) {
                if let strongest = summary.strongestBook {
                    GameRoundSummaryTallyRow(label: "Strongest", tally: strongest, tint: .green)
                }
                if let weakest = summary.weakestBook {
                    GameRoundSummaryTallyRow(label: "Needs work", tally: weakest, tint: .red)
                }

                ForEach(summary.testamentTallies) { tally in
                    GameRoundSummaryTallyBar(tally: tally, tint: tint)
                }

                if summary.weakestBook == nil {
                    if summary.missedBooks.isEmpty {
                        Label("No misses in any book.", systemImage: "checkmark.seal.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                    } else {
                        Label {
                            Text("Missed: \(summary.missedBooks.formatted(.list(type: .and)))")
                        } icon: {
                            Image(systemName: "xmark.circle")
                                .foregroundStyle(.red)
                        }
                        .font(.subheadline)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct GameRoundSummaryTallyRow: View {
    let label: LocalizedStringKey
    let tally: GameRoundSummary.Tally
    let tint: Color

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(tally.name)
                .font(.subheadline.weight(.semibold))
            Text("\(tally.correct)/\(tally.total)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Categories

private struct GameRoundSummaryTallyCard: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tallies: [GameRoundSummary.Tally]
    let tint: Color

    var body: some View {
        GameRoundSummaryCard(title: title, systemImage: systemImage, tint: tint) {
            VStack(spacing: 10) {
                ForEach(tallies) { tally in
                    GameRoundSummaryTallyBar(tally: tally, tint: tint)
                }
            }
        }
    }
}

private struct GameRoundSummaryTallyBar: View {
    let tally: GameRoundSummary.Tally
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(tally.name)
                    .font(.subheadline)
                Spacer()
                Text("\(tally.correct)/\(tally.total)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            ProgressView(value: tally.accuracy)
                .tint(tint)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tally.name)
        .accessibilityValue("\(tally.correct) of \(tally.total) correct")
    }
}

// MARK: - Pool progress

private struct GameRoundSummaryPoolCard: View {
    let progress: GameRoundSummaryView.PoolProgress
    let tint: Color

    var body: some View {
        GameRoundSummaryCard(title: "Question Pool", systemImage: "square.stack.3d.up.fill", tint: tint) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(progress.seen) of \(progress.total) \(progress.title) questions seen")
                    .font(.subheadline)
                    .monospacedDigit()
                ProgressView(value: Double(progress.seen), total: Double(max(1, progress.total)))
                    .tint(tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Answer review

private struct GameRoundSummaryReviewList: View {
    let entries: [GameRoundEntry]
    let unit: GameRoundSummaryView.Unit
    let onOpenReference: (String) -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                HStack {
                    Label(unit == .words ? "Review Words" : "Review Answers", systemImage: "list.bullet.rectangle")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(16)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")

            if isExpanded {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    Divider().padding(.leading, 16)
                    GameRoundSummaryReviewRow(number: index + 1, entry: entry, onOpenReference: onOpenReference)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
        }
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct GameRoundSummaryReviewRow: View {
    let number: Int
    let entry: GameRoundEntry
    let onOpenReference: (String) -> Void

    private var icon: (name: String, tint: Color) {
        switch entry.outcome {
        case .correct: ("checkmark.circle.fill", .green)
        case .wrong: ("xmark.circle.fill", .red)
        case .timedOut: ("hourglass.bottomhalf.filled", .orange)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon.name)
                .foregroundStyle(icon.tint)
                .font(.title3)
                .accessibilityLabel(outcomeLabel)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(number). \(entry.prompt)")
                    .font(.subheadline)
                    .lineLimit(4)

                if entry.outcome == .correct {
                    Text(entry.correctAnswer)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    if let givenAnswer = entry.givenAnswer {
                        Text("Your answer: \(givenAnswer)")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .strikethrough()
                    } else if entry.outcome == .timedOut {
                        Text("Out of time")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    Text("Answer: \(entry.correctAnswer)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }

                if entry.hintCount > 0 {
                    Label {
                        Text(hintText)
                    } icon: {
                        Image(systemName: "lightbulb.fill")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if let reference = entry.reference {
                    Button(reference, systemImage: "book") {
                        onOpenReference(reference)
                    }
                    .font(.footnote)
                    .buttonStyle(.borderless)
                    .accessibilityHint("Opens the passage")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let duration = entry.duration {
                Text(GameRoundSummaryBreakdown.format(duration))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var outcomeLabel: Text {
        switch entry.outcome {
        case .correct: Text("Correct")
        case .wrong: Text("Wrong")
        case .timedOut: Text("Out of time")
        }
    }

    private var hintText: LocalizedStringKey {
        switch entry.hintCount {
        case 1: "1 hint used"
        default: "\(entry.hintCount) hints used"
        }
    }
}

// MARK: - Card

private struct GameRoundSummaryCard<Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    let tint: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    let entries = [
        GameRoundEntry(prompt: "Who built the ark before the great flood?", outcome: .correct, givenAnswer: "Noah", correctAnswer: "Noah", category: "Easy", bookName: "Genesis", reference: "Genesis 6:13-22", duration: .seconds(4)),
        GameRoundEntry(prompt: "What bird returned to Noah carrying an olive leaf?", outcome: .correct, givenAnswer: "Dove", correctAnswer: "Dove", category: "Easy", bookName: "Genesis", reference: "Genesis 8:10-11", duration: .seconds(6)),
        GameRoundEntry(prompt: "Who was the left-handed judge who delivered Israel from Moab?", outcome: .wrong, givenAnswer: "Gideon", correctAnswer: "Ehud", category: "Normal", bookName: "Judges", reference: "Judges 3:15", duration: .seconds(9)),
        GameRoundEntry(prompt: "Which judge's mother was told not to drink wine?", outcome: .timedOut, givenAnswer: nil, correctAnswer: "Samson", category: "Normal", bookName: "Judges", reference: "Judges 13:4", duration: .seconds(15)),
        GameRoundEntry(prompt: "Where was Paul when he was blinded by a light?", outcome: .correct, givenAnswer: "Damascus road", correctAnswer: "Damascus road", category: "Normal", bookName: "Acts", reference: "Acts 9:3", duration: .seconds(5))
    ]
    NavigationStack {
        ScrollView {
            GameRoundSummaryView(
                summary: GameRoundSummary(
                    entries: entries,
                    roundDuration: .seconds(74),
                    isTimed: true,
                    currentStreak: 1,
                    bestStreak: 14,
                    isNewBestStreak: false
                ),
                tint: .cyan,
                poolProgress: .init(title: "Normal", seen: 142, total: 600),
                onPlayAgain: {},
                onChangeSettings: {}
            )
            .padding()
        }
    }
}
