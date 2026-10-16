import SwiftData
import SwiftUI

/// The highlighted verses in Saved Verses, filtered by color and search and grouped like
/// Favorites: one group by recency, or one per book in Bible order.
@MainActor
struct HighlightsLibrary {
    struct Section: Identifiable {
        let title: String?
        let highlights: [VerseNote]
        var id: String { title ?? "all" }
    }

    /// Every highlighted verse, before filtering.
    let totalCount: Int
    let sections: [Section]

    init(
        notes: [VerseNote],
        color: VerseHighlightColor?,
        searchText: String,
        sort: FavoritesView.SortOrder,
        bookNames: [String]
    ) {
        let highlighted = notes.filter { !$0.highlightColor.isEmpty }
        totalCount = highlighted.count

        let query = SavedVerseSearchQuery(searchText, bookNames: bookNames)
        let matching = highlighted.filter { note in
            (color.map { note.highlightColor == $0.rawValue } ?? true) &&
                (query?.matches(
                    bookName: note.bookName,
                    chapter: note.chapterNumber,
                    verses: note.verseNumber...note.lastVerseNumber,
                    texts: [note.verseText, note.title, note.content]
                ) ?? true)
        }
        guard !matching.isEmpty else {
            sections = []
            return
        }

        switch sort {
        case .recent:
            let sorted = matching.sorted { Self.date(of: $0) > Self.date(of: $1) }
            sections = [Section(title: nil, highlights: sorted)]
        case .bibleOrder:
            let bookIndex = Dictionary(bookNames.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            let sorted = matching.sorted {
                (bookIndex[$0.bookName] ?? .max, $0.chapterNumber, $0.verseNumber)
                    < (bookIndex[$1.bookName] ?? .max, $1.chapterNumber, $1.verseNumber)
            }
            var grouped: [Section] = []
            for note in sorted {
                if let last = grouped.last, last.title == note.bookName {
                    grouped[grouped.count - 1] = Section(title: last.title, highlights: last.highlights + [note])
                } else {
                    grouped.append(Section(title: note.bookName, highlights: [note]))
                }
            }
            sections = grouped
        }
    }

    /// When the highlight was last changed, which is when its note or color was saved.
    static func date(of note: VerseNote) -> Date {
        note.updatedAt ?? note.createdAt ?? .distantPast
    }
}

/// Saved Verses' Highlights: every verse highlighted in the reader, with its color and any
/// note written about it.
struct SavedHighlightsView: View {
    @Environment(\.modelContext) private var modelContext

    let notes: [VerseNote]
    let searchText: String
    let sortOrder: FavoritesView.SortOrder
    let bookNames: [String]

    @State private var colorFilter: VerseHighlightColor?
    @State private var openNote: VerseNote?
    @State private var editingNote: VerseNote?
    @State private var removedHighlight: RemovedHighlight?
    @State private var isShowingRemovalToast = false

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let library = HighlightsLibrary(
            notes: notes,
            color: colorFilter,
            searchText: searchText,
            sort: sortOrder,
            bookNames: bookNames
        )

        Group {
            if library.totalCount == 0 {
                ContentUnavailableView(
                    "No Highlights",
                    systemImage: "highlighter",
                    description: Text("Press and hold a verse in the Bible and choose a color to highlight it.")
                )
            } else {
                List {
                    Section {
                        colorFilterRow
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                    if library.sections.isEmpty {
                        ContentUnavailableView(
                            isSearching ? "No Matches" : "No Highlights in This Color",
                            systemImage: isSearching ? "magnifyingglass" : "highlighter",
                            description: Text(isSearching ? "Try a reference like “John 3” or words from the verse or your note." : "Choose another color, or All.")
                        )
                        .listRowBackground(Color.clear)
                    }

                    ForEach(library.sections) { section in
                        Section {
                            ForEach(section.highlights) { note in
                                row(for: note)
                            }
                            .listRowBackground(HeroCardListRowBackground())
                        } header: {
                            if let title = section.title {
                                Text(title)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .sheet(item: $openNote) { note in
            HighlightDetailSheet(note: note) {
                openNote = nil
                // Open the editor once the sheet has gone, so the two don't overlap.
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(350))
                    editingNote = note
                }
            }
        }
        .fullScreenCover(item: $editingNote) { note in
            NavigationStack {
                NoteEditorView(item: .scripture(note))
            }
        }
        .appToast(
            isPresented: $isShowingRemovalToast,
            symbol: "highlighter",
            text: String(localized: "Highlight removed"),
            tint: .secondary,
            actionTitle: String(localized: "Undo"),
            action: undoRemoval
        )
    }

    // MARK: - Color filter

    private var colorFilterRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                FilterChip(isSelected: colorFilter == nil) {
                    withAnimation(.snappy) { colorFilter = nil }
                } label: {
                    Text("All")
                }

                ForEach(VerseHighlightColor.allCases, id: \.self) { color in
                    FilterChip(isSelected: colorFilter == color) {
                        withAnimation(.snappy) { colorFilter = colorFilter == color ? nil : color }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(color.color)
                                .frame(width: 12, height: 12)
                                .overlay { Circle().strokeBorder(.primary.opacity(0.15)) }
                            Text(color.name)
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .accessibilityLabel("Highlight color")
    }

    // MARK: - Row

    private func row(for note: VerseNote) -> some View {
        let color = VerseHighlightColor(rawValue: note.highlightColor)
        let item = NotesListItem.scripture(note)
        return Button {
            openNote = note
        } label: {
            HStack(spacing: 12) {
                Capsule()
                    .fill(color?.color ?? .secondary)
                    .frame(width: 4)
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(note.reference)
                        .font(.headline)
                    Text(note.verseText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                    if item.hasNoteText {
                        Label {
                            Text(note.title.isEmpty ? item.preview : note.title)
                                .lineLimit(2)
                        } icon: {
                            Image(systemName: "note.text")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    }
                    Text("Highlighted \(HighlightsLibrary.date(of: note).formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(color.map { "\(String(localized: $0.name)) highlight" } ?? ""))
        .accessibilityHint(item.hasNoteText ? "Opens the verse and your note" : "Opens the verse")
        .contextMenu {
            Button("Open in Bible", systemImage: "book") { item.openInBible() }
            Button(item.hasNoteText ? "Edit Note" : "Add Note", systemImage: "square.and.pencil") {
                editingNote = note
            }
            Menu {
                ForEach(VerseHighlightColor.allCases, id: \.self) { option in
                    Button {
                        setColor(option, of: note)
                    } label: {
                        if option == color {
                            Label { Text(option.name) } icon: { Image(systemName: "checkmark") }
                        } else {
                            Text(option.name)
                        }
                    }
                }
            } label: {
                Label("Change Color", systemImage: "paintpalette")
            }
            ShareLink(item: item.shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Divider()
            Button("Remove Highlight", systemImage: "highlighter", role: .destructive) { removeHighlight(note) }
        }
        .swipeActions(edge: .leading) {
            ShareLink(item: item.shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing) {
            Button("Remove", systemImage: "highlighter", role: .destructive) { removeHighlight(note) }
        }
    }

    // MARK: - Actions

    private func setColor(_ color: VerseHighlightColor, of note: VerseNote) {
        guard note.highlightColor != color.rawValue else { return }
        note.highlightColor = color.rawValue
        note.updatedAt = Date()
        modelContext.saveLoggingErrors()
        Haptics.selection()
    }

    /// A verse with a note keeps its note, which stays in Notes; a highlight alone is removed.
    private func removeHighlight(_ note: VerseNote) {
        if NotesListItem.scripture(note).hasNoteText {
            removedHighlight = .color(note, note.highlightColor)
            note.highlightColor = ""
        } else {
            removedHighlight = .entry(VerseNoteSnapshot(note: note))
            modelContext.delete(note)
        }
        modelContext.saveLoggingErrors()
        Haptics.selection()
        isShowingRemovalToast = true
    }

    private func undoRemoval() {
        switch removedHighlight {
        case .color(let note, let color):
            note.highlightColor = color
        case .entry(let snapshot):
            modelContext.insert(snapshot.makeNote())
        case nil:
            return
        }
        modelContext.saveLoggingErrors()
        removedHighlight = nil
        Haptics.success()
    }
}

private enum RemovedHighlight {
    /// The note was kept and only its color cleared.
    case color(VerseNote, String)
    /// A highlight with no note, removed entirely.
    case entry(VerseNoteSnapshot)
}

/// A highlighted verse opened from Saved Verses: the verse, its color, and the note
/// written about it, with a way to add one.
private struct HighlightDetailSheet: View {
    @Environment(\.dismiss) private var dismiss

    let note: VerseNote
    let editAction: () -> Void

    var body: some View {
        NavigationStack {
            NoteDetailCard(item: .scripture(note), editAction: editAction)
                .padding()
                .background(AppBackgroundView(tab: .more))
                .navigationTitle("Highlight")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
