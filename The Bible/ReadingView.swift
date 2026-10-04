import SwiftUI
import SwiftData
import UIKit
import WidgetKit

@MainActor
struct ReadingView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    @Query private var verseNotes: [VerseNote]
    @Environment(\.scenePhase) private var scenePhase

    let book: Book
    let chapter: Chapter
    let startVerse: Int
    let onSearch: (() -> Void)?
    let onNavigateBack: (() -> Void)?
    let onBookSelected: ((Book) -> Void)?

    // View model and stores
    @StateObject private var pinnedStore: PinnedVerseStore
    @StateObject private var viewModel: ReadingViewModel

    // Reader-specific font size (independent from global app UI font)
    @AppStorage("readerFontSize") private var readerFontSize: Double = 17
    @AppStorage("showReadVerseCheckmarks") private var showVerseStatusIcons: Bool = false
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @State private var seenVerseNumbers: Set<Int> = []
    @State private var seenVerseLocation: String = ""

    // Observe app-group "last read" to render bookmark icon state live
    @AppStorage("lastReadBook", store: UserDefaults(suiteName: "group.bible.app")!) private var lastReadBook: String = ""
    @AppStorage("lastReadChapter", store: UserDefaults(suiteName: "group.bible.app")!) private var lastReadChapter: Int = 0
    @AppStorage("lastReadVerse", store: UserDefaults(suiteName: "group.bible.app")!) private var lastReadVerse: Int = 0

    // Toast state
    @State private var showFavoriteToast: Bool = false
    @State private var favoriteToastText: String = "Added to Favorites"
    @State private var favoriteToastSymbol: String = "heart.fill"
    @State private var favoriteToastTint: Color = .pink
    @State private var removedFavorite: RemovedReadingFavorite?
    @State private var persistenceFailure: PersistenceFailure?
    @State private var isBookPickerPresented = false

    init(
        book: Book,
        chapter: Chapter,
        startVerse: Int,
        onSearch: (() -> Void)? = nil,
        onNavigateBack: (() -> Void)? = nil,
        onBookSelected: ((Book) -> Void)? = nil
    ) {
        self.book = book
        self.chapter = chapter
        self.startVerse = startVerse
        self.onSearch = onSearch
        self.onNavigateBack = onNavigateBack
        self.onBookSelected = onBookSelected

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
            .navigationBarBackButtonHidden(onNavigateBack != nil)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    if let onNavigateBack {
                        Button(action: onNavigateBack) {
                            Image(systemName: "chevron.backward")
                        }
                        .accessibilityLabel("Back to verse selection")
                    }

                    Button {
                        if let onSearch {
                            onSearch()
                        } else {
                            NotificationCenter.default.post(name: .openBibleSearch, object: nil)
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search Bible")
                }
                ToolbarItem(placement: .principal) {
                    Button {
                        let h = UIImpactFeedbackGenerator(style: .light)
                        h.impactOccurred()
                        isBookPickerPresented = true
                    } label: {
                        Text("\(viewModel.currentBook.name) \(viewModel.currentChapter.number)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose a book")
                    .accessibilityHint("Shows the list of Bible books")
                }
            }
            .sheet(isPresented: $isBookPickerPresented) {
                NavigationStack {
                    List(BibleData.books) { book in
                        Button(book.name) {
                            isBookPickerPresented = false
                            onBookSelected?(book)
                        }
                        .foregroundStyle(.primary)
                    }
                    .navigationTitle("Choose a Book")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isBookPickerPresented = false
                            }
                        }
                    }
                }
            }
            .onAppear {
                viewModel.onAppear()
                saveReaderPosition(verseNumber: viewModel.currentVerse)
                refreshSeenVerses()
                // Ensure newest-only ReadingProgress row
                ReadingProgressStore.dedupe(in: modelContext)
            }
            .onDisappear {
                saveVisibleReaderPosition()
                viewModel.onDisappear()
            }
            .onChange(of: showVerseStatusIcons) { _, isEnabled in
                if isEnabled {
                    refreshSeenVerses()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .bibleStatsExternallyUpdated)) { _ in
                refreshSeenVerses()
            }
            .onChange(of: scenePhase) { _, newPhase in
                viewModel.onScenePhaseChanged(newPhase)

                if newPhase == .inactive || newPhase == .background {
                    saveVisibleReaderPosition()
                }

                // Fallback nudge on app activation (device B):
                // Ensure latest KVS values are pulled locally, then reload the Last Read widget timeline.
                if newPhase == .active {
                    NSUbiquitousKeyValueStore.default.synchronize()
                    DebouncedWidgetReloader.shared.reload(kind: "LastReadWidget")
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("switchToTab"))) { (note: Notification) in
                if let tab = note.userInfo?["tab"] as? Int {
                    viewModel.onTabChanged(tab)
                }
            }
            .appToast(
                isPresented: $showFavoriteToast,
                symbol: favoriteToastSymbol,
                text: favoriteToastText,
                tint: favoriteToastTint,
                actionTitle: removedFavorite == nil ? nil : "Undo",
                action: undoFavoriteRemoval
            )
            .persistenceFailureAlert(failure: $persistenceFailure)
    }

    @ViewBuilder
    private var content: some View {
        ZStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if contextualTipsEnabled {
                        ContextualTipView(
                            id: "reader.shortcuts",
                            title: "Reader shortcuts",
                            message: "Swipe left or right to change chapters. Press and hold a verse for notes, highlights, favorites, and more.",
                            systemImage: "hand.draw"
                        )
                        .padding(.bottom, 12)

                        Divider()
                    }

                    ForEach(currentChapter.verses) { verse in
                        let bookName = viewModel.currentBook.name
                        let chapterNumber = viewModel.currentChapter.number
                        let readUpdate = SeenVerseUpdate(
                            bookName: bookName,
                            chapter: chapterNumber,
                            verse: verse.number,
                            totalVerses: currentChapter.verses.count
                        )

                        ReadingVerseRow(
                            verse: verse,
                            bookName: bookName,
                            chapterNumber: chapterNumber,
                            isHighlighted: viewModel.highlightedVerse == verse.number,
                            isSelected: viewModel.selectedVerse == verse.number,
                            isFavorite: isFavorited(verse),
                            hasNote: hasNote(for: verse.number),
                            isPinned: isBookmarked(verse),
                            isRead: showVerseStatusIcons &&
                                seenVerseLocation == verseLocationKey &&
                                seenVerseNumbers.contains(verse.number),
                            showsStatusIcons: showVerseStatusIcons,
                            savedHighlightColor: highlightColor(for: verse.number),
                            readerFontSize: readerFontSize,
                            onVisibilityChange: { isVisible in
                                viewModel.verseVisibilityChanged(readUpdate, isVisible: isVisible)
                            },
                            onTap: { v in
                                let generator = UISelectionFeedbackGenerator()
                                generator.selectionChanged()
                                viewModel.clearMenuIfNeeded()
                                // Tap now only highlights/selects (no bookmarking)
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
                .padding(AppDesignMetrics.cardPadding)
                .heroCardSurface()
                .padding(.horizontal, 16)
                .padding(.vertical)
                .scrollTargetLayout()
                .onChange(of: viewModel.currentChapterIndex) { _, _ in
                    refreshSeenVerses()
                }
                .onChange(of: viewModel.currentBook.name) { _, _ in
                    refreshSeenVerses()
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
            .onChange(of: viewModel.topVisibleVerseID) { _, _ in
                saveVisibleReaderPosition()
            }

            // Bottom corner navigation arrows overlay
            overlayArrows
        }
        .background(AppBackgroundView(tab: .bible))
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

    private var verseLocationKey: String {
        "\(viewModel.currentBook.name):\(viewModel.currentChapter.number)"
    }

    private func saveVisibleReaderPosition() {
        guard let visibleID = viewModel.topVisibleVerseID,
              let verse = currentChapter.verses.first(where: {
                  viewModel.rowID(for: $0.number) == visibleID
              }) else {
            saveReaderPosition(verseNumber: viewModel.currentVerse)
            return
        }

        saveReaderPosition(verseNumber: verse.number)
    }

    private func saveReaderPosition(verseNumber: Int) {
        DeviceReaderPositionStore.save(BibleReaderLocation(
            bookName: viewModel.currentBook.name,
            chapterNumber: viewModel.currentChapter.number,
            verseNumber: verseNumber
        ))
    }

    private func refreshSeenVerses() {
        guard showVerseStatusIcons else { return }
        let bookName = viewModel.currentBook.name
        let chapterNumber = viewModel.currentChapter.number
        seenVerseNumbers = BibleStatsStore.shared.loadSeenVerses(
            bookName: bookName,
            chapter: chapterNumber
        )
        seenVerseLocation = "\(bookName):\(chapterNumber)"
    }

    private func highlightColor(for verseNumber: Int) -> Color? {
        verseNotes.first {
            $0.bookName == viewModel.currentBook.name &&
            $0.chapterNumber == viewModel.currentChapter.number &&
            $0.verseNumber == verseNumber
        }
        .flatMap { VerseHighlightColor(rawValue: $0.highlightColor)?.color }
    }

    private func hasNote(for verseNumber: Int) -> Bool {
        verseNotes.contains {
            guard $0.bookName == viewModel.currentBook.name,
                  $0.chapterNumber == viewModel.currentChapter.number,
                  $0.verseNumber == verseNumber else { return false }

            let title = $0.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let content = $0.content.trimmingCharacters(in: .whitespacesAndNewlines)
            let seededReference = "\($0.bookName) \($0.chapterNumber):\($0.verseNumber)"
            return !title.isEmpty || (!content.isEmpty && content != seededReference)
        }
    }

    private func isBookmarked(_ verse: Verse) -> Bool {
        lastReadBook == viewModel.currentBook.name &&
        lastReadChapter == viewModel.currentChapter.number &&
        lastReadVerse == verse.number
    }

    // MARK: - Overlay Arrows

    private var overlayArrows: some View {
        // Small, semi-transparent chevrons in bottom-left and bottom-right.
        // Use padding to respect safe area and provide a larger hit target.
        ZStack {
            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        viewModel.previousChapter()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(10) // hit target
                            .background(.ultraThinMaterial, in: Circle())
                            .opacity(0.7)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Previous chapter")
                    .padding(.leading, 12)

                    Spacer()

                    Button(action: {
                        viewModel.nextChapter()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                            .padding(10) // hit target
                            .background(.ultraThinMaterial, in: Circle())
                            .opacity(0.7)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Next chapter")
                    .padding(.trailing, 12)
                }
                .padding(.bottom, 10)
            }
        }
        .allowsHitTesting(true)
    }

    // Extracted to reduce type-checking complexity
    @ViewBuilder
    private func verseMenu(for verse: Verse, bookName: String, chapterNumber: Int) -> some View {
        VerseActionMenu(
            verse: VerseActionReference(
                bookName: bookName,
                chapterNumber: chapterNumber,
                verseNumber: verse.number,
                verseText: verse.text
            ),
            presentation: .buttons,
            onFeedback: handleVerseActionFeedback
        )
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    private func handleVerseActionFeedback(_ feedback: VerseActionFeedback) {
        switch feedback {
        case .addedFavorite:
            favoriteToastSymbol = "heart.fill"
            favoriteToastTint = .pink
            favoriteToastText = "Added to Favorites"
        case .removedFavorite:
            favoriteToastSymbol = "heart.slash"
            favoriteToastTint = .gray
            favoriteToastText = "Removed Favorite"
        case .bookmarked:
            favoriteToastSymbol = "bookmark.fill"
            favoriteToastTint = .accentColor
            favoriteToastText = "Set as Continue Reading"
        case .pinned:
            favoriteToastSymbol = "pin.fill"
            favoriteToastTint = .red
            favoriteToastText = "Pinned to Widget"
        case .unpinned:
            favoriteToastSymbol = "pin"
            favoriteToastTint = .red
            favoriteToastText = "Unpinned from Widget"
        case .copied:
            favoriteToastSymbol = "doc.on.doc"
            favoriteToastTint = .accentColor
            favoriteToastText = "Copied to Clipboard"
        }

        withAnimation(.spring()) {
            showFavoriteToast = true
            viewModel.menuVerse = nil
        }
        viewModel.markActivity()
    }

    // MARK: - Favorites

    private func isFavorited(_ verse: Verse) -> Bool {
        favorites.contains { fav in
            fav.bookName == viewModel.currentBook.name &&
            fav.chapterNumber == viewModel.currentChapter.number &&
            fav.verseNumber == verse.number
        }
    }

    private func saveBookmark(for verse: Verse) {
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                try viewModel.bookmarkVerse(context: modelContext, verse: verse)
            },
            onSuccess: {
                Haptics.success()
                favoriteToastSymbol = "bookmark.fill"
                favoriteToastTint = .accentColor
                favoriteToastText = "Set as Continue Reading"
                withAnimation(.spring()) { showFavoriteToast = true }
            },
            onFailure: { persistenceFailure = $0 }
        )
    }

    private func toggleFavorite(for: Verse) {
        let verse = `for`

        if let existing = favorites.first(where: {
            $0.bookName == viewModel.currentBook.name &&
            $0.chapterNumber == viewModel.currentChapter.number &&
            $0.verseNumber == verse.number
        }) {
            let removalSnapshot = RemovedReadingFavorite(existing)
            ModelContextPersistence.perform(
                in: modelContext,
                operation: {
                    modelContext.delete(existing)
                    try modelContext.save()
                },
                onSuccess: {
                    removedFavorite = removalSnapshot
                    favoriteToastSymbol = "heart.slash"
                    favoriteToastTint = .gray
                    favoriteToastText = "Removed Favorite"
                    withAnimation(.spring()) { showFavoriteToast = true }
                },
                onFailure: { persistenceFailure = $0 }
            )
        } else {
            ModelContextPersistence.perform(
                in: modelContext,
                operation: {
                    let favorite = Favorite(
                        bookName: viewModel.currentBook.name,
                        chapterNumber: viewModel.currentChapter.number,
                        verseNumber: verse.number,
                        verseText: verse.text
                    )
                    modelContext.insert(favorite)
                    try modelContext.save()
                },
                onSuccess: {
                    removedFavorite = nil
                    favoriteToastSymbol = "heart.fill"
                    favoriteToastTint = .pink
                    favoriteToastText = "Added to Favorites"
                    Haptics.success()
                    withAnimation(.spring()) { showFavoriteToast = true }
                },
                onFailure: { persistenceFailure = $0 }
            )
        }
        viewModel.markActivity()
    }

    private func undoFavoriteRemoval() {
        guard let removedFavorite else { return }

        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                modelContext.insert(removedFavorite.model)
                try modelContext.save()
            },
            onSuccess: {
                self.removedFavorite = nil
                Haptics.success()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }

    // MARK: - Share helper

    private func shareText(bookName: String, chapter: Int, verse: Int, text: String) -> String {
        "\(text)\n\(bookName) \(chapter):\(verse)"
    }
}

private struct RemovedReadingFavorite {
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
