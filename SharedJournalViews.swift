import SwiftUI
import Foundation
import UIKit

// Shared notifications for the Journal feature
enum JournalNotifications {
    static let openScripturePreview = Notification.Name("OpenScripturePreview")
    static let entryCreated = Notification.Name("JournalEntryCreated")
    static let entryUpdated = Notification.Name("JournalEntryUpdated")
    // NEW: request Journal tab (iPad) to start a new inline entry from a Bible reference
    static let startInlineNewFromBible = Notification.Name("JournalStartInlineNewFromBible")
}

// Shared helper: extract unique ScriptureRef list from a linkified AttributedString
enum ScriptureRefExtractor {
    static func refs(in attributed: AttributedString) -> [ScriptureRef] {
        var results: [ScriptureRef] = []
        var seen: Set<String> = []
        for run in attributed.runs {
            if let url = run.link, let ref = BibleReferenceLinker.parse(url: url) {
                let key: String = {
                    if let end = ref.endVerse, end != ref.startVerse {
                        return "\(ref.bookName) \(ref.chapter):\(ref.startVerse)-\(end)"
                    } else {
                        return "\(ref.bookName) \(ref.chapter):\(ref.startVerse)"
                    }
                }()
                if !seen.contains(key) {
                    seen.insert(key)
                    results.append(ref)
                }
            }
        }
        return results
    }
}

// Shared UI: scripture preview card
struct ScripturePreviewCard: View {
    let title: String
    let verses: [Verse]
    let refContext: ScriptureRef?
    let onCopy: (() -> Void)?
    let onClose: (() -> Void)?

    init(content: (title: String, verses: [Verse]), refContext: ScriptureRef?, onCopy: (() -> Void)? = nil, onClose: (() -> Void)? = nil) {
        self.title = content.title
        self.verses = content.verses
        self.refContext = refContext
        self.onCopy = onCopy
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                Spacer()
                if let onCopy {
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Copy scripture")
                    .accessibilityHint("Copies the selected scripture and verse text")
                }
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close preview")
                }
            }
            ForEach(verses, id: \.number) { v in
                VStack(alignment: .leading, spacing: 4) {
                    Text(v.text)
                        .font(.body)
                    if let refContext {
                        Text("\(refContext.bookName) \(refContext.chapter):\(v.number)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if v.number != verses.last?.number { Divider().padding(.vertical, 4) }
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
}

// Shared UI: list of scripture links with copy buttons and tap handler
struct ScriptureLinksList: View {
    let refs: [ScriptureRef]
    let onTap: (ScriptureRef) -> Void
    let onCopy: (ScriptureRef) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(refs.enumerated()), id: \.offset) { _, ref in
                HStack(spacing: 8) {
                    Button(action: { onTap(ref) }) {
                        Text(displayString(for: ref))
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundStyle(.blue)
                            .underline()
                    }
                    .buttonStyle(.plain)

                    Button(action: { onCopy(ref) }) {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .accessibilityLabel("Copy reference")
                    .accessibilityHint("Copies the scripture reference")
                }
            }
        }
    }

    private func displayString(for ref: ScriptureRef) -> String {
        if let end = ref.endVerse, end != ref.startVerse {
            return "\(ref.bookName) \(ref.chapter):\(ref.startVerse)-\(end)"
        } else {
            return "\(ref.bookName) \(ref.chapter):\(ref.startVerse)"
        }
    }
}

// Shared UI: tag chip and row
struct TagChip: View {
    let text: String
    let tint: Color
    let isSelected: Bool
    var onTap: (() -> Void)? = nil

    var body: some View {
        let bg = tint.opacity(isSelected ? 0.30 : 0.15)
        let stroke = tint.opacity(isSelected ? 0.8 : 0.4)
        Button(action: { onTap?() }) {
            Text(text)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(bg, in: Capsule())
                .overlay(Capsule().stroke(stroke, lineWidth: isSelected ? 2 : 1))
                .foregroundStyle(tint)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 1)
    }
}

struct TagChipRow: View {
    let tags: [String]
    let selectedTags: Set<String>
    let showColorPicker: Bool
    let onTap: ((String) -> Void)?
    let onColorChange: ((String, Color) -> Void)?

    init(tags: [String], selectedTags: Set<String> = [], showColorPicker: Bool = false, onTap: ((String) -> Void)? = nil, onColorChange: ((String, Color) -> Void)? = nil) {
        self.tags = tags
        self.selectedTags = selectedTags
        self.showColorPicker = showColorPicker
        self.onTap = onTap
        self.onColorChange = onColorChange
    }

    private func displayName(for tag: String) -> String {
        if let preferred = TagDisplayNameStore.displayName(for: tag) {
            return preferred
        }
        // Fallback: Title Case each word for nicer appearance
        return tag
            .split(separator: " ")
            .map { part in
                let s = String(part)
                guard let f = s.first else { return s }
                return String(f).uppercased() + s.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ForEach(tags, id: \.self) { t in
                HStack(spacing: 8) {
                    let tint = TagColorStore.color(for: t) ?? .accentColor
                    TagChip(text: displayName(for: t), tint: tint, isSelected: selectedTags.contains(t.lowercased())) {
                        onTap?(t)
                    }
                    if showColorPicker, let onColorChange {
                        ColorPicker("", selection: Binding(
                            get: { TagColorStore.color(for: t) ?? .accentColor },
                            set: { newValue in onColorChange(t, newValue) }
                        ), supportsOpacity: false)
                        .labelsHidden()
                    }
                }
            }
        }
    }
}

struct CursorTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    @Binding var caretRect: CGRect?
    @Binding var bottomInset: CGFloat
    var onChange: ((String) -> Void)? = nil

    // Optional inline linkifier and link tap callback
    var linkify: ((String) -> AttributedString)? = nil
    var onLinkTap: ((ScriptureRef) -> Void)? = nil

    // Adopt the SwiftUI environment font to match the rest of the app
    @Environment(\.font) private var envFont

    // MARK: - Normalization to ensure dynamic text color in light/dark AND enforce a concrete font on all runs

    private func normalizedAttributedString(_ attr: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attr)
        let fullRange = NSRange(location: 0, length: mutable.length)

        // Remove any explicit black foreground colors; we’ll rely on .label as the default.
        mutable.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            if let color = value as? UIColor {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
                    if r == 0 && g == 0 && b == 0 && a > 0 {
                        mutable.removeAttribute(.foregroundColor, range: range)
                    }
                }
            }
        }

        // Ensure every run has an explicit UIFont. If missing, apply preferred body.
        let bodyFont = resolvedUIFont()
        mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            if value == nil {
                mutable.addAttribute(.font, value: bodyFont, range: range)
            } else if let f = value as? UIFont {
                // If the font looks unreasonably small (defensive), enforce body
                if f.pointSize < bodyFont.pointSize * 0.75 {
                    mutable.addAttribute(.font, value: bodyFont, range: range)
                }
            }
        }

        return mutable
    }

    // Convert SwiftUI Font environment into a UIFont; fall back to preferred body
    private func resolvedUIFont() -> UIFont {
        if let uiFont = UIFont.preferredFont(forTextStyle: .body).withTraits(from: envFont) {
            return uiFont
        }
        return UIFont.preferredFont(forTextStyle: .body)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isScrollEnabled = true
        tv.backgroundColor = .clear
        tv.delegate = context.coordinator

        // Dynamic, adaptive colors for text and caret/selection
        tv.textColor = .label
        tv.tintColor = .tintColor
        tv.typingAttributes[.foregroundColor] = UIColor.label

        // Match keyboard appearance to interface style
        if let style = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.traitCollection.userInterfaceStyle {
            tv.keyboardAppearance = (style == .dark) ? .dark : .light
        }

        // Enable editing and selection
        tv.isEditable = true
        tv.isSelectable = true
        tv.dataDetectorTypes = [] // we apply custom links

        // Link appearance
        tv.linkTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        // Text behavior: disable autocorrect, keep spell checking and predictions; keep smart features and auto-capitalization.
        tv.autocorrectionType = .no
        tv.spellCheckingType = .yes
        tv.autocapitalizationType = .sentences
        tv.smartDashesType = .yes
        tv.smartQuotesType = .yes
        tv.smartInsertDeleteType = .yes

        // Apply app-wide body font (resolves from SwiftUI environment)
        let bodyFont = resolvedUIFont()
        tv.font = bodyFont
        tv.typingAttributes[.font] = bodyFont

        tv.textContainer.lineFragmentPadding = 5
        tv.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

        // Seed text
        if let linkify {
            let linked = NSAttributedString(linkify(text))
            let normalized = normalizedAttributedString(linked)
            tv.attributedText = normalized
            // Reassert dynamic colors and font immediately after setting attributedText
            tv.textColor = .label
            tv.typingAttributes[.foregroundColor] = UIColor.label
            tv.font = bodyFont
            tv.typingAttributes[.font] = bodyFont
        } else {
            tv.text = text
        }

        // Initial insets
        applyInsets(to: tv, bottom: bottomInset)
        DispatchQueue.main.async {
            context.coordinator.updateCaretRect(tv, deferBindingUpdate: true)
        }
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.isInSwiftUIUpdate = true
        defer { context.coordinator.isInSwiftUIUpdate = false }

        // Keep dynamic colors enforced
        if uiView.textColor != .label {
            uiView.textColor = .label
        }
        if (uiView.typingAttributes[.foregroundColor] as? UIColor) != UIColor.label {
            uiView.typingAttributes[.foregroundColor] = UIColor.label
        }

        // Ensure font matches environment (size/family)
        let bodyFont = resolvedUIFont()
        if uiView.font != bodyFont {
            uiView.font = bodyFont
        }
        if (uiView.typingAttributes[.font] as? UIFont) != bodyFont {
            uiView.typingAttributes[.font] = bodyFont
        }

        // Update text (preserving selection)
        let currentString = uiView.text ?? ""
        if let linkify {
            if context.coordinator.lastLinkifiedText != text || uiView.attributedText?.string != text {
                context.coordinator.isProgrammaticUpdate = true
                let oldRange = uiView.selectedRange
                let linked = NSAttributedString(linkify(text))
                let normalized = normalizedAttributedString(linked)
                uiView.attributedText = normalized
                // Immediately reassert dynamic colors and font after assigning attributedText
                uiView.textColor = .label
                uiView.typingAttributes[.foregroundColor] = UIColor.label
                uiView.font = bodyFont
                uiView.typingAttributes[.font] = bodyFont
                uiView.selectedRange = oldRange
                context.coordinator.lastLinkifiedText = text
                context.coordinator.isProgrammaticUpdate = false
            }
        } else {
            if currentString != text {
                context.coordinator.isProgrammaticUpdate = true
                let oldRange = uiView.selectedRange
                uiView.text = text
                uiView.selectedRange = oldRange
                context.coordinator.isProgrammaticUpdate = false
            }
        }

        // Update selection
        if uiView.selectedRange != selection {
            let maxLoc = max(0, (uiView.text as NSString).length)
            let newLoc = min(max(selection.location, 0), maxLoc)
            let maxLen = max(0, maxLoc - newLoc)
            let newLen = min(max(selection.length, 0), maxLen)

            context.coordinator.isProgrammaticUpdate = true
            uiView.selectedRange = NSRange(location: newLoc, length: newLen)
            context.coordinator.isProgrammaticUpdate = false
        }

        // Apply keyboard-driven bottom inset
        applyInsets(to: uiView, bottom: bottomInset)

        // Keep caret visible after updates
        context.coordinator.scrollCaretVisible(uiView)

        context.coordinator.updateCaretRect(uiView, deferBindingUpdate: true)
    }

    private func applyInsets(to tv: UITextView, bottom: CGFloat) {
        var inset = tv.contentInset
        if abs(inset.bottom - bottom) > 0.5 {
            inset.bottom = bottom
            tv.contentInset = inset
        }

        if #available(iOS 13.0, *) {
            var vertical = tv.verticalScrollIndicatorInsets
            if abs(vertical.bottom - bottom) > 0.5 {
                vertical.bottom = bottom
                tv.verticalScrollIndicatorInsets = vertical
            }
        } else {
            var ind = tv.scrollIndicatorInsets
            if abs(ind.bottom - bottom) > 0.5 {
                ind.bottom = bottom
                tv.scrollIndicatorInsets = ind
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate, UIScrollViewDelegate {
        var parent: CursorTextView
        var isProgrammaticUpdate: Bool = false
        var isInSwiftUIUpdate: Bool = false
        private var lastCaretRect: CGRect = .null

        // Cache last linkified source to avoid redundant attribute work
        var lastLinkifiedText: String?

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
            scrollCaretVisible(textView)

            // Re-apply linkification on change if provided
            if let linkify = parent.linkify {
                lastLinkifiedText = newText
                let oldRange = textView.selectedRange
                let linked = NSAttributedString(linkify(newText))
                let normalized = parent.normalizedAttributedString(linked)
                textView.attributedText = normalized
                // Immediately reassert dynamic colors and font after assigning attributedText
                textView.textColor = .label
                textView.typingAttributes[.foregroundColor] = UIColor.label
                let bodyFont = parent.resolvedUIFont()
                textView.font = bodyFont
                textView.typingAttributes[.font] = bodyFont
                textView.selectedRange = oldRange
            }

            // Ensure typing attributes stay dynamic
            if (textView.typingAttributes[.foregroundColor] as? UIColor) != UIColor.label {
                textView.typingAttributes[.foregroundColor] = UIColor.label
            }
            let bodyFont = parent.resolvedUIFont()
            if (textView.typingAttributes[.font] as? UIFont) != bodyFont {
                textView.typingAttributes[.font] = bodyFont
            }

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
            scrollCaretVisible(textView)
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

        func scrollCaretVisible(_ textView: UITextView) {
            let range = textView.selectedRange
            if range.location != NSNotFound {
                textView.scrollRangeToVisible(range)
            }
        }

        // MARK: - Link interaction (iOS 17+)
        @available(iOS 17.0, *)
        private func textView(_ textView: UITextView,
                      shouldInteractWith textItem: UITextItem,
                      in characterRange: NSRange) -> Bool {
            if case let .link(url) = textItem.content,
               let ref = BibleReferenceLinker.parse(url: url),
               let _ = BibleReferenceLinker.loadVerses(for: ref) {
                DispatchQueue.main.async {
                    self.parent.onLinkTap?(ref)
                }
                // handled
                return false
            }
            return true
        }

        // MARK: - Link interaction (iOS 16 and earlier)
        @available(iOS, introduced: 10.0, deprecated: 17.0)
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            if let ref = BibleReferenceLinker.parse(url: URL) {
                if let _ = BibleReferenceLinker.loadVerses(for: ref) {
                    DispatchQueue.main.async {
                        self.parent.onLinkTap?(ref)
                    }
                    // We handled it; don't perform default action
                    return false
                }
            }
            // Not our custom scheme; allow system
            return true
        }
    }
}

private extension UIFont {
    // Try to derive a UIFont from a SwiftUI Font if possible.
    // If envFont is nil or not concrete, return preferred body with no change.
    func withTraits(from swiftUIFont: Font?) -> UIFont? {
        guard let swiftUIFont else { return self }
        switch swiftUIFont {
        case .largeTitle: return UIFont.preferredFont(forTextStyle: .largeTitle)
        case .title: return UIFont.preferredFont(forTextStyle: .title1)
        case .title2: return UIFont.preferredFont(forTextStyle: .title2)
        case .title3: return UIFont.preferredFont(forTextStyle: .title3)
        case .headline: return UIFont.preferredFont(forTextStyle: .headline)
        case .subheadline: return UIFont.preferredFont(forTextStyle: .subheadline)
        case .body: return UIFont.preferredFont(forTextStyle: .body)
        case .callout: return UIFont.preferredFont(forTextStyle: .callout)
        case .footnote: return UIFont.preferredFont(forTextStyle: .footnote)
        case .caption: return UIFont.preferredFont(forTextStyle: .caption1)
        case .caption2: return UIFont.preferredFont(forTextStyle: .caption2)
        default:
            return self
        }
    }
}
