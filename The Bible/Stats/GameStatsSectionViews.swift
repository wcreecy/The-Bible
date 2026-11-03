import SwiftUI

// The per-game sections on the Games card. Each is written once and reused by every game that
// shows it, with only the data and tints passed in.

/// Colors for the Bible's genres, shared by the genre chips.
enum GameStatsGenreTint {
    static func color(for genre: String) -> Color {
        switch genre {
        case "Law": return .blue
        case "History": return .teal
        case "Poetry": return .purple
        case "Major Prophets": return .orange
        case "Minor Prophets": return .pink
        case "Gospels": return .green
        case "Acts": return .indigo
        case "Epistles": return .cyan
        case "Apocalypse": return .red
        default: return .gray
        }
    }
}

/// Old Testament and New Testament accuracy side by side.
struct TestamentAccuracySection: View {
    let summary: (otAnswered: Int, otCorrect: Int, ntAnswered: Int, ntCorrect: Int, otPct: Double, ntPct: Double)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accuracy by Testament (OT vs NT)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                MetricChip(
                    title: "OT",
                    value: "\(Int(round(summary.otPct)))% (\(summary.otCorrect)/\(summary.otAnswered))",
                    tint: .blue
                )
                MetricChip(
                    title: "NT",
                    value: "\(Int(round(summary.ntPct)))% (\(summary.ntCorrect)/\(summary.ntAnswered))",
                    tint: .green
                )
            }
        }
    }
}

/// One chip per genre. Tapping a chip drills into that genre's books.
struct GenreAccuracySection: View {
    let rows: [(genre: String, answered: Int, correct: Int, pct: Double)]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accuracy by Genre")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        Button {
                            onSelect(row.genre)
                        } label: {
                            MetricChip(
                                title: row.genre,
                                value: "\(Int(round(row.pct)))% (\(row.correct)/\(row.answered))",
                                tint: GameStatsGenreTint.color(for: row.genre)
                            )
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Show accuracy by book for \(row.genre)")
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

/// One chip per category, such as People and Places.
struct CategoryAccuracySection: View {
    let title: LocalizedStringKey
    let rows: [(name: String, answered: Int, correct: Int, pct: Double)]
    let tint: (String) -> Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    MetricChip(
                        title: row.name,
                        value: "\(Int(round(row.pct)))% (\(row.correct)/\(row.answered))",
                        tint: tint(row.name)
                    )
                }
            }
        }
    }
}

/// The five weakest or strongest books over the last 30 or 60 days, with the scope and
/// minimum-attempts controls. The caller supplies the data for its game.
struct BookRankingSection: View {
    typealias Row = (book: String, answered: Int, correct: Int, pct: Double)

    let title: LocalizedStringKey
    /// Named in the "not enough activity" message.
    let gameName: String
    let tint: Color
    let topPadding: CGFloat
    @Binding var scope: Int
    @Binding var minAttempts: Int
    let fetch: (_ lastNDays: Int, _ minAttempts: Int) -> [Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Scope", selection: $scope) {
                    Text("30D").tag(0)
                    Text("60D").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 140)
            }

            HStack(spacing: 10) {
                Text("Min attempts")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper(value: $minAttempts, in: 1...50) {
                    Text("\(minAttempts)")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                }
                .frame(maxWidth: 180, alignment: .leading)
                Spacer()
            }

            let days = (scope == 0) ? 30 : 60
            let rows = Array(fetch(days, minAttempts).prefix(5))

            if rows.isEmpty {
                Text("Not enough recent \(gameName) activity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack {
                        Text(row.book)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(Int(round(row.pct)))%")
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(tint)
                            .frame(width: 56, alignment: .trailing)
                        Text("(\(row.correct)/\(row.answered))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 88, alignment: .trailing)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.top, topPadding)
    }
}

/// The books in one genre with their accuracy, shown in the genre drill-down sheet.
struct GenreBookAccuracyList: View {
    let rows: [(book: String, answered: Int, correct: Int, pct: Double)]

    var body: some View {
        List {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.book)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(Int(round(row.pct)))%")
                        .font(.footnote.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.gamerScoreColor(for: row.pct))
                        .frame(width: 56, alignment: .trailing)
                    Text("(\(row.correct)/\(row.answered))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 88, alignment: .trailing)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}
