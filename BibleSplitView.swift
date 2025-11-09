import SwiftUI

struct BibleSplitView: View {
    @State private var selectedBook: Book? = nil
    @State private var selectedChapter: Chapter? = nil
    @State private var navStartVerse: Int = 1
    @State private var searchText: String = ""
    
    private var shouldSearch: Bool {
        let words = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count >= 2
    }
    
    private var searchResults: [(book: Book, chapter: Chapter, verseNumber: Int, verseText: String)] {
        guard shouldSearch else { return [] }
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var results: [(Book, Chapter, Int, String)] = []
        for book in BibleData.books {
            for chapter in book.chapters {
                for verse in chapter.verses {
                    if verse.text.lowercased().contains(needle) {
                        results.append((book, chapter, verse.number, verse.text))
                    }
                }
            }
        }
        return results
    }
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            // Sidebar: Books only
            let canon = BibleData.books
            let indexMap = Dictionary(uniqueKeysWithValues: canon.enumerated().map { ($1.name, $0) })
            let matthewIndex = indexMap["Matthew"] ?? Int.max
            let otBooks = canon.filter { (indexMap[$0.name] ?? Int.max) < matthewIndex }
            let ntBooks = canon.filter { (indexMap[$0.name] ?? Int.max) >= matthewIndex }

            List {
                if !otBooks.isEmpty {
                    Section {
                        ForEach(otBooks, id: \.name) { book in
                            Button {
                                selectedBook = book
                                selectedChapter = nil
                                navStartVerse = 1
                            } label: {
                                HStack {
                                    Text(book.name)
                                    if selectedBook?.name == book.name {
                                        Spacer()
                                        Image(systemName: "checkmark").foregroundStyle(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Old Testament (\(otBooks.count))").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if !ntBooks.isEmpty {
                    Section {
                        ForEach(ntBooks, id: \.name) { book in
                            Button {
                                selectedBook = book
                                selectedChapter = nil
                                navStartVerse = 1
                            } label: {
                                HStack {
                                    Text(book.name)
                                    if selectedBook?.name == book.name {
                                        Spacer()
                                        Image(systemName: "checkmark").foregroundStyle(.blue)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("New Testament (\(ntBooks.count))").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Books")
        } detail: {
            NavigationStack {
                if shouldSearch {
                    // Show search results over the entire Bible
                    if searchResults.isEmpty {
                        ContentUnavailableView("No results", systemImage: "magnifyingglass", description: Text("Type at least two words to search Bible text."))
                    } else {
                        List(searchResults, id: \.verseNumber) { hit in
                            NavigationLink {
                                ReadingView(book: hit.book, chapter: hit.chapter, startVerse: hit.verseNumber)
                                    .id("\(hit.book.name)-\(hit.chapter.number)-\(hit.verseNumber)")
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(hit.book.name) \(hit.chapter.number):\(hit.verseNumber)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(hit.verseText)
                                        .font(.body)
                                        .lineLimit(3)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .navigationTitle("Search")
                    }
                } else if let book = selectedBook {
                    // Root: Chapters for selected book
                    List(book.chapters, id: \.number) { chapter in
                        NavigationLink {
                            // Verses list for selected chapter
                            List(chapter.verses, id: \.number) { verse in
                                NavigationLink {
                                    ReadingView(book: book, chapter: chapter, startVerse: verse.number)
                                        .id("\(book.name)-\(chapter.number)-\(verse.number)")
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text("Verse \(verse.number)")
                                            .font(.headline)
                                        Text(verse.text.prefix(120) + (verse.text.count > 120 ? "…" : ""))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .navigationTitle("\(book.name) \(chapter.number)")
                        } label: {
                            Text("Chapter \(chapter.number)")
                        }
                    }
                    .navigationTitle(book.name)
                } else {
                    ContentUnavailableView("Select a Book", systemImage: "book")
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search Bible text")
        }
    }
}

#Preview {
    BibleSplitView()
}
