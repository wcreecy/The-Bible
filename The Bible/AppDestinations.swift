import SwiftUI

extension View {
    /// Wires up shared navigation destinations for the app’s Route enum.
    /// - Parameters:
    ///   - readerFontSize: Binding to the reader font size used by ReadingView.
    ///   - isPad: Whether the current device is an iPad (available if you want to customize behavior).
    func appDestinations(
        readerFontSize: Binding<Double>,
        isPad: Bool,
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
                        .font(.system(size: readerFontSize.wrappedValue))
                        .toolbar {
                            ToolbarItemGroup(placement: .topBarTrailing) {
                                Button {
                                    readerFontSize.wrappedValue = max(12, readerFontSize.wrappedValue - 1)
                                } label: {
                                    Image(systemName: "textformat.size.smaller")
                                }
                                .accessibilityLabel("Decrease font size")

                                Button {
                                    readerFontSize.wrappedValue = min(30, readerFontSize.wrappedValue + 1)
                                } label: {
                                    Image(systemName: "textformat.size.larger")
                                }
                                .accessibilityLabel("Increase font size")
                            }
                        }

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
