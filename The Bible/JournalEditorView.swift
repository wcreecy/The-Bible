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

    private var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func colorBinding(for tag: String) -> Binding<Color> {
        let initial = TagColorStore.color(for: tag) ?? .accentColor
        var current = initial
        return Binding<Color>(
            get: { TagColorStore.color(for: tag) ?? current },
            set: { newValue in
                TagColorStore.setColor(newValue, for: tag)
            }
        )
    }

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
                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text("Write your thoughts here…")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $content)
                            .frame(minHeight: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                            )
                    }
                }
                Section("Tags") {
                    TextField("sermon notes, prayer, study…", text: $tagsText)
                        .textInputAutocapitalization(.never)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(parsedTags, id: \.self) { t in
                            HStack(spacing: 8) {
                                let color = TagColorStore.color(for: t) ?? .accentColor
                                Text(t)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(color.opacity(0.15), in: Capsule())
                                    .overlay(
                                        Capsule().stroke(color.opacity(0.4), lineWidth: 1)
                                    )
                                    .foregroundStyle(color)
                                ColorPicker("", selection: colorBinding(for: t), supportsOpacity: false)
                                    .labelsHidden()
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: save) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .bold()
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
            isPinned: false,
            isFavorite: false
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
