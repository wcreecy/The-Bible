import SwiftUI
import SwiftData

struct JournalTabView: View {
    @Environment(\.modelContext) private var ctx
    @Query(filter: #Predicate<JournalEntry> { !$0.isArchived }, sort: \JournalEntry.updatedAt, order: .reverse)
    private var entries: [JournalEntry]

    @State private var showComposer: Bool = false

    @Environment(\.horizontalSizeClass) private var hSize
    @State private var selectedEntry: JournalEntry? = nil
    @State private var isEditing: Bool = false

    @State private var selectionMode: Bool = false
    @State private var selectedForDeletion: Set<JournalEntry> = []

    @State private var previewRef: ScriptureRef? = nil
    @State private var previewContent: (title: String, verses: [Verse])? = nil
    @State private var showPreview: Bool = false

    @State private var editingTagsText: String = ""

    @State private var selectedTags: Set<String> = []

    private var filteredEntries: [JournalEntry] {
        if selectedTags.isEmpty { return entries }
        let target = Set(selectedTags.map { $0.lowercased() })
        return entries.filter { entry in
            let entryTags = Set(entry.tags.map { $0.lowercased() })
            return target.isSubset(of: entryTags) // AND filter: must contain all selected tags
        }
    }

    private func toggleTagFilter(_ tag: String) {
        let key = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        let lower = key.lowercased()
        if selectedTags.contains(lower) {
            selectedTags.remove(lower)
        } else {
            selectedTags.insert(lower)
        }
    }

    private func deleteEntry(_ entry: JournalEntry) {
        ctx.delete(entry)
        try? ctx.save()
        if selectedEntry?.id == entry.id { selectedEntry = nil }
    }

    private func deleteSelectedEntries() {
        for entry in selectedForDeletion {
            ctx.delete(entry)
        }
        try? ctx.save()
        selectedForDeletion.removeAll()
        selectionMode = false
    }

    var body: some View {
        if hSize == .regular {
            NavigationSplitView(columnVisibility: .constant(.all)) {
                sidebarList
                    .navigationTitle("Journal")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            if !selectedTags.isEmpty {
                                Button("Clear Filters") { selectedTags.removeAll() }
                            }
                        }
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button { showComposer = true } label: { Label("New Entry", systemImage: "square.and.pencil") }
                            if selectionMode {
                                Button(role: .destructive) {
                                    deleteSelectedEntries()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button("Cancel") { selectionMode = false; selectedForDeletion.removeAll() }
                            } else {
                                Button {
                                    selectionMode = true
                                } label: {
                                    Label("Select", systemImage: "checkmark.circle")
                                }
                            }
                        }
                    }
            } content: {
                if let e = selectedEntry {
                    if isEditing {
                        editorPane(entry: e)
                            .navigationTitle("Edit Entry")
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") {
                                        // Persist edited tags from text to the model
                                        let tags = editingTagsText
                                            .split(separator: ",")
                                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                            .filter { !$0.isEmpty }
                                        e.tags = tags
                                        e.updatedAt = Date()
                                        isEditing = false
                                        try? ctx.save()
                                    }
                                }
                            }
                    } else {
                        readOnlyPane(entry: e)
                            .navigationTitle("Entry")
                            .toolbar {
                                ToolbarItem(placement: .primaryAction) {
                                    Button("Edit") {
                                        editingTagsText = e.tags.joined(separator: ", ")
                                        isEditing = true
                                    }
                                }
                            }
                    }
                } else {
                    ContentUnavailableView("Select an entry", systemImage: "book.closed")
                }
            } detail: {
                if let e = selectedEntry, isEditing {
                    previewPane(entry: e)
                        .navigationTitle("Preview")
                } else {
                    EmptyView()
                }
            }
            .sheet(isPresented: $showComposer) { JournalEditorView(verseRef: nil, showTagColors: false) }
        } else {
            // Compact width: simple list + push to detail
            NavigationStack {
                List(selection: $selectedForDeletion) {
                    ForEach(filteredEntries) { entry in
                        NavigationLink(value: entry) { listRow(for: entry) }
                            .tag(entry)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteEntry(entry)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .environment(\.editMode, .constant(selectionMode ? .active : .inactive))
                .navigationTitle("Journal")
                .toolbar {
                    if !selectedTags.isEmpty {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Clear Filters") { selectedTags.removeAll() }
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { showComposer = true } label: { Label("New Entry", systemImage: "square.and.pencil") }
                        if selectionMode {
                            Button(role: .destructive) { deleteSelectedEntries() } label: { Label("Delete", systemImage: "trash") }
                            Button("Cancel") { selectionMode = false; selectedForDeletion.removeAll() }
                        } else {
                            Button { selectionMode = true } label: { Label("Select", systemImage: "checkmark.circle") }
                        }
                    }
                }
                .navigationDestination(for: JournalEntry.self) { entry in
                    JournalDetailView(entry: entry)
                }
            }
            .sheet(isPresented: $showComposer) { JournalEditorView(verseRef: nil) }
        }
    }

    private var parsedEditingTags: [String] {
        editingTagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    @ViewBuilder
    private var sidebarList: some View {
        List(selection: $selectedForDeletion) {
            if !selectedTags.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(selectedTags), id: \.self) { t in
                                HStack(spacing: 6) {
                                    Text(t)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                                        .overlay(Capsule().stroke(Color.accentColor.opacity(0.35), lineWidth: 1))
                                    Button(action: { toggleTagFilter(t) }) {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            Button("Clear Filters") { selectedTags.removeAll() }
                                .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            ForEach(filteredEntries) { entry in
                Button {
                    selectedEntry = entry
                    isEditing = false
                } label: { listRow(for: entry) }
                .tag(entry)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteEntry(entry)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func listRow(for entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title.isEmpty ? "Untitled" : entry.title)
                .font(.headline)
            if !entry.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(entry.tags.prefix(4), id: \.self) { t in
                        let tint = TagColorStore.color(for: t) ?? .accentColor
                        let isSelected = selectedTags.contains(t.lowercased())
                        Button(action: { toggleTagFilter(t) }) {
                            Text(t)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background((isSelected ? tint : tint).opacity(isSelected ? 0.30 : 0.15), in: Capsule())
                                .overlay(
                                    Capsule().stroke((isSelected ? tint : tint).opacity(isSelected ? 0.8 : 0.4), lineWidth: isSelected ? 2 : 1)
                                )
                                .foregroundStyle(tint)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            if let ref = entry.verseRef {
                Text(ref.display)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func readOnlyPane(entry: JournalEntry) -> some View {
        let linkedBody = BibleReferenceLinker.linkify(entry.body)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(entry.title.isEmpty ? "Untitled" : entry.title)
                    .font(.title2).bold()
                if !entry.tags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(entry.tags, id: \.self) { t in
                            let tint = TagColorStore.color(for: t) ?? .accentColor
                            Text(t)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(tint.opacity(0.15), in: Capsule())
                                .overlay(Capsule().stroke(tint.opacity(0.4), lineWidth: 1))
                                .foregroundStyle(tint)
                        }
                    }
                }
                if let ref = entry.verseRef {
                    Text(ref.display)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Divider()
                Text(linkedBody)
                    .font(.body)
                    .textSelection(.enabled)
                    .environment(\._openURL, OpenURLAction { url in
                        if let r = BibleReferenceLinker.parse(url: url), let content = BibleReferenceLinker.loadVerses(for: r) {
                            previewRef = r
                            previewContent = content
                            withAnimation(.spring()) { showPreview = true }
                            return .handled
                        }
                        return .systemAction
                    })
                if showPreview, let content = previewContent {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(content.title)
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                let verseLines = content.verses.map { "\($0.number). \($0.text)" }.joined(separator: "\n")
                                let copyText = content.title + "\n" + verseLines
                                UIPasteboard.general.string = copyText
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Copy scripture")

                            Button(action: { withAnimation(.easeOut) { showPreview = false } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(content.verses, id: \.number) { v in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(v.text)
                                    .font(.body)
                                Text("\(previewRef?.bookName ?? "") \(previewRef?.chapter ?? 0):\(v.number)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if v.number != content.verses.last?.number { Divider().padding(.vertical, 4) }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Created: \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Updated: \(entry.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private func editorPane(entry: JournalEntry) -> some View {
        let linkedBody = BibleReferenceLinker.linkify(entry.body)
        var linkOverlayBody: AttributedString {
            var s = linkedBody
            // Make everything transparent first
            s.foregroundColor = .clear
            // Re-color and underline only link ranges
            for run in s.runs {
                if run.link != nil {
                    s[run.range].foregroundColor = .blue
                    s[run.range].underlineStyle = .single
                }
            }
            return s
        }

        Form {
            Section("Title") {
                TextField("Title", text: Binding(get: { entry.title }, set: { entry.title = $0; entry.updatedAt = Date(); try? ctx.save() }))
            }
            Section("Tags") {
                TextField(
                    "Add tags (comma-separated)",
                    text: $editingTagsText
                )
                .textInputAutocapitalization(.never)
                if !parsedEditingTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(parsedEditingTags, id: \.self) { t in
                            HStack(spacing: 10) {
                                Circle().fill(TagColorStore.color(for: t) ?? .accentColor).frame(width: 18, height: 18)
                                Text(t).font(.subheadline)
                                Spacer()
                                ColorPicker("", selection: Binding(get: { TagColorStore.color(for: t) ?? .accentColor }, set: { TagColorStore.setColor($0, for: t) }), supportsOpacity: false)
                                    .labelsHidden()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            Section("Body") {
                ZStack(alignment: .topLeading) {
                    if entry.body.isEmpty {
                        Text("Write your thoughts here…")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                    // Inline smart link overlay (non-interactive)
                    Text(linkOverlayBody)
                        .font(.body)
                        .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                    // Actual editor
                    TextEditor(text: Binding(get: { entry.body }, set: { entry.body = $0; entry.updatedAt = Date(); try? ctx.save() }))
                        .frame(minHeight: 240)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Live Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(linkedBody)
                        .frame(minHeight: 60, alignment: .topLeading)
                        .textSelection(.enabled)
                        .environment(\._openURL, OpenURLAction { url in
                            if let ref = BibleReferenceLinker.parse(url: url), let content = BibleReferenceLinker.loadVerses(for: ref) {
                                previewRef = ref
                                previewContent = content
                                withAnimation(.spring()) { showPreview = true }
                                return .handled
                            }
                            return .systemAction
                        })

                    if showPreview, let content = previewContent {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(content.title)
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    let verseLines = content.verses.map { "\($0.number). \($0.text)" }.joined(separator: "\n")
                                    let copyText = content.title + "\n" + verseLines
                                    UIPasteboard.general.string = copyText
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Copy scripture")

                                Button(action: { withAnimation(.easeOut) { showPreview = false } }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            ForEach(content.verses, id: \.number) { v in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(v.text)
                                        .font(.body)
                                    Text("\(previewRef?.bookName ?? "") \(previewRef?.chapter ?? 0):\(v.number)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if v.number != content.verses.last?.number { Divider().padding(.vertical, 4) }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.top, 8)
            }
        }
        .onAppear { editingTagsText = entry.tags.joined(separator: ", ") }
    }

    @ViewBuilder
    private func previewPane(entry: JournalEntry) -> some View {
        let linked = BibleReferenceLinker.linkify(entry.body)
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.title.isEmpty ? "Untitled" : entry.title)
                    .font(.title3).bold()
                Text(linked)
                    .font(.body)
                    .textSelection(.enabled)
                    .environment(\._openURL, OpenURLAction { url in
                        if let r = BibleReferenceLinker.parse(url: url), let content = BibleReferenceLinker.loadVerses(for: r) {
                            previewRef = r
                            previewContent = content
                            withAnimation(.spring()) { showPreview = true }
                            return .handled
                        }
                        return .systemAction
                    })
                if showPreview, let content = previewContent {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(content.title)
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                let verseLines = content.verses.map { "\($0.number). \($0.text)" }.joined(separator: "\n")
                                let copyText = content.title + "\n" + verseLines
                                UIPasteboard.general.string = copyText
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Copy scripture")

                            Button(action: { withAnimation(.easeOut) { showPreview = false } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(content.verses, id: \.number) { v in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(v.text)
                                    .font(.body)
                                Text("\(previewRef?.bookName ?? "") \(previewRef?.chapter ?? 0):\(v.number)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if v.number != content.verses.last?.number { Divider().padding(.vertical, 4) }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(16)
        }
        .id(entry.body)
    }
}

#Preview {
    JournalTabView()
}
