import SwiftData
import SwiftUI

struct NoteDetailCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedScriptureReference: ScriptureRef?
    @State private var isShowingChapterInsights = false

    let item: NotesListItem?
    let editAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let item {
                NoteDetailHeader(
                    title: item.title,
                    subtitle: subtitle(for: item),
                    isFavorite: item.isFavorite,
                    shareText: item.shareText,
                    favoriteAction: { item.toggleFavorite(in: modelContext) },
                    openBibleAction: item.bibleLocation == nil ? nil : { item.openInBible() },
                    chapterInsightsAction: hasSourceChapter(item) ? { isShowingChapterInsights = true } : nil,
                    editAction: editAction
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        details(for: item)
                        Text(BibleReferenceLinker.linkify(NoteFormattedContent.decode(item.formattedContent, fallback: item.content)))
                            .font(.body)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        NoteTimestampView(createdAt: item.createdAt, updatedAt: item.updatedAt)
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView(
                    "Select a Note",
                    systemImage: "note.text",
                    description: Text("Choose a note from the card on the left to read it here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.openURL, OpenURLAction { url in
            guard let reference = BibleReferenceLinker.parse(url: url) else {
                return .systemAction(url)
            }
            selectedScriptureReference = reference
            return .handled
        })
        .sheet(item: $selectedScriptureReference) { reference in
            ScriptureReferencePreview(reference: reference)
        }
        .sheet(isPresented: $isShowingChapterInsights) {
            if case .user(let note) = item, note.hasSourceChapter {
                NavigationStack {
                    ChapterInsightsView(bookName: note.sourceBookName, chapterNumber: note.sourceChapterNumber)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { isShowingChapterInsights = false }
                            }
                        }
                }
            }
        }
    }

    /// The type, plus the passage for a personal note (a Scripture note shows its verses below).
    private func subtitle(for item: NotesListItem) -> String? {
        var parts: [String] = []
        if let category = item.category { parts.append(String(localized: category.title)) }
        if case .user(let note) = item, note.hasSourceChapter {
            parts.append("\(note.sourceBookName) \(note.sourceChapterNumber)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func hasSourceChapter(_ item: NotesListItem) -> Bool {
        if case .user(let note) = item { return note.hasSourceChapter }
        return false
    }

    @ViewBuilder
    private func details(for item: NotesListItem) -> some View {
        switch item {
        case .scripture(let note):
            ScriptureNoteQuotation(
                reference: note.reference,
                verseText: note.verseText,
                highlight: VerseHighlightColor(rawValue: note.highlightColor)
            )
        case .user(let note):
            let sermonLines = item.sermonDetailLines(for: note)
            if !sermonLines.isEmpty || !note.passageReference.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(sermonLines, id: \.self) { line in
                        Label(line, systemImage: line == sermonLines.first ? "person.wave.2" : "calendar")
                    }
                    if !note.passageReference.isEmpty {
                        // Linked so a tap previews the passage, like references in the note body.
                        Label {
                            Text(BibleReferenceLinker.linkify(note.passageReference))
                        } icon: {
                            Image(systemName: "book.closed")
                        }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct ScriptureNoteQuotation: View {
    let reference: String
    let verseText: String
    let highlight: VerseHighlightColor?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(reference, systemImage: "quote.opening")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            Text(verseText)
                .font(.title3)
                .italic()
                .lineSpacing(4)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background((highlight?.color ?? .accentColor).opacity(0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(highlight?.color ?? .accentColor)
                .frame(width: 5)
                .padding(.vertical, 12)
        }
    }
}

struct NoteDetailHeader: View {
    let title: String
    let subtitle: String?
    let isFavorite: Bool
    let shareText: String
    let favoriteAction: () -> Void
    let openBibleAction: (() -> Void)?
    var chapterInsightsAction: (() -> Void)?
    let editAction: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.bold())
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                if let openBibleAction {
                    Button(action: openBibleAction) {
                        Image(systemName: "book.closed")
                    }
                    .accessibilityLabel("Open in Bible")
                }

                if let chapterInsightsAction {
                    Button(action: chapterInsightsAction) {
                        Image(systemName: "text.book.closed")
                    }
                    .accessibilityLabel("Open Chapter Insights")
                }

                Button(action: favoriteAction) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                }
                .foregroundStyle(isFavorite ? .yellow : .primary)
                .accessibilityLabel(isFavorite ? "Remove favorite" : "Favorite")

                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share note")

                Button(action: editAction) {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit note")
            }
            .buttonStyle(.bordered)
        }
    }
}

struct NoteTimestampView: View {
    let createdAt: Date?
    let updatedAt: Date?

    var body: some View {
        if let displayDate {
            Group {
                if wasModified {
                    Text(
                        "Modified \(displayDate, format: .dateTime.month(.abbreviated).day().year().hour().minute())",
                        comment: "Timestamp beneath a saved Bible note."
                    )
                } else {
                    Text(
                        "Added \(displayDate, format: .dateTime.month(.abbreviated).day().year().hour().minute())",
                        comment: "Timestamp beneath a newly added Bible note."
                    )
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    private var wasModified: Bool {
        guard let createdAt, let updatedAt else { return false }
        return updatedAt.timeIntervalSince(createdAt) > 1
    }

    private var displayDate: Date? {
        wasModified ? updatedAt : (createdAt ?? updatedAt)
    }
}
