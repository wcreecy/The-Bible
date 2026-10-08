import SwiftUI

struct FocusReadingView: View {
    let initialLocation: FocusVerseLocation
    let readerFontSize: Double
    let onLocationChange: (FocusVerseLocation) -> Void
    let onExit: () -> Void

    @State private var visibleVerseID: String?
    @State private var showsExitControl = false

    private let pages = FocusPage.all

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

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(pages) { page in
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
                      let page = pages.first(where: { $0.id == newValue }) else { return }
                onLocationChange(page.location)
            }
            .onTapGesture {
                showsExitControl = true
            }
            .accessibilityAction(named: "Exit Focus Mode", onExit)

            if showsExitControl {
                Button(action: onExit) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Exit Focus Mode")
                .padding(.top, 12)
                .padding(.trailing, 16)
                .transition(.opacity)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .task(id: showsExitControl) {
            guard showsExitControl else { return }
            try? await Task.sleep(for: .seconds(3))
            guard Task.isCancelled == false else { return }
            showsExitControl = false
        }
    }
}

private struct FocusVersePage: View {
    let verse: FocusVerse
    let readerFontSize: Double

    @ScaledMetric(relativeTo: .body) private var defaultReaderFontSize: CGFloat = 17

    var body: some View {
        VStack(spacing: 24) {
            Text(verse.text)
                .font(.system(size: defaultReaderFontSize + CGFloat(readerFontSize - 17)))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("\(verse.bookName) \(verse.chapterNumber):\(verse.verseNumber)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
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
