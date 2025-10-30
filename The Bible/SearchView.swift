import SwiftUI

struct SearchView: View {
    @State private var query: String = ""
    @State private var results: [SearchResult] = []

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
            performSearch()
        }
        .onAppear { performSearch() }
    }

    private func performSearch() {
        guard canSearch else {
            results = []
            return
        }
        let allBooks = BibleData.books
        var found: [SearchResult] = []
        for book in allBooks {
            for chapter in book.chapters {
                for verse in chapter.verses {
                    let lower = verse.text.lowercased()
                    // All tokens must be contained
                    let matchesAll = tokens.allSatisfy { lower.contains($0) }
                    if matchesAll {
                        found.append(SearchResult(book: book, chapter: chapter, verse: verse))
                    }
                }
            }
        }
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
