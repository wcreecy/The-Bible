import SwiftData
import SwiftUI

/// Initial content for a new note created from a study feature.
struct UserNotePrefill: Identifiable {
    let id: String
    let title: String
    let body: String
    let passageReference: String
}

/// Adds or edits a personal, sermon, or Chapter Insights note that isn't attached to a verse.
@MainActor
struct UserNoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(AppStorageKey.contextualTipsEnabled) private var contextualTipsEnabled = false

    let existingNote: UserNote?

    @State private var title: String
    @State private var noteText: AttributedString
    @State private var noteSelection = AttributedTextSelection()
    @State private var selectedCategory: NoteCategory
    @State private var passage: String
    @State private var passageExcerpt: NotePassageExcerpt?
    @State private var speaker: String
    @State private var location: String
    @State private var sermonDate: Date
    @State private var formattingChanged = false
    @State private var restoredDraftDate: Date?
    @State private var isShowingSermonDetails: Bool
    @State private var isEditingBody = false
    @State private var isOnScreenKeyboardShown = false
    /// Hides everything above the body while typing with the on-screen keyboard, so it
    /// doesn't squeeze the body.
    @State private var areFieldsCollapsed = false
    @State private var persistenceFailure: PersistenceFailure?

    /// The note as last saved, to tell whether anything has changed.
    private let saved: NoteDraft
    /// The date the picker opened with, which may be a default when the note has none saved.
    private let initialSermonDate: Date
    private let draftKey: String

    init(
        existingNote: UserNote?,
        defaultCategory: NoteCategory = .personal,
        prefill: UserNotePrefill? = nil
    ) {
        self.existingNote = existingNote
        let category = existingNote.flatMap { NoteCategory(rawValue: $0.categoryRawValue) } ?? defaultCategory
        let prefilledBody = prefill?.body ?? ""
        let saved = NoteDraft(
            title: existingNote?.title ?? prefill?.title ?? "",
            body: existingNote?.formattedContent ?? (try? JSONEncoder().encode(AttributedString(existingNote?.content ?? prefilledBody))) ?? Data(),
            category: category.rawValue,
            passageReference: existingNote?.passageReference ?? prefill?.passageReference ?? "",
            sermonSpeaker: existingNote?.sermonSpeaker ?? "",
            sermonLocation: existingNote?.sermonLocation ?? "",
            sermonDate: existingNote?.sermonDate
        )
        self.saved = saved
        draftKey = existingNote == nil ? prefill?.id ?? NoteDraftStore.key(forUserNote: nil) : NoteDraftStore.key(forUserNote: existingNote)

        // Pick up where the last session left off if it closed with unsaved changes.
        let draft = NoteDraftStore.load(draftKey)
        let start = draft ?? saved
        _restoredDraftDate = State(initialValue: draft?.savedAt)
        _title = State(initialValue: start.title)
        _noteText = State(initialValue: draft?.bodyText ?? NoteFormattedContent.decode(
            existingNote?.formattedContent,
            fallback: existingNote?.content ?? prefilledBody
        ))
        _selectedCategory = State(initialValue: NoteCategory(rawValue: start.category) ?? category)
        _passage = State(initialValue: start.passageReference)
        _speaker = State(initialValue: start.sermonSpeaker)
        _location = State(initialValue: start.sermonLocation)
        let initialSermonDate = saved.sermonDate ?? existingNote?.createdAt ?? Date()
        self.initialSermonDate = initialSermonDate
        _sermonDate = State(initialValue: start.sermonDate ?? initialSermonDate)
        _isShowingSermonDetails = State(initialValue: existingNote == nil || draft != nil)
    }

    var body: some View {
        VStack(spacing: 12) {
            if areFieldsCollapsed {
                NoteEditorShowFieldsButton { areFieldsCollapsed = false }
            } else {
                Group {
                    NoteEditorTitleField(title: $title, placeholder: "Note title")
                    passageField
                    sermonControls

                    if selectedCategory == .sermon {
                        sermonDetails
                    }

                    if contextualTipsEnabled {
                        ScriptureReferenceLinkTip()
                        CustomNoteTagsTip()
                    }

                    if let passageExcerpt {
                        NotePassageAnchor(excerpt: passageExcerpt)
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            NoteBodyTextEditor(text: $noteText, selection: $noteSelection, isFocused: $isEditingBody)
        }
        .padding()
        .animation(.snappy, value: areFieldsCollapsed)
        .onScreenKeyboardVisibility($isOnScreenKeyboardShown)
        .task(id: recognizedPassageReference) {
            await loadPassageExcerpt()
        }
        .onChange(of: isEditingBody && isOnScreenKeyboardShown) { _, collapse in
            // Typing collapses everything above the body; leaving the body or putting the
            // keyboard away brings it back.
            areFieldsCollapsed = collapse
        }
        .background(AppBackgroundView(tab: .notes))
        .richNoteEditing(text: $noteText, selection: $noteSelection, onFormattingChange: { formattingChanged = true })
        .navigationTitle(existingNote == nil ? "New Note" : "Edit Note")
        .navigationBarTitleDisplayMode(.inline)
        .noteEditorShell(
            hasChanges: hasChanges,
            canSave: !(trimmedTitle.isEmpty && trimmedNote.isEmpty),
            draftKey: draftKey,
            draft: currentDraft,
            restoredDraftDate: $restoredDraftDate,
            discardRestoredDraft: resetToSaved,
            deleteTitle: existingNote == nil ? nil : "Delete Note",
            deleteMessage: "This note will be deleted from all your devices.",
            save: save,
            delete: deleteNote
        )
        .persistenceFailureAlert(failure: $persistenceFailure)
    }

    // MARK: Sections

    private var passageField: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Passage, such as John 3:1-21 (optional)", text: $passage)
                    .font(.subheadline)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .onSubmit(normalizePassageReference)
                    .accessibilityLabel("Passage")
            }
            .frame(minHeight: 32)

            if !trimmedPassage.isEmpty, recognizedPassageReference == nil {
                Text("Not a recognized verse reference. Use a book, chapter, and verse, such as Romans 8:28.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if let recognizedPassageReference, recognizedPassageReference != trimmedPassage {
                Label("Recognized as \(recognizedPassageReference)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var sermonControls: some View {
        HStack {
            if isSermon {
                Label("Sermon Note", systemImage: "person.wave.2")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                Spacer()
                Button("Remove Sermon Details") {
                    selectedCategory = .personal
                }
                .font(.caption.weight(.semibold))
            } else {
                Button {
                    selectedCategory = .sermon
                    isShowingSermonDetails = true
                } label: {
                    Label("Add Sermon Details", systemImage: "person.wave.2")
                }
                .font(.caption.weight(.semibold))
                Spacer()
                Text(existingNote == nil ? "New note" : "Editing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 32)
    }

    private var sermonDetails: some View {
        DisclosureGroup(isExpanded: $isShowingSermonDetails) {
            VStack(spacing: 8) {
                TextField("Speaker", text: $speaker)
                    .textContentType(.name)
                Divider()
                TextField("Church or location", text: $location)
                Divider()
                DatePicker("Date", selection: $sermonDate, displayedComponents: .date)
            }
            .font(.subheadline)
            .padding(.top, 8)
        } label: {
            Label(sermonSummary, systemImage: "person.wave.2")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var sermonSummary: String {
        let parts = [speaker, location].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return parts.isEmpty ? String(localized: "Sermon Details") : parts.joined(separator: " · ")
    }

    // MARK: State

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedNote: String { String(noteText.characters).trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedPassage: String { passage.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var recognizedPassageReference: String? {
        BibleReferenceLinker.canonicalReference(for: trimmedPassage)
    }
    private var savedPassageReference: String {
        recognizedPassageReference ?? trimmedPassage
    }

    private var parsedPassageReference: ScriptureRef? {
        BibleReferenceLinker.parse(trimmedPassage)
    }

    private var isSermon: Bool { selectedCategory == .sermon }

    private var hasChanges: Bool {
        formattingChanged ||
            title != saved.title ||
            String(noteText.characters) != String(saved.bodyText.characters) ||
            selectedCategory.rawValue != saved.category ||
            savedPassageReference != saved.passageReference ||
            (isSermon && (speaker != saved.sermonSpeaker || location != saved.sermonLocation || sermonDateChanged))
    }

    private var sermonDateChanged: Bool {
        !Calendar.current.isDate(initialSermonDate, inSameDayAs: sermonDate)
    }

    private func normalizePassageReference() {
        guard let recognizedPassageReference else { return }
        passage = recognizedPassageReference
    }

    private func loadPassageExcerpt() async {
        guard let reference = parsedPassageReference else {
            passageExcerpt = nil
            return
        }
        passageExcerpt = nil

        guard let passage = await BibleReferenceLinker.loadVersesEnsuringLoaded(for: reference),
              parsedPassageReference == reference else {
            return
        }

        let excerpt = passage.verses.prefix(3).map(\.text).joined(separator: " ")
        guard !excerpt.isEmpty else { return }
        passageExcerpt = NotePassageExcerpt(reference: reference, title: passage.title, text: excerpt)
    }


    private func currentDraft() -> NoteDraft {
        NoteDraft(
            title: title,
            body: (try? JSONEncoder().encode(noteText)) ?? Data(),
            category: selectedCategory.rawValue,
            passageReference: savedPassageReference,
            sermonSpeaker: speaker,
            sermonLocation: location,
            sermonDate: isSermon ? sermonDate : nil
        )
    }

    private func resetToSaved() {
        title = saved.title
        noteText = saved.bodyText
        selectedCategory = NoteCategory(rawValue: saved.category) ?? .personal
        passage = saved.passageReference
        speaker = saved.sermonSpeaker
        location = saved.sermonLocation
        sermonDate = initialSermonDate
        formattingChanged = false
    }

     // MARK: Saving

    private func save() {
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                let note = existingNote ?? UserNote()
                note.title = trimmedTitle
                note.content = trimmedNote
                note.formattedContent = try JSONEncoder().encode(noteText)
                note.categoryRawValue = selectedCategory.rawValue
                note.passageReference = savedPassageReference
                note.sermonSpeaker = isSermon ? speaker.trimmingCharacters(in: .whitespacesAndNewlines) : ""
                note.sermonLocation = isSermon ? location.trimmingCharacters(in: .whitespacesAndNewlines) : ""
                note.sermonDate = isSermon ? sermonDate : nil
                note.updatedAt = Date()
                if existingNote == nil {
                    modelContext.insert(note)
                }
                try modelContext.save()
            },
            onSuccess: {
                NoteDraftStore.clear(draftKey)
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

private struct NotePassageExcerpt: Equatable {
    let reference: ScriptureRef
    let title: String
    let text: String
}

/// A lightweight Scripture attachment for a note; tapping it opens the passage in the Bible.
private struct NotePassageAnchor: View {
    let excerpt: NotePassageExcerpt

    var body: some View {
        Button {
            Haptics.selection()
            AppRouter.shared.openBibleReference(
                book: excerpt.reference.bookName,
                chapter: excerpt.reference.chapter,
                verse: excerpt.reference.startVerse
            )
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Label(excerpt.title, systemImage: "book.closed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tint)

                Text("“\(excerpt.text)”")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens \(excerpt.title) in the Bible")
    }
}
