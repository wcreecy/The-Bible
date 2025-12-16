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
}
