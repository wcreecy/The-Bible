import SwiftUI

struct FocusReadingView: View {
    let initialLocation: FocusVerseLocation
    let readerFontSize: Double
    let onLocationChange: (FocusVerseLocation) -> Void
    let onExit: () -> Void

    @State private var visibleVerseID: String?
    @State private var showsExitControl = false

    private let verses = FocusVerse.all

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(verses) { verse in
                        FocusVersePage(verse: verse, readerFontSize: readerFontSize)
                            .containerRelativeFrame(.vertical)
                            .id(verse.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollPosition(id: $visibleVerseID)
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .onAppear {
                visibleVerseID = initialLocation.id
            }
            .onChange(of: visibleVerseID) { _, newValue in
                guard let newValue,
                      let verse = verses.first(where: { $0.id == newValue }) else { return }
                onLocationChange(verse.location)
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
        "\(bookName)-\(chapterNumber)-\(verseNumber)"
    }
}

private struct FocusVerse: Identifiable {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let text: String

    var id: String {
        location.id
    }

    var location: FocusVerseLocation {
        FocusVerseLocation(
            bookName: bookName,
            chapterNumber: chapterNumber,
            verseNumber: verseNumber
        )
    }

    static let all: [FocusVerse] = BibleData.books.flatMap { book in
        book.chapters.flatMap { chapter in
            chapter.verses.map { verse in
                FocusVerse(
                    bookName: book.name,
                    chapterNumber: chapter.number,
                    verseNumber: verse.number,
                    text: verse.text
                )
            }
        }
    }
}
