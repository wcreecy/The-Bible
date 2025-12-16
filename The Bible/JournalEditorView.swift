import SwiftUI
import SwiftData
import UIKit

struct JournalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(\.horizontalSizeClass) private var hSize

    let verseRef: VerseRef?
    let showTagColors: Bool
    let onClose: (() -> Void)?

    // Initial snapshots to detect "dirty" state
    private let initialTitle: String
    private let initialContent: String
    private let initialTagsText: String

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var tagsText: String = ""

    @State private var previewRef: ScriptureRef? = nil
    @State private var previewContent: (title: String, verses: [Verse])? = nil
    @State private var showPreview: Bool = false

    @State private var showSaveError = false
    @State private var saveErrorMessage: String = ""
    @State private var showCopyToast: Bool = false
    @State private var showSavedToast: Bool = false
    @State private var editingEntry: JournalEntry? = nil

    // NEW: in-progress draft (for new entries)
    @State private var draftEntry: JournalEntry? = nil
    // Debounced autosave task
    @State private var autosaveTask: Task<Void, Never>? = nil

    // Discard protection
    @State private var showDiscardAlert: Bool = false

    // Caret/selection tracking
    @State private var textSelectionRange: NSRange = NSRange(location: 0, length: 0)
    @State private var caretRect: CGRect? = nil
    // Ensure we only set the initial caret once
    @State private var didSetInitialSelection: Bool = false

    // Linkify cache
    @State private var linkedContent: AttributedString = AttributedString("")
    @State private var linkifyTask: Task<Void, Never>? = nil

    // Keyboard inset for iPhone editor
    @State private var bottomEditorInset: CGFloat = 0

    // Right pane toggle (iPad only) + shared persisted mode
    private enum RightPaneMode: String, CaseIterable, Identifiable {
        case smartLinks = "Smart Links"
        case bible = "Bible"
        var id: String { rawValue }
    }
    @AppStorage("journalRightPaneMode") private var rightPaneModeRaw: String = RightPaneMode.smartLinks.rawValue
    private var rightPaneMode: RightPaneMode {
        get { RightPaneMode(rawValue: rightPaneModeRaw) ?? .smartLinks }
        set { rightPaneModeRaw = newValue.rawValue }
    }

    // Collapsible “Preview & Bible” section (iPhone) no longer used; we switch full-screen
    @State private var showToolsSection: Bool = true

    // Tag colors UX: single toggle used on both platforms (only shown on iPad)
    @State private var showTagColorsToggle: Bool = false

    // iPhone: full-screen Bible mode toggle
    @State private var isShowingBibleReader: Bool = false

    init(verseRef: VerseRef?, initialBody: String? = nil, showTagColors: Bool = false, editingEntry: JournalEntry? = nil, onClose: (() -> Void)? = nil) {
        self.verseRef = verseRef
        self.showTagColors = showTagColors
        self._editingEntry = State(initialValue: editingEntry)
        self.onClose = onClose

        if let editingEntry {
            let t = editingEntry.title
            let b = editingEntry.body
            let tg = editingEntry.tags.joined(separator: ", ")
            self._title = State(initialValue: t)
            self._content = State(initialValue: b)
            self._tagsText = State(initialValue: tg)
            self.initialTitle = t
            self.initialContent = b
            self.initialTagsText = tg
        } else {
            var startContent = initialBody ?? ""
            if let verseRef {
                let smart = Self.smartLinkString(from: verseRef)
                if let initialBody, !initialBody.isEmpty {
                    startContent = smart + "\n" + initialBody
                } else {
                    // IMPORTANT: add a trailing space so the caret (at end) is outside the link range
                    startContent = smart + " "
                }
            }
            self._title = State(initialValue: "")
            self._content = State(initialValue: startContent)
            self._tagsText = State(initialValue: "")
            self.initialTitle = ""
            self.initialContent = startContent
            self.initialTagsText = ""
        }
    }

    private var isDirty: Bool {
        let currentTags = tagsText.trimmingCharacters(in: .whitespacesAndNewlines)
        let initialTags = initialTagsText.trimmingCharacters(in: .whitespacesAndNewlines)
        return title != initialTitle || content != initialContent || currentTags != initialTags
    }

    // Share text mirrors JournalDetailView
    private var shareText: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : title
        let b = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return b.isEmpty ? t : "\(t)\n\n\(b)"
    }

    var body: some View {
        NavigationStack {
            Group {
                if hSize == .regular {
                    regularLayoutWithBottomSave
                } else {
                    // iPhone: toggle between editor and bible reader
                    if isShowingBibleReader {
                        bibleReaderFullScreen
                    } else {
                        compactFullScreenEditor
                    }
                }
            }
            .navigationTitle(
                {
                    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    if editingEntry != nil {
                        return trimmed.isEmpty ? "Untitled" : trimmed
                    } else {
                        return trimmed.isEmpty ? "New Entry" : trimmed
                    }
                }()
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        if isDirty {
                            showDiscardAlert = true
                        } else {
                            if let onClose { onClose() } else { dismiss() }
                        }
                    }
                    .keyboardShortcut("w", modifiers: [.command])
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if hSize != .regular {
                        // iPhone: single toggle button (book <-> notes)
                        Button {
                            isShowingBibleReader.toggle()
                        } label: {
                            if isShowingBibleReader {
                                Label("Notes", systemImage: "note.text")
                            } else {
                                Label("Bible", systemImage: "book")
                            }
                        }
                        .accessibilityHint(isShowingBibleReader ? "Return to notes editor" : "Open Bible reader full screen")
                    }
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Button("Save") {
                        save(manual: true)
                    }
                    .bold()
                    .keyboardShortcut("s", modifiers: [.command])
                }
            }
            .alert("Couldn’t Save Entry", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
            .alert("Discard changes?", isPresented: $showDiscardAlert) {
                Button("Keep Editing", role: .cancel) {}
                Button("Discard", role: .destructive) {
                    if let onClose { onClose() } else { dismiss() }
                }
            } message: {
                Text("You have unsaved changes. If you discard now, your edits will be lost.")
            }
            .appToast(isPresented: $showCopyToast, symbol: "doc.on.doc", text: "Copied to Clipboard", tint: .blue)
            .appToast(isPresented: $showSavedToast, symbol: "Saved", text: "Entry Saved", tint: .green)
            .onAppear {
                // Preseed linkify and tag-colors toggle from caller (optional)
                showTagColorsToggle = showTagColors || (editingEntry != nil)
                scheduleLinkify(for: content)
                // Ensure caret starts after the trailing space/newline we added for new entries
                if !didSetInitialSelection && editingEntry == nil {
                    didSetInitialSelection = true
                    let end = (content as NSString).length
                    textSelectionRange = NSRange(location: end, length: 0)
                }
            }
            .onDisappear {
                linkifyTask?.cancel()
                autosaveTask?.cancel()
                autosaveTask = nil
            }
        }
        // Prevent swipe-to-dismiss if there are unsaved changes
        .interactiveDismissDisabled(isDirty)
        // Debounced autosave triggers
        .onChange(of: title) { _, _ in scheduleAutosave() }
        .onChange(of: content) { _, newValue in
            scheduleLinkify(for: newValue)
            scheduleAutosave()
        }
        .onChange(of: tagsText) { _, _ in scheduleAutosave() }
    }

    // MARK: - Compact (iPhone) Editor

    private var compactFullScreenEditor: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Title", text: $title)
                        .font(.title2.weight(.semibold))
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(false)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Add tags (comma-separated)", text: $tagsText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)

                    if !parsedTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                TagChipRow(
                                    tags: parsedTags,
                                    selectedTags: [],
                                    showColorPicker: false,
                                    onTap: nil,
                                    onColorChange: nil
                                )
                            }
                            .padding(.horizontal, 12)
                        }
                    }

                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text("Write your thoughts here…")
                                .foregroundStyle(.secondary)
                                .padding(.top, 10)
                                .padding(.leading, 14)
                        }
                        CursorTextView(
                            text: $content,
                            selection: $textSelectionRange,
                            caretRect: $caretRect,
                            bottomInset: $bottomEditorInset,
                            onChange: { newText in
                                scheduleLinkify(for: newText)
                            },
                            linkify: { text in
                                BibleReferenceLinker.linkify(text)
                            },
                            onLinkTap: { ref in
                                if let content = BibleReferenceLinker.loadVerses(for: ref) {
                                    previewRef = ref
                                    previewContent = content
                                    withAnimation(.spring()) { showPreview = true }
                                }
                            }
                        )
                        .frame(minHeight: 400)
                    }
                    .padding(.bottom, 6)
                }
                .padding(.vertical, 8)
                // Ensure the overall scroll content avoids being covered by the keyboard
                .padding(.bottom, bottomEditorInset)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .background(KeyboardInsetReader(inset: $bottomEditorInset))
    }

    // MARK: - Compact (iPhone) Full-screen Bible Reader

    private var bibleReaderFullScreen: some View {
        VStack(spacing: 0) {
            BibleReaderForJournal(
                onInsertText: { book, chapter, verse, text in
                    insertVerseText(book: book, chapter: chapter, verse: verse, text: text)
                    isShowingBibleReader = false
                },
                onInsertLink: { book, chapter, verse in
                    insertVerseLink(book: book, chapter: chapter, verse: verse)
                    isShowingBibleReader = false
                },
                onFavorite: { _, _, _, _ in
                    // No-op here; favorites handled elsewhere
                }
            )
        }
        // Removed back chevron; the trailing toggle button handles returning to editor
    }

    // Helpers to insert into editor content at current cursor position
    private func insertAtCursor(_ insertion: String) {
        var ns = content as NSString
        let range = textSelectionRange
        let safeLoc = max(0, min(range.location, ns.length))
        let safeLen = max(0, min(range.length, ns.length - safeLoc))
        let replaceRange = NSRange(location: safeLoc, length: safeLen)
        ns = ns.replacingCharacters(in: replaceRange, with: insertion) as NSString
        content = ns as String

        // Move caret to end of inserted text
        let newLocation = safeLoc + (insertion as NSString).length
        textSelectionRange = NSRange(location: newLocation, length: 0)
        scheduleLinkify(for: content)
        scheduleAutosave()
    }

    private func insertVerseText(book: String, chapter: Int, verse: Int, text: String) {
        // Add newline after the reference so typing continues outside the link
        let insertion = "\(text)\n\(book) \(chapter):\(verse)\n"
        insertAtCursor(insertion)
    }

    private func insertVerseLink(book: String, chapter: Int, verse: Int) {
        // Add a trailing space so the caret is outside the link range
        let insertion = "\(book) \(chapter):\(verse) "
        insertAtCursor(insertion)
    }

    // MARK: - Layouts with bottom Save (iPad/regular width only)

    private var regularLayoutWithBottomSave: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                editorColumn
                    .frame(minWidth: 360, idealWidth: 480, maxWidth: .infinity, alignment: .topLeading)
                    .background(Color(.systemBackground))
                Divider()
                rightPaneColumn
                    .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            bottomSaveBar
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var bottomSaveBar: some View {
        ZStack {
            VisualEffectMaterial()
                .overlay(
                    Rectangle()
                        .fill(Color.black.opacity(0.08))
                        .frame(height: 0.5)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .opacity(0.6)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -1)

            HStack {
                Spacer(minLength: 0)
                Button {
                    save(manual: true)
                } label: {
                    Text("Save Entry")
                        .font(.headline)
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(LocalPillButtonStyle(tint: .accentColor))
                .controlSize(.large)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity)
    }

    private struct VisualEffectMaterial: View {
        var body: some View {
            Rectangle()
                .fill(.ultraThinMaterial)
                .frame(height: 64)
                .frame(maxWidth: .infinity)
                .overlay(Color.clear)
        }
    }

    private var editorColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Title", text: $title)
                    .font(.title2.weight(.semibold))
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Add tags (comma-separated)", text: $tagsText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Toggle(isOn: $showTagColorsToggle) {
                        Label("Edit Tag Colors", systemImage: "paintpalette")
                    }
                    .font(.footnote)
                    .tint(.accentColor)
                }
                .padding(.horizontal, 12)

                if !parsedTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            TagChipRow(
                                tags: parsedTags,
                                selectedTags: [],
                                showColorPicker: showTagColorsToggle,
                                onTap: nil,
                                onColorChange: showTagColorsToggle ? { tag, color in
                                    TagColorStore.setColor(color, for: tag)
                                } : nil
                            )
                        }
                        .padding(.horizontal, 12)
                    }
                }

                ZStack(alignment: .topLeading) {
                    if content.isEmpty {
                        Text("Write your thoughts here…")
                            .foregroundStyle(.secondary)
                            .padding(.top, 10)
                            .padding(.leading, 14)
                    }
                    CursorTextView(
                        text: $content,
                        selection: $textSelectionRange,
                        caretRect: $caretRect,
                        bottomInset: .constant(0),
                        onChange: { newText in
                            scheduleLinkify(for: newText)
                        },
                        linkify: { text in
                            BibleReferenceLinker.linkify(text)
                        },
                        onLinkTap: { ref in
                            // On iPad, route to split preview via notification
                            NotificationCenter.default.post(
                                name: JournalNotifications.openScripturePreview,
                                object: nil,
                                userInfo: [
                                    "book": ref.bookName,
                                    "chapter": ref.chapter,
                                    "start": ref.startVerse,
                                    "end": ref.endVerse as Any
                                ]
                            )
                        }
                    )
                    .frame(minHeight: 400)
                }
                .padding(.bottom, 12)
            }
            .padding(.vertical, 8)
        }
    }

    // iPad right pane with persisted toggle. Includes Tag Colors subsection under Smart Links.
    private var rightPaneColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Right Pane", selection: Binding(
                get: { rightPaneMode },
                set: { newValue in rightPaneModeRaw = newValue.rawValue }
            )) {
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
                    VStack(alignment: .leading, spacing: 12) {
                        previewColumn

                        if !parsedTags.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Tag Colors").font(.caption).foregroundStyle(.secondary)
                                    Spacer()
                                    Toggle("Edit", isOn: $showTagColorsToggle).labelsHidden()
                                }
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        TagChipRow(
                                            tags: parsedTags,
                                            selectedTags: [],
                                            showColorPicker: showTagColorsToggle,
                                            onTap: nil,
                                            onColorChange: showTagColorsToggle ? { tag, color in
                                                TagColorStore.setColor(color, for: tag)
                                            } : nil
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        }
                    }
                case .bible:
                    BibleReaderForJournal()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    // MARK: - Smart Links preview building blocks

    private var previewColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(title.isEmpty ? "Untitled" : title)
                    .font(.title3).bold()

                let refs: [ScriptureRef] = ScriptureRefExtractor.refs(in: linkedContent)
                if !refs.isEmpty {
                    Text("Scripture Links")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ScriptureLinksList(
                        refs: refs,
                        onTap: { ref in
                            if hSize == .regular {
                                NotificationCenter.default.post(
                                    name: JournalNotifications.openScripturePreview,
                                    object: nil,
                                    userInfo: [
                                        "book": ref.bookName,
                                        "chapter": ref.chapter,
                                        "start": ref.startVerse,
                                        "end": ref.endVerse as Any
                                    ]
                                )
                            } else {
                                if let content = BibleReferenceLinker.loadVerses(for: ref) {
                                    previewRef = ref
                                    previewContent = content
                                    withAnimation(.spring()) { showPreview = true }
                                }
                            }
                        },
                        onCopy: { ref in
                            let s: String = {
                                if let end = ref.endVerse, end != ref.startVerse {
                                    return "\(ref.bookName) \(ref.chapter):\(ref.startVerse)-\(end)"
                                }
                                return "\(ref.bookName) \(ref.chapter):\(ref.startVerse)"
                            }()
                            UIPasteboard.general.string = s
                            withAnimation(.spring()) { showCopyToast = true }
                        }
                    )
                }

                if hSize != .regular, showPreview, let content = previewContent {
                    ScripturePreviewCard(content: content, refContext: previewRef, onCopy: {
                        let verseLines = content.verses.map { "\($0.number). \($0.text)" }.joined(separator: "\n")
                        let copyText = content.title + "\n" + verseLines
                        UIPasteboard.general.string = copyText
                        withAnimation(.spring()) { showCopyToast = true }
                    }, onClose: {
                        withAnimation(.easeOut) { showPreview = false }
                    })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(20)
        }
    }

    // MARK: - Parsing and linkify

    private var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func normalizedTags(from tags: [String]) -> [String] {
        var seenLower: Set<String> = []
        var result: [String] = []
        for t in tags {
            let key = t.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            if !seenLower.contains(key) {
                seenLower.insert(key)
                result.append(key)
            }
        }
        return result
    }

    private func scheduleLinkify(for text: String) {
        linkifyTask?.cancel()
        linkifyTask = Task(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 150_000_000)
            if Task.isCancelled { return }
            let result = BibleReferenceLinker.linkify(text)
            await MainActor.run {
                self.linkedContent = result
            }
        }
    }

    // MARK: - Autosave (debounced)

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            // Debounce 1.2s
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if Task.isCancelled { return }
            saveDraft()
        }
    }

    private func saveDraft() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = content // keep body whitespace as typed
        let tags = normalizedTags(from: parsedTags)

        if let entry = editingEntry {
            // Update existing entry in place
            entry.title = trimmedTitle
            entry.body = trimmedBody
            entry.tags = tags
            entry.updatedAt = Date()
            do {
                try ctx.save()
                NotificationCenter.default.post(name: JournalNotifications.entryUpdated, object: nil, userInfo: ["id": entry.uuid?.uuidString ?? ""])
            } catch {
                // Silent fail for autosave
            }
            return
        }

        // New entry path: create or reuse a draft row
        let entry: JournalEntry
        let isFirstSave: Bool
        if let existing = draftEntry {
            entry = existing
            isFirstSave = false
        } else {
            entry = JournalEntry()
            entry.isDraft = true
            entry.verseRef = verseRef
            ctx.insert(entry)
            draftEntry = entry
            isFirstSave = true
        }

        // Use “New Entry” for empty titles to make drafts readable in lists
        entry.title = trimmedTitle.isEmpty ? "New Entry" : trimmedTitle
        entry.body = trimmedBody
        entry.tags = tags
        entry.updatedAt = Date()

        do {
            try ctx.save()
            if isFirstSave {
                NotificationCenter.default.post(name: JournalNotifications.entryCreated, object: nil, userInfo: ["id": entry.uuid?.uuidString ?? ""])
            } else {
                NotificationCenter.default.post(name: JournalNotifications.entryUpdated, object: nil, userInfo: ["id": entry.uuid?.uuidString ?? ""])
            }
        } catch {
            // Silent for autosave
        }
    }

    // MARK: - Save (finalize)

    private func save(manual: Bool) {
        autosaveTask?.cancel()

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = normalizedTags(from: parsedTags)

        if let entry = editingEntry {
            entry.title = trimmedTitle
            entry.body = trimmedBody
            entry.tags = tags
            entry.updatedAt = Date()
            do {
                try ctx.save()
                NotificationCenter.default.post(name: JournalNotifications.entryUpdated, object: nil, userInfo: ["id": entry.uuid?.uuidString ?? ""])
                if manual {
                    withAnimation(.spring()) { showSavedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        if let onClose { onClose() } else { dismiss() }
                    }
                } else {
                    if let onClose { onClose() } else { dismiss() }
                }
            } catch {
                saveErrorMessage = error.localizedDescription
                showSaveError = true
            }
            return
        }

        // Finalize the draft (or create if none yet)
        let entry: JournalEntry
        let wasDraft: Bool
        if let existing = draftEntry {
            entry = existing
            wasDraft = true
        } else {
            entry = JournalEntry()
            entry.verseRef = verseRef
            ctx.insert(entry)
            wasDraft = false
        }

        entry.title = trimmedTitle.isEmpty ? "New Entry" : trimmedTitle
        entry.body = trimmedBody
        entry.tags = tags
        entry.isDraft = false
        entry.updatedAt = Date()

        do {
            try ctx.save()
            NotificationCenter.default.post(
                name: wasDraft ? JournalNotifications.entryUpdated : JournalNotifications.entryCreated,
                object: nil,
                userInfo: ["id": entry.uuid?.uuidString ?? ""]
            )
            if manual {
                withAnimation(.spring()) { showSavedToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    if let onClose { onClose() } else { dismiss() }
                }
            } else {
                if let onClose { onClose() } else { dismiss() }
            }
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }

    // Build a plain reference string from a VerseRef that BibleReferenceLinker will detect.
    private static func smartLinkString(from ref: VerseRef) -> String {
        return "\(ref.book) \(ref.chapter):\(ref.verse)"
    }
}

// Local pill style used for the bottom Save Entry button (iPad only)
private struct LocalPillButtonStyle: ButtonStyle {
    var tint: Color = .accentColor
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isEnabled ? .white : .secondary)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                Capsule(style: .continuous)
                    .fill(isEnabled ? tint : Color(.secondarySystemFill))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(configuration.isPressed ? 0.6 : 0.35), lineWidth: configuration.isPressed ? 2 : 1)
            )
            .shadow(color: .black.opacity(configuration.isPressed ? 0.04 : 0.08), radius: configuration.isPressed ? 1 : 3, x: 0, y: configuration.isPressed ? 0 : 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.85), value: configuration.isPressed)
    }
}

// Keyboard inset helper: observes keyboard and writes a safe bottom inset
private struct KeyboardInsetReader: UIViewRepresentable {
    @Binding var inset: CGFloat

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.backgroundColor = .clear
        context.coordinator.start()
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(inset: $inset) }

    final class Coordinator {
        @Binding var inset: CGFloat
        private var observers: [NSObjectProtocol] = []

        init(inset: Binding<CGFloat>) {
            _inset = inset
        }

        func start() {
            let nc = NotificationCenter.default
            let willChange = nc.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] note in
                self?.handle(note: note)
            }
            let willHide = nc.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] note in
                self?.handle(note: note)
            }
            observers = [willChange, willHide]
        }

        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }

        private func handle(note: Notification) {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                .first else { return }

            let endFrameScreen = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            let endFrame = window.convert(endFrameScreen, from: nil)
            let overlap = max(0, window.bounds.maxY - endFrame.minY)
            let extra: CGFloat = 6
            inset = overlap > 0 ? (overlap + extra) : 0
        }
    }
}

#Preview {
    NavigationStack { ReferenceMatchGameView() }
}
