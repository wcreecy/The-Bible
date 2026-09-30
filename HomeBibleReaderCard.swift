import SwiftUI

struct HomeBibleReaderCard: View {
    @AppStorage("homeBibleReaderBook") private var selectedBookName: String = "Genesis"
    @AppStorage("homeBibleReaderChapter") private var selectedChapterNumber: Int = 1
    @AppStorage("homeBibleReaderVerse") private var selectedVerseNumber: Int = 1

    @State private var book: Book?
    @State private var isLoading = true
    @State private var showsScripturePicker = false

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
            .frame(minHeight: 520, maxHeight: 720)
            .contentShape(Rectangle())
            .simultaneousGesture(chapterSwipeGesture)

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
                    Label("Next", systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
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

        do {
            book = try await BibleRepository.shared.loadBook(named: selectedBookName)
        } catch {
            book = nil
        }

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
            guard let previousBook = try? await BibleRepository.shared.loadBook(named: previousBookName) else {
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
            guard let nextBook = try? await BibleRepository.shared.loadBook(named: nextBookName) else {
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
