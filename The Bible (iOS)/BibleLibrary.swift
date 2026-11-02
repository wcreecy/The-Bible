import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
final class BibleStore {
    static let shared = BibleStore()

    private(set) var books: [Book] = []
    private(set) var isReady = false
    /// The bundled Bible text couldn't be read. Screens show `BibleLoadFailedView`.
    private(set) var loadFailed = false

    @ObservationIgnored private var loadTask: Task<Void, Never>?

    private init() {}

    func ensureLoaded() {
        guard !isReady, loadTask == nil else { return }
        loadTask = Task { [weak self] in
            guard let self else { return }
            books = await BibleRepository.shared.loadAllBooks()
            loadFailed = books.isEmpty
            isReady = true
            loadTask = nil
        }
    }

    /// Loads the Bible again after a failure.
    func retryLoad() {
        guard loadFailed, loadTask == nil else { return }
        isReady = false
        loadFailed = false
        ensureLoaded()
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

/// Shown in place of the books when the Bible text couldn't be loaded.
struct BibleLoadFailedView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Bible Unavailable", systemImage: "book.closed")
        } description: {
            Text("The Bible text couldn’t be loaded. Try again, or reinstall the app if this keeps happening.")
        } actions: {
            Button("Try Again") {
                BibleStore.shared.retryLoad()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
