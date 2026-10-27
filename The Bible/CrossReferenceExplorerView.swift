import SwiftUI
import SwiftData

/// An entry point from the Study screen into the global connection index.
struct CrossReferenceExplorerEntryCard: View {
    var body: some View {
        NavigationLink {
            CrossReferenceExplorerView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Cross-Reference Explorer")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Browse curated connections across Scripture")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(AppDesignMetrics.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .heroCardSurface()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the searchable index of curated Scripture connections")
    }
}

/// A searchable index of editorially curated connections across Scripture.
struct CrossReferenceExplorerView: View {
    @Query(sort: \SavedCrossReference.savedAt, order: .reverse) private var savedConnections: [SavedCrossReference]

    @State private var entries: [CrossReferenceExplorerEntry] = []
    @State private var sections: [CrossReferenceExplorerSection] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var searchScope: CrossReferenceSearchScope = .both
    @State private var selectedSourceBook: String?
    @State private var selectedConnectionType: CrossReferenceConnectionType?
    @State private var isShowingSavedOnly = false
    @State private var selectedEntry: CrossReferenceExplorerEntry?

    private var resultCount: Int {
        sections.reduce(into: 0) { $0 += $1.entries.count }
    }

    private var sourceBookNames: [String] {
        let availableBooks = Set(entries.map(\.bookName))
        return BibleCanon.canonicalOrder().filter(availableBooks.contains)
    }

    private var savedEntryIDs: Set<Int> {
        Set(savedConnections.map(\.entryID))
    }

    private var hasActiveFilters: Bool {
        selectedSourceBook != nil || selectedConnectionType != nil || isShowingSavedOnly || searchScope != .both
    }

    var body: some View {
        List {
            CrossReferenceExplorerIntroduction()

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView("Loading curated connections…")
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if sections.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.entries) { entry in
                        Button {
                            selectedEntry = entry
                        } label: {
                            CrossReferenceExplorerRow(
                                entry: entry,
                                isSaved: savedEntryIDs.contains(entry.id)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the side-by-side Scripture preview")
                        }
                    } header: {
                        Text("\(section.bookName) · \(section.entries.count) connections")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Cross References")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search Genesis 1:1, John 3:16, or a topic")
        .searchScopes($searchScope) {
            ForEach(CrossReferenceSearchScope.allCases) { scope in
                Text(scope.title).tag(scope)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Picker("Source Book", selection: $selectedSourceBook) {
                        Text("All Books").tag(String?.none)
                        ForEach(sourceBookNames, id: \.self) { bookName in
                            Text(bookName).tag(Optional(bookName))
                        }
                    }

                    Picker("Connection Type", selection: $selectedConnectionType) {
                        Text("All Types").tag(CrossReferenceConnectionType?.none)
                        ForEach(CrossReferenceConnectionType.allCases) { type in
                            Label(type.title, systemImage: type.systemImage)
                                .tag(Optional(type))
                        }
                    }

                    Toggle("Saved Only", isOn: $isShowingSavedOnly)
                } label: {
                    Label(
                        "Filter connections",
                        systemImage: hasActiveFilters
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                    )
                }
            }

            if hasActiveFilters {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: clearFilters) {
                        Label("Clear Filters", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
        .task {
            let loadedEntries = await ChapterInsightsRepository.shared.allCrossReferences()
            entries = ChapterCrossReferenceDeduplicator.deduplicated(loadedEntries)
            recomputeSections()
            isLoading = false
        }
        .onChange(of: searchText) { _, _ in recomputeSections() }
        .onChange(of: searchScope) { _, _ in recomputeSections() }
        .onChange(of: selectedSourceBook) { _, _ in recomputeSections() }
        .onChange(of: selectedConnectionType) { _, _ in recomputeSections() }
        .onChange(of: isShowingSavedOnly) { _, _ in recomputeSections() }
        .onChange(of: savedConnections.map(\.entryID)) { _, _ in recomputeSections() }
        .sheet(item: $selectedEntry) { entry in
            CrossReferencePreviewSheet(entry: entry)
                .presentationDetents([.medium, .large])
                .presentationContentInteraction(.scrolls)
        }
    }

    private func recomputeSections() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredEntries = entries.filter { entry in
            guard selectedSourceBook == nil || entry.bookName == selectedSourceBook else {
                return false
            }
            guard selectedConnectionType == nil || entry.connectionType == selectedConnectionType else {
                return false
            }
            guard !isShowingSavedOnly || savedEntryIDs.contains(entry.id) else {
                return false
            }
            guard !query.isEmpty else { return true }

            let matchesSource = entry.sourceReference.localizedCaseInsensitiveContains(query)
            let matchesRelated = entry.relatedReference.localizedCaseInsensitiveContains(query)
            let matchesExplanation = entry.connectionExplanation?.localizedCaseInsensitiveContains(query) == true

            switch searchScope {
            case .source:
                return matchesSource
            case .related:
                return matchesRelated
            case .both:
                return matchesSource || matchesRelated || matchesExplanation
            }
        }

        let bookOrder = Dictionary(
            uniqueKeysWithValues: BibleCanon.canonicalOrder().enumerated().map { ($0.element, $0.offset) }
        )
        sections = Dictionary(grouping: filteredEntries, by: \.bookName)
            .map { bookName, entries in
                CrossReferenceExplorerSection(
                    bookName: bookName,
                    entries: entries.sorted {
                        ($0.chapterNumber, $0.sourceVerse, $0.id) < ($1.chapterNumber, $1.sourceVerse, $1.id)
                    }
                )
            }
            .sorted {
                (bookOrder[$0.bookName] ?? .max, $0.bookName) < (bookOrder[$1.bookName] ?? .max, $1.bookName)
            }
    }

    private func clearFilters() {
        selectedSourceBook = nil
        selectedConnectionType = nil
        isShowingSavedOnly = false
        searchScope = .both
    }
}

private enum CrossReferenceSearchScope: String, CaseIterable, Identifiable {
    case both
    case source
    case related

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .both: "All Fields"
        case .source: "Source Passage"
        case .related: "Related Passage"
        }
    }
}

private struct CrossReferenceExplorerSection: Identifiable {
    let bookName: String
    let entries: [CrossReferenceExplorerEntry]

    var id: String { bookName }
}

private struct CrossReferencePreviewSheet: View {
    let entry: CrossReferenceExplorerEntry

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var savedConnections: [SavedCrossReference]
    @State private var preview: CrossReferencePreview?
    @State private var notePrefill: UserNotePrefill?

    private var savedConnection: SavedCrossReference? {
        savedConnections.first { $0.entryID == entry.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let preview {
                        CrossReferencePassagesPreview(
                            source: preview.source,
                            target: preview.target
                        )

                        if let explanation = preview.explanation {
                            CrossReferenceExplanationPreview(text: explanation)
                        }

                        if let savedConnection {
                            SavedCrossReferenceTakeaway(savedConnection: savedConnection)
                        }
                    } else {
                        ProgressView("Loading passages…")
                            .frame(maxWidth: .infinity, minHeight: 180)
                    }
                }
                .padding()
            }
            .navigationTitle("Scripture Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if let preview {
                        Button {
                            notePrefill = makeNotePrefill(preview: preview)
                        } label: {
                            Label("Create Note", systemImage: "square.and.pencil")
                        }
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    if let savedConnection {
                        Button {
                            modelContext.delete(savedConnection)
                        } label: {
                            Label("Remove from Saved", systemImage: "bookmark.slash")
                        }
                    } else {
                        Button {
                            modelContext.insert(SavedCrossReference(entryID: entry.id))
                        } label: {
                            Label("Save Connection", systemImage: "bookmark")
                        }
                    }
                }
            }
            .task {
                preview = await CrossReferencePreviewLoader.load(entry: entry)
            }
        }
        .sheet(item: $notePrefill) { prefill in
            NavigationStack {
                UserNoteEditorView(existingNote: nil, prefill: prefill)
            }
        }
    }

    private func makeNotePrefill(preview: CrossReferencePreview) -> UserNotePrefill {
        let source = preview.source.reference.displayTitle
        let target = preview.target.reference.displayTitle
        let connection = "\(source) → \(target)"
        let relationship = preview.explanation ?? "These passages are presented together as a curated Scripture connection."

        return UserNotePrefill(
            id: "cross-reference-note-\(entry.id)",
            title: "Scripture Connection",
            body: "\(connection)\n\nRelationship\n\(relationship)\n\nMy thoughts:\n",
            passageReference: source
        )
    }
}

private struct CrossReferencePassagesPreview: View {
    let source: CrossReferencePreview.Passage
    let target: CrossReferencePreview.Passage

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 16) {
                CrossReferencePassagePreview(passage: source)
                CrossReferencePassagePreview(passage: target)
            }

            VStack(alignment: .leading, spacing: 16) {
                CrossReferencePassagePreview(passage: source)

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                    Image(systemName: "arrow.up")
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity)

                CrossReferencePassagePreview(passage: target)
            }
        }
    }
}

private struct CrossReferencePassagePreview: View {
    let passage: CrossReferencePreview.Passage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(passage.reference.displayTitle)
                .font(.headline)
                .foregroundStyle(.tint)

            Text("“\(passage.text)”")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .heroCardSurface()
    }
}

private struct CrossReferenceExplanationPreview: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Relationship")
                .font(.subheadline.weight(.semibold))

            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CrossReferencePreview {
    struct Passage {
        let reference: PassageReference
        let text: String
    }

    let source: Passage
    let target: Passage
    let explanation: String?
}

@MainActor
private enum CrossReferencePreviewLoader {
    static func load(entry: CrossReferenceExplorerEntry) async -> CrossReferencePreview? {
        let sourceReference = PassageReference(
            bookName: entry.bookName,
            startChapter: entry.chapterNumber,
            startVerse: entry.sourceVerse,
            endChapter: entry.chapterNumber,
            endVerse: entry.sourceVerse
        )
        guard let targetReference = PassageReferenceParser.parseList(
            entry.relatedReference,
            book: entry.bookName,
            chapter: entry.chapterNumber
        ).first else {
            return nil
        }

        let books = await BibleRepository.shared.loadAllBooks()
        return CrossReferencePreview(
            source: .init(
                reference: sourceReference,
                text: passageText(for: sourceReference, in: books)
            ),
            target: .init(
                reference: targetReference,
                text: passageText(for: targetReference, in: books)
            ),
            explanation: entry.relationshipDescription
        )
    }

    /// Returns the complete requested passage so the sheet can grow and scroll for longer references.
    private static func passageText(for reference: PassageReference, in books: [Book]) -> String {
        guard let book = books.first(where: { $0.name == reference.bookName }) else {
            return "Passage unavailable."
        }

        let verses = book.chapters
            .filter { $0.number >= reference.startChapter && $0.number <= reference.endChapter }
            .flatMap { chapter in
                chapter.verses.filter { verse in
                    guard let startVerse = reference.startVerse else { return true }
                    if chapter.number == reference.startChapter, verse.number < startVerse { return false }
                    if let endVerse = reference.endVerse,
                       chapter.number == reference.endChapter,
                       verse.number > endVerse {
                        return false
                    }
                    return true
                }
            }

        let text = verses
            .map { "\($0.number) \($0.text)" }
            .joined(separator: " ")
        guard !text.isEmpty else { return "Passage unavailable." }
        return text
    }
}

private struct CrossReferenceExplorerIntroduction: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Curated Scripture Connections", systemImage: "arrow.triangle.branch")
                .font(.headline)

            Text("Explore editorially selected passages that illuminate one another. Filter by connection type, save connections to revisit, and select one to see its context and explanation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .listRowSeparator(.hidden)
    }
}

private struct CrossReferenceExplorerRow: View {
    let entry: CrossReferenceExplorerEntry
    let isSaved: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.sourceReference)
                    .font(.subheadline.weight(.semibold))

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)

                Text(entry.relatedReference)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)

            Text(entry.relationshipDescription)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Label(entry.connectionType.title, systemImage: entry.connectionType.systemImage)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tint)

                if isSaved {
                    Image(systemName: "bookmark.fill")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Saved connection")
                }
            }
        }
        .padding(.vertical, 3)
    }
}

private struct SavedCrossReferenceTakeaway: View {
    @Bindable var savedConnection: SavedCrossReference

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("My Takeaway", systemImage: "bookmark.fill")
                .font(.subheadline.weight(.semibold))

            TextField("Add a personal takeaway", text: $savedConnection.takeaway, axis: .vertical)
                .lineLimit(2...5)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
