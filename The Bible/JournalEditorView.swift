import SwiftUI
import SwiftData
import UIKit

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
            let names = await BibleLibrary.shared.bookNames()
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
        if allBookNames.isEmpty { loadBookNamesIfNeeded() }

        let text = content
        let caretLoc = textSelectionRange.location
        let utf16 = text.utf16
        let clamped = min(max(caretLoc, 0), utf16.count)
        guard let caretUTF16Index = utf16.index(utf16.startIndex, offsetBy: clamped, limitedBy: utf16.endIndex),
              let caretIndex = caretUTF16Index.samePosition(in: text) else {
            showBookSuggestions = false
            bookQuery = ""
            return
        }

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
        var seen = Set<String>()

        func appendIfNew(_ idx: Int) {
            let key = lower[idx]
            if !seen.contains(key) {
                results.append(names[idx])
                seen.insert(key)
            }
        }

        for (idx, nameLower) in lower.enumerated() where nameLower.hasPrefix(qLower) {
            appendIfNew(idx)
            if results.count == 10 { return results }
        }

        if results.count < 10 {
            for (idx, nameLower) in lower.enumerated() where nameLower.contains(qLower) {
                appendIfNew(idx)
                if results.count == 10 { break }
            }
        }

        return results
    }

    private func replaceCurrentTrigger(with bookName: String) {
        var t = content
        guard let hashRange = t.range(of: "#", options: .backwards) else {
            showBookSuggestions = false
            bookQuery = ""
            return
        }
        let tokenStart = hashRange.lowerBound
        var tokenEnd = t.endIndex
        var idx = t.index(after: tokenStart)
        while idx < t.endIndex {
            let ch = t[idx]
            if ch == "\n" || ch.isWhitespace { break }
            idx = t.index(after: idx)
        }
        tokenEnd = idx
        let insertion = "\(bookName) "
        let utf16BeforeToken = t[..<tokenStart].utf16.count
        t.replaceSubrange(tokenStart..<tokenEnd, with: insertion)
        content = t
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
        ScriptureRefExtractor.refs(in: linkedContent)
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
            let result = BibleReferenceLinker.linkify(text)
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
                    Button(action: {
                        showBookSuggestions = false
                        if let onClose { onClose() } else { dismiss() }
                    }) {
                        Image(systemName: "xmark.circle")
                    }
                    .accessibilityLabel("Cancel")
                    .keyboardShortcut("w", modifiers: [.command])
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: save) {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .bold()
                    .accessibilityLabel("Save")
                    .keyboardShortcut("s", modifiers: [.command])
                }
            }
            .alert("Couldn’t Save Entry", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
            .appToast(isPresented: $showCopyToast, symbol: "doc.on.doc", text: "Copied to Clipboard", tint: .blue)
            .onChange(of: textSelectionRange) { _, _ in
                scheduleSuggestionsUpdate()
            }
            .onAppear {
                loadBookNamesIfNeeded()
                scheduleLinkify(for: content)
            }
            .onDisappear {
                suggestionsDebounceTask?.cancel()
                linkifyTask?.cancel()
            }
        }
    }

    private var regularLayout: some View {
        HStack(spacing: 0) {
            editorColumn
                .zIndex(showBookSuggestions ? 2 : 0)

            Divider()

            previewColumn
                .zIndex(1)
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            if showTagColors {
                Divider()
                tagColorsColumn
                    .frame(minWidth: 280, idealWidth: 300, maxWidth: 340, maxHeight: .infinity, alignment: .topLeading)
            }
        }
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
                    .zIndex(showBookSuggestions ? 10 : 0)
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var tagChipsView: some View {
        if !parsedTags.isEmpty {
            TagChipRow(
                tags: parsedTags,
                selectedTags: [],
                showColorPicker: true,
                onTap: nil,
                onColorChange: { tag, color in TagColorStore.setColor(color, for: tag) }
            )
        }
    }

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
                    TagChipRow(
                        tags: parsedTags,
                        selectedTags: [],
                        showColorPicker: true,
                        onTap: nil,
                        onColorChange: { tag, color in TagColorStore.setColor(color, for: tag) }
                    )
                    .padding(.vertical, 4)
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
            CursorTextView(
                text: $content,
                selection: $textSelectionRange,
                caretRect: $caretRect,
                onChange: { newText in
                    scheduleLinkify(for: newText)
                    scheduleSuggestionsUpdate()
                }
            )
            .frame(minHeight: 400)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )

            if showBookSuggestions, let caret = caretRect {
                GeometryReader { geo in
                    suggestionsPopup
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: min(geo.size.width * 0.9, 320))
                        .offset(x: clampX(caret.minX, geo: geo), y: clampY(caret.maxY + 6, geo: geo))
                        .zIndex(1000)
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

                let refs: [ScriptureRef] = detectedScriptureRefs()
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
                            copy(ref)
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

    private var compactLayout: some View {
        Form {
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

            Section {
                DisclosureGroup(isExpanded: $isTagsExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("sermon notes, prayer, study…", text: $tagsText)
                            .textInputAutocapitalization(.never)
                            .foregroundStyle(.primary)
                        TagChipRow(
                            tags: parsedTags,
                            selectedTags: [],
                            showColorPicker: true,
                            onTap: nil,
                            onColorChange: { tag, color in TagColorStore.setColor(color, for: tag) }
                        )
                    }
                } label: {
                    Text("Tags")
                        .font(.headline)
                }
            }

            Section("Body") {
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
                    .frame(minHeight: 280)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )

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

    private func clampX(_ desiredX: CGFloat, geo: GeometryProxy) -> CGFloat {
        let maxX = geo.size.width - 16
        return max(0, min(desiredX, maxX))
    }
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
        tv.textContainer.lineFragmentPadding = 5
        tv.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        DispatchQueue.main.async {
            context.coordinator.updateCaretRect(tv, deferBindingUpdate: true)
        }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.isInSwiftUIUpdate = true
        defer { context.coordinator.isInSwiftUIUpdate = false }

        if uiView.text != text {
            context.coordinator.isProgrammaticUpdate = true
            uiView.text = text
            context.coordinator.isProgrammaticUpdate = false
        }
        if uiView.selectedRange != selection {
            let maxLoc = max(0, (uiView.text as NSString).length)
            let newLoc = min(max(selection.location, 0), maxLoc)
            let maxLen = max(0, maxLoc - newLoc)
            let newLen = min(max(selection.length, 0), maxLen)

            context.coordinator.isProgrammaticUpdate = true
            uiView.selectedRange = NSRange(location: newLoc, length: newLen)
            context.coordinator.isProgrammaticUpdate = false
        }
        context.coordinator.updateCaretRect(uiView, deferBindingUpdate: true)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate, UIScrollViewDelegate {
        var parent: CursorTextView
        var isProgrammaticUpdate: Bool = false
        var isInSwiftUIUpdate: Bool = false
        private var lastCaretRect: CGRect = .null

        init(parent: CursorTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            if isProgrammaticUpdate { return }
            let newText = textView.text ?? ""
            if parent.text != newText {
                DispatchQueue.main.async {
                    self.parent.text = newText
                }
            }
            let newRange = textView.selectedRange
            if parent.selection != newRange {
                DispatchQueue.main.async {
                    self.parent.selection = newRange
                }
            }
            updateCaretRect(textView)
            DispatchQueue.main.async {
                self.parent.onChange?(textView.text)
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            if isProgrammaticUpdate { return }
            let newRange = textView.selectedRange
            if parent.selection != newRange {
                DispatchQueue.main.async {
                    self.parent.selection = newRange
                }
            }
            updateCaretRect(textView)
            DispatchQueue.main.async {
                self.parent.onChange?(textView.text)
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let tv = scrollView as? UITextView else { return }
            updateCaretRect(tv)
        }

        func updateCaretRect(_ textView: UITextView, deferBindingUpdate: Bool = false) {
            let shouldDefer = deferBindingUpdate || isInSwiftUIUpdate

            guard let range = textView.selectedTextRange else {
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

            self.lastCaretRect = rect
            if shouldDefer { return }

            let apply: () -> Void = {
                self.parent.caretRect = rect
            }
            DispatchQueue.main.async { apply() }
        }
    }
}

