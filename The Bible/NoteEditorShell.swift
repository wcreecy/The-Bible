import SwiftData
import SwiftUI

/// An editor's unsaved state, kept on the device so a note survives the app being closed
/// mid-edit. Saved while typing and cleared on Save or Discard.
struct NoteDraft: Codable, Equatable {
    var title: String
    /// The body as encoded `AttributedString`.
    var body: Data
    var category: String
    var highlightColor: String = ""
    var endVerseNumber: Int = 0
    var passageReference: String = ""
    var sermonSpeaker: String = ""
    var sermonLocation: String = ""
    var sermonDate: Date?
    /// Set when the draft is written, so drafts built from the same edits compare equal.
    var savedAt = Date.distantPast

    var bodyText: AttributedString {
        NoteFormattedContent.decode(body, fallback: "")
    }
}

enum NoteDraftStore {
    private static let prefix = "noteDraft."

    /// One draft slot per verse, so a new and an existing note on a verse share it.
    static func key(forVerse book: String, chapter: Int, verse: Int) -> String {
        "\(prefix)verse.\(book).\(chapter).\(verse)"
    }

    /// A slot per existing personal note, plus one shared slot for a new note.
    static func key(forUserNote note: UserNote?) -> String {
        guard let note,
              let id = try? JSONEncoder().encode(note.persistentModelID) else { return "\(prefix)user.new" }
        return "\(prefix)user.\(id.base64EncodedString())"
    }

    static func load(_ key: String, defaults: UserDefaults = .standard) -> NoteDraft? {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(NoteDraft.self, from: $0) }
    }

    static func save(_ draft: NoteDraft, for key: String, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(draft) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear(_ key: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

extension View {
    /// The toolbar and safeguards shared by the note editors: Cancel asks before discarding
    /// changes, Delete asks before deleting, swipe-to-dismiss is blocked while there are
    /// changes, and the draft is saved as the note is edited.
    func noteEditorShell(
        hasChanges: Bool,
        canSave: Bool,
        draftKey: String,
        draft: @escaping () -> NoteDraft,
        restoredDraftDate: Binding<Date?>,
        discardRestoredDraft: @escaping () -> Void,
        deleteTitle: LocalizedStringResource?,
        deleteMessage: LocalizedStringResource,
        save: @escaping () -> Void,
        delete: @escaping () -> Void,
        hidesRestoredDraftBanner: Bool = false
    ) -> some View {
        modifier(NoteEditorShell(
            hasChanges: hasChanges,
            canSave: canSave,
            draftKey: draftKey,
            draft: draft,
            restoredDraftDate: restoredDraftDate,
            discardRestoredDraft: discardRestoredDraft,
            deleteTitle: deleteTitle,
            deleteMessage: deleteMessage,
            save: save,
            delete: delete,
            hidesRestoredDraftBanner: hidesRestoredDraftBanner
        ))
    }
}

private struct NoteEditorShell: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var isConfirmingDiscard = false
    @State private var isConfirmingDelete = false
    @State private var draftSaveTask: Task<Void, Never>?

    let hasChanges: Bool
    let canSave: Bool
    let draftKey: String
    let draft: () -> NoteDraft
    @Binding var restoredDraftDate: Date?
    let discardRestoredDraft: () -> Void
    let deleteTitle: LocalizedStringResource?
    let deleteMessage: LocalizedStringResource
    let save: () -> Void
    let delete: () -> Void
    /// Set while the editor's fields are collapsed for typing.
    let hidesRestoredDraftBanner: Bool

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if let restoredDraftDate, !hidesRestoredDraftBanner {
                    restoredDraftBanner(restoredDraftDate)
                }
            }
            .interactiveDismissDisabled(hasChanges)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges {
                            isConfirmingDiscard = true
                        } else {
                            NoteDraftStore.clear(draftKey)
                            dismiss()
                        }
                    }
                    .confirmationDialog("Discard your changes?", isPresented: $isConfirmingDiscard, titleVisibility: .visible) {
                        Button("Discard Changes", role: .destructive) {
                            NoteDraftStore.clear(draftKey)
                            dismiss()
                        }
                        Button("Keep Editing", role: .cancel) {}
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draftSaveTask?.cancel()
                        save()
                    }
                    .disabled(!canSave)
                }
                if let deleteTitle {
                    ToolbarItem(placement: .secondaryAction) {
                        Button(role: .destructive) {
                            isConfirmingDelete = true
                        } label: {
                            Label { Text(deleteTitle) } icon: { Image(systemName: "trash") }
                        }
                    }
                }
            }
            .confirmationDialog(Text(deleteTitle ?? "Delete"), isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button(role: .destructive) {
                    draftSaveTask?.cancel()
                    NoteDraftStore.clear(draftKey)
                    delete()
                } label: {
                    Text(deleteTitle ?? "Delete")
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(deleteMessage)
            }
            .onChange(of: hasChanges ? draft() : nil) { _, newDraft in
                scheduleDraftSave(newDraft)
            }
            .onChange(of: scenePhase) { _, phase in
                // Write immediately when leaving the app, in case it isn't reopened.
                if phase != .active { writeDraft(hasChanges ? draft() : nil) }
            }
    }

    private func restoredDraftBanner(_ date: Date) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.tint)
            Text("Restored unsaved changes from \(date, format: .dateTime.month(.abbreviated).day().hour().minute())")
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Discard", role: .destructive) {
                NoteDraftStore.clear(draftKey)
                restoredDraftDate = nil
                discardRestoredDraft()
            }
            .font(.footnote.weight(.semibold))
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    /// Saves the draft shortly after typing pauses, so each keystroke isn't written out.
    private func scheduleDraftSave(_ newDraft: NoteDraft?) {
        draftSaveTask?.cancel()
        draftSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            writeDraft(newDraft)
        }
    }

    private func writeDraft(_ newDraft: NoteDraft?) {
        if var newDraft {
            newDraft.savedAt = Date()
            NoteDraftStore.save(newDraft, for: draftKey)
        } else {
            NoteDraftStore.clear(draftKey)
        }
    }
}
