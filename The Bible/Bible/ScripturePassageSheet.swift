import SwiftData
import SwiftUI
import UIKit

/// Preview of a cited passage with Copy, Share, and Open in Bible.
struct ScripturePassageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]

    let reference: PassageReference

    /// Long chapter ranges preview only their first chapter.
    private static let maximumPreviewChapters = 3

    private struct ChapterSection: Identifiable {
        let chapter: Int
        let verses: [Verse]
        var id: Int { chapter }
    }

    @State private var sections: [ChapterSection] = []
    @State private var isTruncated = false
    @State private var isLoading = true
    @State private var didCopy = false
    @State private var persistenceFailure: PersistenceFailure?

    private var favoriteTarget: VerseActionReference? {
        // A verse the translation leaves out has nothing to save.
        guard let section = sections.first,
              let verse = section.verses.first(where: { !$0.isOmitted }) else { return nil }
        return VerseActionReference(
            bookName: reference.bookName,
            chapterNumber: section.chapter,
            verseNumber: verse.number,
            verseText: verse.text
        )
    }

    private var isFavorite: Bool {
        guard let favoriteTarget else { return false }
        return !FavoriteVerses.matching(
            favorites,
            bookName: favoriteTarget.bookName,
            chapterNumber: favoriteTarget.chapterNumber,
            verseNumber: favoriteTarget.verseNumber
        ).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView("Loading scripture…")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if sections.isEmpty {
                        ContentUnavailableView(
                            "Scripture Unavailable",
                            systemImage: "book.closed",
                            description: Text("This passage could not be loaded.")
                        )
                    } else {
                        ForEach(sections) { section in
                            VStack(alignment: .leading, spacing: 12) {
                                if sections.count > 1 || !reference.isSingleChapter {
                                    Text("\(reference.bookName) \(section.chapter)")
                                        .font(.headline)
                                }
                                ForEach(section.verses) { verse in
                                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                                        Text(verse.number, format: .number)
                                            .font(.caption.bold())
                                            .foregroundStyle(.secondary)
                                            .frame(minWidth: 24, alignment: .trailing)
                                        if verse.isOmitted {
                                            Text(Verse.omittedNote(in: BibleRepository.shared.activeTranslation))
                                                .font(.subheadline.italic())
                                                .foregroundStyle(.secondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        } else {
                                            Text(verse.text)
                                                .font(.body)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                    }
                                }
                            }
                        }
                        .textSelection(.enabled)

                        Text(BibleRepository.shared.activeTranslation.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if isTruncated {
                            Text("Showing \(reference.bookName) \(reference.startChapter). Open in Bible to keep reading.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: openInBible) {
                    Label("Open in Bible", systemImage: "book")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .disabled(sections.isEmpty)
            }
            .navigationTitle(reference.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .task(id: reference.id) { await load() }
            .persistenceFailureAlert(failure: $persistenceFailure)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close scripture")
                }

                ToolbarItemGroup(placement: .confirmationAction) {
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(isFavorite ? .red : .primary)
                    }
                    .accessibilityLabel(
                        isFavorite
                            ? "Remove \(favoriteTarget?.bookName ?? reference.bookName) from Favorites"
                            : "Add \(favoriteTarget?.bookName ?? reference.bookName) to Favorites"
                    )
                    .disabled(favoriteTarget == nil)

                    Button {
                        UIPasteboard.general.string = shareText
                        Haptics.selection()
                        didCopy = true
                    } label: {
                        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                    }
                    .accessibilityLabel(didCopy ? "Copied" : "Copy scripture")
                    .disabled(sections.isEmpty)

                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share scripture")
                    .disabled(sections.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var shareText: String {
        let body = sections.map { section in
            section.verses.filter { !$0.isOmitted }.map { "\(section.chapter):\($0.number) \($0.text)" }.joined(separator: "\n")
        }
        .joined(separator: "\n\n")
        return "\(reference.displayTitle) \(BibleRepository.shared.activeTranslation.abbreviation)\n\n\(body)"
    }

    private func toggleFavorite() {
        guard let favoriteTarget else { return }

        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                _ = try FavoriteVerses.toggle(
                    bookName: favoriteTarget.bookName,
                    chapterNumber: favoriteTarget.chapterNumber,
                    verseNumber: favoriteTarget.verseNumber,
                    verseText: favoriteTarget.verseText,
                    favorites: favorites,
                    in: modelContext
                )
            },
            onSuccess: {
                Haptics.success()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }

    private func load() async {
        isLoading = true
        let books = await BibleRepository.shared.loadAllBooks()
        defer { isLoading = false }
        guard let book = books.first(where: { $0.name == reference.bookName }) else {
            sections = []
            return
        }

        let chapterCount = reference.endChapter - reference.startChapter + 1
        isTruncated = chapterCount > Self.maximumPreviewChapters
        let lastChapter = isTruncated ? reference.startChapter : reference.endChapter

        sections = (reference.startChapter...lastChapter).compactMap { number in
            guard book.chapters.indices.contains(number - 1) else { return nil }
            let verses = book.chapters[number - 1].verses
            let from = number == reference.startChapter ? (reference.startVerse ?? 1) : 1
            let to = (number == reference.endChapter ? reference.endVerse : nil) ?? Int.max
            let selected = verses.filter { $0.number >= from && $0.number <= to }
            return selected.isEmpty ? nil : ChapterSection(chapter: number, verses: selected)
        }
    }

    private func openInBible() {
        let destination = reference
        dismiss()
        // Navigate after the sheet starts dismissing so the reader can take over.
        DispatchQueue.main.async {
            AppRouter.shared.openBibleReference(
                book: destination.bookName,
                chapter: destination.startChapter,
                verse: destination.startVerse ?? 1
            )
        }
    }
}
