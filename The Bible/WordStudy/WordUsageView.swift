import SwiftUI

/// Every verse that uses a word, grouped by book. Tapping one opens it in the reader.
struct WordUsageView: View {
    @Environment(\.dismiss) private var dismiss

    let word: OriginalWord
    let translation: BibleTranslation
    let onOpen: (VerseLocation) -> Void

    @State private var verses: [VerseLocation] = []
    @State private var isLoading = true

    private var title: String {
        [word.displayStrongsNumber, word.entry?.gloss].compactMap { $0 }.joined(separator: " · ")
    }

    /// The verses (already in Bible order) in runs by book.
    private var books: [(name: String, verses: [VerseLocation])] {
        var groups: [(name: String, verses: [VerseLocation])] = []
        for verse in verses {
            if groups.last?.name == verse.bookName {
                groups[groups.count - 1].verses.append(verse)
            } else {
                groups.append((verse.bookName, [verse]))
            }
        }
        return groups
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if verses.isEmpty {
                    ContentUnavailableView(
                        "No Verses",
                        systemImage: "text.magnifyingglass",
                        description: Text("No verses were found for this word.")
                    )
                } else {
                    List {
                        ForEach(books, id: \.name) { book in
                            Section {
                                ForEach(book.verses) { verse in
                                    row(for: verse)
                                }
                            } header: {
                                Text(verbatim: "\(book.name) · \(book.verses.count)")
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            if let strongs = word.strongsNumber {
                verses = await OriginalWordsRepository.shared.verses(using: strongs, translation: translation)
            }
            isLoading = false
        }
        .presentationDetents([.large])
    }

    private func row(for verse: VerseLocation) -> some View {
        Button {
            onOpen(verse)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "\(verse.chapter):\(verse.verse)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                if let text = OriginalWordsModel.verseText(verse, preferring: translation)?.text {
                    Text(text)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this verse in the reader")
    }
}
