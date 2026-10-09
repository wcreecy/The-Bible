import SwiftUI

struct SearchHomeCard: View {
    let onSelectResult: (SearchResult) -> Void

    @State private var query = ""
    @State private var results: [SearchResult] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false

    private var searchTokens: [String] {
        query
            .lowercased()
            .split { $0.isWhitespace || $0.isPunctuation }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    var body: some View {
        HeroCard(
            title: "",
            subtitle: nil,
            icon: nil,
            tint: .purple
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Search the Bible", systemImage: "magnifyingglass")
                    .font(.headline)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search verses", text: $query)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)

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

                searchResults
            }
        }
        .onChange(of: query) { _, _ in
            scheduleSearch()
        }
        .onDisappear {
            searchTask?.cancel()
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        if query.isEmpty {
            Text("Find words or phrases in Scripture.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if isSearching {
            ProgressView()
                .controlSize(.small)
        } else if results.isEmpty {
            Text("No matching verses.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            ForEach(results) { result in
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
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()

        guard !searchTokens.isEmpty else {
            results = []
            isSearching = false
            return
        }

        let tokens = searchTokens
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }

            let matchingResults = await BibleSearchIndex.shared.search(
                tokens: tokens,
                allowedBookIndices: nil,
                maxResults: 3
            )
            guard !Task.isCancelled else { return }

            results = matchingResults
            isSearching = false
        }
    }
}
