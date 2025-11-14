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

    @State private var textSelectionRange: NSRange = NSRange(location: 0, length: 0)
    
    @State private var linkifyTask: Task<Void, Never>? = nil

    @State private var linkedContentCache: AttributedString = AttributedString("")
    @State private var detectedRefsCache: [ScriptureRef] = []

    @State private var wordCountState: Int = 0
    @State private var characterCountState: Int = 0

    private func updateBookSuggestions() {
        updateBookSuggestionsUsingSelection()
    }
    private func updateBookSuggestionsUsingSelection(window: Int = 256) {
        let caret = textSelectionRange.location
        let utf16 = content.utf16
        let total = utf16.count
        if total == 0 { showBookSuggestions = false; bookQuery = ""; return }
        let start = max(0, caret - window)
        let end = min(total, caret)
        guard start < end else { showBookSuggestions = false; bookQuery = ""; return }
        let startIdx = utf16.index(utf16.startIndex, offsetBy: start)
        let endIdx = utf16.index(utf16.startIndex, offsetBy: end)
        let slice = String(utf16[startIdx..<endIdx]) ?? ""
        guard let hashRange = slice.range(of: "#", options: .backwards) else {
            showBookSuggestions = false
            bookQuery = ""
            return
        }
        let afterHash = hashRange.upperBound
        let tail = slice[afterHash...]
        var query = ""
        let allowed = CharacterSet.letters.union(CharacterSet(charactersIn: "."))
        var idx = tail.startIndex
        while idx < tail.endIndex {
            let ch = tail[idx]
            if ch.isWhitespace || ch == "\n" { break }
            if let scalar = ch.unicodeScalars.first, !allowed.contains(scalar) { break }
            query.append(ch)
            idx = tail.index(after: idx)
        }
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
        bookQuery = cleaned
        showBookSuggestions = true
    }
    
    private func scheduleLinkifyPreview() {
        let current = content
        linkifyTask?.cancel()
        linkifyTask = Task.detached(priority: .utility) { [current] in
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
            guard !Task.isCancelled else { return }
            let linked = BibleReferenceLinker.linkify(current)
            let refs = Self.extractRefs(from: linked)
            let words = current.split { $0.isWhitespace || $0.isNewline }.count
            let chars = current.count
            await MainActor.run {
                linkedContentCache = linked
                detectedRefsCache = refs
                wordCountState = words
                characterCountState = chars
                updateBookSuggestionsUsingSelection()
            }
        }
    }

    private var filteredBooksForQuery: [String] {
        let names = BibleData.books.map { $0.name }
        let q = bookQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return Array(names.prefix(10)) }
        // Prefer prefix matches first, then contains
        let prefix = names.filter { $0.range(of: q, options: [.caseInsensitive, .diacriticInsensitive])?.lowerBound == $0.startIndex }
        if !prefix.isEmpty { return Array(prefix.prefix(10)) }
        let contains = names.filter { $0.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        return Array(contains.prefix(10))
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
        scheduleLinkifyPreview()
    }

    // MARK: - Stats & Links Helpers

    private func displayString(for ref: ScriptureRef) -> String {
        if let end = ref.endVerse, end != ref.startVerse {
            return "\(ref.bookName) \(ref.chapter):\(ref.startVerse)-\(end)"
        } else {
            return "\(ref.bookName) \(ref.chapter):\(ref.startVerse)"
        }
    }

    private static func extractRefs(from linked: AttributedString) -> [ScriptureRef] {
        var refs: [ScriptureRef] = []
        var seen: Set<String> = []
        for run in linked.runs {
            if let url = run.link, let ref = BibleReferenceLinker.parse(url: url) {
                let key: String
                if let end = ref.endVerse, end != ref.startVerse {
                    key = "\(ref.bookName) \(ref.chapter):\(ref.startVerse)-\(end)"
                } else {
                    key = "\(ref.bookName) \(ref.chapter):\(ref.startVerse)"
                }
                if !seen.contains(key) {
                    seen.insert(key)
                    refs.append(ref)
                }
            }
        }
        return refs
    }

    private func detectedScriptureRefs() -> [ScriptureRef] {
        return detectedRefsCache
    }

    private func copy(_ ref: ScriptureRef) {
        UIPasteboard.general.string = displayString(for: ref)
        withAnimation(.spring()) { showCopyToast = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut) { showCopyToast = false }
        }
    }

    private var linkedContent: AttributedString { BibleReferenceLinker.linkify(content) }

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
                    // iPad split editor: left editor, right live preview
                    HStack(spacing: 0) {
                        // Left: Editor fields
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                TextField("Title", text: $title)
                                    .foregroundStyle(.primary)
                                    .textFieldStyle(.roundedBorder)
                                TextField("sermon notes, prayer, study…", text: $tagsText)
                                    .textInputAutocapitalization(.never)
                                    .foregroundStyle(.primary)
                                    .textFieldStyle(.roundedBorder)
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
                                ZStack(alignment: .topLeading) {
                                    if content.isEmpty {
                                        Text("Write your thoughts here…")
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 8)
                                            .padding(.leading, 5)
                                    }
                                    CursorTextView(text: $content, selection: $textSelectionRange, onChange: { _ in
                                        updateBookSuggestionsUsingSelection()
                                        scheduleLinkifyPreview()
                                    })
                                    .frame(minHeight: 400)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                                    )
                                }
                                if showBookSuggestions {
                                    Divider()
                                        .padding(.top, 6)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Bible Books")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        ForEach(filteredBooksForQuery, id: \.self) { name in
                                            Button(action: { replaceCurrentTrigger(with: name) }) {
                                                Text(name)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding(.vertical, 6)
                                                    .padding(.horizontal, 8)
                                                    .background(
                                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                            .fill(Color(.secondarySystemBackground))
                                                    )
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.top, 6)
                                }
                            }
                            .padding(20)
                        }
                        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                        Divider()

                        // Right: Live Preview with smart links
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(title.isEmpty ? "Untitled" : title)
                                    .font(.title3).bold()
                                Text("Stats & Links")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                // Stats row
                                HStack(spacing: 12) {
                                    Label("\(wordCountState) words", systemImage: "textformat")
                                    Label("\(characterCountState) chars", systemImage: "character.book.closed")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                let refs = detectedScriptureRefs()
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

                                if hSize != .regular, showPreview, let content = previewContent {
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
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                            .padding(20)
                        }
                        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                        if showTagColors {
                            Divider()

                            // Far Right: Tag Colors
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Tag Colors")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if parsedTags.isEmpty {
                                        Text("Add comma-separated tags to pick colors.")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    } else {
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
                                .padding(20)
                            }
                            .frame(minWidth: 280, idealWidth: 300, maxWidth: 340, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                } else {
                    // Compact: original form layout
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
                                CursorTextView(text: $content, selection: $textSelectionRange, onChange: { _ in
                                    updateBookSuggestionsUsingSelection()
                                    scheduleLinkifyPreview()
                                })
                                .frame(minHeight: 200)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                                )
                            }
                            if showBookSuggestions {
                                Divider()
                                    .padding(.top, 6)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Bible Books")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    ForEach(filteredBooksForQuery, id: \.self) { name in
                                        Button(action: { replaceCurrentTrigger(with: name) }) {
                                            Text(name)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .fill(Color(.secondarySystemBackground))
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.top, 6)
                            }
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Stats & Links")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                // Stats row
                                HStack(spacing: 12) {
                                    Label("\(wordCountState) words", systemImage: "textformat")
                                    Label("\(characterCountState) chars", systemImage: "character.book.closed")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                let refs = detectedScriptureRefs()
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
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack(spacing: 8) {
                                            Text(content.title)
                                                .font(.headline)
                                            Spacer()
                                            Button(action: {
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
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
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
            .onAppear {
                updateBookSuggestionsUsingSelection()
                Task.detached(priority: .utility) {
                    _ = BibleReferenceLinker.linkify("")
                }
                // Seed initial caches for an empty or prefilled draft
                scheduleLinkifyPreview()
            }
        }
    }

    private var wordCount: Int {
        content.split { $0.isWhitespace || $0.isNewline }.count
    }
    private var characterCount: Int { content.count }
    private var paragraphCount: Int {
        content.split(whereSeparator: { $0 == "\n" }).split(separator: "\n\n").count
    }
    private var estimatedReadingMinutes: Int {
        let minutes = Double(wordCount) / 200.0
        return max(1, Int(ceil(minutes)))
    }
    private var tagCount: Int { parsedTags.count }

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
        tv.contentInsetAdjustmentBehavior = .never
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if uiView.selectedRange != selection {
            // Clamp selection to valid range
            let maxLoc = (uiView.text as NSString).length
            let loc = min(selection.location, maxLoc)
            uiView.selectedRange = NSRange(location: loc, length: selection.length)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: CursorTextView
        init(parent: CursorTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.onChange?(textView.text)
        }
        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selection = textView.selectedRange
        }
    }
}
