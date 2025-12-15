import SwiftUI
import SwiftData
import UIKit
import WidgetKit

@MainActor
struct ReadingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    @EnvironmentObject private var journalComposer: JournalComposer
    @Environment(\.scenePhase) private var scenePhase

    let book: Book
    let chapter: Chapter
    let startVerse: Int

    // View model and stores
    @StateObject private var pinnedStore: PinnedVerseStore
    @StateObject private var viewModel: ReadingViewModel

    // Reader-specific font size (independent from global app UI font)
    @AppStorage("readerFontSize") private var readerFontSize: Double = 17

    // Toast state
    @State private var showFavoriteToast: Bool = false
    @State private var favoriteToastText: String = "Added to Favorites"
    @State private var favoriteToastSymbol: String = "heart.fill"
    @State private var favoriteToastTint: Color = .pink

    init(book: Book, chapter: Chapter, startVerse: Int) {
        self.book = book
        self.chapter = chapter
        self.startVerse = startVerse

        // Create a single pinned store instance and share it with the view model
        let pinned = PinnedVerseStore()
        _pinnedStore = StateObject(wrappedValue: pinned)
        _viewModel = StateObject(wrappedValue: ReadingViewModel(
            book: book,
            chapter: chapter,
            startVerse: startVerse,
            pinnedStore: pinned,
            inactivitySeconds: 300
        ))
    }

    private var currentChapter: Chapter { viewModel.currentChapter }

    var body: some View {
        content
            .environment(\.font, nil)
            .navigationTitle("\(viewModel.currentBook.name) \(viewModel.currentChapter.number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.searchQuery = ""
                        viewModel.searchResults = []
                        viewModel.isSearching = false
                        viewModel.isSearchPresented = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search Bible")
                }
                ToolbarItem(placement: .principal) {
                    Button {
                        let h = UIImpactFeedbackGenerator(style: .light)
                        h.impactOccurred()
                        NotificationCenter.default.post(name: .resetBibleNavigation, object: nil)
                    } label: {
                        Text("\(viewModel.currentBook.name) \(viewModel.currentChapter.number)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to Books")
                    .accessibilityHint("Go to the list of books")
                }
            }
            .onAppear {
                viewModel.onAppear()
                // Ensure newest-only ReadingProgress row
                ReadingProgressStore.dedupe(in: modelContext)
            }
            .onDisappear {
                viewModel.onDisappear()
            }
            .onChange(of: scenePhase) { _, newPhase in
                viewModel.onScenePhaseChanged(newPhase)
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("switchToTab"))) { (note: Notification) in
                if let tab = note.userInfo?["tab"] as? Int {
                    viewModel.onTabChanged(tab)
                }
            }
            .appToast(isPresented: $showFavoriteToast, symbol: favoriteToastSymbol, text: favoriteToastText, tint: favoriteToastTint)
            .fullScreenCover(isPresented: $viewModel.isSearchPresented) {
                ReadingSearchSheet(viewModel: viewModel)
            }
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(currentChapter.verses) { verse in
                        let bookName = viewModel.currentBook.name
                        let chapterNumber = viewModel.currentChapter.number

                        ReadingVerseRow(
                            verse: verse,
                            bookName: bookName,
                            chapterNumber: chapterNumber,
                            isHighlighted: viewModel.highlightedVerse == verse.number,
                            isSelected: viewModel.selectedVerse == verse.number,
                            isPinned: viewModel.pinVerse == verse.number || viewModel.isPinned(verse.number),
                            readerFontSize: readerFontSize,
                            onAppear: { number in
                                viewModel.markVerseSeenIfAllowed(verse: number, totalVerses: currentChapter.verses.count)
                            },
                            onTap: { v in
                                let generator = UISelectionFeedbackGenerator()
                                generator.selectionChanged()
                                viewModel.clearMenuIfNeeded()
                                viewModel.handleVerseTap(context: modelContext, verse: v)
                            },
                            onLongPress: { number in
                                let generator = UIImpactFeedbackGenerator(style: .heavy)
                                generator.impactOccurred()
                                viewModel.handleVerseLongPress(verseNumber: number)
                            }
                        )
                        .id(viewModel.rowID(for: verse.number))
                        .animation(.easeInOut(duration: 0.6), value: viewModel.highlightedVerse)
                        .animation(.easeInOut(duration: 0.2), value: viewModel.selectedVerse)

                        if viewModel.menuVerse == verse.number {
                            verseMenu(for: verse, bookName: bookName, chapterNumber: chapterNumber)
                                .transition(.opacity)
                        }

                        if verse.number != currentChapter.verses.count {
                            Divider()
                        }
                    }
                }
                .padding(.vertical)
                .scrollTargetLayout()
                .onChange(of: viewModel.currentChapterIndex) { _, _ in
                    // No-op here; VM already updates state and tracker
                }
                .onAppear {
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            viewModel.topVisibleVerseID = viewModel.rowID(for: viewModel.currentVerse)
                        }
                    }
                    viewModel.markActivity()
                }
                .onTapGesture {
                    if viewModel.menuVerse != nil { viewModel.menuVerse = nil }
                    viewModel.markActivity()
                }
            }
            .scrollPosition(id: $viewModel.topVisibleVerseID, anchor: .top)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 5, coordinateSpace: .local)
                .onChanged { _ in
                    ReadingTimeTracker.shared.resume()
                    viewModel.markActivity()
                }
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    if abs(horizontal) > abs(vertical) && abs(horizontal) > 40 {
                        if horizontal < 0 {
                            viewModel.nextChapter()
                        } else {
                            viewModel.previousChapter()
                        }
                    }
                    viewModel.markActivity()
                }
        )
    }

    // Extracted to reduce type-checking complexity
    @ViewBuilder
    private func verseMenu(for verse: Verse, bookName: String, chapterNumber: Int) -> some View {
        HStack(spacing: 24) {
            Button(action: {
                let share = shareText(bookName: bookName, chapter: chapterNumber, verse: verse.number, text: verse.text)
                UIPasteboard.general.string = share
                favoriteToastSymbol = "doc.on.doc"
                favoriteToastTint = .blue
                favoriteToastText = "Copied to Clipboard"
                withAnimation(.spring()) { showFavoriteToast = true }
                withAnimation(.easeInOut) { viewModel.menuVerse = nil }
                viewModel.markActivity()
            }) { Image(systemName: "doc.on.doc") }
            .foregroundStyle(.blue)

            let shareItem = shareText(bookName: bookName, chapter: chapterNumber, verse: verse.number, text: verse.text)
            ShareLink(item: shareItem) {
                Image(systemName: "square.and.arrow.up")
            }
            .foregroundStyle(.blue)

            Button(action: {
                let refText = "\(bookName) \(chapterNumber):\(verse.number)"
                openJournalForReference(text: refText)
                withAnimation(.easeInOut) { viewModel.menuVerse = nil }
                viewModel.markActivity()
            }) {
                Image(systemName: "book.closed")
            }
            .foregroundStyle(.brown)

            Button(action: {
                if viewModel.isPinned(verse.number) {
                    viewModel.pinnedStore.clear()
                    let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.success)
                    favoriteToastSymbol = "pin"
                    favoriteToastTint = .red
                    favoriteToastText = "Unpinned from Widget"
                } else {
                    _ = viewModel.togglePin(verseNumber: verse.number, verseText: verse.text)
                    let gen = UINotificationFeedbackGenerator(); gen.notificationOccurred(.success)
                    favoriteToastSymbol = "pin.fill"
                    favoriteToastTint = .red
                    favoriteToastText = "Pinned to Widget"
                }
                withAnimation(.spring()) { showFavoriteToast = true }
                withAnimation(.easeInOut) { viewModel.menuVerse = nil }
                viewModel.markActivity()
            }) {
                Image(systemName: viewModel.isPinned(verse.number) ? "pin.fill" : "pin")
            }
            .foregroundStyle(.red)

            Button(action: {
                toggleFavorite(for: verse)
                withAnimation(.easeInOut) { viewModel.menuVerse = nil }
                viewModel.markActivity()
            }) { Image(systemName: isFavorited(verse) ? "heart.fill" : "heart") }
            .foregroundStyle(.red)
        }
        .font(.title3)
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    // MARK: - Journal

    private func openJournalForReference(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let colon = trimmed.lastIndex(of: ":") else {
            journalComposer.present(initialBody: nil, verseRef: nil, showTagColors: false)
            return
        }
        let before = String(trimmed[..<colon])
        let after = String(trimmed[trimmed.index(after: colon)...])
        let parts = before.split(separator: " ")
        guard let last = parts.last, let chapterNum = Int(last) else {
            journalComposer.present(initialBody: nil, verseRef: nil, showTagColors: false)
            return
        }
        let bookName = parts.dropLast().joined(separator: " ")
        guard let verseNum = Int(after) else {
            journalComposer.present(initialBody: nil, verseRef: nil, showTagColors: false)
            return
        }
        let ref = VerseRef(book: bookName, chapter: chapterNum, verse: verseNum, translation: "KJV")

        if UIDevice.current.userInterfaceIdiom == .pad {
            NotificationCenter.default.post(name: .switchToTab, object: nil, userInfo: ["tab": 2])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NotificationCenter.default.post(
                    name: JournalNotifications.startInlineNewFromBible,
                    object: nil,
                    userInfo: [
                        "book": bookName,
                        "chapter": chapterNum,
                        "verse": verseNum
                    ]
                )
            }
        } else {
            journalComposer.present(initialBody: nil, verseRef: ref, showTagColors: true)
        }
    }

    // MARK: - Favorites

    private func isFavorited(_ verse: Verse) -> Bool {
        favorites.contains { fav in
            fav.bookName == viewModel.currentBook.name &&
            fav.chapterNumber == viewModel.currentChapter.number &&
            fav.verseNumber == verse.number
        }
    }

    private func toggleFavorite(for: Verse) {
        let verse = `for`
        if let existing = favorites.first(where: {
            $0.bookName == viewModel.currentBook.name &&
            $0.chapterNumber == viewModel.currentChapter.number &&
            $0.verseNumber == verse.number
        }) {
            modelContext.delete(existing)
            try? modelContext.save()
            favoriteToastSymbol = "heart.slash"
            favoriteToastTint = .gray
            favoriteToastText = "Removed Favorite"
        } else {
            let fav = Favorite(
                bookName: viewModel.currentBook.name,
                chapterNumber: viewModel.currentChapter.number,
                verseNumber: verse.number,
                verseText: verse.text
            )
            modelContext.insert(fav)
            try? modelContext.save()
            favoriteToastSymbol = "heart.fill"
            favoriteToastTint = .pink
            favoriteToastText = "Added to Favorites"
        }
        withAnimation(.spring()) { showFavoriteToast = true }
        viewModel.markActivity()
    }

    // MARK: - Share helper

    private func shareText(bookName: String, chapter: Int, verse: Int, text: String) -> String {
        "\(text)\n\(bookName) \(chapter):\(verse)"
    }
}
