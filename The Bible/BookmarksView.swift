import SwiftUI
import SwiftData

/// Places saved with the bookmark button in the verse menu, newest first.
struct BookmarksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Bookmark.createdAt, order: .reverse)]) private var bookmarks: [Bookmark]
    @State private var persistenceFailure: PersistenceFailure?

    var body: some View {
        Group {
            if bookmarks.isEmpty {
                ContentUnavailableView(
                    "No Bookmarks",
                    systemImage: "bookmark",
                    description: Text("Tap the bookmark button in a verse's actions to save a place to come back to.")
                )
            } else {
                List {
                    ForEach(bookmarks) { bookmark in
                        Button {
                            open(bookmark)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(bookmark.bookName) \(bookmark.chapterNumber):\(bookmark.verseNumber)")
                                    .font(.headline)
                                if !bookmark.verseText.isEmpty {
                                    Text(bookmark.verseText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Text(bookmark.createdAt.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens this verse in the Bible")
                    }
                    .onDelete(perform: delete)
                    .listRowBackground(HeroCardListRowBackground())
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppBackgroundView(tab: .more))
        .navigationTitle("Bookmarks")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !bookmarks.isEmpty { EditButton() }
        }
        .persistenceFailureAlert(failure: $persistenceFailure)
    }

    private func open(_ bookmark: Bookmark) {
        NotificationCenter.default.post(name: .openBibleReference, object: nil, userInfo: [
            "book": bookmark.bookName,
            "chapter": bookmark.chapterNumber,
            "verse": bookmark.verseNumber
        ])
    }

    private func delete(at offsets: IndexSet) {
        let removed = offsets.map { bookmarks[$0] }
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                removed.forEach(modelContext.delete)
                try modelContext.save()
            },
            onSuccess: { Haptics.selection() },
            onFailure: { persistenceFailure = $0 }
        )
    }
}

#Preview {
    NavigationStack {
        BookmarksView()
            .modelContainer(for: [Bookmark.self], inMemory: true)
    }
}
