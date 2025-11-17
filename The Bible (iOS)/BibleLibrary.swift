import Foundation
import SwiftUI
import Combine

// DTO for per-book JSON: [[String]] (array of chapters, each an array of verse strings)
private struct KJVBookChaptersDTO: Decodable {
    let chapters: [[String]]
}

// A concurrency-safe loader that can load the whole Bible or a single book off the main thread.
// It supports per-book files in Bundle at "kjv_books/<BookName>.json" (array-of-array of strings).
actor BibleLibrary {
    static let shared = BibleLibrary()

    private var allBooksCache: [Book]? = nil
    private var booksByName: [String: Book] = [:]
    // Shared in-flight tasks so concurrent callers await the same work
    private var allBooksTask: Task<[Book], Error>? = nil
    private var perBookTasks: [String: Task<Book?, Error>] = [:]

    // Load all books from kjv.json off the main thread (only once).
    func loadAllBooks() async throws -> [Book] {
        if let cached = allBooksCache { return cached }
        if let task = allBooksTask {
            return try await task.value
        }

        // Build a task that only does I/O and model construction (no actor mutation inside).
        let task = Task<[Book], Error> {
            do {
                let loaded: [Book] = try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        if let url = Bundle.main.url(forResource: "kjv", withExtension: "json") {
                            do {
                                let data = try Data(contentsOf: url)
                                let decoder = JSONDecoder()
                                struct KJVBookDTO: Decodable {
                                    let abbrev: String
                                    let chapters: [[String]]
                                    let name: String?
                                }
                                let dtoBooks = try decoder.decode([KJVBookDTO].self, from: data)

                                let map: [String: String] = [
                                    "gn": "Genesis","ex": "Exodus","lev": "Leviticus","num": "Numbers","de": "Deuteronomy",
                                    "jos": "Joshua","jdg": "Judges","ru": "Ruth",
                                    "1sa": "1 Samuel","2sa": "2 Samuel",
                                    "1ki": "1 Kings","2ki": "2 Kings",
                                    "1ch": "1 Chronicles","2ch": "2 Chronicles",
                                    "ezr": "Ezra","ne": "Nehemiah","es": "Esther",
                                    "job": "Job","ps": "Psalms","pr": "Proverbs","ec": "Ecclesiastes","so": "Song of Solomon",
                                    "is": "Isaiah","je": "Jeremiah","la": "Lamentations","eze": "Ezekiel","da": "Daniel",
                                    "ho": "Hosea","joe": "Joel","am": "Amos","ob": "Obadiah","jon": "Jonah",
                                    "mic": "Micah","na": "Nahum","hab": "Habakkuk","zep": "Zephaniah",
                                    "hag": "Haggai","zec": "Zechariah","mal": "Malachi",
                                    "mt": "Matthew","mr": "Mark","lu": "Luke","joh": "John",
                                    "ac": "Acts","ro": "Romans",
                                    "1co": "1 Corinthians","2co": "2 Corinthians",
                                    "ga": "Galatians","eph": "Ephesians","php": "Philippians","col": "Colossians",
                                    "1th": "1 Thessalonians","2th": "2 Thessalonians",
                                    "1ti": "1 Timothy","2ti": "2 Timothy",
                                    "tit": "Titus","phm": "Philemon",
                                    "heb": "Hebrews","jas": "James",
                                    "1pe": "1 Peter","2pe": "2 Peter",
                                    "1jo": "1 John","2jo": "2 John","3jo": "3 John",
                                    "jude": "Jude","re": "Revelation"
                                ]

                                let books: [Book] = dtoBooks.map { dto in
                                    let fullName = dto.name ?? map[dto.abbrev.lowercased()] ?? dto.abbrev.uppercased()
                                    return Book(
                                        name: fullName,
                                        chapters: dto.chapters.enumerated().map { (chapterIndex, versesArray) in
                                            Chapter(
                                                number: chapterIndex + 1,
                                                verses: versesArray.enumerated().map { (verseIndex, text) in
                                                    Verse(number: verseIndex + 1, text: text)
                                                }
                                            )
                                        }
                                    )
                                }
                                continuation.resume(returning: books)
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        } else {
                            continuation.resume(throwing: URLError(.fileDoesNotExist))
                        }
                    }
                }
                return loaded
            } catch {
                // Fallback to the static BibleData if kjv.json is missing or failed to load.
                return await BibleData.books
            }
        }

        allBooksTask = task
        do {
            let result = try await task.value
            // Back on the actor: cache results synchronously (no await).
            setAllBooksCache(result)
            // Optionally clear the task to free memory; future calls will hit the cache.
            allBooksTask = nil
            return result
        } catch {
            // Clear failed task so future calls can retry
            allBooksTask = nil
            throw error
        }
    }

    private func setAllBooksCache(_ books: [Book]) {
        self.allBooksCache = books
        self.booksByName = Dictionary(uniqueKeysWithValues: books.map { ($0.name, $0) })
    }

    // Load a single book from "kjv_books/<BookName>.json" if present, else from the all-books cache.
    func loadBook(named name: String) async throws -> Book? {
        if let cached = booksByName[name] { return cached }
        if let inFlight = perBookTasks[name] {
            return try await inFlight.value
        }

        // Create task that only performs I/O and building the model, without touching actor state.
        let task = Task<Book?, Error> {
            // Try per-book file
            if let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "kjv_books") {
                let book = try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            let data = try Data(contentsOf: url)
                            let chapters = try JSONDecoder().decode([[String]].self, from: data)
                            let built = Book(
                                name: name,
                                chapters: chapters.enumerated().map { (chapterIndex, versesArray) in
                                    Chapter(
                                        number: chapterIndex + 1,
                                        verses: versesArray.enumerated().map { (verseIndex, text) in
                                            Verse(number: verseIndex + 1, text: text)
                                        }
                                    )
                                }
                            )
                            continuation.resume(returning: built)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
                return book
            }

            // Fallback: ensure all-books loaded and return by name
            let all = try await loadAllBooks()
            return all.first(where: { $0.name == name })
        }

        perBookTasks[name] = task
        defer { perBookTasks[name] = nil }

        let result = try await task.value
        if let book = result {
            // We are back on the actor; safe to mutate cache synchronously without 'await'.
            self.cache(book: book)
        }
        return result
    }

    private func cache(book: Book) {
        booksByName[book.name] = book
        if var all = allBooksCache {
            if let idx = all.firstIndex(where: { $0.name == book.name }) {
                all[idx] = book
            } else {
                all.append(book)
            }
            allBooksCache = all
        }
    }

    // Convenience to get book names without loading full verse text (best-effort).
    func bookNames() async -> [String] {
        // If per-book directory exists, list its filenames for a light-weight index.
        if let dir = Bundle.main.url(forResource: "kjv_books", withExtension: nil) {
            if let urls = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                let names = urls.compactMap { $0.deletingPathExtension().lastPathComponent }
                return names.sorted()
            }
        }
        // Otherwise, fall back to loading all (or using static BibleData)
        if let cached = allBooksCache {
            return cached.map { $0.name }
        } else if let names = try? await loadAllBooks().map({ $0.name }) {
            return names
        } else {
            return await BibleData.books.map { $0.name }
        }
    }
}

// Observable facade for SwiftUI
@MainActor
final class BibleStore: ObservableObject {
    static let shared = BibleStore()
    // Keep a small cache of books that were requested on demand
    @Published private(set) var books: [Book] = []
    // isReady no longer implies the whole corpus is loaded; keep it for compatibility but leave false.
    @Published private(set) var isReady: Bool = false

    private init() {}

    // No-op to keep call sites compiling; we don’t eagerly load anymore.
    func ensureLoaded() {
        // Intentionally empty: we now load on demand.
    }

    func bookNames() async -> [String] {
        await BibleLibrary.shared.bookNames()
    }

    func book(named name: String) async -> Book? {
        if let existing = books.first(where: { $0.name == name }) {
            return existing
        }
        do {
            if let loaded = try await BibleLibrary.shared.loadBook(named: name) {
                books.append(loaded)
                return loaded
            }
        } catch {
            // Ignore and fall back to static
        }
        return BibleData.books.first(where: { $0.name == name })
    }
}
