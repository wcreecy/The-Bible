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

    // Caret/selection tracking
    @State private var textSelectionRange: NSRange = NSRange(location: 0, length: 0)
    @State private var caretRect: CGRect? = nil

    // Collapsible sections on iPhone
    @State private var isTitleExpanded: Bool = true
    @State private var isTagsExpanded: Bool = true

    // Linkify cache
    @State private var linkedContent: AttributedString = AttributedString("")
    @State private var linkifyTask: Task<Void, Never>? = nil

    // SmartLink sheet
    @State private var showSmartLinkSheet: Bool = false
    @State private var pendingTriggerRange: NSRange? = nil

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
                    regularLayoutWithBottomSave
                } else {
                    compactLayoutWithBottomSave
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
                        if let onClose { onClose() } else { dismiss() }
                    }
                    .keyboardShortcut("w", modifiers: [.command])
                }
                ToolbarItem(placement: .topBarTrailing) {
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
            // Existing toasts
            .appToast(isPresented: $showCopyToast, symbol: "doc.on.doc", text: "Copied to Clipboard", tint: .blue)
            // New "Saved" toast
            .appToast(isPresented: $showSavedToast, symbol: "checkmark.seal.fill", text: "Saved", tint: .green)
            .onAppear {
                scheduleLinkify(for: content)
            }
            .onDisappear {
                linkifyTask?.cancel()
            }
            .sheet(isPresented: $showSmartLinkSheet) {
                SmartLinkSheet { refText in
                    insertSmartLink(refText)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Layouts with bottom Save

    private var regularLayoutWithBottomSave: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                editorColumn
                Divider()
                previewColumn
                    .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                if showTagColors {
                    Divider()
                    tagColorsColumn
                        .frame(minWidth: 280, idealWidth: 300, maxWidth: 340, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .clipped(antialiased: false)

            bottomSaveBar
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var compactLayoutWithBottomSave: some View {
        VStack(spacing: 0) {
            compactLayout
                .clipped(antialiased: false)

            bottomSaveBar
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var bottomSaveBar: some View {
        ZStack {
            // Translucent background with subtle top divider and shadow
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
            VStack(alignment: .leading, spacing: 16) {
                TextField("Title", text: $title)
                    .foregroundStyle(.primary)
                    .textFieldStyle(.roundedBorder)
                TextField("sermon notes, prayer, study…", text: $tagsText)
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(.primary)
                    .textFieldStyle(.roundedBorder)

                tagChipsView

                textEditorWithSmartLinks
                    .padding(.bottom, 24)
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
                    Text("Title").font(.headline)
                }
            }

            Section {
                DisclosureGroup(isExpanded: $isTagsExpanded) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("sermon notes, prayer, study…", text: $tagsText)
                            .textInputAutocapitalization(.never)
                            .foregroundStyle(.primary)
                        tagChipsView
                    }
                } label: {
                    Text("Tags").font(.headline)
                }
            }

            Section("Body") {
                textEditorWithSmartLinks
                    .frame(minHeight: 280)
            }
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

    private var textEditorWithSmartLinks: some View {
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
                    detectHashTrigger()
                }
            )
            .frame(minHeight: 400)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
        }
    }

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

    // MARK: - Helpers

    private var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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

    private func detectHashTrigger() {
        let t = content
        let caretLoc = textSelectionRange.location
        let utf16 = t.utf16
        let clamped = min(max(caretLoc, 0), utf16.count)
        guard let caretUTF16Index = utf16.index(utf16.startIndex, offsetBy: clamped, limitedBy: utf16.endIndex),
              let caretIndex = caretUTF16Index.samePosition(in: t) else {
            return
        }

        let allowed: CharacterSet = CharacterSet.letters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: ".:-"))
        var i = caretIndex
        var foundHash: String.Index? = nil
        while i > t.startIndex {
            i = t.index(before: i)
            let ch = t[i]
            if ch == "#" { foundHash = i; break }
            if ch.isWhitespace || ch == "\n" { break }
            if let scalar = ch.unicodeScalars.first, !allowed.contains(scalar) { break }
        }
        guard let hashIdx = foundHash else { return }

        var endIdx = t.index(after: hashIdx)
        while endIdx < t.endIndex {
            let ch = t[endIdx]
            if ch.isWhitespace || ch == "\n" { break }
            endIdx = t.index(after: endIdx)
        }

        let startUTF16 = t.utf16.distance(from: t.utf16.startIndex, to: hashIdx)
        let endUTF16 = t.utf16.distance(from: t.utf16.startIndex, to: endIdx)
        let range = NSRange(location: startUTF16, length: endUTF16 - startUTF16)
        pendingTriggerRange = range

        if !showSmartLinkSheet {
            showSmartLinkSheet = true
        }
    }

    private func insertSmartLink(_ refText: String) {
        var t = content
        let insertion = refText

        if let range = pendingTriggerRange {
            if let strRange = Range(range, in: t) {
                t.replaceSubrange(strRange, with: insertion)
                content = t
                let newLoc = range.location + insertion.utf16.count
                textSelectionRange = NSRange(location: newLoc, length: 0)
            } else {
                let loc = min(max(textSelectionRange.location, 0), (t as NSString).length)
                if let idx = t.utf16.index(t.utf16.startIndex, offsetBy: loc, limitedBy: t.utf16.endIndex)?.samePosition(in: t) {
                    t.insert(contentsOf: insertion, at: idx)
                    content = t
                    textSelectionRange = NSRange(location: loc + insertion.utf16.count, length: 0)
                }
            }
        } else {
            let loc = min(max(textSelectionRange.location, 0), (t as NSString).length)
            if let idx = t.utf16.index(t.utf16.startIndex, offsetBy: loc, limitedBy: t.utf16.endIndex)?.samePosition(in: t) {
                t.insert(contentsOf: insertion, at: idx)
                content = t
                textSelectionRange = NSRange(location: loc + insertion.utf16.count, length: 0)
            }
        }

        pendingTriggerRange = nil
        showSmartLinkSheet = false
        scheduleLinkify(for: content)
    }

    // MARK: - Save

    private func save(manual: Bool) {
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
                if manual {
                    withAnimation(.spring()) { showSavedToast = true }
                    // Briefly show confirmation before dismiss
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
}

// Local pill style used for the bottom Save Entry button
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

struct CursorTextView: UIViewRepresentable {
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
