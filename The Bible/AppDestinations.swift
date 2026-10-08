import SwiftUI

extension View {
    /// Wires up shared navigation destinations for the app’s Route enum.
    /// - Parameter coordinator: Coordinates navigation between destinations.
    func appDestinations(
        coordinator: NavigationCoordinator
    ) -> some View {
        self
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .book(let book):
                    ChaptersView(book: book)

                case .chapter(let book, let chapter):
                    // Show the verses list so the user can pick which verse to read.
                    VersesView(book: book, chapter: chapter)

                case .reader(let book, let chapter, let startVerse):
                    ReadingView(
                        book: book,
                        chapter: chapter,
                        startVerse: startVerse,
                        onNavigateBack: {
                            coordinator.navigateBackFromReader(book: book, chapter: chapter)
                        },
                        onBookSelected: { selectedBook in
                            coordinator.showChapters(for: selectedBook)
                        }
                    )
                        .id("\(book.name)-\(chapter.number)-\(startVerse)")

                case .search:
                    SearchView()

                // Games
                case .gameQuiz:
                    GameBackgroundContainer { QuizView() }
                case .gameBeatTheClock:
                    GameBackgroundContainer { BeatTheClockGameView() }
                case .gameVerseMatch:
                    GameBackgroundContainer { VerseMatchGameView() }
                case .gameBookOrder:
                    GameBackgroundContainer { BookOrderGameView() }
                case .gameHangman:
                    GameBackgroundContainer { HangmanGameView() }
                case .gameWhoAmI:
                    GameBackgroundContainer { WhoAmIGameView() }
                case .gameWordle:
                    GameBackgroundContainer { WordleView() }
                }
            }
    }
}

private struct GameBackgroundContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            AppBackgroundView(tab: .games)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
