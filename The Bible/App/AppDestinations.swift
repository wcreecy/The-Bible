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
                        coordinator.push(.reader(book: book, chapter: chapter, startVerse: 1, highlightsStartVerse: false))
                    }

                case .reader(let book, let chapter, let startVerse, let highlightsStartVerse, let requestID):
                    ReadingView(
                        book: book,
                        chapter: chapter,
                        startVerse: startVerse,
                        highlightsStartVerse: highlightsStartVerse,
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
                        // A new request for the same passage gets a new reader; see `Route.reader`.
                        .id("\(book.name)-\(chapter.number)-\(startVerse)-\(requestID?.uuidString ?? "")")

                case .search:
                    SearchView()

                case .study(let destination):
                    StudyBibleView(
                        books: BibleData.books,
                        requestedDestination: destination
                    )

                case .readingPlans, .readingPlan, .readingPlanDay, .customReadingPlanBuilder, .readingPlanSeries:
                    ReadingPlanDestination(route: route)
                }
            }
            .environment(\.planNavigation, PlanNavigation(coordinator))
    }
}
