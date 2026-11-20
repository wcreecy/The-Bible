import SwiftUI

/// One mode's results, ready to show.
struct GameModeStatsRow: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let value: String
    let detail: String?
}

/// The modes of the selected game, one row each: accuracy, plus the best and average round
/// for timed modes and the average solve time for puzzles.
struct GameModeStatsSection: View {
    let rows: [GameModeStatsRow]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By Mode")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(rows) { row in
                rowView(row)
            }
        }
    }

    private func rowView(_ row: GameModeStatsRow) -> some View {
        // At accessibility sizes the value goes under the title so neither is cut off.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))

        return VStack(alignment: .leading, spacing: 4) {
            layout {
                Label(row.title, systemImage: row.systemImage)
                    .font(.caption.weight(.semibold))
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 8)
                }
                Text(row.value)
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
            }
            if let detail = row.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Builds the By Mode rows for a game on the Stats tab.
@MainActor
enum GameModeStatsRows {
    /// How a mode is scored, which decides what its row shows.
    private enum Scoring {
        /// Questions answered right or wrong.
        case answers
        /// Puzzles solved or not, with a solve time.
        case puzzles
        /// Timed rounds with a score, named by `unit`.
        case rounds(RoundUnit)
    }

    private enum RoundUnit {
        /// Book Order's Before or After?: answers right in a minute.
        case right
        /// Countdown Classic: points, including bonuses.
        case points
        /// Countdown Rapid Fire: books found.
        case books
    }

    private struct Descriptor {
        let mode: String
        let title: LocalizedStringResource
        let systemImage: String
        let scoring: Scoring
    }

    /// The rows for the modes played, or none when fewer than two modes have been played,
    /// since then the game's own numbers already say it all.
    static func rows(forGame gameName: String) -> [GameModeStatsRow] {
        guard let (game, descriptors) = descriptors(forGame: gameName) else { return [] }
        let results = GameStats.shared.modeResults(game, modes: descriptors.map(\.mode))
        let rows = zip(descriptors, results).compactMap { descriptor, result in
            result.hasPlays ? row(descriptor, result) : nil
        }
        return rows.count >= 2 ? rows : []
    }

    private static func descriptors(forGame gameName: String) -> (GameModeStatsGame, [Descriptor])? {
        switch gameName {
        case "Book Order":
            return (.bookorder, BookOrderMode.allCases.map { mode in
                let scoring: Scoring = mode.isPuzzle ? .puzzles : (mode == .beforeAfter ? .rounds(.right) : .answers)
                return Descriptor(mode: mode.rawValue, title: mode.title, systemImage: mode.systemImage, scoring: scoring)
            })
        case "Countdown":
            return (.beatclock, BeatTheClockMode.allCases.map { mode in
                Descriptor(
                    mode: mode.rawValue, title: mode.title, systemImage: mode.systemImage,
                    scoring: .rounds(mode == .rapidFire ? .books : .points)
                )
            })
        case "Quiz":
            // The icons match the mode choices on the Quiz setup screen.
            return (.quiz, QuizMode.allCases.map { mode in
                Descriptor(
                    mode: mode.rawValue, title: mode.title,
                    systemImage: mode == .reverse ? "text.quote" : "book.closed",
                    scoring: .answers
                )
            })
        case "Who?":
            return (.whoami, WhoAmIGameViewModel.Mode.allCases.map { mode in
                Descriptor(mode: mode.rawValue, title: mode.title, systemImage: mode.icon, scoring: .answers)
            })
        default:
            return nil
        }
    }

    private static func row(_ descriptor: Descriptor, _ result: GameModeResult) -> GameModeStatsRow {
        let accuracy = String(localized: "\(Int(result.accuracy.rounded()))% (\(result.correct)/\(result.answered))")
        let value: String
        let detail: String?

        switch descriptor.scoring {
        case .answers:
            value = accuracy
            detail = nil
        case .puzzles:
            value = String(localized: "\(result.correct) of \(result.answered) solved")
            detail = result.averageSolveSeconds.map {
                String(localized: "Average time \(TimeFormatters.compactClock($0))")
            }
        case .rounds(let unit):
            value = result.answered > 0 ? accuracy : "—"
            detail = roundDetail(unit, result)
        }

        return GameModeStatsRow(
            id: descriptor.mode,
            title: String(localized: descriptor.title),
            systemImage: descriptor.systemImage,
            value: value,
            detail: detail
        )
    }

    private static func roundDetail(_ unit: RoundUnit, _ result: GameModeResult) -> String? {
        guard let average = result.averageRoundScore else { return nil }
        let best = result.bestRound
        let averageText = average.formatted(.number.precision(.fractionLength(0...1)))
        switch unit {
        case .right:
            return String(localized: "Best round: \(best) right · Average \(averageText)")
        case .points:
            return String(localized: "Best game: \(best) points · Average \(averageText)")
        case .books:
            return String(localized: "Best game: \(best) books · Average \(averageText)")
        }
    }
}
