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
    // Use SwiftData's stable PersistentIdentifier for multi-select
    @State private var selectedForDeletion: Set<PersistentIdentifier> = []
    @State private var searchText: String = ""

    @State private var previewRef: ScriptureRef? = nil
    @State private var previewContent: (title: String, verses: [Verse])? = nil
    @State private var showPreview: Bool = false

    @State private var editingTagsText: String = ""

    @State private var selectedTags: Set<String> = []
    @State private var refreshToken: String = ""
    @State private var splitVisibility: NavigationSplitViewVisibility = .all

    @State private var cachedFilteredEntries: [JournalEntry] = []
    @State private var filterDebounceTask: Task<Void, Never>? = nil

    @AppStorage("journalPinnedIDs") private var pinnedIDsRaw: String = ""
    @State private var pinnedIDs: Set<String> = []

    // Inline editor autosave
    @State private var autosaveTask: Task<Void, Never>? = nil

    // Inline linkify cache for preview overlay (debounced)
    @State private var inlineLinkedBody: AttributedString = AttributedString("")
    @State private var inlineLinkifyTask: Task<Void, Never>? = nil
    @State private var inlineLinkifySourceID: UUID = UUID()

    // Caret tracking for edit mode body
    @State private var editSelection: NSRange = NSRange(location: 0, length: 0)
    @State private var editCaretRect: CGRect? = nil
    // Keyboard bottom inset for inline editor
    @State private var editBottomInset: CGFloat = 0

    // Delete confirmations
    @State private var pendingDeleteEntry: JournalEntry? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var showBulkDeleteAlert: Bool = false

    // Track when we’re creating a brand-new entry inline (iPad)
    @State private var isCreatingNewEntry: Bool = false

    // Shared right pane mode with the composer/editor
    private enum RightPaneMode: String, CaseIterable, Identifiable {
        case smartLinks = "Smart Links"
        case bible = "Bible"
        var id: String { rawValue }
    }
    @AppStorage("journalRightPaneMode") private var rightPaneMode: RightPaneMode = .smartLinks

    private func loadPins() {
        let parts = pinnedIDsRaw.split(separator: ",").map { String($0) }
        pinnedIDs = Set(parts)
    }
    private func persistPins() {
        pinnedIDsRaw = pinnedIDs.joined(separator: ",")
    }
    private func isPinned(_ entry: JournalEntry) -> Bool {
        guard let key = entry.uuid?.uuidString else { return false }
        return pinnedIDs.contains(key)
    }
    private func togglePin(_ entry: JournalEntry) {
        guard let key = entry.uuid?.uuidString else { return }
        if pinnedIDs.contains(key) {
            pinnedIDs.remove(key)
            entry.isPinned = false
        } else {
            pinnedIDs.insert(key)
            entry.isPinned = true
        }
        persistPins()
        try? ctx.save()
        recomputeFilteredEntries()
    }

    // MARK: - Filter state helpers

    private var isFiltered: Bool {
        let queryActive = !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let tagsActive = !selectedTags.isEmpty
        return queryActive || tagsActive
    }

    private var filteredDescription: String {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = Array(selectedTags).sorted()

        switch (tags.isEmpty, query.isEmpty) {
        case (false, false):
            return "Tags: \(tags.joined(separator: ", ")) • Search: “\(query)”"
        case (false, true):
            return "Tags: \(tags.joined(separator: ", "))"
        case (true, false):
            return "Search: “\(query)”"
        default:
            return ""
        }
    }

    private var headerCountText: String {
        let count = isFiltered ? cachedFilteredEntries.count : entries.count
        let noun = (count == 1) ? "entry" : "entries"
        return "\(count) \(noun)" + (isFiltered ? " (filtered)" : "")
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
        if selectedEntry?.uuid == entry.uuid { selectedEntry = nil }
        recomputeFilteredEntries()
    }

    private func deleteSelectedEntries() {
        // Map selected ids (PersistentIdentifier) to entries and delete
        let ids = selectedForDeletion
        let toDelete = entries.filter { ids.contains($0.persistentModelID) }
        for entry in toDelete {
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
            try? await Task.sleep(nanoseconds: 120_000_000)
            var list = currentEntries
            if !currentTags.isEmpty {
                let target = Set(currentTags.map { $0.lowercased() })
                list = list.filter { entry in
                    let entryTags = Set(entry.tags.map { $0.lowercased() })
                    return target.isSubset(of: entryTags)
                }
            }
            if !currentQuery.isEmpty {
                list = list.filter { entry in
                    let titleMatch = entry.title.localizedCaseInsensitiveContains(currentQuery)
                    let tagsMatch = entry.tags.contains { $0.localizedCaseInsensitiveContains(currentQuery) }
                    let bodyMatch = entry.body.localizedCaseInsensitiveContains(currentQuery)
                    return titleMatch || tagsMatch || bodyMatch
                }
            }
            // Preserve the current order using object identity (id is optional)
            let indexMap: [ObjectIdentifier: Int] = Dictionary(uniqueKeysWithValues: currentEntries.enumerated().map { (ObjectIdentifier($1), $0) })
            list.sort { lhs, rhs in
                let lp = currentPins.contains(lhs.uuid?.uuidString ?? "")
                let rp = currentPins.contains(rhs.uuid?.uuidString ?? "")
                if lp != rp { return lp && !rp }
                let li = indexMap[ObjectIdentifier(lhs)] ?? 0
                let ri = indexMap[ObjectIdentifier(rhs)] ?? 0
                return li < ri
            }
            cachedFilteredEntries = list
        }
    }

    // MARK: - iPad inline "New" support

    private func startInlineNewEntry(initialBody: String? = nil, verseRef: ScriptureRef? = nil) {
        let e = JournalEntry()
        if let body = initialBody { e.body = body }
        if let ref = verseRef {
            e.verseRef = VerseRef(book: ref.bookName, chapter: ref.chapter, verse: ref.startVerse, translation: nil)
        }
        e.updatedAt = Date()
        ctx.insert(e)
        try? ctx.save()

        selectedEntry = e
        isEditing = true
        isCreatingNewEntry = true
        recomputeFilteredEntries()
    }

    var body: some View {
        if hSize == .regular {
            ipadSplitView
        } else {
            compactNavigationStack
        }
    }

    // MARK: - iPad layout

    @ToolbarContentBuilder
    private var ipadSidebarToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if isFiltered {
                Button {
                    clearAllFilters()
                } label: {
                    Label("Clear Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(ToolbarPillButtonStyle(tint: .accentColor))
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            if selectionMode {
                Button(role: .destructive) {
                    // iPad: delete immediately without confirmation
                    deleteSelectedEntries()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(ToolbarPillButtonStyle(tint: .red))

                Button {
                    selectionMode = false
                    selectedForDeletion.removeAll()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                }
                .buttonStyle(ToolbarPillButtonStyle(tint: .gray))
            } else {
                Button {
                    // iPad: create inline and start editing in the detail column
                    startInlineNewEntry()
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(ToolbarPillButtonStyle(tint: .accentColor))

                Button {
                    selectionMode = true
                } label: {
                    Label("Select", systemImage: "checkmark.circle")
                }
                .buttonStyle(ToolbarPillButtonStyle(tint: .blue))
            }
        }
    }

    // Extracted sidebar view to reduce type-checker complexity
    private var ipadSidebar: some View {
        VStack(spacing: 0) {
            if isFiltered {
                FilterBanner(text: filteredDescription, onClear: clearAllFilters)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
            }
            sidebarList
        }
        .navigationTitle(isFiltered ? "Journal\nFiltered" : "Journal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ipadSidebarToolbar }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search entries")
        .frame(minWidth: 280)
    }

    private func clearAllFilters() {
        withAnimation(.spring()) {
            selectedTags.removeAll()
            searchText = ""
        }
        recomputeFilteredEntries()
    }

    private func handleSplitOnAppear() {
        splitVisibility = .all
        loadPins()
        recomputeFilteredEntries()
    }

    private func handleEntriesChange() {
        recomputeFilteredEntries()
    }

    private func handleSearchChange() {
        recomputeFilteredEntries()
    }

    private func handleTagsChange() {
        recomputeFilteredEntries()
    }

    private func handleCreatedNotification(_ note: Notification) {
        if let id = note.userInfo?["id"] as? String {
            refreshToken = id
            if let created = entries.first(where: { $0.uuid?.uuidString == id }) {
                selectedEntry = created
            }
        } else {
            refreshToken = UUID().uuidString
        }
        recomputeFilteredEntries()
    }

    private var ipadSplitView: some View {
        // Erase the sidebar and detail to AnyView to keep generic depth shallow
        let sidebar = AnyView(ipadSidebar)
        let detail = AnyView(ipadDetailContent)

        // Build split view in two steps to avoid huge single expression
        let baseSplit = NavigationSplitView(columnVisibility: $splitVisibility) {
            sidebar
        } detail: {
            detail
        }

        // Apply modifiers in smaller chained steps
        let configuredSplit = baseSplit
            .navigationSplitViewStyle(.balanced)

        return configuredSplit
            .onAppear { handleSplitOnAppear() }
            .onChange(of: hSize) { _, _ in splitVisibility = .all }
            .onChange(of: entries) { _, _ in handleEntriesChange() }
            .onChange(of: searchText) { _, _ in handleSearchChange() }
            .onChange(of: selectedTags) { _, _ in handleTagsChange() }
            .onReceive(NotificationCenter.default.publisher(for: JournalNotifications.entryCreated)) { note in
                handleCreatedNotification(note)
            }
            // NEW: Handle “start inline new from Bible” routed from ReadingView on iPad
            .onReceive(NotificationCenter.default.publisher(for: JournalNotifications.startInlineNewFromBible)) { note in
                let book = note.userInfo?["book"] as? String ?? ""
                let chapter = note.userInfo?["chapter"] as? Int ?? 0
                let verse = note.userInfo?["verse"] as? Int ?? 0
                guard !book.isEmpty, chapter > 0, verse > 0 else { return }
                let ref = ScriptureRef(bookName: book, chapter: chapter, startVerse: verse, endVerse: nil)
                startInlineNewEntry(initialBody: nil, verseRef: ref)
            }
            .onDisappear {
                filterDebounceTask?.cancel()
                filterDebounceTask = nil
            }
    }

    // Extracted detail content to lighten the NavigationSplitView expression
    @ViewBuilder
    private var ipadDetailContent: some View {
        Group {
            if let e = selectedEntry {
                if isEditing {
                    iPadEditingDetail(entry: e)
                } else {
                    iPadReadOnlyDetail(entry: e)
                }
            } else {
                ContentUnavailableView("Select an entry", systemImage: "book.closed")
            }
        }
    }

    // MARK: - iPad subviews

    private func iPadEditingDetail(entry e: JournalEntry) -> some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Button("Save") {
                            let tags = editingTagsText
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                            e.tags = tags
                            e.updatedAt = Date()
                            try? ctx.save()
                            isEditing = false
                            isCreatingNewEntry = false
                            recomputeFilteredEntries()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)

                        Spacer(minLength: 0)

                        Button("Cancel") {
                            // If this was a brand-new entry and still blank, discard it.
                            if isCreatingNewEntry {
                                let isBlank = e.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    && e.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    && e.tags.isEmpty
                                if isBlank {
                                    ctx.delete(e)
                                    try? ctx.save()
                                    selectedEntry = nil
                                    recomputeFilteredEntries()
                                }
                                isCreatingNewEntry = false
                            }
                            isEditing = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Title", text: Binding(
                            get: { e.title },
                            set: { new in
                                e.title = new
                                e.updatedAt = Date()
                                scheduleAutosave()
                            }
                        ))
                        .font(.title2.weight(.semibold))
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(false)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                        TextField("Add tags (comma-separated)", text: $editingTagsText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)

                        if !parsedEditingTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    TagChipRow(
                                        tags: parsedEditingTags,
                                        selectedTags: [],
                                        showColorPicker: true,
                                        onTap: nil,
                                        onColorChange: { tag, color in TagColorStore.setColor(color, for: tag) }
                                    )
                                }
                                .padding(.horizontal, 12)
                            }
                        }

                        ZStack(alignment: .topLeading) {
                            if e.body.isEmpty {
                                Text("Write your thoughts here…")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 10)
                                    .padding(.leading, 14)
                            }
                            CursorTextView(
                                text: Binding(
                                    get: { e.body },
                                    set: { new in
                                        e.body = new
                                        e.updatedAt = Date()
                                        inlineLinkifySourceID = UUID()
                                        scheduleInlineLinkify(for: new)
                                        scheduleAutosave()
                                    }
                                ),
                                selection: $editSelection,
                                caretRect: $editCaretRect,
                                bottomInset: $editBottomInset
                            )
                            .frame(minHeight: 400)
                        }
                        .padding(.bottom, 12)
                    }
                    .padding(.vertical, 8)
                }
            }
            .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, 1)
            .layoutPriority(1)
            .onAppear {
                editingTagsText = e.tags.joined(separator: ", ")
                inlineLinkedBody = BibleReferenceLinker.linkify(e.body)
            }
            .onDisappear {
                autosaveTask?.cancel()
                autosaveTask = nil
                inlineLinkifyTask?.cancel()
                inlineLinkifyTask = nil
                inlineLinkifySourceID = UUID()
                try? ctx.save()
            }

            Divider()

            // New right pane with toggle mirroring the editor
            VStack(alignment: .leading, spacing: 12) {
                Picker("Right Pane", selection: $rightPaneMode) {
                    ForEach(RightPaneMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Divider()

                Group {
                    switch rightPaneMode {
                    case .smartLinks:
                        ScrollView { previewPane(entry: e) }
                    case .bible:
                        BibleReaderForJournal(
                            onInsertText: { book, chapter, verse, text in
                                insertPlainText(text, into: e)
                            },
                            onInsertLink: { book, chapter, verse in
                                let refText = "\(book) \(chapter):\(verse)"
                                insertSmartLink(refText, into: e)
                            },
                            onFavorite: { book, chapter, verse, text in
                                let fav = Favorite(bookName: book, chapterNumber: chapter, verseNumber: verse, verseText: text)
                                ctx.insert(fav)
                                try? ctx.save()
                            }
                        )
                    }
                }
            }
            .frame(minWidth: 320, idealWidth: 360, maxWidth: 420, maxHeight: .infinity, alignment: .topLeading)
            .layoutPriority(0)
        }
        .zIndex(1)
        .navigationTitle(e.title.isEmpty ? "Untitled" : e.title)
        .toolbar { }
        .eraseToAnyView()
    }

    private func iPadReadOnlyDetail(entry e: JournalEntry) -> some View {
        Group {
            if showPreview, previewContent != nil {
                HStack(spacing: 0) {
                    readOnlyPane(entry: e)
                        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.leading, 1)
                        .layoutPriority(1)
                        .contentShape(Rectangle())
                        .onTapGesture { isEditing = true }
                    Divider()
                    ScrollView { previewPane(entry: e) }
                        .frame(minWidth: 320, idealWidth: 360, maxWidth: 420, maxHeight: .infinity, alignment: .topLeading)
                        .layoutPriority(0)
                }
                .zIndex(1)
            } else {
                readOnlyPane(entry: e)
                    .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, 1)
                    .contentShape(Rectangle())
                    .onTapGesture { isEditing = true }
                    .zIndex(1)
            }
        }
        .navigationTitle(e.title.isEmpty ? "Untitled" : e.title)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                let shareTitle: String = e.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : e.title
                let bodyText = e.body.trimmingCharacters(in: .whitespacesAndNewlines)
                let shareText = bodyText.isEmpty ? shareTitle : "\(shareTitle)\n\n\(bodyText)"
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .eraseToAnyView()
    }

    // MARK: - iPhone layout

    // Compact header row removed per request

    @ViewBuilder
    private var compactList: some View {
        CompactJournalList(
            entries: cachedFilteredEntries,
            isFiltered: isFiltered,
            headerCountText: headerCountText,
            filteredDescription: filteredDescription,
            selection: $selectedForDeletion,
            selectionMode: selectionMode,
            selectedTags: selectedTags,
            onTagTapped: { toggleTagFilter($0) }, onClearFilters: clearAllFilters,
            isPinned: { isPinned($0) },
            onTogglePin: { on in togglePin(on) },
            onRequestDelete: { entry in
                pendingDeleteEntry = entry
                showDeleteAlert = true
            }
        )
        .navigationTitle(isFiltered ? "Journal\nFiltered" : "Journal")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var compactNavigationStack: some View {
        let list = AnyView(compactList)

        let base = NavigationStack {
            list
                .navigationDestination(for: JournalEntry.self) { entry in
                    JournalDetailView(entry: entry)
                        .navigationTitle(entry.title.isEmpty ? "Entry" : entry.title)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if selectionMode {
                            Button(role: .destructive) {
                                if selectedForDeletion.isEmpty {
                                    // No selection yet: show a confirmation anyway
                                    showBulkDeleteAlert = true
                                } else {
                                    showBulkDeleteAlert = true
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .buttonStyle(ToolbarPillButtonStyle(tint: .red))

                            Button {
                                selectionMode = false
                                selectedForDeletion.removeAll()
                            } label: {
                                Label("Cancel", systemImage: "xmark")
                            }
                            .buttonStyle(ToolbarPillButtonStyle(tint: .gray))
                        } else {
                            Button {
                                // New: create entry and present editor via composer
                                let e = JournalEntry()
                                e.updatedAt = Date()
                                ctx.insert(e)
                                try? ctx.save()
                                // Navigate to detail first (so user sees it in stack), then present editor
                                journalComposer.presentForEditing(entry: e)
                            } label: {
                                Label("New", systemImage: "plus")
                            }
                            .buttonStyle(ToolbarPillButtonStyle(tint: .accentColor))

                            Button {
                                selectionMode = true
                                selectedForDeletion.removeAll()
                            } label: {
                                Label("Select", systemImage: "checkmark.circle")
                            }
                            .buttonStyle(ToolbarPillButtonStyle(tint: .blue))
                        }
                    }
                }
        }

        let configured = base
            .environment(\.editMode, .constant(selectionMode ? .active : .inactive))

        return configured
            // Header bar removed: no safeAreaInset injected
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search entries")
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
            .alert("Delete this entry?", isPresented: $showDeleteAlert, presenting: pendingDeleteEntry) { entry in
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteEntry(entry)
                    pendingDeleteEntry = nil
                }
            } message: { _ in
                Text("This action cannot be undone.")
            }
            .alert("Delete selected entries?", isPresented: $showBulkDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteSelectedEntries()
                }
            } message: {
                Text("This action cannot be undone.")
            }
    }

    @ViewBuilder
    private var sidebarList: some View {
        SidebarJournalList(
            entries: cachedFilteredEntries,
            headerCountText: headerCountText,
            selection: $selectedForDeletion,
            selectionMode: selectionMode,
            selectedTags: selectedTags,
            onToggleTag: { toggleTagFilter($0) },
            isPinned: { isPinned($0) },
            onTogglePin: { on in togglePin(on) },
            onRequestDelete: { e in
                // iPad: delete immediately without confirmation
                deleteEntry(e)
            },
            onTapEntry: { e in
                selectedEntry = e
                isEditing = false
            },
            isEntryCurrentlySelected: { e in
                (hSize == .regular) && (selectedEntry?.uuid == e.uuid)
            }
        )
    }

    // Read-only pane (unchanged)
    @ViewBuilder
    private func readOnlyPane(entry: JournalEntry) -> some View {
        let linkedBody = BibleReferenceLinker.linkify(entry.body)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if hSize != .regular {
                    Text(entry.title.isEmpty ? "Untitled" : entry.title)
                        .font(.title2).bold()
                }
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
                    Text("Created: \(entry.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Updated: \(entry.updatedAt?.formatted(date: .abbreviated, time: .shortened) ?? "—")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            try? ctx.save()
        }
    }

    private func scheduleInlineLinkify(for text: String) {
        inlineLinkifyTask?.cancel()
        let sourceID = inlineLinkifySourceID
        inlineLinkifyTask = Task(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 180_000_000)
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
                    CursorTextView(
                        text: Binding(
                            get: { entry.body },
                            set: { new in
                                entry.body = new
                                entry.updatedAt = Date()
                                inlineLinkifySourceID = UUID()
                                scheduleInlineLinkify(for: new)
                                scheduleAutosave()
                            }
                        ),
                        selection: $editSelection,
                        caretRect: $editCaretRect, bottomInset: $editBottomInset
                    )
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
            try? ctx.save()
        }
    }

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

    // MARK: - Smart link insertion (simplified)

    private func insertSmartLink(_ refText: String, into entry: JournalEntry) {
        var t = entry.body
        let loc = min(max(editSelection.location, 0), (t as NSString).length)
        if let idx = t.utf16.index(t.utf16.startIndex, offsetBy: loc, limitedBy: t.utf16.endIndex)?.samePosition(in: t) {
            // Append a trailing space so typing continues outside the link
            let insertion = refText + " "
            t.insert(contentsOf: insertion, at: idx)
            entry.body = t
            editSelection = NSRange(location: loc + insertion.utf16.count, length: 0)
            inlineLinkifySourceID = UUID()
            scheduleInlineLinkify(for: entry.body)
            entry.updatedAt = Date()
            scheduleAutosave()
        }
    }

    // Insert plain text at the current caret in the editor, updating selection and saving
    private func insertPlainText(_ text: String, into entry: JournalEntry) {
        var t = entry.body
        let loc = min(max(editSelection.location, 0), (t as NSString).length)
        if let idx = t.utf16.index(t.utf16.startIndex, offsetBy: loc, limitedBy: t.utf16.endIndex)?.samePosition(in: t) {
            t.insert(contentsOf: text, at: idx)
            entry.body = t
            editSelection = NSRange(location: loc + text.utf16.count, length: 0)
            inlineLinkifySourceID = UUID()
            scheduleInlineLinkify(for: entry.body)
            entry.updatedAt = Date()
            scheduleAutosave()
        }
    }
}

private extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}

// MARK: - Filter banner

// Made internal (not private) so CompactJournalList/SidebarJournalList can use it
struct FilterBanner: View {
    let text: String
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Showing filtered results")
                    .font(.subheadline).bold()
                if !text.isEmpty {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Button("Clear") { onClear() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.blue.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.blue.opacity(0.35), lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack { ReferenceMatchGameView() }
}
