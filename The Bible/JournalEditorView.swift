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
    // Caret rect (in the UITextView’s local coordinate space) used to anchor the suggestions popup
    @State private var caretRect: CGRect? = nil

    // Precomputed book names to avoid rebuilding arrays per keystroke
    private static let allBookNames: [String] = BibleData.books.map { $0.name }
    private static let allBookNamesLower: [String] = allBookNames.map { $0.lowercased() }

    private func updateBookSuggestions() {
        let text = content

        // Map caret (UTF16) to String.Index
        let caretLoc = textSelectionRange.location
        let utf16 = text.utf16
        let clamped = min(caretLoc, utf16.count)
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
        let names = Self.allBookNames
        let lower = Self.allBookNamesLower
        let q = bookQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return Array(names.prefix(10)) }
        let qLower = q.lowercased()
        // Prefer prefix matches first, then contains
        var results: [String] = []
        for (idx, nameLower) in lower.enumerated() {
            if nameLower.hasPrefix(qLower) {
                results.append(names[idx])
                if results.count == 10 { return results }
            }
        }
        if results.count < 10 {
            for (idx, nameLower) in lower.enumerated() {
                if nameLower.contains(qLower) {
                    results.append(names[idx])
                    if results.count == 10 { break }
                }
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut) { showCopyToast = false }
        }
    }

    // Debounced/cached linkify to reduce recomputation while typing
    @State private var linkedContent: AttributedString = AttributedString("")
    @State private var linkifyTask: Task<Void, Never>? = nil
    private func scheduleLinkify(for text: String) {
        linkifyTask?.cancel()
        linkifyTask = Task.detached(priority: .userInitiated) {
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
        let initial = TagColorStore.color(for: tag) ?? .accentColor
        var current = initial
        return Binding<Color>(
            get: { TagColorStore.color(for: tag) ?? current },
            set: { newValue in
                TagColorStore.setColor(newValue, for: tag)
            }
        )
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
            .navigationTitle(editingEntry == nil ? "New Entry" : "Edit Entry")
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
            .onChange(of: textSelectionRange) { _ in
                // Debounce suggestions when caret moves
                suggestionsDebounceTask?.cancel()
                suggestionsDebounceTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    updateBookSuggestions()
                }
            }
            .onAppear {
                // Seed linkified content
                scheduleLinkify(for: content)
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
                    suggestionsDebounceTask?.cancel()
                    suggestionsDebounceTask = Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        updateBookSuggestions()
                    }
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
                }
                .zIndex(10) // Ensure popup stays above any neighboring panels
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
                                    name: Notification.Name("OpenScripturePreview"),
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        withAnimation(.easeOut) { showCopyToast = false }
                    }
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
            Section {
                TextField("Title", text: $title)
                    .foregroundStyle(.primary)
                if let ref = verseRef {
                    LabeledContent("Linked Verse", value: ref.display)
                }
            }
            Section("Tags") {
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
            Section("Body") {
                ZStack(alignment: .topLeading) {
                    if content.isEmpty {
                        Text("Write your thoughts here.  To create smart links, type # in front of the book name, e.g. #Romans 1:2-3")
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
                            scheduleLinkify(for: newText)
                            suggestionsDebounceTask?.cancel()
                            suggestionsDebounceTask = Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 120_000_000)
                                updateBookSuggestions()
                            }
                        }
                    )
                    .frame(minHeight: 200)
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
                        }
                        .zIndex(10) // Ensure popup stays above subsequent sections in the form
                        .transition(.opacity)
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Entry Stats & Links")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    let refs: [ScriptureRef] = detectedScriptureRefs()
                    if !refs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Scripture Links")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            ForEach(Array(refs.enumerated()), id: \.offset) { _, ref in
                                HStack(spacing: 8) {
                                    Button(action: {
                                        if let content = BibleReferenceLinker.loadVerses(for: ref) {
                                            previewRef = ref
                                            previewContent = content
                                            withAnimation(.spring()) { showPreview = true }
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

                    if showPreview, let content = previewContent {
                        scripturePreviewCard(content: content)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.top, 8)
            }
        }
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

        if var entry = editingEntry {
            entry.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.body = content.trimmingCharacters(in: .whitespacesAndNewlines)
            entry.tags = tags
            entry.updatedAt = Date()
            do {
                try ctx.save()
                NotificationCenter.default.post(name: Notification.Name("JournalEntryUpdated"), object: nil, userInfo: ["id": entry.id.uuidString])
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
            NotificationCenter.default.post(name: Notification.Name("JournalEntryCreated"), object: nil, userInfo: ["id": entry.id.uuidString])
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
            context.coordinator.updateCaretRect(tv)
        }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Prevent delegate from feeding back into SwiftUI while we perform programmatic updates
        if uiView.text != text {
            context.coordinator.isProgrammaticUpdate = true
            uiView.text = text
            context.coordinator.isProgrammaticUpdate = false
        }
        if uiView.selectedRange != selection {
            // Clamp selection to valid range
            let maxLoc = (uiView.text as NSString).length
            let loc = min(selection.location, maxLoc)
            context.coordinator.isProgrammaticUpdate = true
            uiView.selectedRange = NSRange(location: loc, length: selection.length)
            context.coordinator.isProgrammaticUpdate = false
        }
        // Keep caret rect fresh (e.g., dynamic type or size changes)
        context.coordinator.updateCaretRect(uiView)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate, UIScrollViewDelegate {
        var parent: CursorTextView
        // Reentrancy flag to avoid "modifying state during view update"
        var isProgrammaticUpdate: Bool = false
        private var lastCaretRect: CGRect = .null

        init(parent: CursorTextView) { self.parent = parent }

        func textViewDidChange(_ textView: UITextView) {
            // Ignore delegate callbacks triggered by programmatic updates
            if isProgrammaticUpdate { return }
            parent.text = textView.text
            // Ensure caret position in SwiftUI is current before triggering onChange
            let newRange = textView.selectedRange
            if parent.selection != newRange {
                parent.selection = newRange
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
                parent.selection = newRange
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

        func updateCaretRect(_ textView: UITextView) {
            guard let range = textView.selectedTextRange else {
                parent.caretRect = nil
                lastCaretRect = .null
                return
            }
            let rect = textView.caretRect(for: range.start)
            // Only propagate meaningful changes to reduce state churn
            if lastCaretRect.isNull || abs(rect.minX - lastCaretRect.minX) > 0.5 || abs(rect.minY - lastCaretRect.minY) > 0.5 {
                lastCaretRect = rect
                parent.caretRect = rect
            }
        }
    }
}
