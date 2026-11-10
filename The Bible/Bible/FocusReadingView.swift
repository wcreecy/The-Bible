import SwiftUI

struct FocusReadingView: View {
    let initialLocation: FocusVerseLocation
    let readerFontSize: Double
    let onLocationChange: (FocusVerseLocation) -> Void
    /// The verse on screen, or `nil` while a chapter title page is shown.
    let onVisibleVerseChange: (FocusVerseLocation?) -> Void
    let onExit: () -> Void

    /// Index of the page on screen in `pageMap`.
    @State private var visiblePageIndex: Int?
    // Position is reported only once scrolling settles, not for every page passed mid-swipe.
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var lastReportedPageIndex: Int?
    @State private var showsControls = false
    @State private var isLocationPickerPresented = false
    /// Owned here so the picker's query survives dismissing it with Cancel.
    @State private var locationSearchText = ""
    /// The controls bar's height, so the verse toast sits just above it at any text size.
    @State private var controlsHeight: CGFloat = 56
    @State private var chapterInsightsDismissal = StudySheetDismissal()
    @State private var verseToast = VerseActionToastState()
    @AppStorage(AppStorageKey.hasSeenFocusModeControlsHint) private var hasSeenControlsHint = false

    // Maps page numbers to Bible locations; pages themselves are built only when shown.
    private let pageMap: FocusPageMap

    init(
        initialLocation: FocusVerseLocation,
        readerFontSize: Double,
        onLocationChange: @escaping (FocusVerseLocation) -> Void,
        onVisibleVerseChange: @escaping (FocusVerseLocation?) -> Void,
        onExit: @escaping () -> Void
    ) {
        self.initialLocation = initialLocation
        self.readerFontSize = readerFontSize
        self.onLocationChange = onLocationChange
        self.onVisibleVerseChange = onVisibleVerseChange
        self.onExit = onExit
        let pageMap = FocusPageMap.current()
        self.pageMap = pageMap
        _visiblePageIndex = State(initialValue: pageMap.index(of: initialLocation))
    }

    private var visiblePage: FocusPage? {
        visiblePageIndex.flatMap(pageMap.page(at:))
    }

    private var currentLocation: FocusVerseLocation {
        visiblePage?.location ?? initialLocation
    }

    private var currentVerse: FocusVerse? {
        guard case .verse(let verse) = visiblePage else { return nil }
        return verse
    }

    /// Reports the page the reader has settled on, once per page.
    private func reportSettledPage() {
        guard visiblePageIndex != lastReportedPageIndex else { return }
        lastReportedPageIndex = visiblePageIndex
        guard let page = visiblePage else {
            onVisibleVerseChange(nil)
            return
        }
        onLocationChange(page.location)
        reportVisibleVerse(page)
    }

    private func reportVisibleVerse(_ page: FocusPage) {
        if case .verse(let verse) = page {
            onVisibleVerseChange(verse.location)
        } else {
            onVisibleVerseChange(nil)
        }
    }

    var body: some View {
        @Bindable var chapterInsightsDismissal = chapterInsightsDismissal

        ZStack(alignment: .bottom) {
            ScrollView {
                FocusPageList(pageMap: pageMap, readerFontSize: readerFontSize)
                    .equatable()
            }
            .scrollPosition(id: $visiblePageIndex, anchor: .center)
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, newPhase in
                scrollPhase = newPhase
                if newPhase == .idle {
                    reportSettledPage()
                }
            }
            .onChange(of: visiblePageIndex) { _, _ in
                // Programmatic jumps (Go to Verse) land without a scroll phase change.
                if scrollPhase == .idle {
                    reportSettledPage()
                }
            }
            .onAppear(perform: reportSettledPage)
            // The controls stay up until the next tap on the page; there is no timer.
            .onTapGesture(perform: toggleControls)
            .accessibilityAction(
                named: showsControls ? "Hide Focus Mode Controls" : "Show Focus Mode Controls",
                toggleControls
            )
            .accessibilityAction(named: "Exit Focus Mode", onExit)

            if showsControls {
                FocusControls(
                    verse: currentVerse,
                    location: currentLocation,
                    onChooseLocation: {
                        isLocationPickerPresented = true
                    },
                    onShowChapterInsights: {
                        chapterInsightsDismissal.isPresented = true
                    },
                    onExit: onExit
                )
                .onGeometryChange(for: CGFloat.self, of: \.size.height) { controlsHeight = $0 }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if !hasSeenControlsHint {
                FocusControlsHint()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            }
        }
        .background(Color(uiColor: .systemBackground))
        // Sits above the controls bar, which is where the verse menu lives.
        .verseActionToast($verseToast, bottomPadding: controlsHeight + 28)
        .sheet(isPresented: $isLocationPickerPresented) {
            ReaderBookPickerSheet(
                searchText: $locationSearchText,
                onSelectBook: { book in
                    go(to: FocusVerseLocation(bookName: book.name, chapterNumber: book.chapters.first?.number ?? 1, verseNumber: 0))
                },
                onSelectReference: { reference in
                    go(to: FocusVerseLocation(
                        bookName: reference.book.name,
                        chapterNumber: reference.chapter.number,
                        verseNumber: reference.reference.startVerse
                    ))
                },
                onCancel: { isLocationPickerPresented = false }
            )
        }
        .sheet(isPresented: $chapterInsightsDismissal.isPresented) {
            NavigationStack {
                ChapterInsightsView(
                    bookName: currentLocation.bookName,
                    chapterNumber: currentLocation.chapterNumber,
                    openedFromReader: true
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            chapterInsightsDismissal.dismiss()
                        }
                    }
                }
            }
            .environment(\.studySheetDismissal, chapterInsightsDismissal)
        }
    }

    /// Moving the scroll position reports the new location through onChange. A book alone
    /// (verse 0) opens on its first chapter's title page.
    private func go(to location: FocusVerseLocation) {
        visiblePageIndex = pageMap.index(of: location)
        locationSearchText = ""
        isLocationPickerPresented = false
    }

    private func toggleControls() {
        withAnimation(.snappy) {
            showsControls.toggle()
        }
        hasSeenControlsHint = true
    }
}

private struct FocusControlsHint: View {
    var body: some View {
        Text("Tap for controls · Swipe to continue")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.thinMaterial, in: Capsule())
            .accessibilityHidden(true)
    }
}

private struct FocusControls: View {
    let verse: FocusVerse?
    let location: FocusVerseLocation
    let onChooseLocation: () -> Void
    let onShowChapterInsights: () -> Void
    let onExit: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            Button(action: onChooseLocation) {
                Label(
                    "\(location.bookName) \(location.chapterNumber):\(location.verseNumber)",
                    systemImage: "book.closed"
                )
                .lineLimit(1)
            }
            .accessibilityLabel("Choose book, chapter, and verse")
            .accessibilityHint("Currently \(location.bookName) \(location.chapterNumber), verse \(location.verseNumber)")

            Spacer(minLength: 0)

            // Favorite, Chapter Insights, and the rest live in one menu so the bar stays small.
            if let verse, !verse.text.isEmpty {
                VerseActionMenu(
                    verse: VerseActionReference(
                        bookName: verse.location.bookName,
                        chapterNumber: verse.location.chapterNumber,
                        verseNumber: verse.location.verseNumber,
                        verseText: verse.text
                    ),
                    presentation: .focus,
                    onShowChapterInsights: onShowChapterInsights
                )
            } else {
                // A title page or an omitted verse has nothing to save, but the chapter
                // still has insights.
                Menu {
                    chapterInsightsButton
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("More actions")
            }

            Button(action: onExit) {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("Exit Focus Mode")
        }
        .font(.headline)
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
        .frame(minHeight: 56)
        .background(.thinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }

    private var chapterInsightsButton: some View {
        Button(action: onShowChapterInsights) {
            Label("Chapter Insights", systemImage: "lightbulb")
        }
    }
}

private struct FocusVersePage: View {
    let verse: FocusVerse
    let readerFontSize: Double

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .body) private var defaultReaderFontSize: CGFloat = 17
    @AppStorage(RedLetterText.suppliedWordsInItalicsKey) private var italicizesSuppliedWords = false

    private static let minimumScale: CGFloat = 0.35

    private var focusFontAdjustment: CGFloat {
        horizontalSizeClass == .regular ? 4 : 0
    }

    var body: some View {
        VStack(spacing: 24) {
            if verse.text.isEmpty {
                Text(Verse.omittedNote(in: BibleRepository.shared.activeTranslation))
                    .font(.body)
                    .italic()
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(Self.minimumScale)
            } else {
                // A page is one screen tall and doesn't scroll, so a verse too long for it
                // (Esther 8:9 at a large text size) shrinks to fit instead of being cut off.
                Text(verse.attributedText(italicizingSuppliedWords: italicizesSuppliedWords))
                    .font(.system(size: defaultReaderFontSize + CGFloat(readerFontSize - 17) + focusFontAdjustment))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(Self.minimumScale)
            }

            Text(verse.location.reference)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(verse.location.reference), \(verse.text.isEmpty ? Verse.omittedNote(in: BibleRepository.shared.activeTranslation) : verse.text)")
    }
}

struct FocusVerseLocation: Equatable {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int

    var id: String {
        "verse-\(bookName)-\(chapterNumber)-\(verseNumber)"
    }

    /// "John 3:16".
    var reference: String {
        "\(bookName) \(chapterNumber):\(verseNumber)"
    }
}

enum FocusPage: Identifiable {
    case chapter(bookName: String, chapterNumber: Int)
    case verse(FocusVerse)

    var id: String {
        switch self {
        case .chapter(let bookName, let chapterNumber):
            "chapter-\(bookName)-\(chapterNumber)"
        case .verse(let verse):
            verse.location.id
        }
    }

    var location: FocusVerseLocation {
        switch self {
        case .chapter(let bookName, let chapterNumber):
            FocusVerseLocation(
                bookName: bookName,
                chapterNumber: chapterNumber,
                verseNumber: 1
            )
        case .verse(let verse):
            verse.location
        }
    }
}

/// The lazily built list of every Focus Mode page. It is equatable so changes elsewhere
/// in Focus Mode (controls, scroll phase) skip re-evaluating all 32,000+ page identities.
private struct FocusPageList: View, Equatable {
    let pageMap: FocusPageMap
    let readerFontSize: Double

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.pageMap.pageCount == rhs.pageMap.pageCount && lhs.readerFontSize == rhs.readerFontSize
    }

    var body: some View {
        // SwiftUI creates only the pages near the screen; the list never changes while
        // Focus Mode is open.
        LazyVStack(spacing: 0) {
            ForEach(0..<pageMap.pageCount, id: \.self) { index in
                if let page = pageMap.page(at: index) {
                    FocusPageView(page: page, readerFontSize: readerFontSize)
                        .containerRelativeFrame(.vertical)
                }
            }
        }
        .scrollTargetLayout()
    }
}

/// Numbers every Focus Mode page across the Bible (a title page per chapter followed by
/// its verses) without building them. One entry per chapter locates any page number.
struct FocusPageMap {
    private struct ChapterEntry {
        let bookIndex: Int
        let chapterIndex: Int
        /// Page number of this chapter's title page; its verses follow it.
        let firstPage: Int
        let verseCount: Int
    }

    private let books: [Book]
    private let chapters: [ChapterEntry]
    private let chapterLookup: [String: Int]
    let pageCount: Int

    private static var cached: (translation: BibleTranslation, map: FocusPageMap)?

    /// The map for the active translation, built once rather than each time the reader
    /// redraws Focus Mode.
    static func current() -> FocusPageMap {
        let translation = BibleRepository.shared.activeTranslation
        if let cached, cached.translation == translation, cached.map.pageCount > 0 {
            return cached.map
        }
        let map = FocusPageMap(books: BibleData.books)
        cached = (translation, map)
        return map
    }

    init(books: [Book]) {
        self.books = books
        var chapters: [ChapterEntry] = []
        var lookup: [String: Int] = [:]
        var nextPage = 0
        for (bookIndex, book) in books.enumerated() {
            for (chapterIndex, chapter) in book.chapters.enumerated() {
                lookup[Self.key(book.name, chapter.number)] = chapters.count
                chapters.append(ChapterEntry(
                    bookIndex: bookIndex,
                    chapterIndex: chapterIndex,
                    firstPage: nextPage,
                    verseCount: chapter.verses.count
                ))
                nextPage += 1 + chapter.verses.count
            }
        }
        self.chapters = chapters
        chapterLookup = lookup
        pageCount = nextPage
    }

    func page(at index: Int) -> FocusPage? {
        guard index >= 0, index < pageCount else { return nil }

        // Last chapter whose title page is at or before `index`.
        var low = 0
        var high = chapters.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if chapters[mid].firstPage <= index {
                low = mid
            } else {
                high = mid - 1
            }
        }

        let entry = chapters[low]
        let book = books[entry.bookIndex]
        let chapter = book.chapters[entry.chapterIndex]
        let offset = index - entry.firstPage
        guard offset > 0 else {
            return .chapter(bookName: book.name, chapterNumber: chapter.number)
        }
        let verse = chapter.verses[offset - 1]
        return .verse(FocusVerse(
            location: FocusVerseLocation(bookName: book.name, chapterNumber: chapter.number, verseNumber: verse.number),
            text: verse.text,
            redLetterRanges: verse.redLetterRanges,
            suppliedWordRanges: verse.suppliedWordRanges
        ))
    }

    /// The page showing a verse, or its chapter's title page if the verse does not exist.
    func index(of location: FocusVerseLocation) -> Int? {
        guard let chapterPosition = chapterLookup[Self.key(location.bookName, location.chapterNumber)] else {
            return nil
        }
        let entry = chapters[chapterPosition]
        let verses = books[entry.bookIndex].chapters[entry.chapterIndex].verses
        guard let verseOffset = verses.firstIndex(where: { $0.number == location.verseNumber }) else {
            return entry.firstPage
        }
        return entry.firstPage + 1 + verseOffset
    }

    private static func key(_ bookName: String, _ chapterNumber: Int) -> String {
        "\(bookName):\(chapterNumber)"
    }
}

struct FocusVerse {
    let location: FocusVerseLocation
    let text: String
    let redLetterRanges: [Range<Int>]
    let suppliedWordRanges: [Range<Int>]

    func attributedText(italicizingSuppliedWords: Bool) -> AttributedString {
        RedLetterText.attributedText(
            text,
            redLetterRanges: redLetterRanges,
            suppliedWordRanges: suppliedWordRanges,
            italicizesSuppliedWords: italicizingSuppliedWords
        )
    }
}

private struct FocusPageView: View {
    let page: FocusPage
    let readerFontSize: Double

    @ViewBuilder
    var body: some View {
        switch page {
        case .chapter(let bookName, let chapterNumber):
            FocusChapterMarkerPage(bookName: bookName, chapterNumber: chapterNumber)
        case .verse(let verse):
            FocusVersePage(verse: verse, readerFontSize: readerFontSize)
        }
    }
}

private struct FocusChapterMarkerPage: View {
    let bookName: String
    let chapterNumber: Int

    var body: some View {
        Text("\(bookName) \(chapterNumber)")
            .font(.title.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview("Long Verse") {
    // Esther 8:9, the Bible's longest verse; at large text sizes it shrinks to fit its page.
    FocusVersePage(
        verse: FocusVerse(
            location: FocusVerseLocation(bookName: "Esther", chapterNumber: 8, verseNumber: 9),
            text: "Then were the king’s scribes called at that time in the third month, that is, the month Sivan, on the three and twentieth day thereof; and it was written according to all that Mordecai commanded unto the Jews, and to the lieutenants, and the deputies and rulers of the provinces which are from India unto Ethiopia, an hundred twenty and seven provinces, unto every province according to the writing thereof, and unto every people after their language, and to the Jews according to their writing, and according to their language.",
            redLetterRanges: [],
            suppliedWordRanges: []
        ),
        readerFontSize: 17
    )
}
