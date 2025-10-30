import SwiftUI
import SwiftData

struct BookmarksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \.createdAt, order: .reverse) private var bookmarks: [Bookmark]

    var body: some View {
        Group {
            if bookmarks.isEmpty {
                ContentUnavailableView(
                    "No Bookmarks",
                    systemImage: "bookmark",
                    description: Text("Long-press a verse and choose Bookmark to save it here.")
                )
            } else {
                List {
                    ForEach(bookmarks) { bm in
                        NavigationLink(
                            destination: ReadingView(
                                book: BibleData.books.first(where: { $0.name == bm.bookName }) ?? BibleData.books.first!,
                                chapter: {
                                    let book = BibleData.books.first(where: { $0.name == bm.bookName }) ?? BibleData.books.first!
                                    return book.chapters.first(where: { $0.number == bm.chapterNumber }) ?? book.chapters.first!
                                }(),
                                startVerse: bm.verseNumber
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bm.verseText)
                                    .font(.body)
                                    .lineLimit(3)
                                Text("\(bm.bookName) \(bm.chapterNumber):\(bm.verseNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(bm.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Bookmarks")
        .toolbar { EditButton() }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(bookmarks[index]) }
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        BookmarksView()
            .modelContainer(for: [Bookmark.self], inMemory: true)
    }
}
