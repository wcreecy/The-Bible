import SwiftUI

/// Loads one book in every available translation so a verse can be read side by side, and
/// steps through the verses around it.
///
/// The repository keeps only the active translation in memory, so this holds just the one
/// book from each of the others while the screen is open.
@MainActor
@Observable
final class VerseCompareModel {
    let bookName: String
    private(set) var chapter: Int
    private(set) var verse: Int
    private(set) var isLoading = true
    private(set) var loadFailed = false

    /// The reader's own translation first, then the rest in a fixed order.
    let translations: [BibleTranslation]
    private var books: [BibleTranslation: Book] = [:]

    init(bookName: String, chapter: Int, verse: Int) {
        self.bookName = bookName
        self.chapter = chapter
        self.verse = verse

        let preferred = BibleRepository.shared.activeTranslation
        let available = BibleTranslation.available
        translations = available.filter { $0 == preferred } + available.filter { $0 != preferred }
    }

    func load() async {
        guard books.isEmpty else { return }
        let active = BibleRepository.shared.activeTranslation
        let bookName = bookName
        var loaded: [BibleTranslation: Book] = [:]

        await withTaskGroup(of: (BibleTranslation, Book?).self) { group in
            for translation in translations {
                group.addTask {
                    let repository = BibleRepository.shared
                    let allBooks = translation == active
                        ? await repository.loadAllBooks(for: translation)
                        : await repository.loadBooksWithoutCaching(for: translation)
                    return (translation, allBooks.first { $0.name == bookName })
                }
            }
            for await (translation, book) in group {
                if let book { loaded[translation] = book }
            }
        }

        books = loaded
        loadFailed = loaded.isEmpty
        isLoading = false
    }

    /// The verse in a translation. Nil when that translation has no such verse number, which
    /// differs from a verse it leaves out (`Verse.isOmitted`).
    func verse(in translation: BibleTranslation) -> Verse? {
        books[translation]?
            .chapters.first { $0.number == chapter }?
            .verses.first { $0.number == verse }
    }

    // MARK: Stepping

    /// Translations number a few chapters differently, so stepping follows the largest count.
    private var chapterCount: Int {
        books.values.map { $0.chapters.count }.max() ?? chapter
    }

    private func verseCount(inChapter number: Int) -> Int {
        books.values.compactMap { book in
            book.chapters.first { $0.number == number }?.verses.count
        }.max() ?? 0
    }

    var canStepBack: Bool { verse > 1 || chapter > 1 }

    var canStepForward: Bool {
        verse < verseCount(inChapter: chapter) || chapter < chapterCount
    }

    func stepBack() {
        if verse > 1 {
            verse -= 1
        } else if chapter > 1 {
            chapter -= 1
            verse = max(verseCount(inChapter: chapter), 1)
        }
    }

    func stepForward() {
        if verse < verseCount(inChapter: chapter) {
            verse += 1
        } else if chapter < chapterCount {
            chapter += 1
            verse = 1
        }
    }
}

/// One verse in every translation. Wide windows show the translations as columns; narrow
/// ones stack them as cards. Step through neighboring verses with the bottom bar.
struct VerseCompareView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: VerseCompareModel

    init(bookName: String, chapter: Int, verse: Int) {
        _model = State(initialValue: VerseCompareModel(bookName: bookName, chapter: chapter, verse: verse))
    }

    /// Below this width a column is too narrow to read comfortably, so the cards stack.
    private let minimumColumnWidth: CGFloat = 240

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.loadFailed {
                ContentUnavailableView(
                    "Couldn't Load the Text",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The translations couldn't be read. Try again.")
                )
            } else {
                ScrollView {
                    comparison
                        .padding()
                }
            }
        }
        .navigationTitle("\(model.bookName) \(model.chapter):\(model.verse)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    Haptics.selection()
                    model.stepBack()
                } label: {
                    Label("Previous Verse", systemImage: "chevron.left")
                }
                .disabled(!model.canStepBack || model.isLoading)

                Spacer()

                Button {
                    Haptics.selection()
                    model.stepForward()
                } label: {
                    Label("Next Verse", systemImage: "chevron.right")
                }
                .disabled(!model.canStepForward || model.isLoading)
            }
        }
        .task { await model.load() }
        .presentationDetents([.medium, .large])
    }

    /// Columns when they all fit at a readable width, otherwise stacked cards.
    private var comparison: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(model.translations) { translation in
                    card(for: translation)
                        .frame(minWidth: minimumColumnWidth, maxWidth: .infinity, alignment: .topLeading)
                }
            }
            VStack(spacing: 12) {
                ForEach(model.translations) { translation in
                    card(for: translation)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func card(for translation: BibleTranslation) -> VerseCompareCard {
        VerseCompareCard(
            translation: translation,
            bookName: model.bookName,
            chapter: model.chapter,
            number: model.verse,
            verse: model.verse(in: translation)
        )
    }
}

private struct VerseCompareCard: View {
    @AppStorage(RedLetterText.suppliedWordsInItalicsKey) private var italicizesSuppliedWords = false

    let translation: BibleTranslation
    let bookName: String
    let chapter: Int
    let number: Int
    /// Nil when the translation has no verse with this number.
    let verse: Verse?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(translation.abbreviation)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.accentColor)

                Text(translation.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let verse, !verse.isOmitted {
                    ShareLink(item: shareText(for: verse)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .font(.subheadline)
                    .accessibilityLabel("Share \(translation.abbreviation) Verse")
                }
            }

            content

            if let note = translation.reorderNote(book: bookName, chapter: chapter, verse: number) {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var content: some View {
        if let verse {
            if verse.isOmitted {
                Text(Verse.omittedNote(in: translation))
                    .font(.callout)
                    .italic()
                    .foregroundStyle(.secondary)
            } else {
                Text(verse.attributedText(italicizingSuppliedWords: italicizesSuppliedWords))
                    .font(.body)
                    .textSelection(.enabled)
            }
        } else {
            Text("The \(translation.abbreviation) has no verse \(number) in this chapter.")
                .font(.callout)
                .italic()
                .foregroundStyle(.secondary)
        }
    }

    private func shareText(for verse: Verse) -> String {
        VerseActionReference(
            bookName: bookName,
            chapterNumber: chapter,
            verseNumber: number,
            verseText: verse.text,
            translation: translation
        ).shareText
    }
}
