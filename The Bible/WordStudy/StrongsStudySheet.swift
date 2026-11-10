import SwiftUI

/// A word found by a Strong's search: its full dictionary entries and every verse that uses it,
/// opened from the search's blue card. Tapping a verse opens it in the reader.
struct StrongsStudySheet: View {
    @Environment(\.dismiss) private var dismiss

    let match: StrongsSearchMatch
    let translation: BibleTranslation
    let onOpen: (VerseLocation) -> Void

    @State private var verses: [VerseLocation] = []
    @State private var isLoading = true

    /// One entry per distinct word; a number's several senses (H0430G, H0430H, …) share a lemma.
    private var entries: [StrongsEntry] {
        var seen = Set<String>()
        return match.entries.filter { seen.insert("\($0.displayNumber)|\($0.lemma)").inserted }
    }

    private var title: String {
        entries.first.map { [$0.displayNumber, $0.gloss].filter { !$0.isEmpty }.joined(separator: " · ") } ?? ""
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
            List {
                Section {
                    ForEach(entries) { entry in
                        entryView(entry)
                    }
                }

                if isLoading {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                } else {
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
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            verses = await OriginalWordsRepository.shared.verses(
                usingAnyOf: match.entries.map(\.strongs),
                translation: translation
            )
            isLoading = false
        }
        .presentationDetents([.medium, .large])
    }

    private func entryView(_ entry: StrongsEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.lemma)
                    .font(.title2)
                if !entry.transliteration.isEmpty {
                    Text(entry.transliteration)
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.secondary)
                }
                Text(entry.displayNumber)
                    .font(.caption.monospaced().weight(.semibold))
                    .lineLimit(1)
                    .fixedSize()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(Color.accentColor)
            }
            if !entry.gloss.isEmpty {
                Text(entry.gloss)
                    .font(.headline)
            }
            if !entry.definition.isEmpty {
                Text(entry.definition)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
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

#Preview("Strong's Study Sheet") {
    StrongsStudySheet(
        match: StrongsSearchMatch(
            entries: [
                StrongsEntry(
                    strongs: "H1834", lemma: "דַּמֶּ֫שֶׂק", transliteration: "dam.me.seq", gloss: "Damascus",
                    definition: "§ Damascus = \"silent is the sackcloth weaver\"\nan ancient trading city, capital of Syria"
                ),
            ],
            verseCount: 40
        ),
        translation: .kjv,
        onOpen: { _ in }
    )
}
