import SwiftUI

/// The end-of-puzzle result for Word Search, shown under the finished grid.
struct WordSearchSummaryCard: View {
    let result: WordSearchViewModel.RoundResult
    let foundCount: Int
    let totalCount: Int
    let elapsed: String
    let hintsUsed: Int
    /// Nil outside Blind mode; otherwise whether the word list was shown.
    let usedWordList: Bool?
    /// Words the puzzle had that weren't found, in the word list's order.
    let missedWords: [String]
    let currentStreak: Int
    let verseRef: String
    let verseText: String
    let onReadInContext: () -> Void

    private var title: String {
        switch result {
        case .won:
            totalCount == 1 ? String(localized: "You found the word!") : String(localized: "All \(totalCount) words found")
        case .timeUp: String(localized: "Time’s up!")
        case .revealed: String(localized: "Words revealed")
        }
    }

    private var subtitle: String? {
        switch result {
        case .won:
            hintsUsed == 0 ? String(localized: "No hints needed.") : nil
        case .timeUp, .revealed:
            String(localized: "You found \(foundCount) of \(totalCount).")
        }
    }

    private var systemImage: String {
        switch result {
        case .won: "checkmark.seal.fill"
        case .timeUp: "hourglass.bottomhalf.filled"
        case .revealed: "eye.fill"
        }
    }

    private var tint: Color {
        switch result {
        case .won: .green
        case .timeUp: .red
        case .revealed: .secondary
        }
    }

    private var facts: [GameSplashFacts.Fact] {
        var facts: [GameSplashFacts.Fact] = [
            ("clock", elapsed, String(localized: "Time")),
            ("checkmark.circle", "\(foundCount)/\(totalCount)", String(localized: "Found")),
            ("lightbulb", "\(hintsUsed)", String(localized: "Hints"))
        ]
        if let usedWordList {
            facts.append(("eye.slash", usedWordList ? String(localized: "Used") : String(localized: "Hidden"), String(localized: "Word List")))
        }
        return facts
    }

    var body: some View {
        GamePuzzleResultCard(
            title: title,
            subtitle: subtitle,
            systemImage: systemImage,
            tint: tint,
            facts: facts,
            streak: GamePuzzleStreak(current: currentStreak),
            scripture: GamePuzzleScripture(reference: verseRef, text: verseText, onOpen: onReadInContext)
        ) {
            if !missedWords.isEmpty {
                GamePuzzleResultSection(title: "Missed Words", systemImage: "xmark.circle", tint: .red) {
                    Text(missedWords.formatted(.list(type: .and)))
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
