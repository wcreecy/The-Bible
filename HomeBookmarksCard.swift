import SwiftUI
import SwiftData

struct HomeBookmarksCard: View {
    @Query(sort: [SortDescriptor(\Bookmark.createdAt, order: .reverse)]) private var bookmarks: [Bookmark]

    let onOpenBookmark: (Bookmark) -> Void

    private var recentBookmarks: [Bookmark] {
        Array(bookmarks.prefix(3))
    }

    var body: some View {
        HeroCard(title: "Bookmarks", icon: "bookmark.fill", tint: .orange) {
            if recentBookmarks.isEmpty {
                ContentUnavailableView(
                    "No Bookmarks Yet",
                    systemImage: "bookmark",
                    description: Text("Save a verse to find it here.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recently saved verses")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ForEach(recentBookmarks) { bookmark in
                        Button {
                            Haptics.selection()
                            onOpenBookmark(bookmark)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(bookmark.bookName) \(bookmark.chapterNumber):\(bookmark.verseNumber)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)

                                if !bookmark.verseText.isEmpty {
                                    Text(bookmark.verseText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens this verse in the Bible")
                    }
                }
            }
        }
    }
}

#Preview {
    HomeBookmarksCard { _ in }
        .modelContainer(for: Bookmark.self, inMemory: true)
        .padding()
}
