import SwiftUI

struct HomeBibleReaderCard: View {
    @AppStorage("homeBibleReaderBook") private var selectedBookName: String = "Genesis"
    @AppStorage("homeBibleReaderChapter") private var selectedChapterNumber: Int = 1
    @AppStorage("homeBibleReaderVerse") private var selectedVerseNumber: Int = 1
    @AppStorage("homeBibleReaderContentHeight") private var preferredContentHeight: Double = 0
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false

    @State private var book: Book?
    @State private var isLoading = true
    @State private var showsScripturePicker = false
    @State private var currentContentHeight: CGFloat = 0
    @State private var resizeStartHeight: CGFloat?
    @State private var liveResizeHeight: CGFloat?

    private var chapter: Chapter? {
        book?.chapters.first(where: { $0.number == selectedChapterNumber })
    }

    private var canonicalBookNames: [String] {
        BibleCanon.canonicalOrder()
    }

    private var selectedBookIndex: Int? {
        canonicalBookNames.firstIndex(of: selectedBookName)
    }

    private var canShowPreviousChapter: Bool {
        guard let selectedBookIndex else { return selectedChapterNumber > 1 }
        return selectedChapterNumber > 1 || selectedBookIndex > canonicalBookNames.startIndex
    }

    private var canShowNextChapter: Bool {
        guard let book else { return false }
        if selectedChapterNumber < book.chapters.count {
            return true
        }
        guard let selectedBookIndex else { return false }
        return selectedBookIndex < canonicalBookNames.index(before: canonicalBookNames.endIndex)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                showsScripturePicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "book.closed.fill")
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedBookName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Chapter \(selectedChapterNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(AppDesignMetrics.cardPadding)

            if contextualTipsEnabled {
                ContextualTipView(
                    id: "home.readerShortcuts",
                    title: "Bible reader shortcuts",
                    message: "Swipe left or right to change chapters, drag the handle to resize, or press and hold a verse to open it in the Bible tab.",
                    systemImage: "hand.draw"
                )
                .padding(.horizontal, AppDesignMetrics.cardPadding)
                .padding(.bottom, AppDesignMetrics.cardPadding)
            }

            Divider()

            Group {
                if isLoading {
                    ProgressView("Loading chapter…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let chapter {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 14) {
                                ForEach(chapter.verses) { verse in
                                    verseRow(verse)
                                        .id(verse.number)
                                }
                            }
                            .padding(AppDesignMetrics.cardPadding)
                        }
                        .id(selectedChapterNumber)
                        .onAppear {
                            scrollToSelectedVerse(using: proxy)
                        }
                        .onChange(of: selectedVerseNumber) { _, _ in
                            scrollToSelectedVerse(using: proxy)
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Chapter Unavailable",
                        systemImage: "book.closed",
                        description: Text("Choose another Bible passage.")
                    )
                }
            }
            .containerRelativeFrame(.vertical, alignment: .top) { availableHeight, _ in
                readerContentHeight(availableHeight: availableHeight)
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height
            } action: { height in
                currentContentHeight = height
            }
            .contentShape(Rectangle())
            .simultaneousGesture(chapterSwipeGesture)

            Image(systemName: "line.3.horizontal")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .contentShape(Rectangle())
                .gesture(resizeGesture)
                .accessibilityLabel("Resize Bible reader")
                .accessibilityHint("Drag up or down to change the reader height")
                .accessibilityAdjustableAction { direction in
                    resizeReader(for: direction)
                }

            Divider()

            HStack {
                Button {
                    Task { await showPreviousChapter() }
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .disabled(!canShowPreviousChapter)

                Spacer()

                Text("\(selectedBookName) \(selectedChapterNumber)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    Task { await showNextChapter() }
                } label: {
                    HStack(spacing: 4) {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                }
                .disabled(!canShowNextChapter)
            }
            .font(.caption.weight(.semibold))
            .padding(AppDesignMetrics.cardPadding)
        }
        .heroCardSurface()
        .task(id: selectedBookName) {
            await loadSelectedBook()
        }
        .sheet(isPresented: $showsScripturePicker) {
            NavigationStack {
                ScripturePickerView(
                    initialBook: selectedBookName,
                    initialChapter: selectedChapterNumber,
                    initialVerse: selectedVerseNumber
                ) { bookName, chapterNumber, verseNumber in
                    selectedBookName = bookName
                    selectedChapterNumber = chapterNumber
                    selectedVerseNumber = verseNumber
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Bible Reader")
    }

    private func verseRow(_ verse: Verse) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(verse.number)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(verse.number == selectedVerseNumber ? Color.accentColor : .secondary)
                .frame(minWidth: 20, alignment: .trailing)

            Text(verse.text)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedVerseNumber = verse.number
        }
        .onLongPressGesture {
            openInBibleTab(at: verse.number)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Verse \(verse.number). \(verse.text)")
        .accessibilityHint("Long press to open this verse in the Bible tab")
    }

    private static let minimumContentHeight: CGFloat = 240
    private static let maximumContentHeight: CGFloat = 900

    private func readerContentHeight(availableHeight: CGFloat) -> CGFloat {
        if let liveResizeHeight {
            return clampedContentHeight(liveResizeHeight)
        }

        if preferredContentHeight > 0 {
            return clampedContentHeight(CGFloat(preferredContentHeight))
        }

        // The default adapts to the window so the chapter controls remain visible.
        return clampedContentHeight(min(520, availableHeight - 392))
    }

    private func clampedContentHeight(_ height: CGFloat) -> CGFloat {
        min(Self.maximumContentHeight, max(Self.minimumContentHeight, height))
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let startHeight = resizeStartHeight ?? currentContentHeight
                if resizeStartHeight == nil {
                    resizeStartHeight = startHeight
                }
                liveResizeHeight = clampedContentHeight(startHeight + value.translation.height)
            }
            .onEnded { value in
                let startHeight = resizeStartHeight ?? currentContentHeight
                let finalHeight = clampedContentHeight(startHeight + value.translation.height)
                preferredContentHeight = Double(finalHeight)
                resizeStartHeight = nil
                liveResizeHeight = nil
                Haptics.selection()
            }
    }

    private func resizeReader(for direction: AccessibilityAdjustmentDirection) {
        let startingHeight = preferredContentHeight > 0
            ? CGFloat(preferredContentHeight)
            : currentContentHeight
        let adjustment: CGFloat

        switch direction {
        case .increment:
            adjustment = 60
        case .decrement:
            adjustment = -60
        @unknown default:
            return
        }

        preferredContentHeight = Double(clampedContentHeight(startingHeight + adjustment))
        Haptics.selection()
    }

    private var chapterSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height),
                      abs(value.translation.width) > 60 else {
                    return
                }

                if value.translation.width < 0 {
                    Task { await showNextChapter() }
                } else {
                    Task { await showPreviousChapter() }
                }
            }
    }

    @MainActor
    private func loadSelectedBook() async {
        isLoading = true
        defer { isLoading = false }

        book = await BibleRepository.shared.loadBook(named: selectedBookName)

        guard let book else { return }
        selectedChapterNumber = min(max(selectedChapterNumber, 1), book.chapters.count)

        if let chapter {
            selectedVerseNumber = min(max(selectedVerseNumber, 1), chapter.verses.count)
        }
    }

    @MainActor
    private func showPreviousChapter() async {
        guard canShowPreviousChapter else { return }

        if selectedChapterNumber > 1 {
            selectedChapterNumber -= 1
        } else if let selectedBookIndex, selectedBookIndex > canonicalBookNames.startIndex {
            let previousBookName = canonicalBookNames[selectedBookIndex - 1]
            guard let previousBook = await BibleRepository.shared.loadBook(named: previousBookName) else {
                return
            }
            book = previousBook
            selectedBookName = previousBookName
            selectedChapterNumber = previousBook.chapters.count
        }

        selectedVerseNumber = 1
        Haptics.selection()
    }

    @MainActor
    private func showNextChapter() async {
        guard canShowNextChapter, let book else { return }

        if selectedChapterNumber < book.chapters.count {
            selectedChapterNumber += 1
        } else if let selectedBookIndex,
                  selectedBookIndex < canonicalBookNames.index(before: canonicalBookNames.endIndex) {
            let nextBookName = canonicalBookNames[selectedBookIndex + 1]
            guard let nextBook = await BibleRepository.shared.loadBook(named: nextBookName) else {
                return
            }
            self.book = nextBook
            selectedBookName = nextBookName
            selectedChapterNumber = 1
        }

        selectedVerseNumber = 1
        Haptics.selection()
    }

    private func scrollToSelectedVerse(using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(selectedVerseNumber, anchor: .top)
            }
        }
    }

    private func openInBibleTab(at verseNumber: Int) {
        selectedVerseNumber = verseNumber
        Haptics.selection()
        NotificationCenter.default.post(
            name: .switchToTab,
            object: nil,
            userInfo: [
                "tab": AppTab.bible.rawValue,
                "tabName": AppTab.bible.name
            ]
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(
                name: .openBibleReference,
                object: nil,
                userInfo: [
                    "book": selectedBookName,
                    "chapter": selectedChapterNumber,
                    "verse": verseNumber,
                    "relayed": true
                ]
            )
        }
    }
}
