import SwiftUI

struct FocusReadingView: View {
    let initialLocation: FocusVerseLocation
    let readerFontSize: Double
    let onLocationChange: (FocusVerseLocation) -> Void
    let onExit: () -> Void

    @State private var visibleVerseID: String?
    @State private var showsControls = false
    @State private var isLocationPickerPresented = false
    @AppStorage("hasSeenFocusModeControlsHint") private var hasSeenControlsHint = false

    private let pageIndex = FocusPageIndex.shared

    init(
        initialLocation: FocusVerseLocation,
        readerFontSize: Double,
        onLocationChange: @escaping (FocusVerseLocation) -> Void,
        onExit: @escaping () -> Void
    ) {
        self.initialLocation = initialLocation
        self.readerFontSize = readerFontSize
        self.onLocationChange = onLocationChange
        self.onExit = onExit
        _visibleVerseID = State(initialValue: initialLocation.id)
    }

    private var currentLocation: FocusVerseLocation {
        guard let visibleVerseID,
              let page = pageIndex.pagesByID[visibleVerseID] else {
            return initialLocation
        }
        return page.location
    }

    private var currentVerse: FocusVerse? {
        pageIndex.versesByID[currentLocation.id]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(pageIndex.pages) { page in
                        FocusPageView(page: page, readerFontSize: readerFontSize)
                            .containerRelativeFrame(.vertical)
                            .id(page.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $visibleVerseID)
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .onChange(of: visibleVerseID) { _, newValue in
                guard let newValue,
                      let page = pageIndex.pagesByID[newValue] else { return }
                onLocationChange(page.location)
            }
            .onTapGesture {
                showsControls = true
                hasSeenControlsHint = true
            }
            .accessibilityAction(named: "Show Focus Mode Controls") {
                showsControls = true
                hasSeenControlsHint = true
            }
            .accessibilityAction(named: "Exit Focus Mode", onExit)

            if showsControls {
                FocusControls(
                    verse: currentVerse,
                    location: currentLocation,
                    onChooseLocation: {
                        isLocationPickerPresented = true
                    },
                    onExit: onExit
                )
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
        .sheet(isPresented: $isLocationPickerPresented) {
            FocusLocationPicker(initialLocation: currentLocation) { location in
                visibleVerseID = location.id
                onLocationChange(location)
                isLocationPickerPresented = false
            }
        }
        .task(id: showsControls) {
            guard showsControls else { return }
            try? await Task.sleep(for: .seconds(4))
            guard Task.isCancelled == false else { return }
            showsControls = false
        }
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

            if let verse {
                VerseActionMenu(
                    verse: VerseActionReference(
                        bookName: verse.bookName,
                        chapterNumber: verse.chapterNumber,
                        verseNumber: verse.verseNumber,
                        verseText: verse.text
                    ),
                    presentation: .focus
                )
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
}

private struct FocusLocationPicker: View {
    @Environment(\.dismiss) private var dismiss

    let onSelect: (FocusVerseLocation) -> Void

    @State private var selectedBookName: String
    @State private var selectedChapterNumber: Int
    @State private var selectedVerseNumber: Int

    init(initialLocation: FocusVerseLocation, onSelect: @escaping (FocusVerseLocation) -> Void) {
        self.onSelect = onSelect
        _selectedBookName = State(initialValue: initialLocation.bookName)
        _selectedChapterNumber = State(initialValue: initialLocation.chapterNumber)
        _selectedVerseNumber = State(initialValue: initialLocation.verseNumber)
    }

    private var selectedBook: Book {
        BibleData.books.first(where: { $0.name == selectedBookName }) ?? BibleData.books[0]
    }

    private var selectedChapter: Chapter {
        selectedBook.chapters.first(where: { $0.number == selectedChapterNumber }) ?? selectedBook.chapters[0]
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Book", selection: $selectedBookName) {
                    ForEach(BibleData.books) { book in
                        Text(book.name).tag(book.name)
                    }
                }

                Picker("Chapter", selection: $selectedChapterNumber) {
                    ForEach(selectedBook.chapters) { chapter in
                        Text("\(chapter.number)").tag(chapter.number)
                    }
                }

                Picker("Verse", selection: $selectedVerseNumber) {
                    ForEach(selectedChapter.verses) { verse in
                        Text("\(verse.number)").tag(verse.number)
                    }
                }
            }
            .navigationTitle("Go to Verse")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedBookName) { _, _ in
                selectedChapterNumber = selectedBook.chapters[0].number
                selectedVerseNumber = selectedBook.chapters[0].verses[0].number
            }
            .onChange(of: selectedChapterNumber) { _, _ in
                selectedVerseNumber = selectedChapter.verses[0].number
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Go") {
                        onSelect(
                            FocusVerseLocation(
                                bookName: selectedBook.name,
                                chapterNumber: selectedChapter.number,
                                verseNumber: selectedVerseNumber
                            )
                        )
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct FocusVersePage: View {
    let verse: FocusVerse
    let readerFontSize: Double

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ScaledMetric(relativeTo: .body) private var defaultReaderFontSize: CGFloat = 17

    private var focusFontAdjustment: CGFloat {
        horizontalSizeClass == .regular ? 4 : 0
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(verse.text)
                .font(.system(size: defaultReaderFontSize + CGFloat(readerFontSize - 17) + focusFontAdjustment))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(verse.bookName) \(verse.chapterNumber):\(verse.verseNumber)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(verse.bookName) \(verse.chapterNumber):\(verse.verseNumber), \(verse.text)")
    }
}

struct FocusVerseLocation: Equatable {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int

    var id: String {
        "verse-\(bookName)-\(chapterNumber)-\(verseNumber)"
    }
}

private enum FocusPage: Identifiable {
    case chapter(bookName: String, chapterNumber: Int)
    case verse(FocusVerse)

    var id: String {
        switch self {
        case .chapter(let bookName, let chapterNumber):
            "chapter-\(bookName)-\(chapterNumber)"
        case .verse(let verse):
            verse.id
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

    static let all: [FocusPage] = BibleData.books.flatMap { book in
        book.chapters.flatMap { chapter in
            let marker = FocusPage.chapter(bookName: book.name, chapterNumber: chapter.number)
            let verses = chapter.verses.map { verse in
                FocusPage.verse(FocusVerse(
                    bookName: book.name,
                    chapterNumber: chapter.number,
                    verseNumber: verse.number,
                    text: verse.text
                ))
            }
            return [marker] + verses
        }
    }
}

private struct FocusPageIndex {
    let pages: [FocusPage]
    let pagesByID: [String: FocusPage]
    let versesByID: [String: FocusVerse]

    static let shared = FocusPageIndex()

    private init() {
        let pages = FocusPage.all
        self.pages = pages
        pagesByID = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, $0) })
        versesByID = Dictionary(uniqueKeysWithValues: pages.compactMap { page in
            guard case let .verse(verse) = page else { return nil }
            return (verse.id, verse)
        })
    }
}

private struct FocusVerse: Identifiable {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let text: String

    var id: String {
        "verse-\(bookName)-\(chapterNumber)-\(verseNumber)"
    }

    var location: FocusVerseLocation {
        FocusVerseLocation(
            bookName: bookName,
            chapterNumber: chapterNumber,
            verseNumber: verseNumber
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
