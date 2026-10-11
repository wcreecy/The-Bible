import SwiftUI
import UIKit

// Pieces shared by the Scripture note editor and the personal note editor.

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

struct NoteFormattingBar: View {
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

enum NoteEditorTextSize {
    static let minimumStep = 0
    static let maximumStep = 6
    static let defaultStep = 3
    static let storageKey = "noteEditorTextSizeStep"

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

struct NoteEditorTitleField: View {
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

struct ScriptureReferenceLinkTip: View {
    var body: some View {
        ContextualTipView(
            id: "notes.scriptureLinks",
            title: "Link Scripture references",
            message: "Type a reference such as John 3:16 in your note. It automatically becomes a tappable link with a Scripture preview.",
            systemImage: "link.badge.plus"
        )
    }
}

struct NoteCategoryMenu: View {
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

struct HighlightColorPicker: View {
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

struct ScriptureReferencePreview: View {
    @Environment(\.dismiss) private var dismiss
    @State private var passage: (title: String, verses: [Verse])?
    @State private var isLoading = true

    let reference: ScriptureRef

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
                    Button(action: copyPassage) {
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

    private func copyPassage() {
        guard let passage, !passage.verses.isEmpty else { return }
        let text = passage.verses.map(\.text).joined(separator: " ")
        UIPasteboard.general.string = "\(text)\n\(passage.title)"
        Haptics.success()
    }

    private var shareText: String {
        guard let passage else { return "" }
        let verses = passage.verses
            .map { "\($0.number) \($0.text)" }
            .joined(separator: "\n")
        return "\(passage.title)\n\n\(verses)"
    }
}

/// Decodes a note's saved rich text, falling back to its plain text.
enum NoteFormattedContent {
    static func decode(_ data: Data?, fallback: String) -> AttributedString {
        if let data, let formatted = try? JSONDecoder().decode(AttributedString.self, from: data) {
            return formatted
        }
        return AttributedString(fallback)
    }
}

/// The note body editor, sized by the editor's text size setting.
struct NoteBodyTextEditor: View {
    @AppStorage(NoteEditorTextSize.storageKey) private var textSizeStep = NoteEditorTextSize.defaultStep

    @Binding var text: AttributedString
    @Binding var selection: AttributedTextSelection

    var body: some View {
        TextEditor(text: $text, selection: $selection)
            .font(.body)
            .dynamicTypeSize(NoteEditorTextSize.dynamicTypeSize(for: textSizeStep))
            .scrollContentBackground(.hidden)
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1))
            }
            .accessibilityLabel("Note")
    }
}

extension View {
    /// Adds the formatting bar, turns typed Scripture references into links, and shows a
    /// preview when one is tapped.
    func richNoteEditing(
        text: Binding<AttributedString>,
        selection: Binding<AttributedTextSelection>,
        formattingBarPadding: CGFloat = 16
    ) -> some View {
        modifier(RichNoteEditing(text: text, selection: selection, formattingBarPadding: formattingBarPadding))
    }
}

private struct RichNoteEditing: ViewModifier {
    @Environment(\.fontResolutionContext) private var fontResolutionContext
    @AppStorage(NoteEditorTextSize.storageKey) private var textSizeStep = NoteEditorTextSize.defaultStep
    @State private var selectedScriptureReference: ScriptureRef?
    @State private var referenceLinkTask: Task<Void, Never>?

    @Binding var text: AttributedString
    @Binding var selection: AttributedTextSelection
    let formattingBarPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                guard let reference = BibleReferenceLinker.parse(url: url) else {
                    return .systemAction(url)
                }
                selectedScriptureReference = reference
                return .handled
            })
            .safeAreaInset(edge: .bottom) {
                NoteFormattingBar(
                    toggleBold: { toggleFontTrait(\.isBold) },
                    toggleUnderline: toggleUnderline,
                    toggleItalic: { toggleFontTrait(\.isItalic) },
                    toggleStrikethrough: toggleStrikethrough,
                    insertBullet: { text.replaceSelection(&selection, withCharacters: "• ") },
                    insertNumberedItem: { text.replaceSelection(&selection, withCharacters: "1. ") },
                    increaseIndent: increaseIndent,
                    decreaseIndent: decreaseIndent,
                    decreaseTextSize: { textSizeStep = max(NoteEditorTextSize.minimumStep, textSizeStep - 1) },
                    increaseTextSize: { textSizeStep = min(NoteEditorTextSize.maximumStep, textSizeStep + 1) },
                    canDecreaseTextSize: textSizeStep > NoteEditorTextSize.minimumStep,
                    canIncreaseTextSize: textSizeStep < NoteEditorTextSize.maximumStep,
                    horizontalPadding: formattingBarPadding
                )
            }
            .onAppear(perform: linkScriptureReferences)
            .onChange(of: String(text.characters)) { _, _ in
                scheduleReferenceLinking()
            }
            .onDisappear {
                referenceLinkTask?.cancel()
            }
            .onChange(of: AppRouter.shared.latest) { _, request in
                guard case .scripturePreview(let url) = request?.destination,
                      let reference = BibleReferenceLinker.parse(url: url) else { return }
                selectedScriptureReference = reference
            }
            .sheet(item: $selectedScriptureReference) { reference in
                ScriptureReferencePreview(reference: reference)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }

    // MARK: - Scripture links

    /// Re-links references after typing pauses, so each keystroke doesn't rescan the note.
    private func scheduleReferenceLinking() {
        referenceLinkTask?.cancel()
        referenceLinkTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            linkScriptureReferences()
        }
    }

    private func linkScriptureReferences() {
        let linked = BibleReferenceLinker.linkify(text)
        guard linked != text else { return }
        text = linked
    }

    // MARK: - Formatting

    private func toggleFontTrait(_ trait: KeyPath<Font.Resolved, Bool>) {
        let resolvedFont = (selection.typingAttributes(in: text).font ?? .body)
            .resolve(in: fontResolutionContext)
        let shouldEnable = !resolvedFont[keyPath: trait]
        text.transformAttributes(in: &selection) {
            let font = $0.font ?? .body
            if trait == \.isBold {
                $0.font = font.bold(shouldEnable)
            } else {
                $0.font = font.italic(shouldEnable)
            }
        }
    }

    private func toggleUnderline() {
        let shouldEnable = selection.typingAttributes(in: text).underlineStyle == nil
        text.transformAttributes(in: &selection) {
            $0.underlineStyle = shouldEnable ? .single : nil
        }
    }

    private func toggleStrikethrough() {
        let shouldEnable = selection.typingAttributes(in: text).strikethroughStyle == nil
        text.transformAttributes(in: &selection) {
            $0.strikethroughStyle = shouldEnable ? .single : nil
        }
    }

    private func increaseIndent() {
        guard case .insertionPoint = selection.indices(in: text) else { return }
        text.replaceSelection(&selection, withCharacters: "    ")
    }

    /// Removes up to four leading spaces from the line containing the caret.
    private func decreaseIndent() {
        guard case let .insertionPoint(caret) = selection.indices(in: text),
              caret > text.startIndex else { return }

        let characters = text.characters
        var lineStart = caret
        while lineStart > text.startIndex {
            let previous = characters.index(before: lineStart)
            if characters[previous] == "\n" { break }
            lineStart = previous
        }

        var indentEnd = lineStart
        for _ in 0..<4 where indentEnd < text.endIndex && characters[indentEnd] == " " {
            indentEnd = characters.index(after: indentEnd)
        }
        guard indentEnd > lineStart else { return }
        text.replaceSubrange(lineStart..<indentEnd, with: AttributedString())
        selection = AttributedTextSelection(insertionPoint: lineStart)
    }
}
