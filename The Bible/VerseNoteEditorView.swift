import SwiftData
import SwiftUI

/// Adds or edits the note and highlight attached to a verse or a run of verses.
@MainActor
struct VerseNoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false

    let existingNote: VerseNote?
    let preservesHighlightWhenRemovingNote: Bool
    /// The first verse of the note: an existing note's start, or the verse it's being added to.
    private let start: VerseActionReference

    @State private var title: String
    @State private var noteText: AttributedString
    @State private var noteSelection = AttributedTextSelection()
    @State private var selectedColor: VerseHighlightColor?
    @State private var endVerse: Int
    @State private var formattingChanged = false
    @State private var restoredDraftDate: Date?
    @State private var isEditingBody = false
    @State private var isOnScreenKeyboardShown = false
    /// Hides everything above the body while typing with the on-screen keyboard, so it
    /// doesn't squeeze the body.
    @State private var areFieldsCollapsed = false
    @State private var persistenceFailure: PersistenceFailure?

    private let saved: NoteDraft
    private let draftKey: String

    init(
        verse: VerseActionReference,
        existingNote: VerseNote?,
        preservesHighlightWhenRemovingNote: Bool = false
    ) {
        self.existingNote = existingNote
        self.preservesHighlightWhenRemovingNote = preservesHighlightWhenRemovingNote
        start = existingNote.map {
            VerseActionReference(
                bookName: $0.bookName,
                chapterNumber: $0.chapterNumber,
                verseNumber: $0.verseNumber,
                verseText: VerseRangeText.text(book: $0.bookName, chapter: $0.chapterNumber, from: $0.verseNumber, through: $0.verseNumber)
                    ?? $0.verseText
            )
        } ?? verse

        let saved = NoteDraft(
            title: existingNote?.title ?? "",
            body: existingNote?.formattedContent ?? (try? JSONEncoder().encode(AttributedString(existingNote?.content ?? ""))) ?? Data(),
            category: NoteCategory.scripture.rawValue,
            highlightColor: existingNote?.highlightColor ?? "",
            endVerseNumber: existingNote?.lastVerseNumber ?? verse.verseNumber
        )
        self.saved = saved
        draftKey = NoteDraftStore.key(forVerse: start.bookName, chapter: start.chapterNumber, verse: start.verseNumber)

        let draft = NoteDraftStore.load(draftKey)
        let initial = draft ?? saved
        _restoredDraftDate = State(initialValue: draft?.savedAt)
        _title = State(initialValue: initial.title)
        _noteText = State(initialValue: draft?.bodyText ?? NoteFormattedContent.decode(
            existingNote?.formattedContent,
            fallback: existingNote?.content ?? ""
        ))
        _selectedColor = State(initialValue: VerseHighlightColor(rawValue: initial.highlightColor))
        _endVerse = State(initialValue: max(initial.endVerseNumber, start.verseNumber))
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 14) {
                if areFieldsCollapsed {
                    NoteEditorShowFieldsButton { areFieldsCollapsed = false }
                } else {
                    Group {
                        VerseNoteOptionsBar(highlight: $selectedColor)

                        ScriptureEditorReferenceCard(
                            reference: reference,
                            verseText: rangeText,
                            startVerse: start.verseNumber,
                            lastVerseInChapter: lastVerseInChapter,
                            endVerse: $endVerse
                        )

                        if contextualTipsEnabled {
                            ScriptureReferenceLinkTip()
                            CustomNoteTagsTip()
                        }

                        NoteEditorTitleField(title: $title, placeholder: "Scripture note title")
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                NoteBodyTextEditor(text: $noteText, selection: $noteSelection, isFocused: $isEditingBody)
            }
            .animation(.snappy, value: areFieldsCollapsed)
            .frame(
                width: max(0, proxy.size.width - (editorHorizontalPadding * 2)),
                height: proxy.size.height
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical)
        .onScreenKeyboardVisibility($isOnScreenKeyboardShown)
        .onChange(of: isEditingBody && isOnScreenKeyboardShown) { _, collapse in
            // Typing collapses everything above the body; leaving the body or putting the
            // keyboard away brings it back.
            areFieldsCollapsed = collapse
        }
        .background(AppBackgroundView(tab: .notes))
        .richNoteEditing(
            text: $noteText,
            selection: $noteSelection,
            formattingBarPadding: editorHorizontalPadding,
            onFormattingChange: { formattingChanged = true }
        )
        .navigationTitle(editorTitle)
        .navigationBarTitleDisplayMode(.inline)
        .noteEditorShell(
            hasChanges: hasChanges,
            canSave: existingNote != nil || !trimmedNote.isEmpty || selectedColor != nil,
            draftKey: draftKey,
            draft: currentDraft,
            restoredDraftDate: $restoredDraftDate,
            discardRestoredDraft: resetToSaved,
            deleteTitle: existingNote == nil ? nil : deleteTitle,
            deleteMessage: deleteMessage,
            save: save,
            delete: deleteEntry
        )
        .persistenceFailureAlert(failure: $persistenceFailure)
    }

    // MARK: State

    private var trimmedNote: String {
        String(noteText.characters).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var reference: String {
        let first = "\(start.bookName) \(start.chapterNumber):\(start.verseNumber)"
        return endVerse > start.verseNumber ? "\(first)–\(endVerse)" : first
    }

    private var rangeText: String {
        VerseRangeText.text(book: start.bookName, chapter: start.chapterNumber, from: start.verseNumber, through: endVerse)
            ?? start.verseText
    }

    private var lastVerseInChapter: Int {
        VerseRangeText.verseCount(book: start.bookName, chapter: start.chapterNumber) ?? start.verseNumber
    }

    private var hasChanges: Bool {
        formattingChanged ||
            title != saved.title ||
            String(noteText.characters) != String(saved.bodyText.characters) ||
            (selectedColor?.rawValue ?? "") != saved.highlightColor ||
            endVerse != saved.endVerseNumber
    }

    private func currentDraft() -> NoteDraft {
        NoteDraft(
            title: title,
            body: (try? JSONEncoder().encode(noteText)) ?? Data(),
            category: NoteCategory.scripture.rawValue,
            highlightColor: selectedColor?.rawValue ?? "",
            endVerseNumber: endVerse
        )
    }

    private func resetToSaved() {
        title = saved.title
        noteText = saved.bodyText
        selectedColor = VerseHighlightColor(rawValue: saved.highlightColor)
        endVerse = max(saved.endVerseNumber, start.verseNumber)
        formattingChanged = false
    }

    private var editorTitle: LocalizedStringResource {
        if preservesHighlightWhenRemovingNote {
            "Edit Scripture Note"
        } else {
            existingNote == nil ? "Add Note & Highlight" : "Edit Note & Highlight"
        }
    }

    private var keepsHighlightOnDelete: Bool {
        preservesHighlightWhenRemovingNote && !(existingNote?.highlightColor.isEmpty ?? true)
    }

    private var deleteTitle: LocalizedStringResource {
        keepsHighlightOnDelete ? "Remove Note" : "Remove Note & Highlight"
    }

    private var deleteMessage: LocalizedStringResource {
        keepsHighlightOnDelete
            ? "The written note will be removed. The verse highlight stays."
            : "The note and its highlight will be removed from all your devices."
    }

    private var editorHorizontalPadding: CGFloat {
        horizontalSizeClass == .compact ? 24 : 16
    }

    // MARK: Saving

    private func save() {
        let addsHighlight = selectedColor != nil && (existingNote?.highlightColor.isEmpty ?? true)

        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                if let existingNote, trimmedNote.isEmpty, selectedColor == nil {
                    modelContext.delete(existingNote)
                    try modelContext.save()
                    return
                }

                let note = existingNote ?? VerseNote(
                    bookName: start.bookName,
                    chapterNumber: start.chapterNumber,
                    verseNumber: start.verseNumber,
                    verseText: rangeText
                )
                note.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                note.content = trimmedNote
                note.formattedContent = try JSONEncoder().encode(noteText)
                note.highlightColor = selectedColor?.rawValue ?? ""
                note.categoryRawValue = NoteCategory.scripture.rawValue
                note.endVerseNumber = endVerse > start.verseNumber ? endVerse : 0
                note.verseText = rangeText
                note.updatedAt = Date()
                if existingNote == nil {
                    modelContext.insert(note)
                }
                try modelContext.save()
            },
            onSuccess: {
                if addsHighlight {
                    TodayChallengeStore.shared.recordVerseHighlightSaved()
                }
                NoteDraftStore.clear(draftKey)
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
                if keepsHighlightOnDelete {
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

/// Verse text for a run of verses in the loaded Bible.
@MainActor
enum VerseRangeText {
    static func text(book: String, chapter: Int, from first: Int, through last: Int) -> String? {
        guard let verses = verses(book: book, chapter: chapter) else { return nil }
        let selected = verses.filter { (first...max(first, last)).contains($0.number) }
        return selected.isEmpty ? nil : selected.map(\.text).joined(separator: " ")
    }

    static func verseCount(book: String, chapter: Int) -> Int? {
        verses(book: book, chapter: chapter)?.last?.number
    }

    private static func verses(book: String, chapter: Int) -> [Verse]? {
        BibleData.books.first { $0.name == book }?.chapters.first { $0.number == chapter }?.verses
    }
}

private struct ScriptureEditorReferenceCard: View {
    let reference: String
    let verseText: String
    let startVerse: Int
    let lastVerseInChapter: Int
    @Binding var endVerse: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(reference, systemImage: "book.closed.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)
                Spacer()
                if lastVerseInChapter > startVerse {
                    Menu {
                        Picker("Through Verse", selection: $endVerse) {
                            ForEach(startVerse...lastVerseInChapter, id: \.self) { verse in
                                Text(verse == startVerse ? "This verse only" : "Through verse \(verse)").tag(verse)
                            }
                        }
                    } label: {
                        Label(endVerse > startVerse ? "Verses \(startVerse)–\(endVerse)" : "Add verses", systemImage: "text.append")
                            .font(.caption.weight(.semibold))
                    }
                    .accessibilityLabel("Verses covered")
                    .accessibilityValue(Text(reference))
                }
            }
            Text(verseText)
                .font(.body)
                .foregroundStyle(.secondary)
                // A range can span many verses; keep it as a quick reminder above the note title.
                .lineLimit(endVerse > startVerse ? 2 : 4)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct VerseNoteOptionsBar: View {
    @Binding var highlight: VerseHighlightColor?

    var body: some View {
        ScriptureHighlightPicker(selection: $highlight)
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
