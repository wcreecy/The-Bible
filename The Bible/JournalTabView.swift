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

    @State private var previewRef: ScriptureRef? = nil
    @State private var previewContent: (title: String, verses: [Verse])? = nil
    @State private var showPreview: Bool = false

    var body: some View {
        if hSize == .regular {
            NavigationSplitView(columnVisibility: .constant(.all)) {
                sidebarList
                    .navigationTitle("Journal")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { showComposer = true } label: { Label("New Entry", systemImage: "square.and.pencil") }
                        }
                    }
            } content: {
                if let e = selectedEntry {
                    if isEditing {
                        editorPane(entry: e)
                            .navigationTitle("Edit Entry")
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { isEditing = false; try? ctx.save() }
                                }
                            }
                    } else {
                        readOnlyPane(entry: e)
                            .navigationTitle("Entry")
                            .toolbar {
                                ToolbarItem(placement: .primaryAction) {
                                    Button("Edit") { isEditing = true }
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
                List(entries) { entry in
                    NavigationLink(value: entry) { listRow(for: entry) }
                }
                .navigationTitle("Journal")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showComposer = true } label: { Label("New Entry", systemImage: "square.and.pencil") }
                    }
                }
                .navigationDestination(for: JournalEntry.self) { entry in
                    JournalDetailView(entry: entry)
                }
            }
            .sheet(isPresented: $showComposer) { JournalEditorView(verseRef: nil) }
        }
    }

    @ViewBuilder
    private var sidebarList: some View {
        List(entries) { entry in
            Button {
                selectedEntry = entry
                isEditing = false
            } label: { listRow(for: entry) }
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
        Form {
            Section("Title") {
                TextField("Title", text: Binding(get: { entry.title }, set: { entry.title = $0; entry.updatedAt = Date(); try? ctx.save() }))
            }
            Section("Tags") {
                TextField(
                    "Add tags (comma-separated)",
                    text: Binding(
                        get: { entry.tags.joined(separator: ", ") },
                        set: { newValue in
                            let parts = newValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                            var seen = Set<String>()
                            var uniq: [String] = []
                            for p in parts { if !seen.contains(p.lowercased()) { seen.insert(p.lowercased()); uniq.append(p) } }
                            entry.tags = uniq
                            entry.updatedAt = Date(); try? ctx.save()
                        }
                    )
                )
                .textInputAutocapitalization(.words)
                if !entry.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(entry.tags, id: \.self) { t in
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
                TextEditor(text: Binding(get: { entry.body }, set: { entry.body = $0; entry.updatedAt = Date(); try? ctx.save() }))
                    .frame(minHeight: 240)
            }
        }
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
    }
}

#Preview {
    JournalTabView()
}
