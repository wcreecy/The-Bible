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
    @Environment(\.undoManager) private var undoManager
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @AppStorage("noteEditorTextSizeStep") private var noteEditorTextSizeStep = NoteEditorTextSize.defaultStep

    let verse: VerseActionReference
    let existingNote: VerseNote?

    @State private var title: String
    @State private var noteText: AttributedString
    @State private var noteSelection = AttributedTextSelection()
    @State private var selectedColor: VerseHighlightColor?
    @State private var selectedCategory: NoteCategory
    @State private var persistenceFailure: PersistenceFailure?
    @State private var selectedScriptureReference: ScriptureRef?

    init(verse: VerseActionReference, existingNote: VerseNote?) {
        self.verse = verse
        self.existingNote = existingNote
        _title = State(initialValue: existingNote?.title ?? "")
        _noteText = State(initialValue: Self.loadFormattedContent(from: existingNote, verse: verse))
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

                VerseNoteOptionsBar(category: $selectedCategory, highlight: $selectedColor)

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
                undo: { undoManager?.undo() },
                redo: { undoManager?.redo() },
                canUndo: undoManager?.canUndo == true,
                canRedo: undoManager?.canRedo == true,
                horizontalPadding: editorHorizontalPadding
            )
        }
        .navigationTitle(existingNote == nil ? "Add Note & Highlight" : "Edit Note & Highlight")
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
                    Button("Remove Note & Highlight", systemImage: "trash", role: .destructive, action: deleteEntry)
                }
            }
        }
        .persistenceFailureAlert(failure: $persistenceFailure)
        .onAppear(perform: linkScriptureReferences)
        .onChange(of: String(noteText.characters)) { _, _ in
            linkScriptureReferences()
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

    private var editorHorizontalPadding: CGFloat {
        horizontalSizeClass == .compact ? 24 : 16
    }

    private static func loadFormattedContent(
        from note: VerseNote?,
        verse: VerseActionReference
    ) -> AttributedString {
        guard let note else {
            let reference = "\(verse.bookName) \(verse.chapterNumber):\(verse.verseNumber)"
            return BibleReferenceLinker.linkify(AttributedString(reference))
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
    let undo: () -> Void
    let redo: () -> Void
    let canUndo: Bool
    let canRedo: Bool
    var horizontalPadding: CGFloat = 16

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                formattingButton("Undo", systemImage: "arrow.uturn.backward", action: undo)
                    .disabled(!canUndo)
                formattingButton("Redo", systemImage: "arrow.uturn.forward", action: redo)
                    .disabled(!canRedo)

                Divider().frame(height: 24)

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
                    HighlightColorPicker(selection: $highlight)
                }
            } else {
                HStack(spacing: 12) {
                    NoteCategoryMenu(category: $category)
                    Divider().frame(height: 28)
                    HighlightColorPicker(selection: $highlight)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct NoteCategoryMenu: View {
    @Binding var category: NoteCategory

    var body: some View {
        Menu {
            Picker("Category", selection: $category) {
                ForEach(NoteCategory.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            Label(category.title, systemImage: "tag.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
        }
        .accessibilityLabel("Note category")
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

private enum NotesHighlightsSort: String, CaseIterable, Identifiable {
    case modifiedNewest
    case modifiedOldest
    case addedNewest
    case addedOldest
    case bibleOrder
    case highlightColor
    case reference

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .modifiedNewest: "Modified: Newest First"
        case .modifiedOldest: "Modified: Oldest First"
        case .addedNewest: "Added: Newest First"
        case .addedOldest: "Added: Oldest First"
        case .bibleOrder: "Bible Order"
        case .highlightColor: "Highlight Color"
        case .reference: "Reference A–Z"
        }
    }

    var systemImage: String {
        switch self {
        case .modifiedNewest, .modifiedOldest: "pencil.and.list.clipboard"
        case .addedNewest, .addedOldest: "calendar"
        case .bibleOrder: "book"
        case .highlightColor: "paintpalette"
        case .reference: "textformat.abc"
        }
    }
}

private enum NotesTabSort: String, CaseIterable, Identifiable {
    case modifiedNewest
    case modifiedOldest
    case createdNewest
    case createdOldest
    case highlightColor
    case tag
    case titleAscending
    case titleDescending

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .modifiedNewest: "Modified: Newest First"
        case .modifiedOldest: "Modified: Oldest First"
        case .createdNewest: "Created: Newest First"
        case .createdOldest: "Created: Oldest First"
        case .highlightColor: "Color"
        case .tag: "Tag"
        case .titleAscending: "Title: A–Z"
        case .titleDescending: "Title: Z–A"
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
        case .all: "All Tags"
        case .sermon: "Sermon"
        case .personal: "Personal"
        case .scripture: "Scripture"
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
}

@MainActor
struct NotesAndHighlightsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \VerseNote.updatedAt, order: .reverse) private var scriptureNotes: [VerseNote]
    @Query(sort: \UserNote.updatedAt, order: .reverse) private var userNotes: [UserNote]

    @AppStorage("notesTabSort") private var sortRawValue = NotesTabSort.modifiedNewest.rawValue
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @State private var selectedFilter = NotesFilter.all
    @State private var highlightFilter = NotesHighlightFilter.all
    @State private var searchText = ""
    @State private var selectedScriptureNote: VerseNote?
    @State private var selectedUserNote: UserNote?
    @State private var isCreatingNote = false
    @State private var isEditingSelection = false
    @State private var isShowingCompactDetail = false

    var body: some View {
        VStack(spacing: 12) {
            NotesOverviewHeader(
                noteCount: visibleNotes.count,
                totalCount: scriptureNotes.count + userNotes.count,
                createAction: { isCreatingNote = true }
            )

            NotesCategoryStrip(selection: $selectedFilter)

            if contextualTipsEnabled {
                ContextualTipView(
                    id: "notes.quickActions",
                    title: "Quick note actions",
                    message: "Swipe a note for quick actions, or press and hold it to delete.",
                    systemImage: "hand.point.up.left"
                )
            }

            GeometryReader { proxy in
                if horizontalSizeClass == .compact {
                    NotesListCard(
                        notes: visibleNotes,
                        selectedScriptureNote: $selectedScriptureNote,
                        selectedUserNote: $selectedUserNote,
                        selectedFilter: $selectedFilter,
                        highlightFilter: $highlightFilter,
                        selectionAction: { isShowingCompactDetail = true }
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 16) {
                        NotesListCard(
                            notes: visibleNotes,
                            selectedScriptureNote: $selectedScriptureNote,
                            selectedUserNote: $selectedUserNote,
                            selectedFilter: $selectedFilter,
                            highlightFilter: $highlightFilter,
                            selectionAction: {}
                        )
                        .frame(width: max(300, (proxy.size.width - 16) * 0.4))

                        NoteDetailCard(
                            scriptureNote: selectedScriptureNote,
                            userNote: selectedUserNote,
                            editAction: { isEditingSelection = true }
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
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
        .searchable(text: $searchText, prompt: "Search all notes")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $sortRawValue) {
                        ForEach(NotesTabSort.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort notes")

                Button {
                    isCreatingNote = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create note")
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
                        existingNote: selectedScriptureNote
                    )
                } else if let selectedUserNote {
                    UserNoteEditorView(existingNote: selectedUserNote)
                }
            }
        }
        .onAppear(perform: selectFirstVisibleNoteIfNeeded)
        .onChange(of: selectedFilter) { _, _ in selectFirstVisibleNoteIfNeeded() }
        .onChange(of: highlightFilter) { _, _ in selectFirstVisibleNote() }
        .onChange(of: sortRawValue) { _, _ in selectFirstVisibleNoteIfNeeded() }
        .onChange(of: searchText) { _, _ in selectFirstVisibleNoteIfNeeded() }
    }

    private var visibleNotes: [NotesListItem] {
        let allNotes = scriptureNotes.map(NotesListItem.scripture) + userNotes.map(NotesListItem.user)
        let favorites = sort(allNotes.filter(\.isFavorite))
        let filteredNotes = sort(allNotes.filter { note in
            !note.isFavorite &&
            matchesSelectedCategory(note.categoryRawValue) &&
                matchesHighlight(note.highlightColor) &&
                note.matchesSearch(searchText)
        })
        return favorites + filteredNotes
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
        let selectedSort = NotesTabSort(rawValue: sortRawValue) ?? .modifiedNewest
        switch selectedSort {
        case .modifiedNewest:
            return notes.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
        case .modifiedOldest:
            return notes.sorted { ($0.updatedAt ?? .distantPast) < ($1.updatedAt ?? .distantPast) }
        case .createdNewest:
            return notes.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .createdOldest:
            return notes.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        case .highlightColor:
            return notes.sorted {
                if $0.highlightColor != $1.highlightColor {
                    return $0.highlightColor < $1.highlightColor
                }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        case .tag:
            return notes.sorted {
                if $0.categoryRawValue != $1.categoryRawValue {
                    return $0.categoryRawValue.localizedStandardCompare($1.categoryRawValue) == .orderedAscending
                }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
        case .titleAscending:
            return notes.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .titleDescending:
            return notes.sorted { $0.title.localizedStandardCompare($1.title) == .orderedDescending }
        }
    }

    private func selectFirstVisibleNoteIfNeeded() {
        let scriptureSelectionIsVisible = selectedScriptureNote.map { selected in
            visibleNotes.contains {
                if case .scripture(let note) = $0 { return note === selected }
                return false
            }
        } ?? false
        let userSelectionIsVisible = selectedUserNote.map { selected in
            visibleNotes.contains {
                if case .user(let note) = $0 { return note === selected }
                return false
            }
        } ?? false

        if !scriptureSelectionIsVisible && !userSelectionIsVisible {
            selectFirstVisibleNote()
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

private struct NotesOverviewHeader: View {
    let noteCount: Int
    let totalCount: Int
    let createAction: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Study Notebook")
                    .font(.title2.bold())
                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button(action: createAction) {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(ModernCircleButtonStyle(tint: .accentColor, isProminent: true))
            .accessibilityLabel("Create note")
        }
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
    }

    private var summaryText: LocalizedStringKey {
        if noteCount == totalCount {
            "\(totalCount) notes and highlights"
        } else {
            "Showing \(noteCount) of \(totalCount) notes"
        }
    }
}

private struct NotesCategoryStrip: View {
    @Binding var selection: NotesFilter

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
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

private struct NotesListCard: View {
    @Environment(\.modelContext) private var modelContext

    let notes: [NotesListItem]
    @Binding var selectedScriptureNote: VerseNote?
    @Binding var selectedUserNote: UserNote?
    @Binding var selectedFilter: NotesFilter
    @Binding var highlightFilter: NotesHighlightFilter
    let selectionAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Library")
                    .font(.headline)

                Text(notes.count, format: .number)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.secondary.opacity(0.12), in: Capsule())

                Spacer()

                NotesFilterMenu(
                    selectedFilter: $selectedFilter,
                    highlightFilter: $highlightFilter
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            List {
                if notes.isEmpty {
                    ContentUnavailableView(
                        "No Notes",
                        systemImage: "note.text",
                        description: Text("Try another tag, color, sort order, or search.")
                    )
                    .padding(.top, 40)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(notes) { item in
                        switch item {
                        case .scripture(let note):
                            NotesTitleButton(
                                title: item.title,
                                preview: item.preview,
                                reference: item.reference,
                                tag: NoteCategory(rawValue: note.categoryRawValue)?.title,
                                highlight: VerseHighlightColor(rawValue: note.highlightColor),
                                isFavorite: note.isFavorite,
                                updatedAt: note.updatedAt ?? note.createdAt,
                                isSelected: selectedScriptureNote === note
                            ) {
                                selectedScriptureNote = note
                                selectedUserNote = nil
                                selectionAction()
                            }
                            .contextMenu {
                                Button(note.isFavorite ? "Remove Favorite" : "Favorite", systemImage: note.isFavorite ? "star.slash" : "star") {
                                    toggleFavorite(note)
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) { delete(note) }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    toggleFavorite(note)
                                } label: {
                                    Label(note.isFavorite ? "Unfavorite" : "Favorite", systemImage: note.isFavorite ? "star.slash" : "star")
                                }
                                .tint(.yellow)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { delete(note) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
                        case .user(let note):
                            NotesTitleButton(
                                title: item.title,
                                preview: item.preview,
                                reference: nil,
                                tag: NoteCategory(rawValue: note.categoryRawValue)?.title,
                                highlight: nil,
                                isFavorite: note.isFavorite,
                                updatedAt: note.updatedAt ?? note.createdAt,
                                isSelected: selectedUserNote === note
                            ) {
                                selectedUserNote = note
                                selectedScriptureNote = nil
                                selectionAction()
                            }
                            .contextMenu {
                                Button(note.isFavorite ? "Remove Favorite" : "Favorite", systemImage: note.isFavorite ? "star.slash" : "star") {
                                    toggleFavorite(note)
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) { delete(note) }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    toggleFavorite(note)
                                } label: {
                                    Label(note.isFavorite ? "Unfavorite" : "Favorite", systemImage: note.isFavorite ? "star.slash" : "star")
                                }
                                .tint(.yellow)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { delete(note) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.vertical, 0, for: .scrollContent)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .heroCardSurface()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func delete(_ note: VerseNote) {
        if selectedScriptureNote === note {
            selectedScriptureNote = nil
        }
        modelContext.delete(note)
        try? modelContext.save()
    }

    private func delete(_ note: UserNote) {
        if selectedUserNote === note {
            selectedUserNote = nil
        }
        modelContext.delete(note)
        try? modelContext.save()
    }

    private func toggleFavorite(_ note: VerseNote) {
        note.isFavorite.toggle()
        try? modelContext.save()
    }

    private func toggleFavorite(_ note: UserNote) {
        note.isFavorite.toggle()
        try? modelContext.save()
    }
}

private struct NotesFilterMenu: View {
    @Binding var selectedFilter: NotesFilter
    @Binding var highlightFilter: NotesHighlightFilter

    var body: some View {
        Menu {
            Picker("Tag", selection: $selectedFilter) {
                ForEach(NotesFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }

            Divider()

            Picker("Highlight Color", selection: $highlightFilter) {
                ForEach(NotesHighlightFilter.allCases) { option in
                    Text(option.title).tag(option)
                }
            }

        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("Filter and sort notes")
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
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(highlight?.color ?? .accentColor.opacity(0.35))
                    .frame(width: 4)
                    .padding(.vertical, 7)

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
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tint)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(.tint.opacity(0.11), in: Capsule())
                        }
                        if let reference {
                            Label(reference, systemImage: "book.closed")
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        if let updatedAt {
                            Text(updatedAt, format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
            }
            .frame(minHeight: 76)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.38) : Color.primary.opacity(0.07))
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
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
                    shareText: scriptureShareText(scriptureNote),
                    favoriteAction: { toggleFavorite(scriptureNote) },
                    openBibleAction: { openInBible(scriptureNote) },
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
                    shareText: userShareText(userNote),
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

    private func openInBible(_ note: VerseNote) {
        NotificationCenter.default.post(name: .openBibleReference, object: nil, userInfo: [
            "book": note.bookName,
            "chapter": note.chapterNumber,
            "verse": note.verseNumber
        ])
    }

    private func scriptureShareText(_ note: VerseNote) -> String {
        let title = note.title.isEmpty ? "Scripture Note" : note.title
        return "\(title)\n\(note.bookName) \(note.chapterNumber):\(note.verseNumber)\n\n\(note.verseText)\n\n\(note.content)"
    }

    private func userShareText(_ note: UserNote) -> String {
        let title = note.title.isEmpty ? "Untitled Note" : note.title
        return "\(title)\n\n\(note.content)"
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

@MainActor
private struct ScriptureNotesView: View {
    @Query(sort: \VerseNote.updatedAt, order: .reverse) private var notes: [VerseNote]
    @AppStorage("notesHighlightsSort") private var sortRawValue = NotesHighlightsSort.modifiedNewest.rawValue
    @State private var searchText = ""
    @State private var selectedNote: VerseNote?

    var body: some View {
        List {
            if visibleNotes.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Notes or Highlights" : "No Results",
                    systemImage: searchText.isEmpty ? "highlighter" : "magnifyingglass",
                    description: Text(searchText.isEmpty
                        ? "Press and hold a verse to add a private note or highlight."
                        : "Try searching for a reference, verse, or note.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(visibleNotes) { note in
                    Button {
                        selectedNote = note
                    } label: {
                        NoteHighlightRow(
                            title: note.title,
                            reference: "\(note.bookName) \(note.chapterNumber):\(note.verseNumber)",
                            verseText: note.verseText,
                            noteText: formattedContent(for: note),
                            highlight: VerseHighlightColor(rawValue: note.highlightColor),
                            createdAt: note.createdAt,
                            updatedAt: note.updatedAt
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button("Open", systemImage: "book") {
                            open(note)
                        }
                        .tint(.accentColor)
                    }
                }
                .onDelete(perform: delete)
                .listRowBackground(HeroCardListRowBackground())
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackgroundView(tab: .notes))
        .navigationTitle("Notes")
        .searchable(text: $searchText, prompt: "Search notes and verses")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort By", selection: $sortRawValue) {
                        ForEach(NotesHighlightsSort.allCases) { option in
                            Label(option.title, systemImage: option.systemImage)
                                .tag(option.rawValue)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort notes and highlights")
            }
        }
        .sheet(item: $selectedNote) { note in
            NavigationStack {
                VerseNoteEditorView(
                    verse: VerseActionReference(
                        bookName: note.bookName,
                        chapterNumber: note.chapterNumber,
                        verseNumber: note.verseNumber,
                        verseText: note.verseText
                    ),
                    existingNote: note
                )
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Open in Bible", systemImage: "book") {
                            selectedNote = nil
                            open(note)
                        }
                    }
                }
            }
        }
    }

    private var visibleNotes: [VerseNote] {
        let filteredNotes: [VerseNote]
        if searchText.isEmpty {
            filteredNotes = notes
        } else {
            filteredNotes = notes.filter {
                $0.bookName.localizedCaseInsensitiveContains(searchText) ||
                $0.verseText.localizedCaseInsensitiveContains(searchText) ||
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                "\($0.chapterNumber):\($0.verseNumber)".localizedCaseInsensitiveContains(searchText)
            }
        }

        let selectedSort = NotesHighlightsSort(rawValue: sortRawValue) ?? .modifiedNewest
        switch selectedSort {
        case .modifiedNewest:
            return filteredNotes.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
        case .modifiedOldest:
            return filteredNotes.sorted { ($0.updatedAt ?? .distantPast) < ($1.updatedAt ?? .distantPast) }
        case .addedNewest:
            return filteredNotes.sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
        case .addedOldest:
            return filteredNotes.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        case .bibleOrder:
            let bookPositions = Dictionary(
                uniqueKeysWithValues: BibleData.books.enumerated().map { ($0.element.name, $0.offset) }
            )
            return filteredNotes.sorted {
                let left = bookPositions[$0.bookName] ?? .max
                let right = bookPositions[$1.bookName] ?? .max
                if left != right { return left < right }
                if $0.chapterNumber != $1.chapterNumber { return $0.chapterNumber < $1.chapterNumber }
                return $0.verseNumber < $1.verseNumber
            }
        case .highlightColor:
            let colorPositions = Dictionary(
                uniqueKeysWithValues: VerseHighlightColor.allCases.enumerated().map { ($0.element.rawValue, $0.offset) }
            )
            return filteredNotes.sorted {
                let left = colorPositions[$0.highlightColor] ?? .max
                let right = colorPositions[$1.highlightColor] ?? .max
                if left != right { return left < right }
                return referencePrecedes($0, $1)
            }
        case .reference:
            return filteredNotes.sorted(by: referencePrecedes)
        }
    }

    private func referencePrecedes(_ left: VerseNote, _ right: VerseNote) -> Bool {
        let comparison = left.bookName.localizedStandardCompare(right.bookName)
        if comparison != .orderedSame { return comparison == .orderedAscending }
        if left.chapterNumber != right.chapterNumber { return left.chapterNumber < right.chapterNumber }
        return left.verseNumber < right.verseNumber
    }

    private func formattedContent(for note: VerseNote) -> AttributedString {
        if let data = note.formattedContent,
           let formatted = try? JSONDecoder().decode(AttributedString.self, from: data) {
            return formatted
        }
        return AttributedString(note.content)
    }

    private func open(_ note: VerseNote) {
        NotificationCenter.default.post(
            name: .openBibleReference,
            object: nil,
            userInfo: [
                "book": note.bookName,
                "chapter": note.chapterNumber,
                "verse": note.verseNumber
            ]
        )
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(visibleNotes[index])
        }
        try? modelContext.save()
    }

    @Environment(\.modelContext) private var modelContext
}

private struct NoteHighlightRow: View {
    let title: String
    let reference: String
    let verseText: String
    let noteText: AttributedString
    let highlight: VerseHighlightColor?
    let createdAt: Date?
    let updatedAt: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(highlight?.color ?? .clear)
                .frame(width: 6)
                .overlay {
                    if highlight == nil {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.2))
                    }
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(title.isEmpty ? reference : title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if !title.isEmpty {
                    Text(reference)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(verseText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                if !noteText.characters.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "note.text")
                        Text(noteText)
                    }
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }
                NoteTimestampView(createdAt: createdAt, updatedAt: updatedAt)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
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
private struct UserNotesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserNote.updatedAt, order: .reverse) private var notes: [UserNote]
    @State private var searchText = ""
    @State private var selectedNote: UserNote?
    @State private var isCreatingNote = false

    var body: some View {
        List {
            if visibleNotes.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty ? "No Personal Notes" : "No Results",
                    systemImage: searchText.isEmpty ? "note.text" : "magnifyingglass",
                    description: Text(searchText.isEmpty
                        ? "Tap the plus button to create your first note."
                        : "Try searching for a note title or its contents.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(visibleNotes) { note in
                    Button {
                        selectedNote = note
                    } label: {
                        UserNoteRow(
                            title: note.title,
                            content: formattedContent(for: note),
                            createdAt: note.createdAt,
                            updatedAt: note.updatedAt
                        )
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: delete)
                .listRowBackground(HeroCardListRowBackground())
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackgroundView(tab: .notes))
        .navigationTitle("My Notes")
        .searchable(text: $searchText, prompt: "Search personal notes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isCreatingNote = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create note")
            }
        }
        .fullScreenCover(isPresented: $isCreatingNote) {
            NavigationStack {
                UserNoteEditorView(existingNote: nil)
            }
        }
        .fullScreenCover(item: $selectedNote) { note in
            NavigationStack {
                UserNoteEditorView(existingNote: note)
            }
        }
    }

    private var visibleNotes: [UserNote] {
        guard !searchText.isEmpty else { return notes }
        return notes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func formattedContent(for note: UserNote) -> AttributedString {
        if let data = note.formattedContent,
           let formatted = try? JSONDecoder().decode(AttributedString.self, from: data) {
            return formatted
        }
        return AttributedString(note.content)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(visibleNotes[index])
        }
        try? modelContext.save()
    }
}

private struct UserNoteRow: View {
    let title: String
    let content: AttributedString
    let createdAt: Date?
    let updatedAt: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.isEmpty ? "Untitled Note" : title)
                .font(.headline)
                .foregroundStyle(.primary)

            if !content.characters.isEmpty {
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            NoteTimestampView(createdAt: createdAt, updatedAt: updatedAt)
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
}

@MainActor
private struct UserNoteEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fontResolutionContext) private var fontResolutionContext
    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @AppStorage("contextualTipsEnabled") private var contextualTipsEnabled = false
    @AppStorage("noteEditorTextSizeStep") private var noteEditorTextSizeStep = NoteEditorTextSize.defaultStep

    let existingNote: UserNote?

    @State private var title: String
    @State private var noteText: AttributedString
    @State private var noteSelection = AttributedTextSelection()
    @State private var selectedCategory: NoteCategory
    @State private var persistenceFailure: PersistenceFailure?
    @State private var selectedScriptureReference: ScriptureRef?

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
                canIncreaseTextSize: noteEditorTextSizeStep < NoteEditorTextSize.maximumStep,
                undo: { undoManager?.undo() },
                redo: { undoManager?.redo() },
                canUndo: undoManager?.canUndo == true,
                canRedo: undoManager?.canRedo == true
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
            linkScriptureReferences()
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
