import SwiftData
import SwiftUI

struct NoteDetailCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedScriptureReference: ScriptureRef?

    let scriptureNote: VerseNote?
    let userNote: UserNote?
    let editAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let scriptureNote {
                NoteDetailHeader(
                    title: scriptureNote.title.isEmpty ? "Scripture Note" : scriptureNote.title,
                    subtitle: "\(scriptureNote.bookName) \(scriptureNote.chapterNumber):\(scriptureNote.verseNumber)",
                    isFavorite: scriptureNote.isFavorite,
                    shareText: NotesListItem.scripture(scriptureNote).shareText,
                    favoriteAction: { toggleFavorite(scriptureNote) },
                    openBibleAction: { NotesListItem.scripture(scriptureNote).openInBible() },
                    editAction: editAction
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ScriptureNoteQuotation(
                            reference: "\(scriptureNote.bookName) \(scriptureNote.chapterNumber):\(scriptureNote.verseNumber)",
                            verseText: scriptureNote.verseText,
                            highlight: VerseHighlightColor(rawValue: scriptureNote.highlightColor)
                        )
                        Text(formattedContent(data: scriptureNote.formattedContent, fallback: scriptureNote.content))
                            .font(.body)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        NoteTimestampView(createdAt: scriptureNote.createdAt, updatedAt: scriptureNote.updatedAt)
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let userNote {
                NoteDetailHeader(
                    title: userNote.title.isEmpty ? "Untitled Note" : userNote.title,
                    subtitle: nil,
                    isFavorite: userNote.isFavorite,
                    shareText: NotesListItem.user(userNote).shareText,
                    favoriteAction: { toggleFavorite(userNote) },
                    openBibleAction: nil,
                    editAction: editAction
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(formattedContent(data: userNote.formattedContent, fallback: userNote.content))
                            .font(.body)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        NoteTimestampView(createdAt: userNote.createdAt, updatedAt: userNote.updatedAt)
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
    }

    private func formattedContent(data: Data?, fallback: String) -> AttributedString {
        BibleReferenceLinker.linkify(NoteFormattedContent.decode(data, fallback: fallback))
    }

    private func toggleFavorite(_ note: VerseNote) {
        note.isFavorite.toggle()
        modelContext.saveLoggingErrors()
        Haptics.selection()
    }

    private func toggleFavorite(_ note: UserNote) {
        note.isFavorite.toggle()
        modelContext.saveLoggingErrors()
        Haptics.selection()
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
