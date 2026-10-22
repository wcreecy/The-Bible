import SwiftUI

struct SearchHomeCard: View {
    enum Presentation {
        case card
        case inline
    }

    let presentation: Presentation
    /// Called when typing starts and when results arrive, so Home can scroll the card
    /// above the keyboard and tab bar.
    let onNeedsVisibility: () -> Void
    let onSelectResult: (SearchResult) -> Void

    init(
        presentation: Presentation = .card,
        onNeedsVisibility: @escaping () -> Void = {},
        onSelectResult: @escaping (SearchResult) -> Void
    ) {
        self.presentation = presentation
        self.onNeedsVisibility = onNeedsVisibility
        self.onSelectResult = onSelectResult
    }

    /// A book, chapter, or verse the query names directly, shown above the keyword matches.
    private struct ReferenceMatch: Identifiable {
        let title: String
        let previewText: String
        let destination: SearchResult

        var id: String { destination.id }
    }

    @State private var query = ""
    @State private var referenceMatch: ReferenceMatch?
    @State private var results: [SearchResult] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false
    @FocusState private var isFieldFocused: Bool

    private var searchTokens: [String] {
        query
            .lowercased()
            .split { $0.isWhitespace || $0.isPunctuation }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    var body: some View {
        Group {
            switch presentation {
            case .card:
                HeroCard(
                    title: "",
                    subtitle: nil,
                    icon: nil,
                    tint: .purple
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Search the Bible", systemImage: "magnifyingglass")
                            .font(.headline)
                        searchField
                        searchResults
                    }
                }
            case .inline:
                VStack(alignment: .leading, spacing: 10) {
                    searchField
                    if !query.isEmpty {
                        searchResults
                    }
                }
            }
        }
        .onChange(of: query) { _, newValue in
            // Some hardware keyboard layouts send ";" for Shift-; — treat it as ":" in references.
            let normalizedQuery = newValue.replacingOccurrences(of: ";", with: ":")
            guard normalizedQuery == newValue else {
                query = normalizedQuery
                return
            }
            scheduleSearch()
        }
        .onChange(of: isFieldFocused) { _, focused in
            if focused { onNeedsVisibility() }
        }
        .onChange(of: isSearching) { _, searching in
            // Results change the card's height; keep all of it in view.
            if !searching && isFieldFocused { onNeedsVisibility() }
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search words or a reference", text: $query)
                .textFieldStyle(.plain)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .focused($isFieldFocused)
                .onSubmit(openTopResult)

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel("Search the Bible")
    }

    @ViewBuilder
    private var searchResults: some View {
        if query.isEmpty {
            Text("Find words, phrases, or references like John 3:16.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            if let referenceMatch {
                referenceRow(referenceMatch)
            }

            if isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if results.isEmpty {
                if referenceMatch == nil {
                    Text("No matching verses.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(results) { result in
                    resultRow(result)
                }
            }
        }
    }

    private func referenceRow(_ match: ReferenceMatch) -> some View {
        Button {
            onSelectResult(match.destination)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "book")
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text(match.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(match.previewText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(match.title)
        .accessibilityHint("Opens \(match.title) in the Bible reader")
    }

    private func resultRow(_ result: SearchResult) -> some View {
        Button {
            onSelectResult(result)
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(result.bookName) \(result.chapterNumber):\(result.verseNumber)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(result.verseText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens this verse in the Bible reader")
    }

    private func openTopResult() {
        if let destination = referenceMatch?.destination ?? results.first {
            onSelectResult(destination)
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchTokens.isEmpty else {
            referenceMatch = nil
            results = []
            isSearching = false
            return
        }

        let tokens = searchTokens
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            let books = await BibleRepository.shared.loadAllBooks()
            let match = Self.referenceMatch(for: trimmedQuery, in: books)
            let matchingResults = await BibleSearchIndex.shared.search(
                tokens: tokens,
                allowedBookIndices: nil,
                maxResults: match == nil ? 3 : 2
            )
            guard !Task.isCancelled else { return }

            referenceMatch = match
            results = matchingResults.filter { $0.id != match?.destination.id }
            isSearching = false
        }
    }

    /// Interprets the query as a verse ("John 3:16"), chapter ("John 1"), or book ("John") reference.
    private static func referenceMatch(for query: String, in books: [Book]) -> ReferenceMatch? {
        if let reference = BibleReferenceParser.reference(for: query, in: books) {
            let verse = reference.verse ?? reference.chapter.verses.first
            return ReferenceMatch(
                title: reference.title,
                previewText: verse?.text ?? "",
                destination: SearchResult(
                    bookIndex: reference.bookIndex,
                    bookName: reference.book.name,
                    chapterNumber: reference.chapter.number,
                    verseNumber: verse?.number ?? 1,
                    verseText: verse?.text ?? "",
                    isReferenceMatch: true
                )
            )
        }

        // A bare book name opens its first chapter. Require three characters so short words
        // like "am" or "is" aren't treated as book abbreviations.
        guard query.count >= 3,
              !BibleReferenceParser.isReferenceShaped(query),
              let bookIndex = BibleReferenceParser.bookIndex(matching: query, in: books),
              let chapter = books[bookIndex].chapters.first,
              let verse = chapter.verses.first else { return nil }

        let book = books[bookIndex]
        return ReferenceMatch(
            title: book.name,
            previewText: verse.text,
            destination: SearchResult(
                bookIndex: bookIndex,
                bookName: book.name,
                chapterNumber: chapter.number,
                verseNumber: verse.number,
                verseText: verse.text,
                isReferenceMatch: true
            )
        )
    }
}
