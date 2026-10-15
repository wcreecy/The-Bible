import SwiftData
import SwiftUI

/// Adds or edits the note and highlight attached to a verse.
@MainActor
struct VerseNoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false

    let verse: VerseActionReference
    let existingNote: VerseNote?
    let preservesHighlightWhenRemovingNote: Bool

    @State private var title: String
    @State private var noteText: AttributedString
    @State private var noteSelection = AttributedTextSelection()
    @State private var selectedColor: VerseHighlightColor?
    @State private var selectedCategory: NoteCategory
    @State private var persistenceFailure: PersistenceFailure?

    init(
        verse: VerseActionReference,
        existingNote: VerseNote?,
        preservesHighlightWhenRemovingNote: Bool = false
    ) {
        self.verse = verse
        self.existingNote = existingNote
        self.preservesHighlightWhenRemovingNote = preservesHighlightWhenRemovingNote
        _title = State(initialValue: existingNote?.title ?? "")
        _noteText = State(initialValue: NoteFormattedContent.decode(
            existingNote?.formattedContent,
            fallback: existingNote?.content ?? ""
        ))
        _selectedColor = State(
            initialValue: existingNote.flatMap { VerseHighlightColor(rawValue: $0.highlightColor) }
        )
        _selectedCategory = State(
            initialValue: existingNote.flatMap { NoteCategory(rawValue: $0.categoryRawValue) } ?? .scripture
        )
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 14) {
                NoteEditorTitleField(title: $title, placeholder: "Scripture note title")

                if contextualTipsEnabled {
                    ScriptureReferenceLinkTip()
                    CustomNoteTagsTip()
                }

                ScriptureEditorReferenceCard(
                    reference: "\(verse.bookName) \(verse.chapterNumber):\(verse.verseNumber)",
                    verseText: verse.verseText
                )

                VerseNoteOptionsBar(
                    category: $selectedCategory,
                    highlight: $selectedColor
                )

                NoteBodyTextEditor(text: $noteText, selection: $noteSelection)
            }
            .frame(
                width: max(0, proxy.size.width - (editorHorizontalPadding * 2)),
                height: proxy.size.height
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical)
        .background(AppBackgroundView(tab: .notes))
        .richNoteEditing(
            text: $noteText,
            selection: $noteSelection,
            formattingBarPadding: editorHorizontalPadding
        )
        .navigationTitle(editorTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(existingNote == nil && trimmedNote.isEmpty && selectedColor == nil)
            }
            if existingNote != nil {
                ToolbarItem(placement: .secondaryAction) {
                    Button(
                        preservesHighlightWhenRemovingNote ? "Remove Note" : "Remove Note & Highlight",
                        systemImage: "trash",
                        role: .destructive,
                        action: deleteEntry
                    )
                }
            }
        }
        .persistenceFailureAlert(failure: $persistenceFailure)
    }

    private var trimmedNote: String {
        String(noteText.characters).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var editorTitle: LocalizedStringResource {
        if preservesHighlightWhenRemovingNote {
            "Edit Scripture Note"
        } else {
            existingNote == nil ? "Add Note & Highlight" : "Edit Note & Highlight"
        }
    }

    private var editorHorizontalPadding: CGFloat {
        horizontalSizeClass == .compact ? 24 : 16
    }

    private func save() {
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                if let existingNote, trimmedNote.isEmpty, selectedColor == nil {
                    modelContext.delete(existingNote)
                    try modelContext.save()
                    return
                }

                let note = existingNote ?? VerseNote(
                    bookName: verse.bookName,
                    chapterNumber: verse.chapterNumber,
                    verseNumber: verse.verseNumber,
                    verseText: verse.verseText
                )
                note.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                note.content = trimmedNote
                note.formattedContent = try JSONEncoder().encode(noteText)
                note.highlightColor = selectedColor?.rawValue ?? ""
                note.categoryRawValue = selectedCategory.rawValue
                note.updatedAt = Date()
                if existingNote == nil {
                    modelContext.insert(note)
                }
                try modelContext.save()
            },
            onSuccess: {
                Haptics.success()
                dismiss()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }

    private func deleteEntry() {
        guard let existingNote else { return }
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                if preservesHighlightWhenRemovingNote, !existingNote.highlightColor.isEmpty {
                    existingNote.title = ""
                    existingNote.content = ""
                    existingNote.formattedContent = nil
                    existingNote.updatedAt = Date()
                } else {
                    modelContext.delete(existingNote)
                }
                try modelContext.save()
            },
            onSuccess: {
                Haptics.selection()
                dismiss()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }
}

private struct ScriptureEditorReferenceCard: View {
    let reference: String
    let verseText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(reference, systemImage: "book.closed.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            Text(verseText)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct VerseNoteOptionsBar: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Binding var category: NoteCategory
    @Binding var highlight: VerseHighlightColor?

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                VStack(alignment: .leading, spacing: 8) {
                    NoteCategoryMenu(category: $category)
                    Divider()
                    ScriptureHighlightPicker(selection: $highlight)
                }
            } else {
                HStack(spacing: 12) {
                    NoteCategoryMenu(category: $category)
                    Divider().frame(height: 28)
                    ScriptureHighlightPicker(selection: $highlight)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

}

private struct ScriptureHighlightPicker: View {
    @Binding var selection: VerseHighlightColor?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Scripture Highlight", systemImage: "highlighter")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HighlightColorPicker(selection: $selection)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
