import SwiftUI

struct BooksView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator
    let books: [Book]
    @State private var searchText: String = ""
    // Shared preference across devices
    @AppStorage("bibleBooksSortAlphabetical") private var sortAlphabetically: Bool = false

    private var filteredBooks: [Book] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return books }
        return books.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var azBooks: [Book] {
        filteredBooks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        Group {
            if sortAlphabetically {
                // Single A–Z section
                List {
                    Section {
                        ForEach(azBooks) { book in
                            Button { coordinator.push(.book(book)) } label: {
                                HStack {
                                    Text(book.name)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.primary)
                        }
                    } header: {
                        Text("All Books (\(azBooks.count))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                // Canonical OT/NT grouping
                let canon = BibleData.books
                let indexMap = Dictionary(uniqueKeysWithValues: canon.enumerated().map { ($1.name, $0) })
                let matthewIndex = indexMap["Matthew"] ?? Int.max
                let otBooks = filteredBooks.filter { (indexMap[$0.name] ?? Int.max) < matthewIndex }
                let ntBooks = filteredBooks.filter { (indexMap[$0.name] ?? Int.max) >= matthewIndex }

                List {
                    if !otBooks.isEmpty {
                        Section {
                            ForEach(otBooks) { book in
                                Button { coordinator.push(.book(book)) } label: {
                                    HStack {
                                        Text(book.name)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.primary)
                            }
                        } header: {
                            Text("Old Testament (\(otBooks.count))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !ntBooks.isEmpty {
                        Section {
                            ForEach(ntBooks) { book in
                                Button { coordinator.push(.book(book)) } label: {
                                    HStack {
                                        Text(book.name)
                                        Spacer()
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.primary)
                            }
                        } header: {
                            Text("New Testament (\(ntBooks.count))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Books")
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search books")
        .tint(.blue)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        sortAlphabetically = false
                    } label: {
                        Label("Canonical", systemImage: "list.number")
                    }
                    .disabled(!sortAlphabetically)

                    Button {
                        sortAlphabetically = true
                    } label: {
                        Label("A–Z", systemImage: "textformat.abc")
                    }
                    .disabled(sortAlphabetically)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort")
                .accessibilityHint("Choose canonical or alphabetical order")
            }
        }
    }
}

#Preview {
    NavigationStack {
        BooksView(books: BibleData.books)
            .environmentObject(NavigationCoordinator())
    }
}
