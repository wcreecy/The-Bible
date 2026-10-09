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

    /// Returns from the reader to the chapter grid for the book being read. Pops when
    /// that grid is already underneath; otherwise (deep links, swiping into another
    /// book) replaces the stack with it.
    func navigateBackFromReader(book: Book) {
        if path.count >= 2,
           case .book(let previousBook) = path[path.count - 2],
           previousBook.name == book.name {
            pop()
        } else {
            path = [.book(book)]
        }
    }

    func showChapters(for book: Book) {
        path = [.book(book)]
    }
}
