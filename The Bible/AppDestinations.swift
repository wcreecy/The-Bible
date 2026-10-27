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
                    ChaptersView(book: book) { chapter in
                        coordinator.push(.reader(book: book, chapter: chapter, startVerse: 1))
                    }

                case .chapter(let book, let chapter):
                    // Show the verses list so the user can pick which verse to read.
                    VersesView(book: book, chapter: chapter)

                case .reader(let book, let chapter, let startVerse):
                    ReadingView(
                        book: book,
                        chapter: chapter,
                        startVerse: startVerse,
                        onNavigateBack: { currentBook in
                            coordinator.navigateBackFromReader(book: currentBook)
                        },
                        onBookSelected: { selectedBook in
                            coordinator.showChapters(for: selectedBook)
                        },
                        onReferenceSelected: { book, chapter, verse in
                            coordinator.push(.reader(book: book, chapter: chapter, startVerse: verse))
                        }
                    )
                        .id("\(book.name)-\(chapter.number)-\(startVerse)")

                case .search:
                    SearchView()

                case .study(let destination):
                    StudyBibleView(
                        books: BibleData.books,
                        requestedDestination: destination
                    )
                }
            }
    }
}
