import SwiftUI
import SwiftData

struct JournalTabView: View {
    @Environment(\.modelContext) private var ctx
    @EnvironmentObject private var journalComposer: JournalComposer
    @Query(filter: #Predicate<JournalEntry> { !$0.isArchived }, sort: \JournalEntry.updatedAt, order: .reverse)
    private var entries: [JournalEntry]

    @Environment(\.horizontalSizeClass) private var hSize
    @State private var selectedEntry: JournalEntry? = nil
    @State private var isEditing: Bool = false

    @State private var selectionMode: Bool = false
    @State private var selectedForDeletion: Set<JournalEntry> = []
    @State private var searchText: String = ""

    @State private var previewRef: ScriptureRef? = nil
    @State private var previewContent: (title: String, verses: [Verse])? = nil
    @State private var showPreview: Bool = false

    @State private var editingTagsText: String = ""

    @State private var selectedTags: Set<String> = []
    @State private var refreshToken: String = ""
    @State private var splitVisibility: NavigationSplitViewVisibility = .all

    @AppStorage("journalPinnedIDs") private var pinnedIDsRaw: String = ""

    private var filteredEntries: [JournalEntry] {
        var list = entries
        // Tag filter (AND across selected tags)
        if !selectedTags.isEmpty {
            let target = Set(selectedTags.map { $0.lowercased() })
            list = list.filter { entry in
                let entryTags = Set(entry.tags.map { $0.lowercased() })
                return target.isSubset(of: entryTags)
            }
        }
        // Search filter across title, tags, and body
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            list = list.filter { entry in
                let titleMatch = entry.title.localizedCaseInsensitiveContains(query)
                let tagsMatch = entry.tags.contains { $0.localizedCaseInsensitiveContains(query) }
                let bodyMatch = entry.body.localizedCaseInsensitiveContains(query)
                return titleMatch || tagsMatch || bodyMatch
            }
        }
        // Sort: pinned first, then preserve original order based on the original entries array
        let indexMap: [UUID: Int] = Dictionary(uniqueKeysWithValues: entries.enumerated().map { ($1.id, $0) })
        let pins = readPinnedIDs()
        return list.sorted { lhs, rhs in
            let lp = pins.contains(lhs.id.uuidString)
            let rp = pins.contains(rhs.id.uuidString)
            if lp != rp { return lp && !rp }
            let li = indexMap[lhs.id] ?? 0
            let ri = indexMap[rhs.id] ?? 0
            return li < ri
        }
    }

    private func readPinnedIDs() -> Set<String> {
        let parts = pinnedIDsRaw.split(separator: ",").map { String($0) }
        return Set(parts)
    }
    private func writePinnedIDs(_ set: Set<String>) {
        pinnedIDsRaw = set.joined(separator: ",")
    }
    private func isPinned(_ entry: JournalEntry) -> Bool {
        let pins = readPinnedIDs()
        return pins.contains(entry.id.uuidString)
    }
    private func togglePin(_ entry: JournalEntry) {
        var pins = readPinnedIDs()
        let key = entry.id.uuidString
        if pins.contains(key) { pins.remove(key) } else { pins.insert(key) }
        writePinnedIDs(pins)
    }

    private var headerCountText: String {
        let queryActive = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let tagsActive = !selectedTags.isEmpty
        let filtered = queryActive || tagsActive
        let count = filtered ? filteredEntries.count : entries.count
        let noun = (count == 1) ? "entry" : "entries"
        return "\(count) \(noun)" + (filtered ? " (filtered)" : "")
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
            NavigationSplitView(columnVisibility: $splitVisibility) {
                sidebarList
                    .id(refreshToken)
                    .navigationTitle("Journal Entries")
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            if !selectedTags.isEmpty {
                                Button("Clear Filters") { selectedTags.removeAll() }
                            }
                        }
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            if selectionMode {
                                Button(role: .destructive) {
                                    deleteSelectedEntries()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button("Cancel") {
                                    selectionMode = false
                                    selectedForDeletion.removeAll()
                                }
                            } else {
                                Button {
                                    journalComposer.present(initialBody: nil, verseRef: nil, showTagColors: false)
                                } label: {
                                    Label("New Entry", systemImage: "square.and.pencil")
                                }
                                Button {
                                    selectionMode = true
                                } label: {
                                    Label("Select", systemImage: "checkmark.circle")
                                }
                            }
                        }
                    }
                    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search entries")
                    .frame(minWidth: 280)
            } detail: {
                if let e = selectedEntry {
                    if isEditing {
                        HStack(spacing: 0) {
                            // Middle: Editor (widest)
                            editorPane(entry: e, showInlinePreview: false)
                                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .layoutPriority(1)

                            Divider()

                            // Right: Live Preview (updates live as entry changes)
                            ScrollView { previewPane(entry: e) }
                                .frame(minWidth: 320, idealWidth: 360, maxWidth: 420, maxHeight: .infinity, alignment: .topLeading)
                        }
                        .navigationTitle(e.title.isEmpty ? "Untitled" : e.title)
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
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { isEditing = false }
                            }
                        }
                    } else {
                        readOnlyPane(entry: e)
                            .navigationTitle(e.title.isEmpty ? "Untitled" : e.title)
                            .toolbar {
                                ToolbarItem(placement: .primaryAction) {
                                    Button("Edit") {
                                        journalComposer.presentForEditing(entry: e)
                                    }
                                }
                            }
                    }
                } else {
                    ContentUnavailableView("Select an entry", systemImage: "book.closed")
                }
            }
            .navigationSplitViewStyle(.balanced)
            .onAppear { splitVisibility = .all }
            .onChange(of: hSize) { _, _ in splitVisibility = .all }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("JournalEntryCreated"))) { note in
                if let id = note.userInfo?["id"] as? String {
                    // Force a lightweight refresh; reselect the new entry if present
                    refreshToken = id
                    if let created = entries.first(where: { $0.id.uuidString == id }) {
                        selectedEntry = created
                    }
                } else {
                    refreshToken = UUID().uuidString
                }
            }
        } else {
            // Compact width: simple list + push to detail
            NavigationStack {
                List(selection: $selectedForDeletion) {
                    Section {
                        ForEach(filteredEntries) { entry in
                            NavigationLink(destination: JournalDetailView(entry: entry)) { listRow(for: entry) }
                                .tag(entry)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteEntry(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        togglePin(entry)
                                    } label: {
                                        Label(isPinned(entry) ? "Unpin" : "Pin", systemImage: "pin.fill")
                                    }
                                    .tint(.yellow)
                                }
                                .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                        }
                    } header: {
                        Text(headerCountText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toolbar {
                    if !selectedTags.isEmpty {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Clear Filters") { selectedTags.removeAll() }
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if selectionMode {
                            Button(role: .destructive) {
                                deleteSelectedEntries()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button("Cancel") {
                                selectionMode = false
                                selectedForDeletion.removeAll()
                            }
                        } else {
                            Button {
                                journalComposer.present(initialBody: nil, verseRef: nil, showTagColors: false)
                            } label: {
                                Label("New Entry", systemImage: "square.and.pencil")
                            }
                            Button {
                                selectionMode = true
                            } label: {
                                Label("Select", systemImage: "checkmark.circle")
                            }
                        }
                    }
                }
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search entries")
                .environment(\.editMode, .constant(selectionMode ? .active : .inactive))
                .navigationDestination(for: JournalEntry.self) { entry in
                    JournalDetailView(entry: entry)
                }
            }
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
            Section {
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
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            togglePin(entry)
                        } label: {
                            Label(isPinned(entry) ? "Unpin" : "Pin", systemImage: "pin.fill")
                        }
                        .tint(.yellow)
                    }
                    .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                }
            } header: {
                Text(headerCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .environment(\.editMode, .constant(selectionMode ? .active : .inactive))
    }

    @ViewBuilder
    private func listRow(for entry: JournalEntry) -> some View {
        let isPadSelected = (hSize == .regular) && (selectedEntry?.id == entry.id)
        VStack(alignment: .leading, spacing: 2) {
            // Content area that should be highlighted (between dividers)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isPinned(entry) {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.yellow)
                            .imageScale(.small)
                    }
                    Text(entry.title.isEmpty ? "Untitled" : entry.title)
                }
                .font(.subheadline)
                if !entry.tags.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(entry.tags.prefix(4), id: \.self) { t in
                            let tint = TagColorStore.color(for: t) ?? .accentColor
                            let isSelected = selectedTags.contains(t.lowercased())
                            Button(action: { toggleTagFilter(t) }) {
                                Text(t)
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
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
                if !entry.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(entry.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }
                if let ref = entry.verseRef {
                    Text(ref.display)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(
                isPadSelected ? AnyView(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                ) : AnyView(EmptyView())
            )

            // Divider remains outside the highlight to visually bound the selection
            if hSize == .regular {
                Divider()
                    .padding(.top, 3)
            }
        }
        .padding(.vertical, 1)
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
    private func editorPane(entry: JournalEntry, showInlinePreview: Bool = true) -> some View {
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
                    if showInlinePreview {
                        // Inline smart link overlay (non-interactive)
                        Text(linkOverlayBody)
                            .font(.body)
                            .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    // Actual editor
                    TextEditor(text: Binding(get: { entry.body }, set: { entry.body = $0; entry.updatedAt = Date(); try? ctx.save() }))
                        .frame(minHeight: 240)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                }
            }
            if showInlinePreview {
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
