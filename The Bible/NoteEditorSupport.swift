import SwiftData
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

    /// The default step matches the system text size; each step above or below it moves one
    /// Dynamic Type size larger or smaller.
    static func dynamicTypeSize(for step: Int, relativeTo base: DynamicTypeSize) -> DynamicTypeSize {
        let sizes = DynamicTypeSize.allCases
        guard let baseIndex = sizes.firstIndex(of: base) else { return base }
        let offset = min(maximumStep, max(minimumStep, step)) - defaultStep
        let index = min(sizes.count - 1, max(0, baseIndex + offset))
        return sizes[index]
    }
}

struct NoteEditorTitleField: View {
    @Binding var title: String
    let placeholder: LocalizedStringKey

    var body: some View {
        TextField(placeholder, text: $title, axis: .vertical)
            .font(.title2.bold())
            .textFieldStyle(.plain)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1))
            }
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

struct CustomNoteTagsTip: View {
    var body: some View {
        ContextualTipView(
            id: "notes.customTags",
            title: "Organize with custom tags",
            message: "Type a tag such as #prayer in the note. Your existing tags are suggested as you type, and in Notes you can filter by tag.",
            systemImage: "number"
        )
    }
}

struct NoteCategoryMenu: View {
    @Binding var category: NoteCategory

    var body: some View {
        Menu {
            Picker("Type", selection: $category) {
                ForEach(NoteCategory.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
        } label: {
            Label(category.title, systemImage: "square.stack.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
        }
        .accessibilityLabel("Note type")
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

@MainActor
private final class NoteTabKeyAction {
    var handler: ((Int) -> Void)?

    func perform(_ direction: Int) {
        handler?(direction)
    }
}

fileprivate extension EnvironmentValues {
    /// Handles hardware Tab (+1) and Shift-Tab (-1) in the note body editor.
    @Entry var noteTabKeyAction: NoteTabKeyAction?
}

/// The note body editor, sized by the editor's text size setting.
struct NoteBodyTextEditor: View {
    @AppStorage(NoteEditorTextSize.storageKey) private var textSizeStep = NoteEditorTextSize.defaultStep
    @Environment(\.noteTabKeyAction) private var tabKeyAction
    @Environment(\.dynamicTypeSize) private var systemTypeSize
    @Environment(\.self) private var environment

    @Binding var text: AttributedString
    @Binding var selection: AttributedTextSelection
    /// Set while the body has keyboard focus, so editors can tuck other fields away.
    var isFocused: Binding<Bool> = .constant(false)

    var body: some View {
        NoteEditorKeyCommandHost(
            onTab: { tabKeyAction?.perform($0) },
            content: AnyView(
                FocusReportingTextEditor(text: $text, selection: $selection, isFocused: isFocused)
                    .font(.body)
                    .dynamicTypeSize(NoteEditorTextSize.dynamicTypeSize(for: textSizeStep, relativeTo: systemTypeSize))
                    .scrollContentBackground(.hidden)
                    .accessibilityLabel("Note")
                    // A hosted view doesn't inherit SwiftUI's environment (e.g. the
                    // Scripture-link openURL handler), so pass it through.
                    .environment(\.self, environment)
            )
        )
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1))
        }
    }
}

extension View {
    /// Sets `isShown` while the on-screen keyboard is up. With a hardware keyboard, iPad
    /// shows only a short shortcut bar, which doesn't count, so editors keep their fields.
    func onScreenKeyboardVisibility(_ isShown: Binding<Bool>) -> some View {
        task {
            for await notification in NotificationCenter.default.notifications(named: UIResponder.keyboardWillChangeFrameNotification) {
                isShown.wrappedValue = OnScreenKeyboard.isShown(
                    endFrame: (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
                    screenHeight: (notification.object as? UIScreen)?.bounds.height
                )
            }
        }
    }
}

enum OnScreenKeyboard {
    /// Taller than the hardware keyboard's shortcut bar, shorter than any on-screen keyboard.
    static let minimumHeight: CGFloat = 150

    /// Whether a keyboard frame is a full on-screen keyboard on screen. A hidden keyboard
    /// ends below the screen; a floating iPad keyboard reports no frame and covers little.
    static func isShown(endFrame: CGRect?, screenHeight: CGFloat?) -> Bool {
        guard let endFrame, endFrame.height >= minimumHeight else { return false }
        guard let screenHeight else { return true }
        return endFrame.minY < screenHeight
    }
}

/// Stands in for the fields above the note body while they're collapsed for typing.
struct NoteEditorShowFieldsButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.down")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 28)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel("Show Note Details")
        .transition(.opacity)
    }
}

/// Tracks focus inside the hosted hierarchy, since a `FocusState` doesn't reach across the
/// hosting controller boundary.
private struct FocusReportingTextEditor: View {
    @FocusState private var hasFocus: Bool

    @Binding var text: AttributedString
    @Binding var selection: AttributedTextSelection
    @Binding var isFocused: Bool

    var body: some View {
        TextEditor(text: $text, selection: $selection)
            .focused($hasFocus)
            .onChange(of: hasFocus) { _, focused in
                isFocused = focused
            }
    }
}

/// Hosts the note text view in a UIKit controller so Tab and Shift-Tab key commands sit in
/// the text view's responder chain. SwiftUI's `onKeyPress` never sees Tab in a `TextEditor`;
/// the text system claims it first, so these commands ask for priority over system behavior.
private struct NoteEditorKeyCommandHost: UIViewControllerRepresentable {
    let onTab: (Int) -> Void
    let content: AnyView

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller(rootView: content)
        controller.view.backgroundColor = .clear
        // The surrounding SwiftUI layout already handles safe areas and the keyboard.
        controller.safeAreaRegions = []
        controller.onTab = onTab
        return controller
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.rootView = content
        controller.onTab = onTab
    }

    final class Controller: UIHostingController<AnyView> {
        var onTab: ((Int) -> Void)?

        override var keyCommands: [UIKeyCommand]? {
            let indent = UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(indentLine))
            let outdent = UIKeyCommand(input: "\t", modifierFlags: .shift, action: #selector(outdentLine))
            for command in [indent, outdent] {
                command.wantsPriorityOverSystemBehavior = true
            }
            return (super.keyCommands ?? []) + [indent, outdent]
        }

        @objc private func indentLine() { onTab?(1) }
        @objc private func outdentLine() { onTab?(-1) }
    }
}

extension View {
    /// Adds the formatting bar, turns typed Scripture references into links, and shows a
    /// preview when one is tapped.
    func richNoteEditing(
        text: Binding<AttributedString>,
        selection: Binding<AttributedTextSelection>,
        formattingBarPadding: CGFloat = 16,
        onFormattingChange: @escaping () -> Void = {}
    ) -> some View {
        modifier(RichNoteEditing(
            text: text,
            selection: selection,
            formattingBarPadding: formattingBarPadding,
            onFormattingChange: onFormattingChange
        ))
    }
}

/// Runtime-only marker for generated custom-tag styling, so it can be refreshed
/// without affecting other note formatting.
private enum NoteCustomTagAttribute: AttributedStringKey {
    typealias Value = Bool
    static let name = "com.thebible.custom-note-tag"
}

private struct RichNoteEditing: ViewModifier {
    @Environment(\.fontResolutionContext) private var fontResolutionContext
    @AppStorage(NoteEditorTextSize.storageKey) private var textSizeStep = NoteEditorTextSize.defaultStep
    @State private var selectedScriptureReference: ScriptureRef?
    @State private var referenceLinkTask: Task<Void, Never>?
    @State private var tabKeyAction = NoteTabKeyAction()

    @Binding var text: AttributedString
    @Binding var selection: AttributedTextSelection
    let formattingBarPadding: CGFloat
    let onFormattingChange: () -> Void

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
                VStack(spacing: 6) {
                    if let partialTag {
                        NoteTagSuggestionBar(prefix: partialTag.prefix, horizontalPadding: formattingBarPadding) {
                            completeTag($0, replacing: partialTag.range)
                        }
                    }
                    formattingBar
                }
            }
            .onAppear {
                tabKeyAction.handler = handleTabKey
                linkScriptureReferences()
                styleCustomTags()
            }
            .onChange(of: String(text.characters)) { oldValue, newValue in
                handleListTyping(previousCount: oldValue.count, newCount: newValue.count)
                styleCustomTags()
                scheduleReferenceLinking()
            }
            // Hardware Tab / Shift-Tab, delivered by the editor's key commands.
            .environment(\.noteTabKeyAction, tabKeyAction)
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

    private var formattingBar: some View {
        NoteFormattingBar(
            toggleBold: { formatting { toggleFontTrait(\.isBold) } },
            toggleUnderline: { formatting(toggleUnderline) },
            toggleItalic: { formatting { toggleFontTrait(\.isItalic) } },
            toggleStrikethrough: { formatting(toggleStrikethrough) },
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

    /// Applies a formatting change and reports it, since it doesn't change the note's characters.
    private func formatting(_ change: () -> Void) {
        change()
        onFormattingChange()
    }

    // MARK: - Tag suggestions

    /// The tag being typed at the caret, if any.
    private var partialTag: (range: Range<String.Index>, prefix: String)? {
        guard case let .insertionPoint(caret) = selection.indices(in: text) else { return nil }
        return NoteCustomTags.partialTag(in: String(text.characters), endingAt: offset(of: caret))
    }

    /// Replaces the partial tag with the chosen one and a trailing space.
    private func completeTag(_ tag: String, replacing range: Range<String.Index>) {
        let plain = String(text.characters)
        let startOffset = plain.distance(from: plain.startIndex, to: range.lowerBound)
        let endOffset = plain.distance(from: plain.startIndex, to: range.upperBound)
        let replacement = "#\(tag) "
        text.replaceSubrange(index(atOffset: startOffset)..<index(atOffset: endOffset), with: AttributedString(replacement))
        selection = AttributedTextSelection(insertionPoint: index(atOffset: startOffset + replacement.count))
        styleCustomTags()
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

    // MARK: - Custom tags

    /// Applies lightweight, editable recognition styling to each complete custom tag.
    private func styleCustomTags() {
        var styledText = text
        let styledRanges = styledText.runs.compactMap { run in
            run[NoteCustomTagAttribute.self] == true ? run.range : nil
        }

        for range in styledRanges {
            styledText[range].foregroundColor = nil
            styledText[range].backgroundColor = nil
            styledText[range][NoteCustomTagAttribute.self] = nil
        }

        let plainText = String(styledText.characters)
        for stringRange in NoteCustomTags.ranges(in: plainText) {
            guard let lowerBound = AttributedString.Index(stringRange.lowerBound, within: styledText),
                  let upperBound = AttributedString.Index(stringRange.upperBound, within: styledText) else {
                continue
            }

            let range = lowerBound..<upperBound
            styledText[range].foregroundColor = .accentColor
            styledText[range].backgroundColor = .accentColor.opacity(0.14)
            styledText[range][NoteCustomTagAttribute.self] = true

            // The delimiter must remain unstyled so the editor doesn't carry a tag's
            // appearance into the word typed after a space or punctuation mark.
            if upperBound < styledText.endIndex {
                let delimiterRange = upperBound..<styledText.characters.index(after: upperBound)
                styledText[delimiterRange].foregroundColor = nil
                styledText[delimiterRange].backgroundColor = nil
                styledText[delimiterRange][NoteCustomTagAttribute.self] = nil
            }
        }

        guard styledText != text else { return }
        text = styledText
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
        shiftLine(by: 1, listItemsOnly: false)
    }

    private func decreaseIndent() {
        shiftLine(by: -1, listItemsOnly: false)
    }

    // MARK: - Lists

    /// Reacts to a single typed character: Return continues (or ends) a list, and a Tab
    /// that reached the text as a character indents a list item instead.
    private func handleListTyping(previousCount: Int, newCount: Int) {
        guard newCount == previousCount + 1,
              case let .insertionPoint(caret) = selection.indices(in: text),
              caret > text.startIndex else { return }

        let typed = text.characters.index(before: caret)
        switch text.characters[typed] {
        case "\n":
            continueList(afterNewlineAt: typed, caret: caret)
        case "\t":
            let lineStart = startOfLine(containing: typed)
            let line = String(text.characters[lineStart..<endOfLine(containing: typed)])
            guard NoteListMarker.parse(line) != nil else { return }
            let typedOffset = offset(of: typed)
            text.replaceSubrange(typed..<caret, with: AttributedString())
            selection = AttributedTextSelection(insertionPoint: index(atOffset: typedOffset))
            shiftLine(by: 1, listItemsOnly: true)
        default:
            break
        }
    }

    /// After Return on a list item, starts the next item with the same marker (numbers count
    /// up). Return on an empty item removes it and ends the list, as in Notes.
    private func continueList(afterNewlineAt newline: AttributedString.Index, caret: AttributedString.Index) {
        let lineStart = startOfLine(containing: newline)
        guard let item = NoteListMarker.parse(String(text.characters[lineStart..<newline])) else { return }

        let restOfNewLine = text.characters[caret..<endOfLine(containing: caret)]
        let itemIsEmpty = item.content.allSatisfy(\.isWhitespace) && restOfNewLine.allSatisfy(\.isWhitespace)

        if itemIsEmpty {
            let lineStartOffset = offset(of: lineStart)
            text.replaceSubrange(lineStart..<caret, with: AttributedString())
            selection = AttributedTextSelection(insertionPoint: index(atOffset: lineStartOffset))
        } else {
            text.replaceSelection(&selection, withCharacters: item.indent + item.marker.next.text + " ")
        }
    }

    /// Tab indents a list item, or types an indent elsewhere; Shift-Tab outdents the line.
    private func handleTabKey(_ direction: Int) {
        guard case .insertionPoint = selection.indices(in: text) else { return }
        if shiftLine(by: direction, listItemsOnly: true) { return }
        if direction > 0 {
            text.replaceSelection(&selection, withCharacters: NoteListMarker.indentUnit)
        } else {
            shiftLine(by: -1, listItemsOnly: false)
        }
    }

    /// Indents (`direction` > 0) or outdents the line holding the caret by one level, keeping
    /// the caret on the same character. List items also take their new level's marker, as in
    /// Notes: bullets change symbol, numbers continue that level's count or restart at 1.
    /// Returns whether the line was eligible.
    @discardableResult
    private func shiftLine(by direction: Int, listItemsOnly: Bool) -> Bool {
        guard case let .insertionPoint(caret) = selection.indices(in: text) else { return false }

        let lineStart = startOfLine(containing: caret)
        let lineEnd = endOfLine(containing: caret)
        let line = String(text.characters[lineStart..<lineEnd])
        let item = NoteListMarker.parse(line)
        if listItemsOnly, item == nil { return false }

        let oldIndent = item?.indent ?? String(line.prefix { $0 == " " || $0 == "\t" })
        let newIndent: String
        if direction > 0 {
            newIndent = NoteListMarker.indentUnit + oldIndent
        } else {
            let removable = NoteListMarker.outdentLength(of: line)
            // Nothing to outdent; still consume Shift-Tab so it doesn't move focus.
            guard removable > 0 else { return true }
            newIndent = String(oldIndent.dropFirst(removable))
        }

        let oldPrefixLength: Int
        let newPrefix: String
        if let item {
            let precedingText = String(text.characters[text.characters.startIndex..<lineStart])
            let marker = item.marker.adjusted(
                toIndent: newIndent,
                after: precedingText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            )
            oldPrefixLength = item.prefixLength
            newPrefix = newIndent + marker.text + " "
        } else {
            oldPrefixLength = oldIndent.count
            newPrefix = newIndent
        }

        let lineStartOffset = offset(of: lineStart)
        let caretOffset = offset(of: caret)
        text.replaceSubrange(
            lineStart..<index(atOffset: lineStartOffset + oldPrefixLength),
            with: AttributedString(newPrefix)
        )

        // Keep the caret on the same character; a caret inside the old prefix lands after the new one.
        let caretInContent = max(0, caretOffset - lineStartOffset - oldPrefixLength)
        selection = AttributedTextSelection(
            insertionPoint: index(atOffset: lineStartOffset + newPrefix.count + caretInContent)
        )
        return true
    }

    private func startOfLine(containing index: AttributedString.Index) -> AttributedString.Index {
        let characters = text.characters
        var start = index
        while start > characters.startIndex {
            let previous = characters.index(before: start)
            if characters[previous] == "\n" { break }
            start = previous
        }
        return start
    }

    private func endOfLine(containing index: AttributedString.Index) -> AttributedString.Index {
        let characters = text.characters
        return characters[index...].firstIndex(of: "\n") ?? characters.endIndex
    }

    private func offset(of index: AttributedString.Index) -> Int {
        text.characters.distance(from: text.characters.startIndex, to: index)
    }

    private func index(atOffset offset: Int) -> AttributedString.Index {
        text.characters.index(text.characters.startIndex, offsetBy: offset)
    }
}

/// A plain-text list item in a note: optional indent, a marker, one space, then the content.
/// Bullets ("•", "-", "*", …) repeat as-is; numbers ("1.", "2)") count up.
struct NoteListMarker: Equatable {
    enum Kind: Equatable {
        case bullet(Character)
        case number(Int, punctuation: Character)
    }

    static let indentUnit = "    "
    private static let bulletSymbols: Set<Character> = ["•", "◦", "▪", "‣", "–", "-", "*"]
    /// Bullets by nesting level, as in Notes; deeper levels repeat the cycle.
    private static let nestedBullets: [Character] = ["•", "◦", "▪"]

    let kind: Kind

    var text: String {
        switch kind {
        case .bullet(let symbol): String(symbol)
        case .number(let number, let punctuation): "\(number)\(punctuation)"
        }
    }

    /// The marker for the item after this one.
    var next: NoteListMarker {
        guard case .number(let number, let punctuation) = kind else { return self }
        return NoteListMarker(kind: .number(number + 1, punctuation: punctuation))
    }

    /// This marker for an item moved to `indent`, given the lines above it.
    /// "•", "◦" and "▪" bullets take the new level's symbol (other bullets, like "-", stay put).
    /// Numbers continue the nearest item above at the new level, or restart at 1 when there
    /// isn't one before the list breaks or a shallower item starts it.
    func adjusted(toIndent indent: String, after precedingLines: [String]) -> NoteListMarker {
        let level = Self.level(of: indent)
        switch kind {
        case .bullet(let symbol):
            guard Self.nestedBullets.contains(symbol) else { return self }
            return NoteListMarker(kind: .bullet(Self.nestedBullets[level % Self.nestedBullets.count]))

        case .number(_, let punctuation):
            for line in precedingLines.reversed() {
                guard let previous = Self.parse(line) else { break }
                let previousLevel = Self.level(of: previous.indent)
                if previousLevel < level { break }
                if previousLevel == level, case .number(let number, let previousPunctuation) = previous.marker.kind,
                   previousPunctuation == punctuation {
                    return NoteListMarker(kind: .number(number + 1, punctuation: punctuation))
                }
            }
            return NoteListMarker(kind: .number(1, punctuation: punctuation))
        }
    }

    /// Nesting depth: one level per tab or per indent unit of spaces.
    static func level(of indent: String) -> Int {
        let tabs = indent.filter { $0 == "\t" }.count
        let spaces = indent.filter { $0 == " " }.count
        return tabs + spaces / indentUnit.count
    }

    struct Item: Equatable {
        let indent: String
        let marker: NoteListMarker
        let content: String

        /// Characters before the content: indent, marker and its space.
        var prefixLength: Int { indent.count + marker.text.count + 1 }
    }

    /// Parses one line (without its newline); nil when it isn't a list item.
    static func parse(_ line: String) -> Item? {
        let indentEnd = line.firstIndex { $0 != " " && $0 != "\t" } ?? line.endIndex
        let rest = line[indentEnd...]
        guard let space = rest.firstIndex(of: " ") else { return nil }

        let token = rest[..<space]
        let content = String(rest[rest.index(after: space)...])
        let indent = String(line[..<indentEnd])

        if token.count == 1, let symbol = token.first, bulletSymbols.contains(symbol) {
            return Item(indent: indent, marker: NoteListMarker(kind: .bullet(symbol)), content: content)
        }

        // Up to three digits, so a line like "2024. was a year" isn't taken for a list.
        let digits = token.dropLast()
        if let punctuation = token.last, punctuation == "." || punctuation == ")",
           (1...3).contains(digits.count), digits.allSatisfy(\.isASCII), digits.allSatisfy(\.isNumber),
           let number = Int(digits) {
            return Item(indent: indent, marker: NoteListMarker(kind: .number(number, punctuation: punctuation)), content: content)
        }
        return nil
    }

    /// How many leading characters one outdent removes: a tab, or up to one indent unit of spaces.
    static func outdentLength(of line: String) -> Int {
        if line.first == "\t" { return 1 }
        return line.prefix(indentUnit.count).prefix { $0 == " " }.count
    }
}

/// Existing custom tags matching the one being typed, most-used first; tapping one completes it.
private struct NoteTagSuggestionBar: View {
    @Query private var verseNotes: [VerseNote]
    @Query private var userNotes: [UserNote]

    let prefix: String
    let horizontalPadding: CGFloat
    let choose: (String) -> Void

    var body: some View {
        let suggestions = matchingTags
        if !suggestions.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { tag in
                        Button("#\(tag)") { choose(tag) }
                            .font(.subheadline.weight(.semibold))
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .padding(.horizontal, 12)
            }
            .scrollIndicators(.hidden)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
            .padding(.horizontal, horizontalPadding)
            .accessibilityLabel("Tag suggestions")
        }
    }

    private var matchingTags: [String] {
        var counts: [String: Int] = [:]
        let texts = verseNotes.flatMap { [$0.title, $0.content] } + userNotes.flatMap { [$0.title, $0.content] }
        for text in texts {
            for tag in NoteCustomTags.tags(in: text) { counts[tag, default: 0] += 1 }
        }
        return counts
            .filter { $0.key.hasPrefix(prefix) && $0.key != prefix }
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(8)
            .map(\.key)
    }
}
