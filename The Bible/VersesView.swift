import SwiftUI
import SwiftData
import UIKit

struct VersesView: View {
    let book: Book
    let chapter: Chapter
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @Query private var favorites: [Favorite]

    @State private var showToast: Bool = false
    @State private var toastText: String = ""
    @State private var toastSymbol: String = "checkmark.circle.fill"
    @State private var toastTint: Color = .blue

    @State private var previewVerse: Verse? = nil

    @State private var navToReader: Bool = false
    @State private var navStartVerse: Int = 1

    var body: some View {
        List {
            ForEach(chapter.verses) { verse in
                NavigationLink(
                    value: Route.reader(book: book, chapter: chapter, startVerse: verse.number)
                ) {
                    HStack(spacing: 0) {
                        Text("Verse \(verse.number)")
                        Text(" of \(chapter.verses.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    previewVerse = verse
                }
            }
        }
        .sheet(item: $previewVerse) { verse in
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(book.name) \(chapter.number):\(verse.number)")
                            .font(.title3).bold()
                        Text(verse.text)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                }
                .navigationTitle("Verse Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { previewVerse = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Open") {
                            navStartVerse = verse.number
                            previewVerse = nil
                            if let book = BibleData.books.first(where: { $0.name == self.book.name }), let chapter = book.chapters.first(where: { $0.number == self.chapter.number }) {
                                coordinator.push(.reader(book: book, chapter: chapter, startVerse: verse.number))
                            }
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        VerseActionMenu(
                            verse: VerseActionReference(
                                bookName: book.name,
                                chapterNumber: chapter.number,
                                verseNumber: verse.number,
                                verseText: verse.text
                            ),
                            presentation: .buttons,
                            onFeedback: handleVerseActionFeedback
                        )
                    }
                }
            }
            .appToast(isPresented: $showToast, symbol: toastSymbol, text: toastText, tint: toastTint)
        }
        .navigationTitle("\(book.name) \(chapter.number)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handleVerseActionFeedback(_ feedback: VerseActionFeedback) {
        switch feedback {
        case .addedFavorite:
            toastSymbol = "heart.fill"
            toastTint = .pink
            toastText = "Added to Favorites"
        case .removedFavorite:
            toastSymbol = "heart.slash"
            toastTint = .secondary
            toastText = "Removed Favorite"
        case .bookmarked:
            toastSymbol = "bookmark.fill"
            toastTint = .accentColor
            toastText = "Set as Continue Reading"
        case .pinned:
            toastSymbol = "pin.fill"
            toastTint = .red
            toastText = "Pinned to Widget"
        case .unpinned:
            toastSymbol = "pin"
            toastTint = .red
            toastText = "Unpinned from Widget"
        case .copied:
            toastSymbol = "doc.on.doc"
            toastTint = .accentColor
            toastText = "Copied to Clipboard"
        }
        withAnimation(.spring()) { showToast = true }
    }

    private func isFavorited(_ verse: Verse) -> Bool {
        favorites.contains { fav in
            fav.bookName == book.name && fav.chapterNumber == chapter.number && fav.verseNumber == verse.number
        }
    }

    private func toggleFavorite(for verse: Verse) {
        if let existing = favorites.first(where: { $0.bookName == book.name && $0.chapterNumber == chapter.number && $0.verseNumber == verse.number }) {
            modelContext.delete(existing)
            try? modelContext.save()
            toastSymbol = "xmark.circle.fill"
            toastTint = .red
            toastText = "Removed Favorite"
        } else {
            let fav = Favorite(
                bookName: book.name,
                chapterNumber: chapter.number,
                verseNumber: verse.number,
                verseText: verse.text
            )
            modelContext.insert(fav)
            try? modelContext.save()
            toastSymbol = "heart.fill"
            toastTint = .pink
            toastText = "Favorited \(book.name) \(chapter.number):\(verse.number)"
        }
        withAnimation(.spring()) { showToast = true }
    }
}

#Preview {
    NavigationStack {
        VersesView(book: BibleData.books.first!, chapter: BibleData.books.first!.chapters.first!)
            .environmentObject(NavigationCoordinator())
    }
}

