import SwiftData
import SwiftUI

// MARK: - Tags

/// Renames, merges, and removes custom tags across notes.
@MainActor
enum NoteTagEditor {
    /// Replaces `tag` with `replacement` in every note's title and body, merging into an existing
    /// tag of that name; a nil replacement removes the "#" and keeps the word. Notes keep their
    /// modified dates, since the writing itself didn't change. Returns how many notes changed.
    @discardableResult
    static func rename(
        _ tag: String,
        to replacement: String?,
        verseNotes: [VerseNote],
        userNotes: [UserNote]
    ) -> Int {
        var changed = 0
        for note in verseNotes where apply(tag, replacement, title: &note.title, content: &note.content, formatted: &note.formattedContent) {
            changed += 1
        }
        for note in userNotes where apply(tag, replacement, title: &note.title, content: &note.content, formatted: &note.formattedContent) {
            changed += 1
        }
        return changed
    }

    private static func apply(
        _ tag: String,
        _ replacement: String?,
        title: inout String,
        content: inout String,
        formatted: inout Data?
    ) -> Bool {
        let newTitle = NoteCustomTags.renaming(tag, to: replacement, in: title)
        let newContent = NoteCustomTags.renaming(tag, to: replacement, in: content)
        guard newTitle != title || newContent != content else { return false }
        if formatted != nil {
            let text = NoteFormattedContent.decode(formatted, fallback: content)
            formatted = try? JSONEncoder().encode(NoteCustomTags.renaming(tag, to: replacement, in: text))
        }
        title = newTitle
        content = newContent
        return true
    }
}

/// Lists every custom tag with its count, to rename, merge, or remove tags.
struct NotesTagManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var verseNotes: [VerseNote]
    @Query private var userNotes: [UserNote]

    @State private var renamingTag: String?
    @State private var newName = ""
    @State private var removingTag: String?
    @State private var persistenceFailure: PersistenceFailure?

    var body: some View {
        List {
            if tags.isEmpty {
                ContentUnavailableView(
                    "No Tags",
                    systemImage: "tag",
                    description: Text("Type # and a word in a note, such as #prayer, to tag it.")
                )
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(tags) { tag in
                        HStack {
                            Text(verbatim: "#\(tag.tag)")
                            Spacer()
                            Text(tag.count == 1 ? "1 note" : "\(tag.count) notes")
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(.rect)
                        .onTapGesture { beginRename(tag.tag) }
                        .swipeActions {
                            Button("Remove", systemImage: "trash", role: .destructive) { removingTag = tag.tag }
                            Button("Rename", systemImage: "pencil") { beginRename(tag.tag) }
                                .tint(.accentColor)
                        }
                        .contextMenu {
                            Button("Rename", systemImage: "pencil") { beginRename(tag.tag) }
                            Button("Remove Tag", systemImage: "trash", role: .destructive) { removingTag = tag.tag }
                        }
                    }
                } footer: {
                    Text("Tap a tag to rename it. Renaming to an existing tag merges the two. Removing a tag keeps the word in your notes without the #.")
                }
            }
        }
        .navigationTitle("Manage Tags")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .alert("Rename Tag", isPresented: isRenaming) {
            TextField("Tag name", text: $newName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Rename") { commitRename() }
                .disabled(validNewName == nil)
            Button("Cancel", role: .cancel) { renamingTag = nil }
        } message: {
            if let validNewName, validNewName != renamingTag, tags.contains(where: { $0.tag == validNewName }) {
                Text("#\(renamingTag ?? "") will be merged into #\(validNewName).")
            } else {
                Text("Letters, numbers, and underscores only.")
            }
        }
        .confirmationDialog(
            Text("Remove #\(removingTag ?? "")?"),
            isPresented: isRemoving,
            titleVisibility: .visible
        ) {
            Button("Remove Tag", role: .destructive) {
                if let removingTag { change(removingTag, to: nil) }
                removingTag = nil
            }
            Button("Cancel", role: .cancel) { removingTag = nil }
        } message: {
            Text("The word stays in your notes without the #.")
        }
        .persistenceFailureAlert(failure: $persistenceFailure)
    }

    private var tags: [NotesLibrary.TagCount] {
        NotesLibrary(scriptureNotes: verseNotes, userNotes: userNotes, filters: NotesFilters(), sort: .title, ascending: true).tags
    }

    private var validNewName: String? { NoteCustomTags.normalizedTag(newName) }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renamingTag != nil }, set: { if !$0 { renamingTag = nil } })
    }

    private var isRemoving: Binding<Bool> {
        Binding(get: { removingTag != nil }, set: { if !$0 { removingTag = nil } })
    }

    private func beginRename(_ tag: String) {
        newName = tag
        renamingTag = tag
    }

    private func commitRename() {
        defer { renamingTag = nil }
        guard let renamingTag, let validNewName, validNewName != renamingTag else { return }
        change(renamingTag, to: validNewName)
    }

    private func change(_ tag: String, to replacement: String?) {
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                NoteTagEditor.rename(tag, to: replacement, verseNotes: verseNotes, userNotes: userNotes)
                try modelContext.save()
            },
            onSuccess: { Haptics.success() },
            onFailure: { persistenceFailure = $0 }
        )
    }
}
