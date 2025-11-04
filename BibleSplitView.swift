import SwiftUI

struct BibleSplitView: View {
    @State private var selectedBook: Book? = nil
    @State private var selectedChapter: Chapter? = nil
    @State private var navStartVerse: Int = 1
    
    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List {
                ForEach(BibleData.books, id: \.name) { book in
                    Button {
                        selectedBook = book
                        selectedChapter = nil
                        navStartVerse = 1
                    } label: {
                        HStack {
                            Text(book.name)
                            if selectedBook?.name == book.name {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Books")
        } content: {
            if let book = selectedBook {
                if selectedChapter == nil {
                    List(book.chapters, id: \.number) { chapter in
                        Button {
                            selectedChapter = chapter
                            navStartVerse = 1
                        } label: {
                            Text("Chapter \(chapter.number)")
                        }
                    }
                    .navigationTitle(book.name)
                } else if let chapter = selectedChapter {
                    List(chapter.verses, id: \.number) { verse in
                        Button {
                            navStartVerse = verse.number
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
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                selectedChapter = nil
                            } label: {
                                Label("Back to Chapters", systemImage: "chevron.left")
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Select a Book", systemImage: "book")
            }
        } detail: {
            if let book = selectedBook, let chapter = selectedChapter {
                ReadingView(book: book, chapter: chapter, startVerse: navStartVerse)
                    .id("\(book.name)-\(chapter.number)-\(navStartVerse)")
            } else {
                ContentUnavailableView("Select a Chapter", systemImage: "text.book.closed")
            }
        }
    }
}

#Preview {
    BibleSplitView()
}
