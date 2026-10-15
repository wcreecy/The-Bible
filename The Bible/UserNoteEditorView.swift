import SwiftData
import SwiftUI

/// Adds or edits a personal note that isn't attached to a verse.
@MainActor
struct UserNoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false

    let existingNote: UserNote?

    @State private var title: String
    @State private var noteText: AttributedString
    @State private var noteSelection = AttributedTextSelection()
    @State private var selectedCategory: NoteCategory
    @State private var persistenceFailure: PersistenceFailure?

    init(existingNote: UserNote?, defaultCategory: NoteCategory = .personal) {
        self.existingNote = existingNote
        _title = State(initialValue: existingNote?.title ?? "")
        _noteText = State(initialValue: NoteFormattedContent.decode(
            existingNote?.formattedContent,
            fallback: existingNote?.content ?? ""
        ))
        _selectedCategory = State(
            initialValue: existingNote.flatMap { NoteCategory(rawValue: $0.categoryRawValue) } ?? defaultCategory
        )
    }

    var body: some View {
        VStack(spacing: 14) {
            NoteEditorTitleField(title: $title, placeholder: "Note title")

            if contextualTipsEnabled {
                ScriptureReferenceLinkTip()
                CustomNoteTagsTip()
            }

            HStack {
                NoteCategoryMenu(category: $selectedCategory)
                Spacer()
                Text(existingNote == nil ? "New note" : "Editing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            NoteBodyTextEditor(text: $noteText, selection: $noteSelection)
        }
        .padding()
        .background(AppBackgroundView(tab: .notes))
        .richNoteEditing(text: $noteText, selection: $noteSelection)
        .navigationTitle(existingNote == nil ? "New Note" : "Edit Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(trimmedTitle.isEmpty && trimmedNote.isEmpty)
            }
            if existingNote != nil {
                ToolbarItem(placement: .secondaryAction) {
                    Button("Delete Note", systemImage: "trash", role: .destructive, action: deleteNote)
                }
            }
        }
        .persistenceFailureAlert(failure: $persistenceFailure)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNote: String {
        String(noteText.characters).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                let note = existingNote ?? UserNote()
                note.title = trimmedTitle
                note.content = trimmedNote
                note.formattedContent = try JSONEncoder().encode(noteText)
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

    private func deleteNote() {
        guard let existingNote else { return }
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                modelContext.delete(existingNote)
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
