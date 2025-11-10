import SwiftUI
import SwiftData

struct JournalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    // If invoked from a verse, we’ll seed the title smartly
    let verseRef: VerseRef?

    @State private var title: String = ""
    @State private var content: String = ""      // <-- renamed from `body`
    @State private var tagsText: String = ""     // comma-separated
    @State private var isFavorite = false
    @State private var isPinned = false

    @State private var showSaveError = false
    @State private var saveErrorMessage: String = ""

    init(verseRef: VerseRef?, initialBody: String? = nil) {
        self.verseRef = verseRef
        _title = State(initialValue: verseRef?.display ?? "")
        _content = State(initialValue: initialBody ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    if let ref = verseRef {
                        LabeledContent("Linked Verse", value: ref.display)
                    }
                }
                Section("Body") {
                    TextEditor(text: $content)
                        .frame(minHeight: 160)
                }
                Section("Tags") {
                    TextField("faith, prayer, study…", text: $tagsText)
                        .textInputAutocapitalization(.never)
                }
                Section("Options") {
                    Toggle("Favorite", isOn: $isFavorite)
                    Toggle("Pin", isOn: $isPinned)
                }
            }
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }.bold()
                }
            }
            .alert("Couldn’t Save Entry", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    private func save() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let entry = JournalEntry(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: content.trimmingCharacters(in: .whitespacesAndNewlines),
            verseRef: verseRef,
            tags: tags,
            isPinned: isPinned,
            isFavorite: isFavorite
        )
        // Ensure timestamps are current if your model uses them
        entry.updatedAt = Date()
        ctx.insert(entry)
        do {
            try ctx.save()
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }
}
