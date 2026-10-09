import SwiftData
import SwiftUI
import UIKit

enum VerseHighlightColor: String, CaseIterable, Identifiable {
    case yellow
    case green
    case blue
    case pink
    case purple

    var id: String { rawValue }

    var name: LocalizedStringResource {
        switch self {
        case .yellow: "Yellow"
        case .green: "Green"
        case .blue: "Blue"
        case .pink: "Pink"
        case .purple: "Purple"
        }
    }

    var color: Color {
        switch self {
        case .yellow: .yellow
        case .green: .green
        case .blue: .blue
        case .pink: .pink
        case .purple: .purple
        }
    }
}

@MainActor
struct VerseNoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontResolutionContext) private var fontResolutionContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @AppStorage("noteEditorTextSizeStep") private var noteEditorTextSizeStep = NoteEditorTextSize.defaultStep

    let verse: VerseActionReference
    let existingNote: VerseNote?
    let preservesHighlightWhenRemovingNote: Bool

    @State private var title: String
    @State private var noteText: AttributedString
    @State private var noteSelection = AttributedTextSelection()
    @State private var selectedColor: VerseHighlightColor?
    @State private var selectedCategory: NoteCategory
    @State private var persistenceFailure: PersistenceFailure?
    @State private var selectedScriptureReference: ScriptureRef?
    @State private var referenceLinkTask: Task<Void, Never>?

    private func scheduleReferenceLinking() {
        referenceLinkTask?.cancel()
        referenceLinkTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            linkScriptureReferences()
        }
    }

    init(
        verse: VerseActionReference,
        existingNote: VerseNote?,
        preservesHighlightWhenRemovingNote: Bool = false
    ) {
        self.verse = verse
        self.existingNote = existingNote
        self.preservesHighlightWhenRemovingNote = preservesHighlightWhenRemovingNote
        _title = State(initialValue: existingNote?.title ?? "")
        _noteText = State(initialValue: Self.loadFormattedContent(from: existingNote))
        _selectedColor = State(
            initialValue: existingNote.flatMap { VerseHighlightColor(rawValue: $0.highlightColor) }
        )
        _selectedCategory = State(
            initialValue: existingNote.flatMap { NoteCategory(rawValue: $0.categoryRawValue) } ?? .scripture
        )
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 14) {
                NoteEditorTitleField(title: $title, placeholder: "Scripture note title")

                if contextualTipsEnabled {
                    ScriptureReferenceLinkTip()
                }

                ScriptureEditorReferenceCard(
                    reference: "\(verse.bookName) \(verse.chapterNumber):\(verse.verseNumber)",
                    verseText: verse.verseText
                )

                VerseNoteOptionsBar(
                    category: $selectedCategory,
                    highlight: $selectedColor
                )

                TextEditor(text: $noteText, selection: $noteSelection)
                    .font(.body)
                    .dynamicTypeSize(NoteEditorTextSize.dynamicTypeSize(for: noteEditorTextSizeStep))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.1))
                    }
                    .accessibilityLabel("Note")
                    .environment(\.openURL, OpenURLAction { url in
                        guard let reference = BibleReferenceLinker.parse(url: url) else {
                            return .systemAction(url)
                        }
                        selectedScriptureReference = reference
                        return .handled
                    })
            }
            .frame(
                width: max(0, proxy.size.width - (editorHorizontalPadding * 2)),
                height: proxy.size.height
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical)
        .background(AppBackgroundView(tab: .notes))
        .safeAreaInset(edge: .bottom) {
            NoteFormattingBar(
                toggleBold: { toggleFontTrait(\.isBold) },
                toggleUnderline: toggleUnderline,
                toggleItalic: { toggleFontTrait(\.isItalic) },
                toggleStrikethrough: toggleStrikethrough,
                insertBullet: insertBullet,
                insertNumberedItem: insertNumberedItem,
                increaseIndent: increaseIndent,
                decreaseIndent: decreaseIndent,
                decreaseTextSize: decreaseTextSize,
                increaseTextSize: increaseTextSize,
                canDecreaseTextSize: noteEditorTextSizeStep > NoteEditorTextSize.minimumStep,
                canIncreaseTextSize: noteEditorTextSizeStep < NoteEditorTextSize.maximumStep,
                horizontalPadding: editorHorizontalPadding
            )
        }
        .navigationTitle(editorTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(existingNote == nil && trimmedNote.isEmpty && selectedColor == nil)
            }
            if existingNote != nil {
                ToolbarItem(placement: .secondaryAction) {
                    Button(
                        preservesHighlightWhenRemovingNote ? "Remove Note" : "Remove Note & Highlight",
                        systemImage: "trash",
                        role: .destructive,
                        action: deleteEntry
                    )
                }
            }
        }
        .persistenceFailureAlert(failure: $persistenceFailure)
        .onAppear(perform: linkScriptureReferences)
        .onChange(of: String(noteText.characters)) { _, _ in
            scheduleReferenceLinking()
        }
        .onDisappear {
            referenceLinkTask?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openScripturePreview)) { notification in
            guard let url = notification.object as? URL,
                  let reference = BibleReferenceLinker.parse(url: url) else { return }
            selectedScriptureReference = reference
        }
        .sheet(item: $selectedScriptureReference) { reference in
            ScriptureReferencePreview(
                reference: reference,
                copyAction: { copyScripture(reference) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var trimmedNote: String {
        String(noteText.characters).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var editorTitle: LocalizedStringResource {
        if preservesHighlightWhenRemovingNote {
            "Edit Scripture Note"
        } else {
            existingNote == nil ? "Add Note & Highlight" : "Edit Note & Highlight"
        }
    }

    private var editorHorizontalPadding: CGFloat {
        horizontalSizeClass == .compact ? 24 : 16
    }

    private static func loadFormattedContent(from note: VerseNote?) -> AttributedString {
        guard let note else {
            return AttributedString()
        }
        if let data = note.formattedContent,
           let formatted = try? JSONDecoder().decode(AttributedString.self, from: data) {
            return formatted
        }
        return AttributedString(note.content)
    }

    private func linkScriptureReferences() {
        let linked = BibleReferenceLinker.linkify(noteText)
        guard linked != noteText else { return }
        noteText = linked
    }

    private func copyScripture(_ reference: ScriptureRef) {
        guard let passage = BibleReferenceLinker.loadVerses(for: reference),
              !passage.verses.isEmpty else { return }
        let text = passage.verses.map(\.text).joined(separator: " ")
        UIPasteboard.general.string = "\(text)\n\(passage.title)"
        Haptics.success()
    }

    private func toggleFontTrait(_ trait: KeyPath<Font.Resolved, Bool>) {
        let resolvedFont = (noteSelection.typingAttributes(in: noteText).font ?? .body)
            .resolve(in: fontResolutionContext)
        let shouldEnable = !resolvedFont[keyPath: trait]
        noteText.transformAttributes(in: &noteSelection) {
            let font = $0.font ?? .body
            if trait == \.isBold {
                $0.font = font.bold(shouldEnable)
            } else {
                $0.font = font.italic(shouldEnable)
            }
        }
    }

    private func toggleUnderline() {
        let shouldEnable = noteSelection.typingAttributes(in: noteText).underlineStyle == nil
        noteText.transformAttributes(in: &noteSelection) {
            $0.underlineStyle = shouldEnable ? .single : nil
        }
    }

    private func toggleStrikethrough() {
        let shouldEnable = noteSelection.typingAttributes(in: noteText).strikethroughStyle == nil
        noteText.transformAttributes(in: &noteSelection) {
            $0.strikethroughStyle = shouldEnable ? .single : nil
        }
    }

    private func insertBullet() {
        noteText.replaceSelection(&noteSelection, withCharacters: "• ")
    }

    private func insertNumberedItem() {
        noteText.replaceSelection(&noteSelection, withCharacters: "1. ")
    }

    private func increaseIndent() {
        guard case .insertionPoint = noteSelection.indices(in: noteText) else { return }
        noteText.replaceSelection(&noteSelection, withCharacters: "    ")
    }

    private func decreaseIndent() {
        guard case let .insertionPoint(caret) = noteSelection.indices(in: noteText),
              caret > noteText.startIndex else { return }

        let characters = noteText.characters
        var lineStart = caret
        while lineStart > noteText.startIndex {
            let previous = characters.index(before: lineStart)
            if characters[previous] == "\n" { break }
            lineStart = previous
        }

        var indentEnd = lineStart
        for _ in 0..<4 where indentEnd < noteText.endIndex && characters[indentEnd] == " " {
            indentEnd = characters.index(after: indentEnd)
        }
        guard indentEnd > lineStart else { return }
        noteText.replaceSubrange(lineStart..<indentEnd, with: AttributedString())
        noteSelection = AttributedTextSelection(insertionPoint: lineStart)
    }

    private func decreaseTextSize() {
        noteEditorTextSizeStep = max(NoteEditorTextSize.minimumStep, noteEditorTextSizeStep - 1)
    }

    private func increaseTextSize() {
        noteEditorTextSizeStep = min(NoteEditorTextSize.maximumStep, noteEditorTextSizeStep + 1)
    }

    private func save() {
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                if let existingNote, trimmedNote.isEmpty, selectedColor == nil {
                    modelContext.delete(existingNote)
                    try modelContext.save()
                    return
                }

                let note = existingNote ?? VerseNote(
                    bookName: verse.bookName,
                    chapterNumber: verse.chapterNumber,
                    verseNumber: verse.verseNumber,
                    verseText: verse.verseText
                )
                note.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                note.content = trimmedNote
                note.formattedContent = try JSONEncoder().encode(noteText)
                note.highlightColor = selectedColor?.rawValue ?? ""
                note.categoryRawValue = selectedCategory.rawValue
                note.updatedAt = Date()
                if existingNote == nil {
                    modelContext.insert(note)
                }
                try modelContext.save()
            },
            onSuccess: {
                Haptics.success()
                dismiss()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }

    private func deleteEntry() {
        guard let existingNote else { return }
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                if preservesHighlightWhenRemovingNote, !existingNote.highlightColor.isEmpty {
                    existingNote.title = ""
                    existingNote.content = ""
                    existingNote.formattedContent = nil
                    existingNote.updatedAt = Date()
                } else {
                    modelContext.delete(existingNote)
                }
                try modelContext.save()
            },
            onSuccess: {
                Haptics.selection()
                dismiss()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }
}

private struct ScriptureReferencePreview: View {
    @Environment(\.dismiss) private var dismiss
    @State private var passage: (title: String, verses: [Verse])?
    @State private var isLoading = true

    let reference: ScriptureRef
    let copyAction: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView("Loading scripture…")
                            .frame(maxWidth: .infinity, alignment: .center)
                    } else if let passage, !passage.verses.isEmpty {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(passage.verses) { verse in
                                HStack(alignment: .firstTextBaseline, spacing: 10) {
                                    Text(verse.number, format: .number)
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                        .frame(minWidth: 24, alignment: .trailing)

                                    Text(verse.text)
                                        .font(.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                        .textSelection(.enabled)
                    } else {
                        ContentUnavailableView(
                            "Scripture Unavailable",
                            systemImage: "book.closed",
                            description: Text("The referenced passage could not be loaded.")
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .navigationTitle(passage?.title ?? "Scripture")
            .navigationBarTitleDisplayMode(.inline)
            .task(id: reference.id) {
                isLoading = true
                passage = await BibleReferenceLinker.loadVersesEnsuringLoaded(for: reference)
                isLoading = false
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close scripture")
                }

                ToolbarItemGroup(placement: .confirmationAction) {
                    Button(action: copyAction) {
                        Image(systemName: "doc.on.doc")
                    }
                    .accessibilityLabel("Copy scripture")
                    .disabled(passage?.verses.isEmpty != false)

                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share scripture")
                    .disabled(passage?.verses.isEmpty != false)
                }
            }
        }
    }

    private var shareText: String {
        guard let passage else { return "" }
        let verses = passage.verses
            .map { "\($0.number) \($0.text)" }
            .joined(separator: "\n")
        return "\(passage.title)\n\n\(verses)"
    }
}

private struct NoteFormattingBar: View {
    let toggleBold: () -> Void
    let toggleUnderline: () -> Void
    let toggleItalic: () -> Void
    let toggleStrikethrough: () -> Void
    let insertBullet: () -> Void
    let insertNumberedItem: () -> Void
    let increaseIndent: () -> Void
    let decreaseIndent: () -> Void
    let decreaseTextSize: () -> Void
    let increaseTextSize: () -> Void
    let canDecreaseTextSize: Bool
    let canIncreaseTextSize: Bool
    var horizontalPadding: CGFloat = 16

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                formattingButton("Bold", systemImage: "bold", action: toggleBold)
                formattingButton("Underline", systemImage: "underline", action: toggleUnderline)
                formattingButton("Italic", systemImage: "italic", action: toggleItalic)
                formattingButton("Strikethrough", systemImage: "strikethrough", action: toggleStrikethrough)

                Menu {
                    Button("Bulleted List", systemImage: "list.bullet", action: insertBullet)
                    Button("Numbered List", systemImage: "list.number", action: insertNumberedItem)
                    Divider()
                    Button("Decrease Indent", systemImage: "decrease.indent", action: decreaseIndent)
                    Button("Increase Indent", systemImage: "increase.indent", action: increaseIndent)
                } label: {
                    Image(systemName: "list.bullet.indent")
                        .frame(width: 30, height: 30)
                        .contentShape(.rect)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Lists and indentation")

                Divider().frame(height: 24)

                formattingButton("Decrease text size", systemImage: "textformat.size.smaller", action: decreaseTextSize)
                    .disabled(!canDecreaseTextSize)
                formattingButton("Increase text size", systemImage: "textformat.size.larger", action: increaseTextSize)
                    .disabled(!canIncreaseTextSize)
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, 4)
    }

    private func formattingButton(
        _ accessibilityLabel: LocalizedStringKey,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 30, height: 30)
                .contentShape(.rect)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(accessibilityLabel)
    }
}

private enum NoteTextColor: String, CaseIterable, Identifiable {
    case red
    case orange
    case yellow
    case green
    case blue
    case purple

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .red: "Red"
        case .orange: "Orange"
        case .yellow: "Yellow"
        case .green: "Green"
        case .blue: "Blue"
        case .purple: "Purple"
        }
    }

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: Color(red: 0.72, green: 0.52, blue: 0.02)
        case .green: .green
        case .blue: .blue
        case .purple: .purple
        }
    }

}

private enum NoteEditorTextSize {
    static let minimumStep = 0
    static let maximumStep = 6
    static let defaultStep = 3

    static func dynamicTypeSize(for step: Int) -> DynamicTypeSize {
        switch min(maximumStep, max(minimumStep, step)) {
        case 0: .xSmall
        case 1: .small
        case 2: .medium
        case 3: .large
        case 4: .xLarge
        case 5: .xxLarge
        default: .xxxLarge
        }
    }
}

private struct NoteEditorTitleField: View {
    @Binding var title: String
    let placeholder: LocalizedStringKey

    var body: some View {
        TextField(placeholder, text: $title, axis: .vertical)
            .font(.title2.bold())
            .textFieldStyle(.plain)
            .padding(.horizontal, 2)
            .accessibilityLabel("Note title")
    }
}

private struct ScriptureReferenceLinkTip: View {
    var body: some View {
        ContextualTipView(
            id: "notes.scriptureLinks",
            title: "Link Scripture references",
            message: "Type a reference such as John 3:16 in your note. It automatically becomes a tappable link with a Scripture preview.",
            systemImage: "link.badge.plus"
        )
    }
}

private struct ScriptureEditorReferenceCard: View {
    let reference: String
    let verseText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(reference, systemImage: "book.closed.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            Text(verseText)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct VerseNoteOptionsBar: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Binding var category: NoteCategory
    @Binding var highlight: VerseHighlightColor?

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                VStack(alignment: .leading, spacing: 8) {
                    NoteCategoryMenu(category: $category)
                    Divider()
                    ScriptureHighlightPicker(selection: $highlight)
                }
            } else {
                HStack(spacing: 12) {
                    NoteCategoryMenu(category: $category)
                    Divider().frame(height: 28)
                    ScriptureHighlightPicker(selection: $highlight)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

}

private struct ScriptureHighlightPicker: View {
    @Binding var selection: VerseHighlightColor?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Scripture Highlight", systemImage: "highlighter")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HighlightColorPicker(selection: $selection)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct NoteCategoryMenu: View {
    @Binding var category: NoteCategory

    var body: some View {
        Menu {
            Picker("Tag", selection: $category) {
                ForEach(NoteCategory.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            Label(category.title, systemImage: "tag.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
        }
        .accessibilityLabel("Note tag")
        .accessibilityValue(Text(category.title))
    }
}

private struct HighlightColorPicker: View {
    @Binding var selection: VerseHighlightColor?

    var body: some View {
        HStack(spacing: 14) {
            ForEach(VerseHighlightColor.allCases) { highlight in
                Button {
                    selection = highlight
                } label: {
                    Circle()
                        .fill(highlight.color)
                        .frame(width: 32, height: 32)
                        .overlay {
                            if selection == highlight {
                                Circle().stroke(.primary, lineWidth: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(highlight.name))
                .accessibilityAddTraits(selection == highlight ? .isSelected : [])
            }

            Button {
                selection = nil
            } label: {
                Circle()
                    .fill(Color.secondary.opacity(0.16))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .overlay {
                        if selection == nil {
                            Circle().stroke(.primary, lineWidth: 3)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear highlight")
            .accessibilityAddTraits(selection == nil ? .isSelected : [])
        }
        .frame(maxWidth: .infinity)
    }
}

private enum NotesTabSort: String, CaseIterable, Identifiable {
    case modified
    case created
    case title
    case tag
    case color

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .modified: "Date Modified"
        case .created: "Date Created"
        case .title: "Title"
        case .tag: "Tag"
        case .color: "Highlight Color"
        }
    }

    var systemImage: String {
        switch self {
        case .modified: "pencil"
        case .created: "calendar"
        case .title: "textformat"
        case .tag: "tag"
        case .color: "highlighter"
        }
    }

    /// Dates read most naturally newest-first; text-based fields read A–Z.
    var defaultAscending: Bool {
        switch self {
        case .modified, .created: false
        case .title, .tag, .color: true
        }
    }

    func orderTitle(ascending: Bool) -> LocalizedStringResource {
        switch self {
        case .modified, .created: ascending ? "Oldest First" : "Newest First"
        case .title, .tag: ascending ? "A–Z" : "Z–A"
        case .color: ascending ? "Ascending" : "Descending"
        }
    }
}

private enum NotesFilter: String, CaseIterable, Identifiable {
    case all
    case sermon
    case personal
    case scripture

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .all: "All"
        case .sermon: "Sermon"
        case .personal: "Personal"
        case .scripture: "Scripture"
        }
    }

    func libraryTitle(noteCount: Int) -> LocalizedStringKey {
        switch self {
        case .all: "All Notes (\(noteCount))"
        case .sermon: "Sermon Notes (\(noteCount))"
        case .personal: "Personal Notes (\(noteCount))"
        case .scripture: "Scripture Notes (\(noteCount))"
        }
    }
}

private enum NotesListItem: Identifiable {
    enum ID: Hashable {
        case scripture(PersistentIdentifier)
        case user(PersistentIdentifier)
    }

    case scripture(VerseNote)
    case user(UserNote)

    var id: ID {
        switch self {
        case .scripture(let note): .scripture(note.persistentModelID)
        case .user(let note): .user(note.persistentModelID)
        }
    }

    var title: String {
        switch self {
        case .scripture(let note):
            note.title.isEmpty ? "\(note.bookName) \(note.chapterNumber):\(note.verseNumber)" : note.title
        case .user(let note):
            note.title.isEmpty ? "Untitled Note" : note.title
        }
    }

    var categoryRawValue: String {
        switch self {
        case .scripture(let note): note.categoryRawValue
        case .user(let note): note.categoryRawValue
        }
    }

    var preview: String {
        let content: String
        switch self {
        case .scripture(let note): content = note.content
        case .user(let note): content = note.content
        }
        return content
            .components(separatedBy: .newlines)
            .lazy
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? ""
    }

    var highlightColor: String {
        switch self {
        case .scripture(let note): note.highlightColor
        case .user: ""
        }
    }

    var reference: String? {
        switch self {
        case .scripture(let note):
            "\(note.bookName) \(note.chapterNumber):\(note.verseNumber)"
        case .user:
            nil
        }
    }

    var createdAt: Date? {
        switch self {
        case .scripture(let note): note.createdAt
        case .user(let note): note.createdAt
        }
    }

    var updatedAt: Date? {
        switch self {
        case .scripture(let note): note.updatedAt
        case .user(let note): note.updatedAt
        }
    }

    var isFavorite: Bool {
        switch self {
        case .scripture(let note): note.isFavorite
        case .user(let note): note.isFavorite
        }
    }

    /// Whether the entry has written content, as opposed to being a verse highlight only.
    var hasNoteText: Bool {
        switch self {
        case .scripture(let note): !note.title.isEmpty || !note.content.isEmpty
        case .user: true
        }
    }

    /// Scripture notes with a highlight keep the highlight when their note is deleted,
    /// matching the editor's "Remove Note" behavior. Highlight-only entries remove the highlight.
    var deleteTitle: LocalizedStringResource {
        guard !highlightColor.isEmpty else { return "Delete" }
        return hasNoteText ? "Delete Note" : "Remove Highlight"
    }

    var shareText: String {
        switch self {
        case .scripture(let note):
            let title = note.title.isEmpty ? "Scripture Note" : note.title
            return "\(title)\n\(note.bookName) \(note.chapterNumber):\(note.verseNumber)\n\n\(note.verseText)\n\n\(note.content)"
        case .user(let note):
            let title = note.title.isEmpty ? "Untitled Note" : note.title
            return "\(title)\n\n\(note.content)"
        }
    }

    func toggleFavorite() {
        switch self {
        case .scripture(let note): note.isFavorite.toggle()
        case .user(let note): note.isFavorite.toggle()
        }
    }

    func openInBible() {
        guard case .scripture(let note) = self else { return }
        NotificationCenter.default.post(name: .openBibleReference, object: nil, userInfo: [
            "book": note.bookName,
            "chapter": note.chapterNumber,
            "verse": note.verseNumber
        ])
    }

    func matchesSearch(_ searchText: String) -> Bool {
        guard !searchText.isEmpty else { return true }
        switch self {
        case .scripture(let note):
            return title.localizedCaseInsensitiveContains(searchText) ||
                note.bookName.localizedCaseInsensitiveContains(searchText) ||
                note.verseText.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText) ||
                "\(note.chapterNumber):\(note.verseNumber)".localizedCaseInsensitiveContains(searchText)
        case .user(let note):
            return title.localizedCaseInsensitiveContains(searchText) ||
                note.content.localizedCaseInsensitiveContains(searchText)
        }
    }
}

private enum NotesHighlightFilter: String, CaseIterable, Identifiable {
    case all
    case none
    case yellow
    case green
    case blue
    case pink
    case purple

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .all: "All Highlight Colors"
        case .none: "No Highlight"
        case .yellow: "Yellow"
        case .green: "Green"
        case .blue: "Blue"
        case .pink: "Pink"
        case .purple: "Purple"
        }
    }

    var highlightColor: VerseHighlightColor? {
        VerseHighlightColor(rawValue: rawValue)
    }
}

@MainActor
struct NotesAndHighlightsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VerseNote.updatedAt, order: .reverse) private var scriptureNotes: [VerseNote]
    @Query(sort: \UserNote.updatedAt, order: .reverse) private var userNotes: [UserNote]

    @AppStorage("notesTabSortField") private var sortFieldRawValue = NotesTabSort.modified.rawValue
    @AppStorage("notesTabSortAscending") private var sortAscending = NotesTabSort.modified.defaultAscending
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @State private var selectedFilter = NotesFilter.all
    @State private var highlightFilter = NotesHighlightFilter.all
    @State private var searchText = ""
    @State private var isSearchPresented = false
    @State private var selectedScriptureNote: VerseNote?
    @State private var selectedUserNote: UserNote?
    @State private var isCreatingNote = false
    @State private var isEditingSelection = false
    @State private var isShowingCompactDetail = false
    @State private var deletedNoteSnapshot: DeletedNoteSnapshot?
    @State private var isShowingDeleteUndo = false
    @State private var deleteUndoText = ""

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactContent
            } else {
                regularContent
            }
        }
        .background(AppBackgroundView(tab: .notes))
        .navigationTitle("Notes")
        .navigationDestination(isPresented: $isShowingCompactDetail) {
            NoteDetailCard(
                scriptureNote: selectedScriptureNote,
                userNote: selectedUserNote,
                editAction: {
                    isShowingCompactDetail = false
                    DispatchQueue.main.async {
                        isEditingSelection = true
                    }
                }
            )
            .padding()
            .background(AppBackgroundView(tab: .notes))
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
        }
        .searchable(
            text: $searchText,
            isPresented: $isSearchPresented,
            prompt: "Search all notes"
        )
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NotesViewOptionsMenu(
                    sortField: sortFieldBinding,
                    sortAscending: $sortAscending,
                    highlightFilter: $highlightFilter
                )

                Button {
                    isCreatingNote = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create note")
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .fullScreenCover(isPresented: $isCreatingNote) {
            NavigationStack {
                UserNoteEditorView(
                    existingNote: nil,
                    defaultCategory: selectedFilter.noteCategory ?? .personal
                )
            }
        }
        .fullScreenCover(isPresented: $isEditingSelection) {
            NavigationStack {
                if let selectedScriptureNote {
                    VerseNoteEditorView(
                        verse: VerseActionReference(
                            bookName: selectedScriptureNote.bookName,
                            chapterNumber: selectedScriptureNote.chapterNumber,
                            verseNumber: selectedScriptureNote.verseNumber,
                            verseText: selectedScriptureNote.verseText
                        ),
                        existingNote: selectedScriptureNote,
                        preservesHighlightWhenRemovingNote: true
                    )
                } else if let selectedUserNote {
                    UserNoteEditorView(existingNote: selectedUserNote)
                }
            }
        }
        .background {
            ZStack {
                keyboardShortcutControls
                NotesKeyboardCommandResponder(
                    isEnabled: !isSearchPresented && !isCreatingNote && !isEditingSelection,
                    moveSelection: moveSelection,
                    requestDeletion: requestSelectedNoteDeletion
                )
            }
        }
        .appToast(
            isPresented: $isShowingDeleteUndo,
            symbol: "trash",
            text: deleteUndoText,
            tint: .red,
            actionTitle: "Undo",
            action: undoLastDeletion
        )
        .onAppear(perform: selectFirstVisibleNoteIfNeeded)
        .onChange(of: selectedFilter) { _, _ in selectFirstVisibleNoteIfNeeded() }
        .onChange(of: highlightFilter) { _, _ in selectFirstVisibleNoteIfNeeded() }
        .onChange(of: sortFieldRawValue) { _, _ in selectFirstVisibleNoteIfNeeded() }
        .onChange(of: sortAscending) { _, _ in selectFirstVisibleNoteIfNeeded() }
        .onChange(of: searchText) { _, _ in selectFirstVisibleNoteIfNeeded() }
    }

    private var keyboardShortcutControls: some View {
        Group {
            Button("Search Notes") {
                isSearchPresented = true
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("Edit Selected Note") {
                editSelectedNote()
            }
            .keyboardShortcut("e", modifiers: .command)
            .disabled(selectedScriptureNote == nil && selectedUserNote == nil)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private var compactContent: some View {
        VStack(spacing: 12) {
            NotesCategoryStrip(selection: $selectedFilter, highlightFilter: $highlightFilter)
            contextualTip

            notesList(
                newNoteAction: nil,
                selectAction: { item in
                    select(item)
                    isShowingCompactDetail = true
                }
            )
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    private var regularContent: some View {
        VStack(spacing: 12) {
            NotesCategoryStrip(selection: $selectedFilter, highlightFilter: $highlightFilter)
            contextualTip

            ResizableNotesColumns {
                notesList(
                    newNoteAction: { isCreatingNote = true },
                    selectAction: select
                )
                .padding(.horizontal, 2)
                .padding(.vertical, 12)
            } detail: {
                VStack(spacing: 12) {
                    if selectedNoteIsExcludedFromVisibleNotes {
                        Label(
                            "This note isn’t included in the active filter or search.",
                            systemImage: "line.3.horizontal.decrease.circle"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            Color.orange.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityLabel("The open note is not included in the active filter or search.")
                    }

                    NoteDetailCard(
                        scriptureNote: selectedScriptureNote,
                        userNote: selectedUserNote,
                        editAction: { isEditingSelection = true }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
    }

    @ViewBuilder
    private var contextualTip: some View {
        if contextualTipsEnabled {
            ContextualTipView(
                id: "notes.quickActions",
                title: "Browse and manage notes",
                message: "Filter by tag or highlight color. Select a note to follow links without editing, or swipe or press and hold it for quick actions.",
                systemImage: "hand.point.up.left"
            )
        }
    }

    private func notesList(
        newNoteAction: (() -> Void)?,
        selectAction: @escaping (NotesListItem) -> Void
    ) -> some View {
        NotesListCard(
            notes: visibleNotes,
            selectedID: selectedItem?.id,
            filter: selectedFilter,
            hasAnyNotes: !scriptureNotes.isEmpty || !userNotes.isEmpty,
            showsClearFiltersAction: hasActiveFilters,
            clearFiltersAction: clearFilters,
            newNoteAction: newNoteAction,
            createFirstNoteAction: { isCreatingNote = true },
            selectAction: selectAction,
            editAction: { item in
                select(item)
                isEditingSelection = true
            },
            deleteAction: delete
        )
    }

    /// Notes matching the active tag, highlight filter, and search. Favorites are
    /// pinned above the rest but are still subject to every filter.
    private var visibleNotes: [NotesListItem] {
        let allNotes = scriptureNotes.map(NotesListItem.scripture) + userNotes.map(NotesListItem.user)
        let matchingNotes = allNotes.filter { note in
            matchesSelectedCategory(note.categoryRawValue) &&
                matchesHighlight(note.highlightColor) &&
                note.matchesSearch(searchText)
        }
        return sort(matchingNotes.filter(\.isFavorite)) + sort(matchingNotes.filter { !$0.isFavorite })
    }

    private var sortField: NotesTabSort {
        NotesTabSort(rawValue: sortFieldRawValue) ?? .modified
    }

    /// Picking a new sort field resets the direction to that field's natural order.
    private var sortFieldBinding: Binding<NotesTabSort> {
        Binding(
            get: { sortField },
            set: { newValue in
                guard newValue != sortField else { return }
                sortFieldRawValue = newValue.rawValue
                sortAscending = newValue.defaultAscending
            }
        )
    }

    private var hasActiveFilters: Bool {
        selectedFilter != .all || highlightFilter != .all || !searchText.isEmpty
    }

    private func clearFilters() {
        withAnimation(.snappy) {
            selectedFilter = .all
            highlightFilter = .all
            searchText = ""
        }
    }

    private func matchesSelectedCategory(_ rawValue: String) -> Bool {
        selectedFilter == .all || rawValue == selectedFilter.rawValue
    }

    private func matchesHighlight(_ rawValue: String) -> Bool {
        switch highlightFilter {
        case .all: true
        case .none: rawValue.isEmpty
        default: rawValue == highlightFilter.rawValue
        }
    }

    private func sort(_ notes: [NotesListItem]) -> [NotesListItem] {
        let field = sortField
        let ascending = sortAscending
        return notes.sorted { lhs, rhs in
            let order = Self.compare(lhs, rhs, by: field)
            if order != .orderedSame {
                return order == (ascending ? .orderedAscending : .orderedDescending)
            }
            // Ties always fall back to title A–Z so the order is stable and predictable.
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private static func compare(
        _ lhs: NotesListItem,
        _ rhs: NotesListItem,
        by field: NotesTabSort
    ) -> ComparisonResult {
        switch field {
        case .modified:
            return (lhs.updatedAt ?? .distantPast).compare(rhs.updatedAt ?? .distantPast)
        case .created:
            return (lhs.createdAt ?? .distantPast).compare(rhs.createdAt ?? .distantPast)
        case .title:
            return lhs.title.localizedStandardCompare(rhs.title)
        case .tag:
            return lhs.categoryRawValue.localizedStandardCompare(rhs.categoryRawValue)
        case .color:
            // Follow the highlight picker's color order; notes without a highlight sort last.
            let left = colorPosition(lhs.highlightColor)
            let right = colorPosition(rhs.highlightColor)
            return left == right ? .orderedSame : (left < right ? .orderedAscending : .orderedDescending)
        }
    }

    private static func colorPosition(_ rawValue: String) -> Int {
        VerseHighlightColor.allCases.firstIndex { $0.rawValue == rawValue } ?? VerseHighlightColor.allCases.count
    }

    private var selectedNoteIsExcludedFromVisibleNotes: Bool {
        if let selectedScriptureNote {
            return !visibleNotes.contains {
                if case .scripture(let note) = $0 { return note === selectedScriptureNote }
                return false
            }
        }

        if let selectedUserNote {
            return !visibleNotes.contains {
                if case .user(let note) = $0 { return note === selectedUserNote }
                return false
            }
        }

        return false
    }

    private func selectFirstVisibleNoteIfNeeded() {
        guard selectedScriptureNote == nil, selectedUserNote == nil else { return }
        selectFirstVisibleNote()
    }

    private func moveSelection(by offset: Int) {
        guard !visibleNotes.isEmpty else { return }

        let selectedID: NotesListItem.ID? = if let selectedScriptureNote {
            .scripture(selectedScriptureNote.persistentModelID)
        } else if let selectedUserNote {
            .user(selectedUserNote.persistentModelID)
        } else {
            nil
        }
        let currentIndex = selectedID.flatMap { id in
            visibleNotes.firstIndex { $0.id == id }
        }
        let proposedIndex = (currentIndex ?? (offset > 0 ? -1 : visibleNotes.count)) + offset
        let destinationIndex = min(max(proposedIndex, 0), visibleNotes.count - 1)
        select(visibleNotes[destinationIndex])
    }

    private func editSelectedNote() {
        guard selectedScriptureNote != nil || selectedUserNote != nil else { return }
        isEditingSelection = true
    }

    private func requestSelectedNoteDeletion() {
        guard let selectedItem else { return }
        delete(selectedItem)
    }

    private var selectedItem: NotesListItem? {
        if let selectedScriptureNote {
            return .scripture(selectedScriptureNote)
        }
        if let selectedUserNote {
            return .user(selectedUserNote)
        }
        return nil
    }

    private func delete(_ item: NotesListItem) {
        if case .scripture(let note) = item, !note.highlightColor.isEmpty, item.hasNoteText {
            // Match the editor's "Remove Note": clear the written note but keep the verse highlight.
            deletedNoteSnapshot = .scriptureText(note, VerseNoteSnapshot(note: note))
            note.title = ""
            note.content = ""
            note.formattedContent = nil
            note.updatedAt = Date()
            try? modelContext.save()
            showDeleteUndo("Note deleted · Highlight kept")
            return
        }

        let notesBeforeDeletion = visibleNotes
        let deletedIndex = notesBeforeDeletion.firstIndex { $0.id == item.id }
        let wasSelected: Bool

        switch item {
        case .scripture(let note):
            wasSelected = selectedScriptureNote === note
            deletedNoteSnapshot = .scripture(VerseNoteSnapshot(note: note), wasSelected: wasSelected)
            modelContext.delete(note)
        case .user(let note):
            wasSelected = selectedUserNote === note
            deletedNoteSnapshot = .user(UserNoteSnapshot(note: note), wasSelected: wasSelected)
            modelContext.delete(note)
        }
        try? modelContext.save()

        if wasSelected {
            selectedScriptureNote = nil
            selectedUserNote = nil
            let remainingNotes = notesBeforeDeletion.filter { $0.id != item.id }
            if !remainingNotes.isEmpty {
                select(remainingNotes[min(deletedIndex ?? 0, remainingNotes.count - 1)])
            }
        }

        showDeleteUndo(item.hasNoteText ? "Note deleted" : "Highlight removed")
    }

    private func showDeleteUndo(_ text: String) {
        deleteUndoText = text
        isShowingDeleteUndo = false
        Task { @MainActor in
            await Task.yield()
            withAnimation(.snappy) {
                isShowingDeleteUndo = true
            }
        }
    }

    private func undoLastDeletion() {
        guard let deletedNoteSnapshot else { return }

        switch deletedNoteSnapshot {
        case .scriptureText(let note, let snapshot):
            snapshot.restoreText(to: note)
        case .scripture(let snapshot, let wasSelected):
            let note = snapshot.makeNote()
            modelContext.insert(note)
            if wasSelected {
                select(.scripture(note))
            }
        case .user(let snapshot, let wasSelected):
            let note = snapshot.makeNote()
            modelContext.insert(note)
            if wasSelected {
                select(.user(note))
            }
        }

        try? modelContext.save()
        self.deletedNoteSnapshot = nil
    }

    private func select(_ item: NotesListItem) {
        switch item {
        case .scripture(let note):
            selectedScriptureNote = note
            selectedUserNote = nil
        case .user(let note):
            selectedScriptureNote = nil
            selectedUserNote = note
        }
    }

    private func selectFirstVisibleNote() {
        switch visibleNotes.first {
        case .scripture(let note):
            selectedScriptureNote = note
            selectedUserNote = nil
        case .user(let note):
            selectedScriptureNote = nil
            selectedUserNote = note
        case nil:
            selectedScriptureNote = nil
            selectedUserNote = nil
        }
    }
}

private struct ResizableNotesColumns<ListContent: View, DetailContent: View>: View {
    @State private var listColumnFraction: CGFloat = 0.4
    @GestureState private var dragTranslation: CGFloat = 0

    let listContent: ListContent
    let detailContent: DetailContent

    init(
        @ViewBuilder listContent: () -> ListContent,
        @ViewBuilder detail: () -> DetailContent
    ) {
        self.listContent = listContent()
        self.detailContent = detail()
    }

    var body: some View {
        GeometryReader { proxy in
            let dividerWidth: CGFloat = 20
            let availableWidth = max(proxy.size.width - dividerWidth, 1)
            let minimumListWidth = min(300, availableWidth * 0.45)
            let minimumDetailWidth = min(360, availableWidth - minimumListWidth)
            let minimumFraction = minimumListWidth / availableWidth
            let maximumFraction = (availableWidth - minimumDetailWidth) / availableWidth
            let committedFraction = min(max(listColumnFraction, minimumFraction), maximumFraction)
            let previewFraction = min(
                max(
                    committedFraction + (dragTranslation / availableWidth),
                    minimumFraction
                ),
                maximumFraction
            )
            let listWidth = availableWidth * committedFraction
            let previewListWidth = availableWidth * previewFraction

            ZStack(alignment: .leading) {
                HStack(alignment: .top, spacing: 0) {
                    listContent
                        .frame(width: listWidth)

                    Color.clear
                        .frame(width: dividerWidth)

                    detailContent
                        .frame(width: availableWidth - listWidth)
                }

                Capsule()
                    .fill(Color.secondary.opacity(0.45))
                    .frame(width: 4, height: 48)
                    .frame(width: dividerWidth)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .offset(x: previewListWidth)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .updating($dragTranslation) { value, translation, _ in
                                translation = value.translation.width
                            }
                            .onEnded { value in
                                listColumnFraction = min(
                                    max(
                                        committedFraction + (value.translation.width / availableWidth),
                                        minimumFraction
                                    ),
                                    maximumFraction
                                )
                            }
                    )
                    .accessibilityElement()
                    .accessibilityLabel("Resize notes list")
                    .accessibilityValue("\(Int(previewFraction * 100)) percent")
                    .accessibilityAdjustableAction { direction in
                        let adjustment: CGFloat = direction == .increment ? 0.05 : -0.05
                        listColumnFraction = min(
                            max(committedFraction + adjustment, minimumFraction),
                            maximumFraction
                        )
                    }
            }
        }
    }
}

private enum DeletedNoteSnapshot {
    case scripture(VerseNoteSnapshot, wasSelected: Bool)
    case user(UserNoteSnapshot, wasSelected: Bool)
    /// The note's text was cleared but the entry was kept for its verse highlight.
    case scriptureText(VerseNote, VerseNoteSnapshot)
}

private struct VerseNoteSnapshot {
    let title: String
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String
    let content: String
    let formattedContent: Data?
    let highlightColor: String
    let categoryRawValue: String
    let isFavorite: Bool
    let createdAt: Date?
    let updatedAt: Date?

    init(note: VerseNote) {
        title = note.title
        bookName = note.bookName
        chapterNumber = note.chapterNumber
        verseNumber = note.verseNumber
        verseText = note.verseText
        content = note.content
        formattedContent = note.formattedContent
        highlightColor = note.highlightColor
        categoryRawValue = note.categoryRawValue
        isFavorite = note.isFavorite
        createdAt = note.createdAt
        updatedAt = note.updatedAt
    }

    func makeNote() -> VerseNote {
        let note = VerseNote()
        note.title = title
        note.bookName = bookName
        note.chapterNumber = chapterNumber
        note.verseNumber = verseNumber
        note.verseText = verseText
        note.content = content
        note.formattedContent = formattedContent
        note.highlightColor = highlightColor
        note.categoryRawValue = categoryRawValue
        note.isFavorite = isFavorite
        note.createdAt = createdAt
        note.updatedAt = updatedAt
        return note
    }

    func restoreText(to note: VerseNote) {
        note.title = title
        note.content = content
        note.formattedContent = formattedContent
        note.updatedAt = updatedAt
    }
}

private struct UserNoteSnapshot {
    let title: String
    let content: String
    let formattedContent: Data?
    let categoryRawValue: String
    let isFavorite: Bool
    let createdAt: Date?
    let updatedAt: Date?

    init(note: UserNote) {
        title = note.title
        content = note.content
        formattedContent = note.formattedContent
        categoryRawValue = note.categoryRawValue
        isFavorite = note.isFavorite
        createdAt = note.createdAt
        updatedAt = note.updatedAt
    }

    func makeNote() -> UserNote {
        let note = UserNote()
        note.title = title
        note.content = content
        note.formattedContent = formattedContent
        note.categoryRawValue = categoryRawValue
        note.isFavorite = isFavorite
        note.createdAt = createdAt
        note.updatedAt = updatedAt
        return note
    }
}

private struct NotesKeyboardCommandResponder: UIViewRepresentable {
    let isEnabled: Bool
    let moveSelection: (Int) -> Void
    let requestDeletion: () -> Void

    func makeUIView(context: Context) -> KeyCommandView {
        KeyCommandView()
    }

    func updateUIView(_ view: KeyCommandView, context: Context) {
        view.moveSelection = moveSelection
        view.requestDeletion = requestDeletion
        view.isCommandHandlingEnabled = isEnabled

        DispatchQueue.main.async {
            if isEnabled {
                view.becomeFirstResponder()
            } else if view.isFirstResponder {
                view.resignFirstResponder()
            }
        }
    }

    @MainActor
    final class KeyCommandView: UIView {
        var moveSelection: ((Int) -> Void)?
        var requestDeletion: (() -> Void)?
        var isCommandHandlingEnabled = true

        override var canBecomeFirstResponder: Bool {
            isCommandHandlingEnabled
        }

        override var keyCommands: [UIKeyCommand]? {
            guard isCommandHandlingEnabled else { return nil }

            return [
                command(
                    input: UIKeyCommand.inputUpArrow,
                    action: #selector(selectPreviousNote),
                    title: "Previous Note"
                ),
                command(
                    input: UIKeyCommand.inputDownArrow,
                    action: #selector(selectNextNote),
                    title: "Next Note"
                ),
                command(
                    input: "\u{8}",
                    action: #selector(deleteSelectedNote),
                    title: "Delete Selected Note"
                ),
                command(
                    input: UIKeyCommand.inputDelete,
                    action: #selector(deleteSelectedNote),
                    title: "Delete Selected Note"
                )
            ]
        }

        private func command(input: String, action: Selector, title: String) -> UIKeyCommand {
            let command = UIKeyCommand(
                title: title,
                action: action,
                input: input,
                modifierFlags: []
            )
            return command
        }

        @objc private func selectPreviousNote() {
            moveSelection?(-1)
        }

        @objc private func selectNextNote() {
            moveSelection?(1)
        }

        @objc private func deleteSelectedNote() {
            requestDeletion?()
        }
    }
}

private struct NotesCategoryStrip: View {
    @Binding var selection: NotesFilter
    @Binding var highlightFilter: NotesHighlightFilter

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                if highlightFilter != .all {
                    activeHighlightChip
                }

                ForEach(NotesFilter.allCases) { filter in
                    Button {
                        withAnimation(.snappy) {
                            selection = filter
                        }
                    } label: {
                        Label(filter.title, systemImage: filter.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 40)
                            .foregroundStyle(selection == filter ? Color.white : Color.primary)
                            .background(
                                selection == filter ? Color.accentColor : Color.primary.opacity(0.07),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == filter ? .isSelected : [])
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
    }

    /// Makes an active highlight filter visible and removable with one tap.
    private var activeHighlightChip: some View {
        Button {
            withAnimation(.snappy) {
                highlightFilter = .all
            }
        } label: {
            HStack(spacing: 6) {
                if let color = highlightFilter.highlightColor?.color {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "circle.slash")
                }
                Text(highlightFilter.title)
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .frame(minHeight: 40)
            .foregroundStyle(.primary)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.accentColor.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Highlight filter")
        .accessibilityValue(Text(highlightFilter.title))
        .accessibilityHint("Removes the highlight color filter")
    }
}

private struct NotesListCard: View {
    let notes: [NotesListItem]
    let selectedID: NotesListItem.ID?
    let filter: NotesFilter
    let hasAnyNotes: Bool
    let showsClearFiltersAction: Bool
    let clearFiltersAction: () -> Void
    /// When provided, an inline "New Note" button appears in the list header.
    let newNoteAction: (() -> Void)?
    let createFirstNoteAction: () -> Void
    let selectAction: (NotesListItem) -> Void
    let editAction: (NotesListItem) -> Void
    let deleteAction: (NotesListItem) -> Void

    var body: some View {
        List {
            summaryHeader
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(
                    EdgeInsets(
                        top: AppDesignMetrics.cardPadding,
                        leading: AppDesignMetrics.cardPadding,
                        bottom: 4,
                        trailing: AppDesignMetrics.cardPadding
                    )
                )

            if notes.isEmpty {
                emptyState
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else if favoriteNotes.isEmpty {
                rows(for: otherNotes)
            } else {
                groupHeader("Favorites", systemImage: "star.fill")
                rows(for: favoriteNotes)

                if !otherNotes.isEmpty {
                    groupHeader("Notes", systemImage: "note.text")
                    rows(for: otherNotes)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.vertical, 0, for: .scrollContent)
        .clipShape(.rect(cornerRadius: AppDesignMetrics.cardCornerRadius))
        .heroCardSurface()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var favoriteNotes: [NotesListItem] {
        notes.filter(\.isFavorite)
    }

    private var otherNotes: [NotesListItem] {
        notes.filter { !$0.isFavorite }
    }

    private var summaryHeader: some View {
        HStack(spacing: 8) {
            Text(filter.libraryTitle(noteCount: notes.count))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            if showsClearFiltersAction {
                // Icon-only when sharing the header with the New Note button.
                if newNoteAction == nil {
                    clearFiltersButton.labelStyle(.titleAndIcon)
                } else {
                    clearFiltersButton.labelStyle(.iconOnly)
                }
            }

            if let newNoteAction {
                Button("New Note", systemImage: "plus", action: newNoteAction)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var clearFiltersButton: some View {
        Button("Clear All Filters", systemImage: "line.3.horizontal.decrease.circle") {
            clearFiltersAction()
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("Clear all filters")
    }

    private func groupHeader(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(
                EdgeInsets(
                    top: 12,
                    leading: AppDesignMetrics.cardPadding,
                    bottom: 4,
                    trailing: AppDesignMetrics.cardPadding
                )
            )
    }

    @ViewBuilder
    private var emptyState: some View {
        if hasAnyNotes {
            ContentUnavailableView {
                Label("No Matching Notes", systemImage: "note.text")
            } description: {
                Text("Try another tag, color, or search.")
            } actions: {
                if showsClearFiltersAction {
                    Button("Clear All Filters", systemImage: "line.3.horizontal.decrease.circle") {
                        clearFiltersAction()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        } else {
            ContentUnavailableView {
                Label("No Notes Yet", systemImage: "note.text")
            } description: {
                Text("Tap + to write a note, or press and hold a verse in the Bible to add a note or highlight.")
            } actions: {
                Button("New Note", systemImage: "plus", action: createFirstNoteAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func rows(for items: [NotesListItem]) -> some View {
        ForEach(items) { item in
            NotesListRow(
                item: item,
                isSelected: item.id == selectedID,
                selectAction: { selectAction(item) },
                editAction: { editAction(item) },
                deleteAction: { deleteAction(item) }
            )
            .listRowBackground(
                item.id == selectedID ? Color.accentColor.opacity(0.13) : Color.clear
            )
            .listRowSeparator(item.id == items.last?.id ? .hidden : .visible)
            .listRowSeparatorTint(Color.primary.opacity(0.09))
            .listRowInsets(EdgeInsets())
        }
    }
}

/// A note row with the same quick actions everywhere: swipe on iPhone and iPad,
/// plus a press-and-hold (or right-click) menu.
private struct NotesListRow: View {
    @Environment(\.modelContext) private var modelContext

    let item: NotesListItem
    let isSelected: Bool
    let selectAction: () -> Void
    let editAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        NotesTitleButton(
            title: item.title,
            preview: item.preview,
            reference: item.reference,
            tag: NoteCategory(rawValue: item.categoryRawValue)?.title,
            highlight: VerseHighlightColor(rawValue: item.highlightColor),
            isFavorite: item.isFavorite,
            updatedAt: item.updatedAt ?? item.createdAt,
            isSelected: isSelected,
            action: selectAction
        )
        .swipeActions(edge: .leading) {
            favoriteButton
                .tint(.yellow)
        }
        .swipeActions(edge: .trailing) {
            deleteButton
        }
        .contextMenu {
            favoriteButton

            Button("Edit", systemImage: "pencil", action: editAction)

            ShareLink(item: item.shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            if item.reference != nil {
                Button("Open in Bible", systemImage: "book.closed") {
                    item.openInBible()
                }
            }

            Divider()

            deleteButton
        }
    }

    private var favoriteButton: some View {
        Button {
            item.toggleFavorite()
            try? modelContext.save()
            Haptics.selection()
        } label: {
            Label(
                item.isFavorite ? "Unfavorite" : "Favorite",
                systemImage: item.isFavorite ? "star.slash" : "star"
            )
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: deleteAction) {
            Label {
                Text(item.deleteTitle)
            } icon: {
                Image(systemName: "trash")
            }
        }
    }
}

/// Combines sorting and the highlight color filter into a single toolbar menu.
private struct NotesViewOptionsMenu: View {
    @Binding var sortField: NotesTabSort
    @Binding var sortAscending: Bool
    @Binding var highlightFilter: NotesHighlightFilter

    var body: some View {
        Menu {
            Section("Sort By") {
                Picker("Sort By", selection: $sortField) {
                    ForEach(NotesTabSort.allCases) { option in
                        Label(option.title, systemImage: option.systemImage)
                            .tag(option)
                    }
                }
                .pickerStyle(.inline)
            }

            Section {
                Picker("Order", selection: $sortAscending) {
                    Text(sortField.orderTitle(ascending: false)).tag(false)
                    Text(sortField.orderTitle(ascending: true)).tag(true)
                }
                .pickerStyle(.inline)
            }

            Section("Filter") {
                Picker(selection: $highlightFilter) {
                    ForEach(NotesHighlightFilter.allCases) { option in
                        Text(option.title).tag(option)
                    }
                } label: {
                    Label("Highlight Color", systemImage: "highlighter")
                    Text(highlightFilter.title)
                }
                .pickerStyle(.menu)
            }
        } label: {
            Image(
                systemName: highlightFilter == .all
                    ? "line.3.horizontal.decrease"
                    : "line.3.horizontal.decrease.circle.fill"
            )
            .foregroundStyle(
                highlightFilter == .all
                    ? AnyShapeStyle(.primary)
                    : AnyShapeStyle(.tint)
            )
        }
        .accessibilityLabel("Sort and filter notes")
        .accessibilityValue(Text(sortField.title))
    }
}

private extension NotesFilter {
    var systemImage: String {
        switch self {
        case .all: "square.grid.2x2"
        case .sermon: "person.wave.2"
        case .personal: "person.crop.circle"
        case .scripture: "book.closed"
        }
    }
}

private extension NotesFilter {
    var noteCategory: NoteCategory? {
        switch self {
        case .all: nil
        case .sermon: .sermon
        case .personal: .personal
        case .scripture: .scripture
        }
    }
}

private struct NotesTitleButton: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let title: String
    let preview: String
    let reference: String?
    let tag: LocalizedStringResource?
    let highlight: VerseHighlightColor?
    let isFavorite: Bool
    let updatedAt: Date?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                if let highlight {
                    Capsule()
                        .fill(highlight.color)
                        .frame(width: 3)
                        .padding(.vertical, 5)
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(title)
                            .font(.subheadline.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer(minLength: 4)

                        if isFavorite {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                                .accessibilityLabel("Favorite")
                        }
                    }

                    if !preview.isEmpty {
                        Text(preview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(horizontalSizeClass == .compact ? 2 : 1)
                    }

                    HStack(spacing: 6) {
                        if let tag {
                            Text(tag)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.tint)
                        }
                        if let reference {
                            Label(reference, systemImage: "book.closed")
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if let updatedAt {
                            Text(updatedAt, format: rowDateFormat(for: updatedAt))
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                .padding(.leading, 12)
            }
            .frame(minHeight: 76, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    /// Omits the year for this year's notes so older notes aren't mistaken for recent ones.
    private func rowDateFormat(for date: Date) -> Date.FormatStyle {
        let style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return Calendar.current.isDate(date, equalTo: .now, toGranularity: .year) ? style : style.year()
    }
}

private struct NoteDetailCard: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedScriptureReference: ScriptureRef?

    let scriptureNote: VerseNote?
    let userNote: UserNote?
    let editAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let scriptureNote {
                NoteDetailHeader(
                    title: scriptureNote.title.isEmpty ? "Scripture Note" : scriptureNote.title,
                    subtitle: "\(scriptureNote.bookName) \(scriptureNote.chapterNumber):\(scriptureNote.verseNumber)",
                    isFavorite: scriptureNote.isFavorite,
                    shareText: NotesListItem.scripture(scriptureNote).shareText,
                    favoriteAction: { toggleFavorite(scriptureNote) },
                    openBibleAction: { NotesListItem.scripture(scriptureNote).openInBible() },
                    editAction: editAction
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ScriptureNoteQuotation(
                            reference: "\(scriptureNote.bookName) \(scriptureNote.chapterNumber):\(scriptureNote.verseNumber)",
                            verseText: scriptureNote.verseText,
                            highlight: VerseHighlightColor(rawValue: scriptureNote.highlightColor)
                        )
                        Text(formattedContent(data: scriptureNote.formattedContent, fallback: scriptureNote.content))
                            .font(.body)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        NoteTimestampView(createdAt: scriptureNote.createdAt, updatedAt: scriptureNote.updatedAt)
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let userNote {
                NoteDetailHeader(
                    title: userNote.title.isEmpty ? "Untitled Note" : userNote.title,
                    subtitle: nil,
                    isFavorite: userNote.isFavorite,
                    shareText: NotesListItem.user(userNote).shareText,
                    favoriteAction: { toggleFavorite(userNote) },
                    openBibleAction: nil,
                    editAction: editAction
                )
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(formattedContent(data: userNote.formattedContent, fallback: userNote.content))
                            .font(.body)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        NoteTimestampView(createdAt: userNote.createdAt, updatedAt: userNote.updatedAt)
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView(
                    "Select a Note",
                    systemImage: "note.text",
                    description: Text("Choose a note from the card on the left to read it here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .environment(\.openURL, OpenURLAction { url in
            guard let reference = BibleReferenceLinker.parse(url: url) else {
                return .systemAction(url)
            }
            selectedScriptureReference = reference
            return .handled
        })
        .sheet(item: $selectedScriptureReference) { reference in
            ScriptureReferencePreview(
                reference: reference,
                copyAction: { copyScripture(reference) }
            )
        }
    }

    private func formattedContent(data: Data?, fallback: String) -> AttributedString {
        if let data, let formatted = try? JSONDecoder().decode(AttributedString.self, from: data) {
            return BibleReferenceLinker.linkify(formatted)
        }
        return BibleReferenceLinker.linkify(AttributedString(fallback))
    }

    private func copyScripture(_ reference: ScriptureRef) {
        guard let passage = BibleReferenceLinker.loadVerses(for: reference),
              !passage.verses.isEmpty else { return }
        let text = passage.verses.map(\.text).joined(separator: " ")
        UIPasteboard.general.string = "\(text)\n\(passage.title)"
        Haptics.success()
    }

    private func toggleFavorite(_ note: VerseNote) {
        note.isFavorite.toggle()
        try? modelContext.save()
        Haptics.selection()
    }

    private func toggleFavorite(_ note: UserNote) {
        note.isFavorite.toggle()
        try? modelContext.save()
        Haptics.selection()
    }

}

private struct ScriptureNoteQuotation: View {
    let reference: String
    let verseText: String
    let highlight: VerseHighlightColor?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(reference, systemImage: "quote.opening")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            Text(verseText)
                .font(.title3)
                .italic()
                .lineSpacing(4)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background((highlight?.color ?? .accentColor).opacity(0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(highlight?.color ?? .accentColor)
                .frame(width: 5)
                .padding(.vertical, 12)
        }
    }
}

private struct NoteDetailHeader: View {
    let title: String
    let subtitle: String?
    let isFavorite: Bool
    let shareText: String
    let favoriteAction: () -> Void
    let openBibleAction: (() -> Void)?
    let editAction: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.bold())
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                if let openBibleAction {
                    Button(action: openBibleAction) {
                        Image(systemName: "book.closed")
                    }
                    .accessibilityLabel("Open in Bible")
                }

                Button(action: favoriteAction) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                }
                .foregroundStyle(isFavorite ? .yellow : .primary)
                .accessibilityLabel(isFavorite ? "Remove favorite" : "Favorite")

                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share note")

                Button(action: editAction) {
                    Image(systemName: "pencil")
                }
                .accessibilityLabel("Edit note")
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct NoteTimestampView: View {
    let createdAt: Date?
    let updatedAt: Date?

    var body: some View {
        if let displayDate {
            Group {
                if wasModified {
                    Text(
                        "Modified \(displayDate, format: .dateTime.month(.abbreviated).day().year().hour().minute())",
                        comment: "Timestamp beneath a saved Bible note."
                    )
                } else {
                    Text(
                        "Added \(displayDate, format: .dateTime.month(.abbreviated).day().year().hour().minute())",
                        comment: "Timestamp beneath a newly added Bible note."
                    )
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    private var wasModified: Bool {
        guard let createdAt, let updatedAt else { return false }
        return updatedAt.timeIntervalSince(createdAt) > 1
    }

    private var displayDate: Date? {
        wasModified ? updatedAt : (createdAt ?? updatedAt)
    }
}

@MainActor
private struct UserNoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontResolutionContext) private var fontResolutionContext
    @Environment(\.modelContext) private var modelContext
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @AppStorage("noteEditorTextSizeStep") private var noteEditorTextSizeStep = NoteEditorTextSize.defaultStep

    let existingNote: UserNote?

    @State private var title: String
    @State private var noteText: AttributedString
    @State private var noteSelection = AttributedTextSelection()
    @State private var selectedCategory: NoteCategory
    @State private var persistenceFailure: PersistenceFailure?
    @State private var selectedScriptureReference: ScriptureRef?
    @State private var referenceLinkTask: Task<Void, Never>?

    private func scheduleReferenceLinking() {
        referenceLinkTask?.cancel()
        referenceLinkTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            linkScriptureReferences()
        }
    }

    init(existingNote: UserNote?, defaultCategory: NoteCategory = .personal) {
        self.existingNote = existingNote
        _title = State(initialValue: existingNote?.title ?? "")
        _noteText = State(initialValue: Self.loadFormattedContent(from: existingNote))
        _selectedCategory = State(
            initialValue: existingNote.flatMap { NoteCategory(rawValue: $0.categoryRawValue) } ?? defaultCategory
        )
    }

    var body: some View {
        VStack(spacing: 14) {
            NoteEditorTitleField(title: $title, placeholder: "Note title")

            if contextualTipsEnabled {
                ScriptureReferenceLinkTip()
            }

            HStack {
                NoteCategoryMenu(category: $selectedCategory)
                Spacer()
                Text(existingNote == nil ? "New note" : "Editing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            TextEditor(text: $noteText, selection: $noteSelection)
                .font(.body)
                .dynamicTypeSize(NoteEditorTextSize.dynamicTypeSize(for: noteEditorTextSizeStep))
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1))
                }
                .accessibilityLabel("Note")
                .environment(\.openURL, OpenURLAction { url in
                    guard let reference = BibleReferenceLinker.parse(url: url) else {
                        return .systemAction(url)
                    }
                    selectedScriptureReference = reference
                    return .handled
                })
        }
        .padding()
        .background(AppBackgroundView(tab: .notes))
        .safeAreaInset(edge: .bottom) {
            NoteFormattingBar(
                toggleBold: { toggleFontTrait(\.isBold) },
                toggleUnderline: toggleUnderline,
                toggleItalic: { toggleFontTrait(\.isItalic) },
                toggleStrikethrough: toggleStrikethrough,
                insertBullet: insertBullet,
                insertNumberedItem: insertNumberedItem,
                increaseIndent: increaseIndent,
                decreaseIndent: decreaseIndent,
                decreaseTextSize: decreaseTextSize,
                increaseTextSize: increaseTextSize,
                canDecreaseTextSize: noteEditorTextSizeStep > NoteEditorTextSize.minimumStep,
                canIncreaseTextSize: noteEditorTextSizeStep < NoteEditorTextSize.maximumStep
            )
        }
        .navigationTitle(existingNote == nil ? "New Note" : "Edit Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(trimmedTitle.isEmpty && trimmedNote.isEmpty)
            }
            if existingNote != nil {
                ToolbarItem(placement: .secondaryAction) {
                    Button("Delete Note", systemImage: "trash", role: .destructive, action: deleteNote)
                }
            }
        }
        .persistenceFailureAlert(failure: $persistenceFailure)
        .onAppear(perform: linkScriptureReferences)
        .onChange(of: String(noteText.characters)) { _, _ in
            scheduleReferenceLinking()
        }
        .onDisappear {
            referenceLinkTask?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openScripturePreview)) { notification in
            guard let url = notification.object as? URL,
                  let reference = BibleReferenceLinker.parse(url: url) else { return }
            selectedScriptureReference = reference
        }
        .sheet(item: $selectedScriptureReference) { reference in
            ScriptureReferencePreview(
                reference: reference,
                copyAction: { copyScripture(reference) }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNote: String {
        String(noteText.characters).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func loadFormattedContent(from note: UserNote?) -> AttributedString {
        guard let note else { return AttributedString() }
        if let data = note.formattedContent,
           let formatted = try? JSONDecoder().decode(AttributedString.self, from: data) {
            return formatted
        }
        return AttributedString(note.content)
    }

    private func linkScriptureReferences() {
        let linked = BibleReferenceLinker.linkify(noteText)
        guard linked != noteText else { return }
        noteText = linked
    }

    private func copyScripture(_ reference: ScriptureRef) {
        guard let passage = BibleReferenceLinker.loadVerses(for: reference),
              !passage.verses.isEmpty else { return }
        let text = passage.verses.map(\.text).joined(separator: " ")
        UIPasteboard.general.string = "\(text)\n\(passage.title)"
        Haptics.success()
    }

    private func toggleFontTrait(_ trait: KeyPath<Font.Resolved, Bool>) {
        let resolvedFont = (noteSelection.typingAttributes(in: noteText).font ?? .body)
            .resolve(in: fontResolutionContext)
        let shouldEnable = !resolvedFont[keyPath: trait]
        noteText.transformAttributes(in: &noteSelection) {
            let font = $0.font ?? .body
            if trait == \.isBold {
                $0.font = font.bold(shouldEnable)
            } else {
                $0.font = font.italic(shouldEnable)
            }
        }
    }

    private func toggleUnderline() {
        let shouldEnable = noteSelection.typingAttributes(in: noteText).underlineStyle == nil
        noteText.transformAttributes(in: &noteSelection) {
            $0.underlineStyle = shouldEnable ? .single : nil
        }
    }

    private func toggleStrikethrough() {
        let shouldEnable = noteSelection.typingAttributes(in: noteText).strikethroughStyle == nil
        noteText.transformAttributes(in: &noteSelection) {
            $0.strikethroughStyle = shouldEnable ? .single : nil
        }
    }

    private func insertBullet() {
        noteText.replaceSelection(&noteSelection, withCharacters: "• ")
    }

    private func insertNumberedItem() {
        noteText.replaceSelection(&noteSelection, withCharacters: "1. ")
    }

    private func increaseIndent() {
        guard case .insertionPoint = noteSelection.indices(in: noteText) else { return }
        noteText.replaceSelection(&noteSelection, withCharacters: "    ")
    }

    private func decreaseIndent() {
        guard case let .insertionPoint(caret) = noteSelection.indices(in: noteText),
              caret > noteText.startIndex else { return }

        let characters = noteText.characters
        var lineStart = caret
        while lineStart > noteText.startIndex {
            let previous = characters.index(before: lineStart)
            if characters[previous] == "\n" { break }
            lineStart = previous
        }

        var indentEnd = lineStart
        for _ in 0..<4 where indentEnd < noteText.endIndex && characters[indentEnd] == " " {
            indentEnd = characters.index(after: indentEnd)
        }
        guard indentEnd > lineStart else { return }
        noteText.replaceSubrange(lineStart..<indentEnd, with: AttributedString())
        noteSelection = AttributedTextSelection(insertionPoint: lineStart)
    }

    private func decreaseTextSize() {
        noteEditorTextSizeStep = max(NoteEditorTextSize.minimumStep, noteEditorTextSizeStep - 1)
    }

    private func increaseTextSize() {
        noteEditorTextSizeStep = min(NoteEditorTextSize.maximumStep, noteEditorTextSizeStep + 1)
    }

    private func save() {
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                let note = existingNote ?? UserNote()
                note.title = trimmedTitle
                note.content = trimmedNote
                note.formattedContent = try JSONEncoder().encode(noteText)
                note.categoryRawValue = selectedCategory.rawValue
                note.updatedAt = Date()
                if existingNote == nil {
                    modelContext.insert(note)
                }
                try modelContext.save()
            },
            onSuccess: {
                Haptics.success()
                dismiss()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }

    private func deleteNote() {
        guard let existingNote else { return }
        ModelContextPersistence.perform(
            in: modelContext,
            operation: {
                modelContext.delete(existingNote)
                try modelContext.save()
            },
            onSuccess: {
                Haptics.selection()
                dismiss()
            },
            onFailure: { persistenceFailure = $0 }
        )
    }
}
