import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Favorite.createdAt, order: .reverse)]) private var favorites: [Favorite]

    var body: some View {
        Group {
            if favorites.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "heart",
                    description: Text("Long-press a verse and choose Favorite to save it here.")
                )
            } else {
                List {
                    ForEach(favorites) { fav in
                        let book = BibleData.books.first(where: { $0.name == fav.bookName }) ?? BibleData.books.first!
                        let chapter = book.chapters.first(where: { $0.number == fav.chapterNumber }) ?? book.chapters.first!

                        NavigationLink {
                            ReadingView(
                                book: book,
                                chapter: chapter,
                                startVerse: fav.verseNumber
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(fav.verseText)
                                    .font(.body)
                                    .lineLimit(3)
                                Text("\(fav.bookName) \(fav.chapterNumber):\(fav.verseNumber)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(fav.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Favorites")
        .toolbar { EditButton() }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(favorites[index]) }
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
            .modelContainer(for: [Favorite.self], inMemory: true)
    }
}
