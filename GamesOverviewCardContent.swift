import SwiftUI

/// The inside of the Games card on the Stats tab: a game picker, the headline numbers and chart,
/// and the sections that belong to the selected game.
struct GamesOverviewCardContent: View {
    let version: Int
    let hSizeClass: UserInterfaceSizeClass?
    let dynamicTypeSize: DynamicTypeSize
    @Binding var selectedGame: String
    @Binding var wordScope: Int
    @Binding var weakBooksScope: Int
    @Binding var weakBooksMinAttempts: Int
    @Binding var showGenreDrill: Bool
    @Binding var selectedGenre: String?

    private func gameIcon(for name: String) -> String {
        switch name {
        case "All Games":    return "sparkles"
        case "Quiz":   return "questionmark.circle"
        case "Hangman":      return "figure"
        case "Verses":       return "text.quote"
        case "Countdown": return "timer"
        case "Book Order":   return "books.vertical"
        case "Who?":         return "person.crop.circle.badge.questionmark"
        case "Word":         return "square.grid.3x3"
        default:             return "gamecontroller"
        }
    }

    private func sortKey(for name: String) -> String {
        let key = (name == "Word") ? "Who?" : name
        return key.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .autoupdatingCurrent)
    }

    private func gameNameComparator(_ lhs: String, _ rhs: String) -> Bool {
        let l = sortKey(for: lhs)
        let r = sortKey(for: rhs)
        if l == r {
            let priority: [String: Int] = ["Who?": 0, "Word": 1]
            let pl = priority[lhs] ?? 2
            let pr = priority[rhs] ?? 2
            if pl != pr { return pl < pr }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
        return l.localizedCompare(r) == .orderedAscending
    }

    var body: some View {
        statisticsContent()
    }

    private func statisticsHeader(pickerOptions: [String]) -> some View {
        let headerLayout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: hSizeClass == .compact ? 10 : 12))

        return headerLayout {
            Text("Game Statistics")
                .font(.headline)
                .lineLimit(1)

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer(minLength: 8)
            }

            Menu {
                ForEach(pickerOptions, id: \.self) { name in
                    Button {
                        selectedGame = name
                    } label: {
                        Label(name, systemImage: gameIcon(for: name))
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: gameIcon(for: selectedGame))
                    Text(
                        dynamicTypeSize.isAccessibilitySize && selectedGame == "All Games"
                            ? "All"
                            : selectedGame
                    )
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .font(.caption2.weight(.semibold))
                .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 10 : (hSizeClass == .compact ? 1 : 2))
                .padding(.horizontal, dynamicTypeSize.isAccessibilitySize ? 12 : 6)
                .glassEffect(.regular.tint(Color.accentColor.opacity(0.14)), in: .capsule)
                .contentShape(Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Select Game")
                .accessibilityValue(selectedGame)
            }
            .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil, alignment: .leading)
            .animation(.easeInOut(duration: 0.2), value: selectedGame)
        }
        .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 16 : (hSizeClass == .compact ? 8 : 0))
    }

    private func statisticsContent() -> some View {
        let _ = version

        let breakdown = GameStats.shared.breakdownSnapshot()
        let isEmpty = (breakdown.totalAnswered == 0)

        let availableNames = Array(Set(breakdown.entries.map { $0.name }))
        let pickerOptions = ["All Games"] + availableNames.sorted(by: gameNameComparator)

        let kpi = GameStatsKPI(selectedGame: selectedGame, wordScope: wordScope, breakdown: breakdown)

        return VStack(alignment: .leading, spacing: 10) {
            statisticsHeader(pickerOptions: pickerOptions)

            Divider()

            if !isEmpty {
                GameActivitySummary(selectedGame: selectedGame, wordScope: wordScope, version: version, kpi: kpi)

                gameSections
            } else {
                Text("Play any game to see your stats.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Per-game sections

    /// The sections that follow the summary, which depend on the selected game.
    @ViewBuilder
    private var gameSections: some View {
        switch selectedGame {
        case "Quiz", "Trivia":
            let isTrivia = selectedGame == "Trivia"
            TestamentAccuracySection(
                summary: isTrivia ? GameStats.shared.triviaOTNTSummary() : GameStats.shared.quizOTNTSummary()
            )
            GenreAccuracySection(
                rows: isTrivia ? GameStats.shared.triviaAccuracyByGenre() : GameStats.shared.quizAccuracyByGenre(),
                onSelect: openGenreDrill
            )
            bookRankings(
                gameName: selectedGame,
                weak: { days, minAttempts in
                    isTrivia
                        ? GameStats.shared.triviaWeakBooks(lastNDays: days, minAttempts: minAttempts)
                        : GameStats.shared.quizWeakBooks(lastNDays: days, minAttempts: minAttempts)
                },
                strong: { days, minAttempts in
                    isTrivia
                        ? GameStats.shared.triviaStrongBooks(lastNDays: days, minAttempts: minAttempts)
                        : GameStats.shared.quizStrongBooks(lastNDays: days, minAttempts: minAttempts)
                }
            )

        case "Hangman":
            CategoryAccuracySection(
                title: "Accuracy by Category",
                rows: GameStats.shared.hangmanAccuracyByCategory().map {
                    (name: $0.category, answered: $0.answered, correct: $0.correct, pct: $0.pct)
                },
                tint: { category in
                    switch category {
                    case "People": return .orange
                    case "Places": return .teal
                    case "Books": return .purple
                    default: return .gray
                    }
                }
            )

        case "Countdown":
            CategoryAccuracySection(
                title: "Accuracy by Type",
                rows: GameStats.shared.beatclockAccuracyByType().map {
                    (name: $0.type, answered: $0.answered, correct: $0.correct, pct: $0.pct)
                },
                tint: { type in
                    switch type {
                    case "People": return .orange
                    case "Places": return .teal
                    default: return .gray
                    }
                }
            )

        case "Verses":
            TestamentAccuracySection(summary: GameStats.shared.verseMatchOTNTSummary())
            GenreAccuracySection(
                rows: GameStats.shared.verseMatchAccuracyByGenre(),
                onSelect: openGenreDrill
            )
            bookRankings(
                gameName: "Verses",
                weak: { GameStats.shared.verseMatchWeakBooks(lastNDays: $0, minAttempts: $1) },
                strong: { GameStats.shared.verseMatchStrongBooks(lastNDays: $0, minAttempts: $1) }
            )

        case "Word":
            WordStatsSection(wordScope: $wordScope)

        default:
            EmptyView()
        }
    }

    private func openGenreDrill(_ genre: String) {
        selectedGenre = genre
        showGenreDrill = true
    }

    /// The weakest and strongest books, sharing one scope and one minimum-attempts setting.
    @ViewBuilder
    private func bookRankings(
        gameName: String,
        weak: @escaping (_ lastNDays: Int, _ minAttempts: Int) -> [BookRankingSection.Row],
        strong: @escaping (_ lastNDays: Int, _ minAttempts: Int) -> [BookRankingSection.Row]
    ) -> some View {
        BookRankingSection(
            title: "Top Weak Books",
            gameName: gameName,
            tint: .red,
            topPadding: 4,
            scope: $weakBooksScope,
            minAttempts: $weakBooksMinAttempts,
            fetch: weak
        )
        BookRankingSection(
            title: "Top Strong Books",
            gameName: gameName,
            tint: .green,
            topPadding: 2,
            scope: $weakBooksScope,
            minAttempts: $weakBooksMinAttempts,
            fetch: strong
        )
    }
}
