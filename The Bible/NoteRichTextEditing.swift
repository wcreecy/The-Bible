import SwiftData
import SwiftUI
import UIKit

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
