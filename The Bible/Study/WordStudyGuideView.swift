import SwiftUI

/// The Bible Study way into the Hebrew and Greek words behind the text. Word study itself
/// lives on each verse and in Search; this page explains both and starts a search.
struct WordStudyGuideView: View {
    @State private var query = ""
    @State private var searchedWord: String?

    /// Searches that find an original word rather than English text.
    private static let examples: [(query: String, meaning: String)] = [
        ("agape", "love"),
        ("logos", "word"),
        ("H430", "God"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("See the Hebrew and Greek words behind the text: what each one means, and everywhere else it's used.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HeroCard(title: "From Any Verse", icon: "text.book.closed") {
                    Text("While reading, press and hold a verse and choose **Hebrew Words** (Old Testament) or **Greek Words** (New Testament).")
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HeroCard(title: "Search an Original Word", icon: "character.book.closed") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Type a word in Hebrew or Greek letters, a Strong's number such as G26, or a transliteration such as agape.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            TextField("Word or Strong's number", text: $query)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.search)
                                .onSubmit(search)
                                .padding(10)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Button("Search", action: search)
                                .buttonStyle(.glassProminent)
                                .disabled(trimmedQuery.isEmpty)
                        }

                        Text("Try one of these")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        PassageFlowLayout(spacing: 8) {
                            ForEach(Self.examples, id: \.query) { example in
                                Button {
                                    searchedWord = example.query
                                } label: {
                                    Text("\(example.query) · \(example.meaning)")
                                        .font(.subheadline)
                                        .lineLimit(1)
                                }
                                .buttonStyle(.glass)
                                .buttonBorderShape(.capsule)
                                .accessibilityLabel("Search \(example.query), meaning \(example.meaning)")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .tabBarContentClearance()
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle("Word Study")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $searchedWord) { word in
            SearchView(initialQuery: word)
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func search() {
        guard !trimmedQuery.isEmpty else { return }
        searchedWord = trimmedQuery
    }
}

#Preview {
    NavigationStack {
        WordStudyGuideView()
    }
}
