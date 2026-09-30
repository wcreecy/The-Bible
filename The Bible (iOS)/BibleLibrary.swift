import Combine
import Foundation

@MainActor
final class BibleStore: ObservableObject {
    static let shared = BibleStore()

    @Published private(set) var books: [Book] = []
    @Published private(set) var isReady = false

    private var loadTask: Task<Void, Never>?

    private init() {}

    func ensureLoaded() {
        guard !isReady, loadTask == nil else { return }
        loadTask = Task { [weak self] in
            guard let self else { return }
            books = await BibleRepository.shared.loadAllBooks()
            isReady = true
            loadTask = nil
        }
    }

    func bookNames() async -> [String] {
        await BibleRepository.shared.bookNames()
    }

    func book(named name: String) async -> Book? {
        if let existing = books.first(where: { $0.name == name }) {
            return existing
        }
        guard let loaded = await BibleRepository.shared.loadBook(named: name) else {
            return nil
        }
        if !books.contains(where: { $0.name == loaded.name }) {
            books.append(loaded)
        }
        return loaded
    }
}
