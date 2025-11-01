import SwiftUI

struct SearchView: View {
    @State private var query: String = ""
    @State private var results: [SearchResult] = []
    @State private var searchTask: Task<Void, Never>? = nil

    private var tokens: [String] {
        query
            .lowercased()
            .split { $0.isWhitespace || $0.isPunctuation }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private var canSearch: Bool { tokens.count >= 2 }

    var body: some View {
        Group {
            if canSearch {
                if results.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try different keywords or check spelling.")
                    )
                } else {
                    List(results) { item in
                        NavigationLink(
                            destination: ReadingView(
                                book: item.book,
                                chapter: item.chapter,
                                startVerse: item.verse.number
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 6) {
                                // Verse text snippet
                                Text(item.verse.text)
                                    .font(.body)
                                    .lineLimit(3)
                                // Reference line
                                Text("\(item.book.name) \(item.chapter.number):\(item.verse.number)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Search the Bible",
                    systemImage: "magnifyingglass",
                    description: Text("Enter at least two words to begin searching.")
                )
            }
        }
        .navigationTitle("Search")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Enter at least two words")
        .onChange(of: query) { _, _ in
            // Debounce typing to avoid searching on every keystroke
            searchTask?.cancel()
            let currentQuery = query
            searchTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                // If the query changed while waiting, another task will run
                guard !Task.isCancelled else { return }
                await performSearchAsync(for: currentQuery)
            }
        }
        .onAppear { performSearch() }
    }

    private func performSearch() {
        let current = query
        Task { await performSearchAsync(for: current) }
    }

    @MainActor
    private func performSearchAsync(for query: String) async {
        // Tokenize
        let tokens = query
            .lowercased()
            .split { $0.isWhitespace || $0.isPunctuation }
            .map(String.init)
            .filter { !$0.isEmpty }

        guard tokens.count >= 2 else {
            results = []
            return
        }

        // Offload heavy work off the main thread
        let maxResults = 200
        let found: [SearchResult] = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var temp: [SearchResult] = []
                outer: for book in BibleData.books {
                    for chapter in book.chapters {
                        for verse in chapter.verses {
                            let lower = verse.text.lowercased()
                            var matchesAll = true
                            for t in tokens {
                                if !lower.contains(t) { matchesAll = false; break }
                            }
                            if matchesAll {
                                temp.append(SearchResult(book: book, chapter: chapter, verse: verse))
                                if temp.count >= maxResults { break outer }
                            }
                        }
                    }
                }
                continuation.resume(returning: temp)
            }
        }

        // Update UI on main actor
        results = found
    }
}

private struct SearchResult: Identifiable, Hashable {
    let id = UUID()
    let book: Book
    let chapter: Chapter
    let verse: Verse
}

#Preview {
    NavigationStack { SearchView() }
}
