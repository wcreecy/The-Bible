import SwiftUI
import Combine

@MainActor
final class NavigationCoordinator: ObservableObject {
    @Published var path: [Route] = []

    func push(_ route: Route) {
        path.append(route)
    }

    func pop() {
        _ = path.popLast()
    }

    func reset() {
        path.removeAll()
    }

    func showReaderHierarchy(book: Book, chapter: Chapter, startVerse: Int) {
        path = [
            .book(book),
            .chapter(book: book, chapter: chapter),
            .reader(book: book, chapter: chapter, startVerse: startVerse)
        ]
    }

    func navigateBackFromReader(book: Book, chapter: Chapter) {
        if path.count >= 2,
           case .chapter(let previousBook, let previousChapter) = path[path.count - 2],
           previousBook == book,
           previousChapter == chapter {
            pop()
        } else {
            path = [
                .book(book),
                .chapter(book: book, chapter: chapter)
            ]
        }
    }

    func showChapters(for book: Book) {
        path = [.book(book)]
    }
}
