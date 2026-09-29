import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Favorite.createdAt, order: .reverse)]) private var favorites: [Favorite]

    @State private var searchText: String = ""
    @State private var removedFavorites: [RemovedFavorite] = []
    @State private var showRemovalToast: Bool = false
    @State private var persistenceFailure: PersistenceFailure?

    // Tokenize the search text into lowercase words
    private var tokens: [String] {
        searchText
            .lowercased()
            .split { $0.isWhitespace || $0.isPunctuation }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    // Filter favorites by all tokens (match in verse text, book name, or reference)
    private var filteredFavorites: [Favorite] {
        guard !tokens.isEmpty else { return favorites }
        return favorites.filter { fav in
            let verse = fav.verseText.lowercased()
            let book = fav.bookName.lowercased()
            let reference = "\(fav.bookName) \(fav.chapterNumber):\(fav.verseNumber)".lowercased()
            // Require all tokens to be found somewhere
            for t in tokens {
                if !verse.contains(t) && !book.contains(t) && !reference.contains(t) {
                    return false
                }
            }
            return true
        }
    }

    var body: some View {
        Group {
            if favorites.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "heart",
                    description: Text("Long-press a verse and choose Favorite to save it here.")
                )
            } else if filteredFavorites.isEmpty && !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView(
                    "No Matches",
                    systemImage: "magnifyingglass",
                    description: Text("Try different keywords or check spelling.")
                )
            } else {
                List {
                    ForEach(filteredFavorites) { fav in
                        // Tap to open this favorite in the Bible tab via the central router
                        Button {
                            openInBibleTab(fav)
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
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteFiltered)
                    .listRowBackground(HeroCardListRowBackground())
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(AppBackgroundView(tab: .favorites))
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { EditButton() }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search favorites")
        .appToast(
            isPresented: $showRemovalToast,
            symbol: "heart.slash",
            text: removedFavorites.count == 1 ? "Favorite removed" : "Favorites removed",
            tint: .secondary,
            actionTitle: "Undo",
            action: undoFavoriteRemoval
        )
        .persistenceFailureAlert(failure: $persistenceFailure)
    }

    // Post a notification consumed by ContentView to switch to the Bible tab and navigate
    private func openInBibleTab(_ fav: Favorite) {
        NotificationCenter.default.post(name: .openBibleReference, object: nil, userInfo: [
            "book": fav.bookName,
            "chapter": fav.chapterNumber,
            "verse": fav.verseNumber
        ])
    }

    // Delete using indices from the filtered list to ensure correct items are removed
    private func deleteFiltered(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { filteredFavorites[$0] }
        let removalSnapshot = itemsToDelete.map { RemovedFavorite($0) }

        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                for item in itemsToDelete {
                    modelContext.delete(item)
                }
                try modelContext.save()
            },
            onSuccess: {
                removedFavorites = removalSnapshot
                Haptics.selection()
                showRemovalToast = true
            },
            onFailure: { persistenceFailure = $0 }
        )
    }

    private func undoFavoriteRemoval() {
        let favoritesToRestore = removedFavorites

        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                for favorite in favoritesToRestore {
                    modelContext.insert(favorite.model)
                }
                try modelContext.save()
            },
            onSuccess: {
                removedFavorites = []
                Haptics.success()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }
}

private struct RemovedFavorite {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String
    let createdAt: Date

    init(_ favorite: Favorite) {
        bookName = favorite.bookName
        chapterNumber = favorite.chapterNumber
        verseNumber = favorite.verseNumber
        verseText = favorite.verseText
        createdAt = favorite.createdAt
    }

    var model: Favorite {
        Favorite(
            bookName: bookName,
            chapterNumber: chapterNumber,
            verseNumber: verseNumber,
            verseText: verseText,
            createdAt: createdAt
        )
    }
}

#Preview {
    NavigationStack {
        FavoritesView()
            .modelContainer(for: [Favorite.self], inMemory: true)
    }
}
