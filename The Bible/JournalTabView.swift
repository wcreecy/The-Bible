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

    // Cached filtered list to avoid recomputing every render
    @State private var cachedFilteredEntries: [JournalEntry] = []
    @State private var filterDebounceTask: Task<Void, Never>? = nil

    // Pin cache (avoid repeated split/join)
    @AppStorage("journalPinnedIDs") private var pinnedIDsRaw: String = ""
    @State private var pinnedIDs: Set<String> = []

    // Inline editor autosave
    @State private var autosaveTask: Task<Void, Never>? = nil

    // Inline linkify cache for preview overlay (debounced)
    @State private var inlineLinkedBody: AttributedString = AttributedString("")
    @State private var inlineLinkifyTask: Task<Void, Never>? = nil
    @State private var inlineLinkifySourceID: UUID = UUID()

    private func loadPins() {
        let parts = pinnedIDsRaw.split(separator: ",").map { String($0) }
        pinnedIDs = Set(parts)
    }
    private func persistPins() {
        pinnedIDsRaw = pinnedIDs.joined(separator: ",")
    }
    private func isPinned(_ entry: JournalEntry) -> Bool {
        pinnedIDs.contains(entry.id.uuidString)
    }
    private func togglePin(_ entry: JournalEntry) {
        let key = entry.id.uuidString
        if pinnedIDs.contains(key) {
            pinnedIDs.remove(key)
        } else {
            pinnedIDs.insert(key)
        }
        persistPins()
        recomputeFilteredEntries()
    }

    private var headerCountText: String {
        let queryActive = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let tagsActive = !selectedTags.isEmpty
        let filtered = queryActive || tagsActive
        let count = filtered ? cachedFilteredEntries.count : entries.count
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
        recomputeFilteredEntries()
    }

    private func deleteSelectedEntries() {
        for entry in selectedForDeletion {
            ctx.delete(entry)
        }
        try? ctx.save()
        selectedForDeletion.removeAll()
        selectionMode = false
        recomputeFilteredEntries()
    }

    private func recomputeFilteredEntries() {
        let currentEntries = entries
        let currentTags = selectedTags
        let currentQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentPins = pinnedIDs

        filterDebounceTask?.cancel()
        filterDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000) // 120ms debounce
            var list = currentEntries
            // Tag filter (AND across selected tags)
            if !currentTags.isEmpty {
                let target = Set(currentTags.map { $0.lowercased() })
                list = list.filter { entry in
                    let entryTags = Set(entry.tags.map { $0.lowercased() })
                    return target.isSubset(of: entryTags)
                }
            }
            // Search filter across title, tags, and body
            if !currentQuery.isEmpty {
                list = list.filter { entry in
                    let titleMatch = entry.title.localizedCaseInsensitiveContains(currentQuery)
                    let tagsMatch = entry.tags.contains { $0.localizedCaseInsensitiveContains(currentQuery) }
                    let bodyMatch = entry.body.localizedCaseInsensitiveContains(currentQuery)
                    return titleMatch || tagsMatch || bodyMatch
                }
            }
            // Sort: pinned first, then preserve original order based on the original entries array
            let indexMap: [UUID: Int] = Dictionary(uniqueKeysWithValues: currentEntries.enumerated().map { ($1.id, $0) })
            list.sort { lhs, rhs in
                let lp = currentPins.contains(lhs.id.uuidString)
                let rp = currentPins.contains(rhs.id.uuidString)
                if lp != rp { return lp && !rp }
                let li = indexMap[lhs.id] ?? 0
                let ri = indexMap[rhs.id] ?? 0
                return li < ri
            }
            cachedFilteredEntries = list
        }
    }

    var body: some View {
        if hSize == .regular {
            NavigationSplitView(columnVisibility: $splitVisibility) {
                sidebarList
                    .id(refreshToken)
                    .navigationTitle("Journal")
                    .toolbar {
                        // Leading: optional filters clear chip
                        ToolbarItem(placement: .topBarLeading) {
                            if !selectedTags.isEmpty {
                                Button {
                                    selectedTags.removeAll()
                                } label: {
                                    Label("Clear Filters", systemImage: "line.3.horizontal.decrease.circle")
                                }
                                .accessibilityLabel("Clear Filters")
                            }
                        }
                        // Trailing: action buttons
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            if selectionMode {
                                Button(role: .destructive) {
                                    deleteSelectedEntries()
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .accessibilityLabel("Delete Selected")

                                Button {
                                    selectionMode = false
                                    selectedForDeletion.removeAll()
                                } label: {
                                    Image(systemName: "xmark")
                                }
                                .accessibilityLabel("Cancel Selection")
                            } else {
                                Button {
                                    journalComposer.present(initialBody: nil, verseRef: nil, showTagColors: false)
                                } label: {
                                    Image(systemName: "square.and.pencil")
                                }
                                .tint(.blue)
                                .accessibilityLabel("New Entry")

                                Button {
                                    selectionMode = true
                                } label: {
                                    Image(systemName: "checkmark.circle")
                                }
                                .accessibilityLabel("Select")
                            }
                        }
                    }
                    .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search entries")
                    .frame(minWidth: 280)
            } detail: {
                if let e = selectedEntry {
                    if isEditing {
                        HStack(spacing: 0) {
                            editorPane(entry: e, showInlinePreview: true)
                                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .layoutPriority(1)
                            Divider()
                            ScrollView { previewPane(entry: e) }
                                .frame(minWidth: 320, idealWidth: 360, maxWidth: 420, maxHeight: .infinity, alignment: .topLeading)
                        }
                        .navigationTitle(e.title.isEmpty ? "Untitled" : e.title)
                        .toolbar {
                            ToolbarItemGroup(placement: .topBarTrailing) {
                                Button {
                                    // Cancel editing; discard tag text changes
                                    isEditing = false
                                } label: {
                                    Image(systemName: "xmark.circle")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Cancel")

                                Button {
                                    let tags = editingTagsText
                                        .split(separator: ",")
                                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                        .filter { !$0.isEmpty }
                                    e.tags = tags
                                    e.updatedAt = Date()
                                    try? ctx.save()
                                    isEditing = false
                                    recomputeFilteredEntries()
                                } label: {
                                    Image(systemName: "checkmark.circle")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Done")
                            }
                        }
                    } else {
                        Group {
                            if showPreview, previewContent != nil {
                                HStack(spacing: 0) {
                                    readOnlyPane(entry: e)
                                        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        .layoutPriority(1)
                                    Divider()
                                    ScrollView { previewPane(entry: e) }
                                        .frame(minWidth: 320, idealWidth: 360, maxWidth: 420, maxHeight: .infinity, alignment: .topLeading)
                                }
                            } else {
                                readOnlyPane(entry: e)
                            }
                        }
                        .navigationTitle(e.title.isEmpty ? "Untitled" : e.title)
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button {
                                    editingTagsText = e.tags.joined(separator: ", ")
                                    isEditing = true
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .accessibilityLabel("Edit")
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("Select an entry", systemImage: "book.closed")
                }
            }
            .navigationSplitViewStyle(.balanced)
            .onAppear {
                splitVisibility = .all
                loadPins()
                recomputeFilteredEntries()
            }
            .onChange(of: hSize) { _, _ in splitVisibility = .all }
            .onChange(of: entries) { _, _ in recomputeFilteredEntries() }
            .onChange(of: searchText) { _, _ in recomputeFilteredEntries() }
            .onChange(of: selectedTags) { _, _ in recomputeFilteredEntries() }
            .onReceive(NotificationCenter.default.publisher(for: JournalNotifications.entryCreated)) { note in
                if let id = note.userInfo?["id"] as? String {
                    refreshToken = id
                    if let created = entries.first(where: { $0.id.uuidString == id }) {
                        selectedEntry = created
                    }
                } else {
                    refreshToken = UUID().uuidString
                }
                recomputeFilteredEntries()
            }
            .onDisappear {
                filterDebounceTask?.cancel()
                filterDebounceTask = nil
            }
        } else {
            // Compact width
            NavigationStack {
                List(selection: $selectedForDeletion) {
                    Section {
                        ForEach(cachedFilteredEntries) { entry in
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
                            Button {
                                selectedTags.removeAll()
                            } label: {
                                Label("Clear Filters", systemImage: "line.3.horizontal.decrease.circle")
                            }
                        }
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if selectionMode {
                            Button(role: .destructive) {
                                deleteSelectedEntries()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .accessibilityLabel("Delete Selected")

                            Button {
                                selectionMode = false
                                selectedForDeletion.removeAll()
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel("Cancel Selection")
                        } else {
                            Button {
                                journalComposer.present(initialBody: nil, verseRef: nil, showTagColors: false)
                            } label: {
                                Image(systemName: "square.and.pencil")
                            }
                            .accessibilityLabel("New Entry")

                            Button {
                                selectionMode = true
                            } label: {
                                Image(systemName: "checkmark.circle")
                            }
                            .accessibilityLabel("Select")
                        }
                    }
                }
                .navigationTitle("Journal")
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search entries")
                .environment(\.editMode, .constant(selectionMode ? .active : .inactive))
                .navigationDestination(for: JournalEntry.self) { entry in
                    JournalDetailView(entry: entry)
                }
                .onAppear {
                    loadPins()
                    recomputeFilteredEntries()
                }
                .onChange(of: entries) { _, _ in recomputeFilteredEntries() }
                .onChange(of: searchText) { _, _ in recomputeFilteredEntries() }
                .onChange(of: selectedTags) { _, _ in recomputeFilteredEntries() }
                .onDisappear {
                    filterDebounceTask?.cancel()
                    filterDebounceTask = nil
                }
            }
        }
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
                ForEach(cachedFilteredEntries) { entry in
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
                            TagChip(text: t, tint: tint, isSelected: selectedTags.contains(t.lowercased())) {
                                toggleTagFilter(t)
                            }
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
                    TagChipRow(tags: entry.tags, selectedTags: [], showColorPicker: false, onTap: nil, onColorChange: nil)
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
                if hSize != .regular, let content = previewContent, showPreview {
                    ScripturePreviewCard(content: content, refContext: previewRef, onCopy: {
                        let verseLines = content.verses.map { "\($0.number). \($0.text)" }.joined(separator: "\n")
                        UIPasteboard.general.string = content.title + "\n" + verseLines
                    }, onClose: {
                        withAnimation(.easeOut) { showPreview = false }
                    })
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

    // Debounced save to improve typing performance and power use
    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms
            try? ctx.save()
        }
    }

    // Debounced linkify for inline overlay
    private func scheduleInlineLinkify(for text: String) {
        inlineLinkifyTask?.cancel()
        let sourceID = inlineLinkifySourceID
        inlineLinkifyTask = Task(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 180_000_000) // 180ms
            if Task.isCancelled { return }
            let result = BibleReferenceLinker.linkify(text)
            await MainActor.run {
                if sourceID == inlineLinkifySourceID {
                    self.inlineLinkedBody = result
                }
            }
        }
    }

    @ViewBuilder
    private func editorPane(entry: JournalEntry, showInlinePreview: Bool = true) -> some View {
        Form {
            Section("Title") {
                TextField("Title", text: Binding(
                    get: { entry.title },
                    set: { new in
                        entry.title = new
                        entry.updatedAt = Date()
                        scheduleAutosave()
                    }
                ))
            }
            Section("Tags") {
                TextField("Add tags (comma-separated)", text: $editingTagsText)
                    .textInputAutocapitalization(.never)
                if !parsedEditingTags.isEmpty {
                    TagChipRow(tags: parsedEditingTags, selectedTags: [], showColorPicker: true, onTap: nil, onColorChange: { tag, color in
                        TagColorStore.setColor(color, for: tag)
                    })
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
                        Text(inlineLinkedBodyMasked(from: inlineLinkedBody))
                            .font(.body)
                            .frame(maxWidth: .infinity, minHeight: hSize == .regular ? 360 : 240, alignment: .topLeading)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: Binding(
                        get: { entry.body },
                        set: { new in
                            entry.body = new
                            entry.updatedAt = Date()
                            inlineLinkifySourceID = UUID()
                            scheduleInlineLinkify(for: new)
                            scheduleAutosave()
                        }
                    ))
                    .frame(minHeight: hSize == .regular ? 360 : 240)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )
                }
            }
        }
        .onAppear {
            editingTagsText = entry.tags.joined(separator: ", ")
            inlineLinkedBody = BibleReferenceLinker.linkify(entry.body)
        }
        .onDisappear {
            autosaveTask?.cancel()
            autosaveTask = nil
            inlineLinkifyTask?.cancel()
            inlineLinkifyTask = nil
            inlineLinkifySourceID = UUID()
            // Final save on exit edit pane
            try? ctx.save()
        }
    }

    // Make non-link text transparent, style links blue/underlined
    private func inlineLinkedBodyMasked(from linked: AttributedString) -> AttributedString {
        var s = linked
        s.foregroundColor = .clear
        for run in s.runs where run.link != nil {
            s[run.range].foregroundColor = .blue
            s[run.range].underlineStyle = .single
        }
        return s
    }

    @ViewBuilder
    private func previewPane(entry: JournalEntry) -> some View {
        let linkedForRefs = BibleReferenceLinker.linkify(entry.body)
        let refs: [ScriptureRef] = ScriptureRefExtractor.refs(in: linkedForRefs)

        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.title.isEmpty ? "Untitled" : entry.title)
                    .font(.title3).bold()

                if !refs.isEmpty {
                    ScriptureLinksList(
                        refs: refs,
                        onTap: { r in
                            if let content = BibleReferenceLinker.loadVerses(for: r) {
                                previewRef = r
                                previewContent = content
                                withAnimation(.spring()) { showPreview = true }
                            }
                        },
                        onCopy: { r in
                            let display: String = {
                                if let end = r.endVerse, end != r.startVerse { return "\(r.bookName) \(r.chapter):\(r.startVerse)-\(end)" }
                                return "\(r.bookName) \(r.chapter):\(r.startVerse)"
                            }()
                            UIPasteboard.general.string = display
                        }
                    )
                }

                if showPreview, let content = previewContent {
                    ScripturePreviewCard(content: content, refContext: previewRef, onCopy: {
                        let verseLines = content.verses.map { "\($0.number). \($0.text)" }.joined(separator: "\n")
                        UIPasteboard.general.string = content.title + "\n" + verseLines
                    }, onClose: {
                        withAnimation(.easeOut) { showPreview = false }
                    })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(16)
        }
        .id(entry.body)
    }

    private var parsedEditingTags: [String] {
        editingTagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

#Preview {
    JournalTabView()
}

