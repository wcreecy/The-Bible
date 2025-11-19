import SwiftUI
import SwiftData
import UIKit

private enum JournalNotifications {
    static let openScripturePreview = Notification.Name("OpenScripturePreview")
    static let entryCreated = Notification.Name("JournalEntryCreated")
    static let entryUpdated = Notification.Name("JournalEntryUpdated")
}

struct JournalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(\.horizontalSizeClass) private var hSize

    // If invoked from a verse, we’ll seed the title smartly
    let verseRef: VerseRef?
    let showTagColors: Bool
    let onClose: (() -> Void)?

    @State private var title: String = ""
    @State private var content: String = ""      // <-- renamed from `body`
    @State private var tagsText: String = ""     // comma-separated

    @State private var previewRef: ScriptureRef? = nil
    @State private var previewContent: (title: String, verses: [Verse])? = nil
    @State private var showPreview: Bool = false

    @State private var showSaveError = false
    @State private var saveErrorMessage: String = ""
    @State private var showCopyToast: Bool = false
    @State private var editingEntry: JournalEntry? = nil

    // MARK: - Smart Link Composer (book suggestions with # trigger)
    @State private var showBookSuggestions: Bool = false
    @State private var bookQuery: String = ""
    @State private var suggestionsDebounceTask: Task<Void, Never>? = nil

    @State private var textSelectionRange: NSRange = NSRange(location: 0, length: 0)
    // Caret rect (in the UITextView’s local coordinate space) used to anchor the suggestions popup
    @State private var caretRect: CGRect? = nil

    // Collapsible sections on iPhone
    @State private var isTitleExpanded: Bool = true
    @State private var isTagsExpanded: Bool = true

    // Avoid main-thread JSON decode: load names lazily via BibleLibrary and keep a tiny canonical list for ordering only.
    private static let canonicalBookOrder: [String] = [
        "Genesis","Exodus","Leviticus","Numbers","Deuteronomy",
        "Joshua","Judges","Ruth",
        "1 Samuel","2 Samuel",
        "1 Kings","2 Kings",
        "1 Chronicles","2 Chronicles",
        "Ezra","Nehemiah","Esther",
        "Job","Psalms","Proverbs","Ecclesiastes","Song of Solomon",
        "Isaiah","Jeremiah","Lamentations","Ezekiel","Daniel",
        "Hosea","Joel","Amos","Obadiah","Jonah",
        "Micah","Nahum","Habakkuk","Zephaniah",
        "Haggai","Zechariah","Malachi",
        "Matthew","Mark","Luke","John",
        "Acts","Romans",
        "1 Corinthians","2 Corinthians",
        "Galatians","Ephesians","Philippians","Colossians",
        "1 Thessalonians","2 Thessalonians",
        "1 Timothy","2 Timothy",
        "Titus","Philemon",
        "Hebrews","James",
        "1 Peter","2 Peter",
        "1 John","2 John","3 John",
        "Jude","Revelation"
    ]
    @State private var allBookNames: [String] = []
    @State private var allBookNamesLower: [String] = []

    private func loadBookNamesIfNeeded() {
        guard allBookNames.isEmpty else { return }
        Task {
            // Get names quickly without decoding verse text
            let names = await BibleLibrary.shared.bookNames()
            // Order according to our canonical sequence (unknowns go last in original order)
            let pos = Dictionary(uniqueKeysWithValues: Self.canonicalBookOrder.enumerated().map { ($1, $0) })
            let ordered = names.sorted { (a, b) in
                (pos[a] ?? Int.max) < (pos[b] ?? Int.max)
            }
            await MainActor.run {
                self.allBookNames = ordered.isEmpty ? Self.canonicalBookOrder : ordered
                self.allBookNamesLower = self.allBookNames.map { $0.lowercased() }
            }
        }
    }

    private func updateBookSuggestions() {
        // Ensure names are loaded the first time suggestions are needed
        if allBookNames.isEmpty { loadBookNamesIfNeeded() }

        let text = content

        // Map caret (UTF16) to String.Index
        let caretLoc = textSelectionRange.location
        let utf16 = text.utf16
        let clamped = min(max(caretLoc, 0), utf16.count)
        guard let caretUTF16Index = utf16.index(utf16.startIndex, offsetBy: clamped, limitedBy: utf16.endIndex),
              let caretIndex = caretUTF16Index.samePosition(in: text) else {
            showBookSuggestions = false
            bookQuery = ""
            return
        }

        // Walk backward from the caret to find a '#' that starts the current token,
        // stopping if we hit whitespace/newline or a disallowed character first.
        let allowed: CharacterSet = CharacterSet.letters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: "."))

        var i = caretIndex
        var foundHash: String.Index? = nil
        while i > text.startIndex {
            i = text.index(before: i)
            let ch = text[i]
            if ch == "#" {
                foundHash = i
                break
            }
            if ch.isWhitespace || ch == "\n" { break }
            if let scalar = ch.unicodeScalars.first, !allowed.contains(scalar) { break }
        }

        guard let hashIdx = foundHash else {
            showBookSuggestions = false
            bookQuery = ""
            return
        }

        let afterHash = text.index(after: hashIdx)
        guard afterHash <= caretIndex else {
            showBookSuggestions = false
            bookQuery = ""
            return
        }

        let rawQuery = String(text[afterHash..<caretIndex])
        let cleaned = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        bookQuery = cleaned
        showBookSuggestions = true
    }

    private var filteredBooksForQuery: [String] {
        let names = allBookNames
        let lower = allBookNamesLower
        if names.isEmpty { return [] }

        let q = bookQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return Array(names.prefix(10)) }
        let qLower = q.lowercased()

        var results: [String] = []
        var seen = Set<String>() // track lowercased names to avoid duplicates

        func appendIfNew(_ idx: Int) {
            let key = lower[idx]
            if !seen.contains(key) {
                results.append(names[idx])
                seen.insert(key)
            }
        }

        // Prefer prefix matches first
        for (idx, nameLower) in lower.enumerated() where nameLower.hasPrefix(qLower) {
            appendIfNew(idx)
            if results.count == 10 { return results }
        }

        // Then contains matches, excluding anything already added
        if results.count < 10 {
            for (idx, nameLower) in lower.enumerated() where nameLower.contains(qLower) {
                appendIfNew(idx)
                if results.count == 10 { break }
            }
        }

        return results
    }

    private func replaceCurrentTrigger(with bookName: String) {
        // Work on a mutable copy
        var t = content
        // Find last '#'
        guard let hashRange = t.range(of: "#", options: .backwards) else {
            showBookSuggestions = false
            bookQuery = ""
            return
        }
        let tokenStart = hashRange.lowerBound
        // Find end of token (next whitespace/newline)
        var tokenEnd = t.endIndex
        var idx = t.index(after: tokenStart)
        while idx < t.endIndex {
            let ch = t[idx]
            if ch == "\n" || ch.isWhitespace { break }
            idx = t.index(after: idx)
        }
        tokenEnd = idx
        let insertion = "\(bookName) "
        // Compute caret position in UTF16 based on original text
        let utf16BeforeToken = t[..<tokenStart].utf16.count
        // Perform replacement
        t.replaceSubrange(tokenStart..<tokenEnd, with: insertion)
        content = t
        // New caret position is start of token + insertion length
        let caretLocation = utf16BeforeToken + insertion.utf16.count
        textSelectionRange = NSRange(location: caretLocation, length: 0)
        showBookSuggestions = false
        bookQuery = ""
    }

    // MARK: - Stats & Links Helpers

    private func displayString(for ref: ScriptureRef) -> String {
        if let end = ref.endVerse, end != ref.startVerse {
            return "\(ref.bookName) \(ref.chapter):\(ref.startVerse)-\(end)"
        } else {
            return "\(ref.bookName) \(ref.chapter):\(ref.startVerse)"
        }
    }

    private func detectedScriptureRefs() -> [ScriptureRef] {
        var refs: [ScriptureRef] = []
        var seen: Set<String> = []
        for run in linkedContent.runs {
            if let url = run.link, let ref = BibleReferenceLinker.parse(url: url) {
                let key = displayString(for: ref)
                if !seen.contains(key) {
                    seen.insert(key)
                    refs.append(ref)
                }
            }
        }
        return refs
    }

    private func copy(_ ref: ScriptureRef) {
        UIPasteboard.general.string = displayString(for: ref)
        withAnimation(.spring()) { showCopyToast = true }
    }

    // Debounced/cached linkify to reduce recomputation while typing
    @State private var linkedContent: AttributedString = AttributedString("")
    @State private var linkifyTask: Task<Void, Never>? = nil

    private func scheduleLinkify(for text: String) {
        linkifyTask?.cancel()
        linkifyTask = Task(priority: .userInitiated) {
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce
            if Task.isCancelled { return }
            // Heavy regex on a background thread
            let result = BibleReferenceLinker.linkify(text)
            // Assign on main
            await MainActor.run {
                self.linkedContent = result
            }
        }
    }

    private var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func colorBinding(for tag: String) -> Binding<Color> {
        let fallback = TagColorStore.color(for: tag) ?? .accentColor
        return Binding<Color>(
            get: { TagColorStore.color(for: tag) ?? fallback },
            set: { newValue in
                TagColorStore.setColor(newValue, for: tag)
            }
        )
    }

    // Centralized debounce for suggestions to avoid repeated code
    private func scheduleSuggestionsUpdate() {
        suggestionsDebounceTask?.cancel()
        suggestionsDebounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000)
            updateBookSuggestions()
        }
    }

    init(verseRef: VerseRef?, initialBody: String? = nil, showTagColors: Bool = false, editingEntry: JournalEntry? = nil, onClose: (() -> Void)? = nil) {
        self.verseRef = verseRef
        self.showTagColors = showTagColors
        _title = State(initialValue: editingEntry?.title ?? verseRef?.display ?? "")
        _content = State(initialValue: editingEntry?.body ?? initialBody ?? "")
        _tagsText = State(initialValue: editingEntry?.tags.joined(separator: ", ") ?? "")
        self._editingEntry = State(initialValue: editingEntry)
        self.onClose = onClose
    }

    var body: some View {
        NavigationStack {
            Group {
                if hSize == .regular {
                    regularLayout
                } else {
                    compactLayout
                }
            }
            // Title behavior:
            // - Editing existing entry: show its current title (or Untitled if empty)
            // - Creating new entry: show "New Entry" until the user types a title; then reflect that live
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
                        showBookSuggestions = false
                        if let onClose { onClose() } else { dismiss() }
                    }
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
            .appToast(isPresented: $showCopyToast, symbol: "doc.on.doc", text: "Copied to Clipboard", tint: .blue)
            .onChange(of: textSelectionRange) { _, _ in
                // Debounce suggestions when caret moves
                scheduleSuggestionsUpdate()
            }
            .onAppear {
                // Start loading book names (asynchronously, no UI block)
                loadBookNamesIfNeeded()
                // Seed linkified content
                scheduleLinkify(for: content)
            }
            .onDisappear {
                // Cancel any pending async work to avoid late state updates after teardown
                suggestionsDebounceTask?.cancel()
                linkifyTask?.cancel()
            }
        }
    }

    // MARK: - Extracted Layouts

    private var regularLayout: some View {
        HStack(spacing: 0) {
            editorColumn
                // Raise the entire editor column above the right column while suggestions are visible
                .zIndex(showBookSuggestions ? 2 : 0)

            Divider()

            previewColumn
                .zIndex(1) // Baseline for right column
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if showTagColors {
                Divider()

                // Far Right: Tag Colors
                tagColorsColumn
                    .frame(minWidth: 280, idealWidth: 300, maxWidth: 340, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        // Ensure overlays from the editor can extend over the right side if needed
        .clipped(antialiased: false)
    }

    private var editorColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Title", text: $title)
                    .foregroundStyle(.primary)
                    .textFieldStyle(.roundedBorder)
                TextField("sermon notes, prayer, study…", text: $tagsText)
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(.primary)
                    .textFieldStyle(.roundedBorder)

                tagChipsView

                textEditorWithSuggestions
                    // Make sure the editor’s popup wins stacking inside this column
                    .zIndex(showBookSuggestions ? 10 : 0)
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var tagChipsView: some View {
        if !parsedTags.isEmpty {
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

    // Far-right column to manage tag colors in regular width
    private var tagColorsColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tag Colors")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if parsedTags.isEmpty {
                    Text("No tags yet. Add comma-separated tags above to set colors.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(parsedTags, id: \.self) { t in
                        HStack(spacing: 10) {
                            let color = TagColorStore.color(for: t) ?? .accentColor
                            Text(t)
                                .font(.subheadline)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(color.opacity(0.15), in: Capsule())
                                .overlay(
                                    Capsule().stroke(color.opacity(0.4), lineWidth: 1)
                                )
                                .foregroundStyle(color)
                            Spacer()
                            ColorPicker("", selection: colorBinding(for: t), supportsOpacity: false)
                                .labelsHidden()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(20)
        }
    }

    private var textEditorWithSuggestions: some View {
        ZStack(alignment: .topLeading) {
            if content.isEmpty {
                Text("Write your thoughts here…")
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.leading, 5)
            }
            // Text view + caret tracking
            CursorTextView(
                text: $content,
                selection: $textSelectionRange,
                caretRect: $caretRect,
                onChange: { newText in
                    // Debounce both linkify and suggestions
                    scheduleLinkify(for: newText)
                    scheduleSuggestionsUpdate()
                }
            )
            .frame(minHeight: 400)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )

            // Suggestions popup anchored to caret
            if showBookSuggestions, let caret = caretRect {
                GeometryReader { geo in
                    suggestionsPopup
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: min(geo.size.width * 0.9, 320))
                        .offset(x: clampX(caret.minX, geo: geo), y: clampY(caret.maxY + 6, geo: geo))
                        .zIndex(1000) // Keep popup above anything within the editor
                }
                .zIndex(1000)
                .transition(.opacity)
            }
        }
    }

    private var previewColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(title.isEmpty ? "Untitled" : title)
                    .font(.title3).bold()
                Text("Entry Stats & Links")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                let refs: [ScriptureRef] = detectedScriptureRefs()
                scriptureLinksView(refs: refs)

                if hSize != .regular, showPreview, let content = previewContent {
                    scripturePreviewCard(content: content)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private func scriptureLinksView(refs: [ScriptureRef]) -> some View {
        if !refs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Scripture Links")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(Array(refs.enumerated()), id: \.offset) { _, ref in
                    HStack(spacing: 8) {
                        Button(action: {
                            if hSize == .regular {
                                // Request 3rd-column scripture preview via NotificationCenter
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
                        }) {
                            Text(displayString(for: ref))
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(.blue)
                                .underline()
                        }
                        .buttonStyle(.plain)

                        Button { copy(ref) } label: { Image(systemName: "doc.on.doc") }
                            .buttonStyle(.plain)
                            .foregroundStyle(.blue)
                            .accessibilityLabel("Copy reference")
                    }
                }
            }
        }
    }

    private func scripturePreviewCard(content: (title: String, verses: [Verse])) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(content.title)
                    .font(.headline)
                Spacer()
                Button(action: {
                    // Build formatted scripture text and copy to clipboard
                    let verseLines = content.verses.map { "\($0.number). \($0.text)" }.joined(separator: "\n")
                    let copyText = content.title + "\n" + verseLines
                    UIPasteboard.general.string = copyText
                    withAnimation(.spring()) { showCopyToast = true }
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
    }

    private var compactLayout: some View {
        Form {
            // Collapsible Title section
            Section {
                DisclosureGroup(isExpanded: $isTitleExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Title", text: $title)
                            .foregroundStyle(.primary)
                        if let ref = verseRef {
                            LabeledContent("Linked Verse", value: ref.display)
                        }
                    }
                } label: {
                    Text("Title")
                        .font(.headline)
                }
            }

            // Collapsible Tags section
            Section {
                DisclosureGroup(isExpanded: $isTagsExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("sermon notes, prayer, study…", text: $tagsText)
                            .textInputAutocapitalization(.never)
                            .foregroundStyle(.primary)
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
                } label: {
                    Text("Tags")
                        .font(.headline)
                }
            }

            // Body section stays always visible
            Section("Body") {
                // Editor only on iPhone: remove "Entry Stats & Links" to maximize space
                ZStack(alignment: .topLeading) {
                    if content.isEmpty {
                        Text("Write your thoughts here.  To create smart links, type # in front of the book name, e.g. #Romans 1:2-3")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                    CursorTextView(
                        text: $content,
                        selection: $textSelectionRange,
                        caretRect: $caretRect,
                        onChange: { newText in
                            scheduleLinkify(for: newText)
                            scheduleSuggestionsUpdate()
                        }
                    )
                    .frame(minHeight: 280) // Expanded editor height on iPhone
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )

                    // Suggestions popup anchored to caret
                    if showBookSuggestions, let caret = caretRect {
                        GeometryReader { geo in
                            suggestionsPopup
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: min(geo.size.width * 0.95, 320))
                                .offset(x: clampX(caret.minX, geo: geo), y: clampY(caret.maxY + 6, geo: geo))
                                .zIndex(1000)
                        }
                        .zIndex(1000)
                        .transition(.opacity)
                    }
                }
                .zIndex(2)
            }
        }
        .clipped(antialiased: false)
    }

    // Suggestions popup view
    private var suggestionsPopup: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !filteredBooksForQuery.isEmpty {
                ForEach(filteredBooksForQuery, id: \.self) { name in
                    Button(action: { replaceCurrentTrigger(with: name) }) {
                        HStack {
                            Text(name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("No matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 6)
    }

    // Clamp X so the popup stays inside the text view’s bounds
    private func clampX(_ desiredX: CGFloat, geo: GeometryProxy) -> CGFloat {
        let maxX = geo.size.width - 16 // padding from right edge
        return max(0, min(desiredX, maxX))
    }
    // Clamp Y similarly (basic protection; popup height is unknown so we just keep a top margin)
    private func clampY(_ desiredY: CGFloat, geo: GeometryProxy) -> CGFloat {
        let maxY = geo.size.height - 16
        return max(0, min(desiredY, maxY))
    }

    private func save() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let entry = editingEntry {
            entry.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.body = content.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.tags = tags
            entry.updatedAt = Date()
            do {
                try ctx.save()
                NotificationCenter.default.post(name: JournalNotifications.entryUpdated, object: nil, userInfo: ["id": entry.id.uuidString])
                if let onClose { onClose() } else { dismiss() }
            } catch {
                saveErrorMessage = error.localizedDescription
                showSaveError = true
            }
            return
        }

        let entry = JournalEntry(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: content.trimmingCharacters(in: .whitespacesAndNewlines),
            verseRef: verseRef,
            tags: tags,
            isPinned: false,
            isFavorite: false
        )
        entry.updatedAt = Date()
        ctx.insert(entry)
        do {
            try ctx.save()
            NotificationCenter.default.post(name: JournalNotifications.entryCreated, object: nil, userInfo: ["id": entry.id.uuidString])
            if let onClose { onClose() } else { dismiss() }
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }
}

private struct CursorTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    @Binding var caretRect: CGRect?
    var onChange: ((String) -> Void)? = nil

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isScrollEnabled = true
        tv.backgroundColor = .clear
        tv.text = text
        tv.delegate = context.coordinator
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.smartDashesType = .no
        tv.smartQuotesType = .no
        tv.smartInsertDeleteType = .no
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        // Provide consistent insets so caret positioning matches overlay
        tv.textContainer.lineFragmentPadding = 5
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        // Initial caret update on next runloop
        DispatchQueue.main.async {
            context.coordinator.updateCaretRect(tv, deferBindingUpdate: true)
        }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Mark that we're in SwiftUI's update cycle to suppress @State writes
        context.coordinator.isInSwiftUIUpdate = true
        defer { context.coordinator.isInSwiftUIUpdate = false }

        // Prevent delegate from feeding back into SwiftUI while we perform programmatic updates
        if uiView.text != text {
            context.coordinator.isProgrammaticUpdate = true
            uiView.text = text
            context.coordinator.isProgrammaticUpdate = false
        }
        if uiView.selectedRange != selection {
            // Clamp selection to valid range (both location and length)
            let maxLoc = max(0, (uiView.text as NSString).length)
            let newLoc = min(max(selection.location, 0), maxLoc)
            let maxLen = max(0, maxLoc - newLoc)
            let newLen = min(max(selection.length, 0), maxLen)

            context.coordinator.isProgrammaticUpdate = true
            uiView.selectedRange = NSRange(location: newLoc, length: newLen)
            context.coordinator.isProgrammaticUpdate = false
        }
        // Keep caret rect fresh (e.g., dynamic type or size changes)
        context.coordinator.updateCaretRect(uiView, deferBindingUpdate: true)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate, UIScrollViewDelegate {
        var parent: CursorTextView
        // Reentrancy flag to avoid "modifying state during view update"
        var isProgrammaticUpdate: Bool = false
        // True while updateUIView is running
        var isInSwiftUIUpdate: Bool = false
        private var lastCaretRect: CGRect = .null

        init(parent: CursorTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            // Ignore delegate callbacks triggered by programmatic updates
            if isProgrammaticUpdate { return }
            let newText = textView.text ?? ""
            if parent.text != newText {
                DispatchQueue.main.async {
                    self.parent.text = newText
                }
            }
            // Ensure caret position in SwiftUI is current before triggering onChange
            let newRange = textView.selectedRange
            if parent.selection != newRange {
                DispatchQueue.main.async {
                    self.parent.selection = newRange
                }
            }
            updateCaretRect(textView)
            // Defer the callback to the next runloop so caret/selection are fully settled
            DispatchQueue.main.async {
                self.parent.onChange?(textView.text)
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            // Ignore delegate callbacks triggered by programmatic updates
            if isProgrammaticUpdate { return }
            let newRange = textView.selectedRange
            if parent.selection != newRange {
                DispatchQueue.main.async {
                    self.parent.selection = newRange
                }
            }
            updateCaretRect(textView)
            // Also trigger suggestion update when the caret moves
            DispatchQueue.main.async {
                self.parent.onChange?(textView.text)
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let tv = scrollView as? UITextView else { return }
            updateCaretRect(tv)
        }

        func updateCaretRect(_ textView: UITextView, deferBindingUpdate: Bool = false) {
            // If we're in SwiftUI's update pass, never touch @State here.
            let shouldDefer = deferBindingUpdate || isInSwiftUIUpdate

            guard let range = textView.selectedTextRange else {
                // When we shouldn't touch SwiftUI state (e.g. from updateUIView), just reset our cache.
                if shouldDefer {
                    self.lastCaretRect = .null
                    return
                }
                let applyNil: () -> Void = {
                    self.parent.caretRect = nil
                    self.lastCaretRect = .null
                }
                DispatchQueue.main.async { applyNil() }
                return
            }

            let rect = textView.caretRect(for: range.start)
            let needsUpdate = lastCaretRect.isNull
                || abs(rect.minX - lastCaretRect.minX) > 0.5
                || abs(rect.minY - lastCaretRect.minY) > 0.5

            guard needsUpdate else { return }

            // Always update our local cache immediately
            self.lastCaretRect = rect

            // If we're being called from a SwiftUI update cycle, don't write to @State here.
            if shouldDefer {
                return
            }

            let apply: () -> Void = {
                self.parent.caretRect = rect
            }

            // Defer binding updates to avoid "modifying state during view update"
            DispatchQueue.main.async { apply() }
        }
    }
}

