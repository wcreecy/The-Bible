import SwiftUI

extension View {
    /// Wires up shared navigation destinations for the app’s Route enum.
    /// - Parameters:
    ///   - readerFontSize: Binding to the reader font size used by ReadingView.
    ///   - isPad: Whether the current device is an iPad (available if you want to customize behavior).
    func appDestinations(readerFontSize: Binding<Double>, isPad: Bool) -> some View {
        self
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .book(let book):
                    ChaptersView(book: book)

                case .chapter(let book, let chapter):
                    // Show the verses list so the user can pick which verse to read.
                    VersesView(book: book, chapter: chapter)

                case .reader(let book, let chapter, let startVerse):
                    ReadingView(book: book, chapter: chapter, startVerse: startVerse)
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

                // Games
                case .gameQuiz:
                    QuizView()
                case .gameBeatTheClock:
                    BeatTheClockGameView()
                case .gameReferenceMatch:
                    ReferenceMatchGameView()
                case .gameBookOrder:
                    BookOrderGameView()
                case .gameHangman:
                    HangmanGameView()
                case .gameWhoAmI:
                    WhoAmIGameView()
                }
            }
    }
}
