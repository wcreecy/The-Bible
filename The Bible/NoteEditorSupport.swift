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
    static let storageKey = AppStorageKey.noteEditorTextSizeStep

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
        if let data, let formatted = PersistedDecoding.decode(AttributedString.self, from: data, name: "note formatted content") {
            return formatted
        }
        return AttributedString(fallback)
    }
}

@MainActor
final class NoteTabKeyAction {
    var handler: ((Int) -> Void)?

    func perform(_ direction: Int) {
        handler?(direction)
    }
}

extension EnvironmentValues {
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
