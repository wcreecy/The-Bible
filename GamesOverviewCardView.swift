import SwiftUI

// MARK: - Split cards (Overview + Player Stat Sheet)

struct GamesOverviewCardView: View {
    private var stats = GameStats.shared
    @State private var version: Int = 0

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("statsSelectedGame") private var selectedGame: String = "All Games"

    @State private var wordScope: Int = 2

    @State private var weakBooksScope: Int = 0
    @State private var weakBooksMinAttempts: Int = 5

    @State private var showGenreDrill: Bool = false
    @State private var selectedGenre: String? = nil

    var body: some View {
        cardBody
    }

    /// Keeps the large card hierarchy behind an opaque result boundary for the Swift type checker.
    private var cardBody: some View {
        HeroCard(title: "Games", icon: "gamecontroller", tint: .purple) {
            GamesOverviewCardContent(
                version: version,
                hSizeClass: hSizeClass,
                dynamicTypeSize: dynamicTypeSize,
                selectedGame: $selectedGame,
                wordScope: $wordScope,
                weakBooksScope: $weakBooksScope,
                weakBooksMinAttempts: $weakBooksMinAttempts,
                showGenreDrill: $showGenreDrill,
                selectedGenre: $selectedGenre
            )
        }
        .onAppear { version &+= 1 }
        .onChange(of: stats.version) { _, _ in
            version &+= 1
            let names = Array(Set(GameStats.shared.breakdownSnapshot().entries.map { $0.name }))
            if selectedGame != "All Games" && !names.contains(selectedGame) {
                selectedGame = "All Games"
            }
        }
        .onNotification(.gameStatsExternallyUpdated) {
            version &+= 1
        }
        .sheet(isPresented: $showGenreDrill) {
            genreDrillSheet
        }
    }

    /// The books in the tapped genre, for the game that is selected.
    private var genreDrillSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if let g = selectedGenre {
                    let rows = booksInGenre(g)
                    if rows.isEmpty {
                        ContentUnavailableView("No data for \(g)", systemImage: "book")
                    } else {
                        GenreBookAccuracyList(rows: rows)
                    }
                } else {
                    ContentUnavailableView("No genre selected", systemImage: "tag")
                }
            }
            .navigationTitle(selectedGenre ?? "Genre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showGenreDrill = false }
                }
            }
        }
    }

    private func booksInGenre(_ genre: String) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        switch selectedGame {
        case "Verses": return GameStats.shared.verseMatchAccuracyByBook(inGenre: genre)
        case "Trivia": return GameStats.shared.triviaAccuracyByBook(inGenre: genre)
        default: return GameStats.shared.quizAccuracyByBook(inGenre: genre)
        }
    }
}
