import SwiftUI

struct ReadingSearchSheet: View {
    @ObservedObject var viewModel: ReadingViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search Bible (type at least two words)", text: $viewModel.searchQuery)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .onChange(of: viewModel.searchQuery) { _, newValue in
                                viewModel.runSearchIfEligible(query: newValue)
                            }
                            .submitLabel(.search)
                            .onSubmit {
                                viewModel.runSearchIfEligible(query: viewModel.searchQuery, force: true)
                            }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )

                    if viewModel.isSearching {
                        ProgressView("Searching…")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if viewModel.searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            if viewModel.eligibleWordCount(in: viewModel.searchQuery) < 2 {
                                Text("Type at least two words to search.")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No results found.")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(viewModel.searchResults) { item in
                                Button {
                                    viewModel.jumpToSearchResult(item)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(item.bookName) \(item.chapterNumber):\(item.verseNumber)")
                                            .font(.subheadline.weight(.semibold))
                                        Text("“\(item.verseText)”")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                if item.id != viewModel.searchResults.last?.id {
                                    Divider()
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .padding(16)
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { viewModel.isSearchPresented = false }
                }
            }
        }
    }
}

