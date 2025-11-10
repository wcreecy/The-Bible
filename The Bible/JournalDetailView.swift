import SwiftUI
import SwiftData
import Foundation

struct JournalDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let entry: JournalEntry

    @State private var titleText: String = ""
    @State private var bodyText: String = ""
    @State private var tagsText: String = "" // comma-separated
    @State private var isEditing: Bool = false

    // Autosave debounce
    @State private var autosaveTask: Task<Void, Never>? = nil

    init(entry: JournalEntry) {
        self.entry = entry
        _titleText = State(initialValue: entry.title)
        _bodyText = State(initialValue: entry.body)
        _tagsText = State(initialValue: entry.tags.joined(separator: ", "))
    }

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

    var body: some View {
        Form {
            Section("Title") {
                if isEditing {
                    TextField("Title", text: $titleText)
                } else {
                    Text(titleText.isEmpty ? "Untitled" : titleText)
                        .foregroundStyle(.primary)
                }
            }
            Section("Tags") {
                if isEditing {
                    TextField("sermon notes, prayer, study…", text: $tagsText)
                        .textInputAutocapitalization(.never)
                }
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
                            if isEditing {
                                ColorPicker("", selection: colorBinding(for: t), supportsOpacity: false)
                                    .labelsHidden()
                            }
                        }
                    }
                }
            }
            Section("Body") {
                if isEditing {
                    ZStack(alignment: .topLeading) {
                        if bodyText.isEmpty {
                            Text("Write your thoughts here…")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        TextEditor(text: $bodyText)
                            .frame(minHeight: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                            )
                    }
                } else {
                    if bodyText.isEmpty {
                        Text("No content")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(bodyText)
                            .frame(minHeight: 200, alignment: .topLeading)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button(action: { saveNow(); isEditing = false }) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                } else {
                    Button("Edit") { isEditing = true }
                }
            }
        }
        .onChange(of: titleText) { _, _ in if isEditing { scheduleAutosave() } }
        .onChange(of: bodyText) { _, _ in if isEditing { scheduleAutosave() } }
        .onChange(of: tagsText) { _, _ in if isEditing { scheduleAutosave() } }
    }

    // MARK: - Saving

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            saveNow()
        }
    }

    private func saveNow() {
        // Parse tags from comma-separated text
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        entry.title = titleText
        entry.body = bodyText
        entry.tags = tags
        entry.updatedAt = Date()
        try? modelContext.save()
    }
}

#Preview {
    // Lightweight preview with in-memory model
    struct Container: View {
        @State private var entry: JournalEntry
        init() {
            let e = JournalEntry(
                title: "My Notes",
                body: "Write your thoughts here.\n\n- Bullet\n- Points\n\nSome plain text.",
                verseRef: nil,
                tags: ["prayer", "study"],
                isPinned: false,
                isFavorite: false
            )
            _entry = State(initialValue: e)
        }
        var body: some View {
            NavigationStack { JournalDetailView(entry: entry) }
                .modelContainer(for: [JournalEntry.self], inMemory: true)
        }
    }
    return Container()
}
