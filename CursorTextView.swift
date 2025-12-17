#if canImport(UIKit)
import SwiftUI
import Foundation
import UIKit

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

        // Remove explicit black colors; rely on dynamic .label
        mutable.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            if let color = value as? UIColor {
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                if color.getRed(&r, green: &g, blue:&b, alpha:&a), r == 0, g == 0, b == 0, a > 0 {
                    mutable.removeAttribute(.foregroundColor, range: range)
                }
            }
        }

        // Ensure every run has an explicit UIFont
        let bodyFont = resolvedUIFont()
        mutable.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            if value == nil {
                mutable.addAttribute(.font, value: bodyFont, range: range)
            } else if let f = value as? UIFont, f.pointSize < bodyFont.pointSize * 0.75 {
                mutable.addAttribute(.font, value: bodyFont, range: range)
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

        // Dynamic colors
        tv.textColor = .label
        tv.tintColor = .tintColor
        tv.typingAttributes[.foregroundColor] = UIColor.label

        // Keyboard appearance
        if let style = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.traitCollection.userInterfaceStyle {
            tv.keyboardAppearance = (style == .dark) ? .dark : .light
        }

        tv.isEditable = true
        tv.isSelectable = true
        tv.dataDetectorTypes = []

        // Link appearance
        tv.linkTextAttributes = [
            .foregroundColor: UIColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        // Text behavior
        tv.autocorrectionType = .no
        tv.spellCheckingType = .yes
        tv.autocapitalizationType = .sentences
        tv.smartDashesType = .yes
        tv.smartQuotesType = .yes
        tv.smartInsertDeleteType = .yes

        // Apply font
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
            tv.textColor = .label
            tv.typingAttributes[.foregroundColor] = UIColor.label
            tv.font = bodyFont
            tv.typingAttributes[.font] = bodyFont
            // IMPORTANT: ensure we don't inherit .link in typingAttributes
            tv.typingAttributes[.link] = nil
        } else {
            tv.text = text
            tv.typingAttributes[.link] = nil
        }

        applyInsets(to: tv, bottom: bottomInset)
        DispatchQueue.main.async {
            context.coordinator.updateCaretRect(tv, deferBindingUpdate: true)
        }

        // Start keyboard tracking to avoid mutating during animations
        context.coordinator.startKeyboardTracking()

        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.isInSwiftUIUpdate = true
        defer { context.coordinator.isInSwiftUIUpdate = false }

        // Keep dynamic colors and font enforced
        if uiView.textColor != .label { uiView.textColor = .label }
        if (uiView.typingAttributes[.foregroundColor] as? UIColor) != UIColor.label {
            uiView.typingAttributes[.foregroundColor] = UIColor.label
        }
        let bodyFont = resolvedUIFont()
        if uiView.font != bodyFont { uiView.font = bodyFont }
        if (uiView.typingAttributes[.font] as? UIFont) != bodyFont {
            uiView.typingAttributes[.font] = bodyFont
        }

        // Update text (preserving selection) only if needed
        if let linkify {
            if context.coordinator.lastLinkifiedText != text || uiView.attributedText?.string != text {
                // If the keyboard is animating, defer this whole relinkify to avoid UIKit warnings/jumps
                if context.coordinator.isKeyboardAnimating {
                    context.coordinator.deferSwiftUIUpdate { [weak uiView] in
                        guard let tv = uiView else { return }
                        self.updateUIView(tv, context: context)
                    }
                } else {
                    context.coordinator.isProgrammaticUpdate = true
                    context.coordinator.isRelinkifying = true
                    // Use current selection at the moment of apply and clamp it
                    let currentRange = uiView.selectedRange
                    let clampedOld = context.coordinator.clampSelection(currentRange, forLength: (uiView.attributedText?.string as NSString?)?.length ?? (uiView.text as NSString?)?.length ?? 0)
                    let linked = NSAttributedString(linkify(text))
                    let normalized = normalizedAttributedString(linked)

                    // Skip assignment if link ranges are unchanged to avoid layout churn
                    if !context.coordinator.linkRangesChanged(between: uiView.attributedText, and: normalized) {
                        uiView.textColor = .label
                        uiView.typingAttributes[.foregroundColor] = UIColor.label
                        uiView.font = bodyFont
                        uiView.typingAttributes[.font] = bodyFont
                        uiView.typingAttributes[.link] = nil
                    } else {
                        uiView.attributedText = normalized
                        uiView.textColor = .label
                        uiView.typingAttributes[.foregroundColor] = UIColor.label
                        uiView.font = bodyFont
                        uiView.typingAttributes[.font] = bodyFont
                        uiView.typingAttributes[.link] = nil
                    }

                    // Clamp selection to new length and restore
                    let newLen = (uiView.attributedText?.string as NSString?)?.length ?? 0
                    let clampedNew = context.coordinator.clampSelection(clampedOld, forLength: newLen)
                    uiView.selectedRange = clampedNew
                    context.coordinator.lastLinkifiedText = text
                    context.coordinator.isProgrammaticUpdate = false
                    context.coordinator.didProgrammaticallyAdjustSelection = true
                    context.coordinator.isRelinkifying = false
                }
            }
        } else {
            if (uiView.text ?? "") != text {
                if context.coordinator.isKeyboardAnimating {
                    context.coordinator.deferSwiftUIUpdate { [weak uiView] in
                        guard let tv = uiView else { return }
                        self.updateUIView(tv, context: context)
                    }
                } else {
                    context.coordinator.isProgrammaticUpdate = true
                    let currentRange = uiView.selectedRange
                    let clampedOld = context.coordinator.clampSelection(currentRange, forLength: (uiView.text as NSString?)?.length ?? 0)
                    uiView.text = text
                    // Ensure no lingering link typing attribute
                    uiView.typingAttributes[.link] = nil
                    let newLen = (uiView.text as NSString).length
                    let clampedNew = context.coordinator.clampSelection(clampedOld, forLength: newLen)
                    uiView.selectedRange = clampedNew
                    context.coordinator.isProgrammaticUpdate = false
                    context.coordinator.didProgrammaticallyAdjustSelection = true
                }
            }
        }

        // Update selection only if actually different
        if uiView.selectedRange != selection && !context.coordinator.isKeyboardAnimating {
            let maxLoc = max(0, (uiView.text as NSString).length)
            let newRange = context.coordinator.clampSelection(selection, forLength: maxLoc)
            if uiView.selectedRange != newRange {
                context.coordinator.isProgrammaticUpdate = true
                uiView.selectedRange = newRange
                context.coordinator.isProgrammaticUpdate = false
                context.coordinator.didProgrammaticallyAdjustSelection = true
            }
        }

        // Apply keyboard-driven bottom inset
        applyInsets(to: uiView, bottom: bottomInset)

        // Avoid forcing scroll while the user types; only ensure caret visible after programmatic selection changes.
        if context.coordinator.didProgrammaticallyAdjustSelection {
            context.coordinator.didProgrammaticallyAdjustSelection = false
            // Suppress scroll nudges originating from relinkify or during keyboard animation
            if !context.coordinator.isRelinkifying && !context.coordinator.isKeyboardAnimating {
                context.coordinator.scrollCaretVisible(uiView)
            }
        }

        // Always keep link out of typing attributes during updates
        if uiView.typingAttributes[.link] != nil {
            uiView.typingAttributes[.link] = nil
        }

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
        var didProgrammaticallyAdjustSelection: Bool = false
        private var lastCaretRect: CGRect = .null

        // Cache last linkified source to avoid redundant attribute work
        var lastLinkifiedText: String?

        // Debounced relinkify work item to avoid stale selection races
        private var pendingRelinkify: DispatchWorkItem?

        // Track when we are actively relinkifying to suppress scroll nudges
        var isRelinkifying: Bool = false

        // Throttle caretRect publishing
        private var caretPublishWork: DispatchWorkItem?
        private var pendingCaretRect: CGRect?

        // Keyboard animation tracking
        private(set) var isKeyboardAnimating: Bool = false
        private var keyboardObs: [NSObjectProtocol] = []
        private var deferredSwiftUIUpdates: [() -> Void] = []

        init(parent: CursorTextView) { self.parent = parent }

        func startKeyboardTracking() {
            let nc = NotificationCenter.default
            let willChange = nc.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] notification in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.handleKeyboard(note: notification, starting: true)
                }
            }
            let didChange = nc.addObserver(forName: UIResponder.keyboardDidChangeFrameNotification, object: nil, queue: .main) { [weak self] notification in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.handleKeyboard(note: notification, starting: false)
                }
            }
            let willHide = nc.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] notification in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.handleKeyboard(note: notification, starting: true)
                }
            }
            let didHide = nc.addObserver(forName: UIResponder.keyboardDidHideNotification, object: nil, queue: .main) { [weak self] notification in
                guard let self else { return }
                DispatchQueue.main.async {
                    self.handleKeyboard(note: notification, starting: false)
                }
            }
            keyboardObs = [willChange, didChange, willHide, didHide]
        }

        deinit {
            keyboardObs.forEach { NotificationCenter.default.removeObserver($0) }
        }

        private func handleKeyboard(note: Notification, starting: Bool) {
            if starting {
                isKeyboardAnimating = true
            } else {
                // Delay clearing by one runloop to let UIKit finish internal tracking
                DispatchQueue.main.async {
                    self.isKeyboardAnimating = false
                    // Run any deferred SwiftUI-driven updates now
                    let jobs = self.deferredSwiftUIUpdates
                    self.deferredSwiftUIUpdates.removeAll()
                    for job in jobs { job() }
                }
            }
        }

        func deferSwiftUIUpdate(_ block: @escaping () -> Void) {
            deferredSwiftUIUpdates.append(block)
        }

        // Clamp helper to keep selection within bounds of a given string length
        func clampSelection(_ range: NSRange, forLength length: Int) -> NSRange {
            let maxLoc = max(0, length)
            let loc = min(max(range.location, 0), maxLoc)
            let maxLen = max(0, maxLoc - loc)
            let len = min(max(range.length, 0), maxLen)
            return NSRange(location: loc, length: len)
        }

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

            // Debounced re-linkify to coalesce rapid typing and avoid stale selection
            if let linkify = parent.linkify {
                lastLinkifiedText = newText
                // Cancel any pending work
                pendingRelinkify?.cancel()

                // Skip relinkify during marked text (IME/composition) or keyboard animation to avoid caret jumps
                if textView.markedTextRange != nil || isKeyboardAnimating {
                    ensureDynamicTypingAttributes(on: textView)
                    DispatchQueue.main.async {
                        self.parent.onChange?(textView.text)
                    }
                    return
                }

                // If caret is currently inside a link range, delay relinkify to avoid attribute churn under caret
                if isCaretInsideLink(textView) {
                    ensureDynamicTypingAttributes(on: textView)
                    DispatchQueue.main.async {
                        self.parent.onChange?(textView.text)
                    }
                    return
                }

                let work = DispatchWorkItem { [weak self, weak textView] in
                    guard let self, let tv = textView else { return }

                    if tv.markedTextRange != nil || self.isKeyboardAnimating { return }
                    if self.isCaretInsideLink(tv) { return }

                    let currentString = tv.text ?? ""
                    let linked = NSAttributedString(linkify(currentString))
                    let normalized = self.parent.normalizedAttributedString(linked)

                    if !self.linkRangesChanged(between: tv.attributedText, and: normalized) {
                        self.isProgrammaticUpdate = true
                        let bodyFont = self.parent.resolvedUIFont()
                        tv.textColor = .label
                        tv.typingAttributes[.foregroundColor] = UIColor.label
                        tv.font = bodyFont
                        tv.typingAttributes[.font] = bodyFont
                        tv.typingAttributes[.link] = nil
                        let len = (tv.attributedText?.string as NSString?)?.length ?? (tv.text as NSString?)?.length ?? 0
                        let clamped = self.clampSelection(tv.selectedRange, forLength: len)
                        if tv.selectedRange != clamped {
                            tv.selectedRange = clamped
                            self.didProgrammaticallyAdjustSelection = true
                        }
                        self.isProgrammaticUpdate = false
                        self.lastLinkifiedText = currentString
                        return
                    }

                    if tv.attributedText?.string != currentString {
                        if self.isKeyboardAnimating { return }
                        self.isProgrammaticUpdate = true
                        self.isRelinkifying = true
                        let beforeLen = (tv.attributedText?.string as NSString?)?.length ?? (tv.text as NSString?)?.length ?? 0
                        let currentSel = self.clampSelection(tv.selectedRange, forLength: beforeLen)
                        tv.attributedText = normalized
                        tv.textColor = .label
                        tv.typingAttributes[.foregroundColor] = UIColor.label
                        let bodyFont = self.parent.resolvedUIFont()
                        tv.font = bodyFont
                        tv.typingAttributes[.font] = bodyFont
                        tv.typingAttributes[.link] = nil
                        let afterLen = (tv.attributedText?.string as NSString?)?.length ?? 0
                        let clampedSel = self.clampSelection(currentSel, forLength: afterLen)
                        tv.selectedRange = clampedSel
                        self.isProgrammaticUpdate = false
                        self.didProgrammaticallyAdjustSelection = true
                        self.isRelinkifying = false
                        self.lastLinkifiedText = currentString
                    } else {
                        self.isProgrammaticUpdate = true
                        let bodyFont = self.parent.resolvedUIFont()
                        tv.textColor = .label
                        tv.typingAttributes[.foregroundColor] = UIColor.label
                        tv.font = bodyFont
                        tv.typingAttributes[.font] = bodyFont
                        tv.typingAttributes[.link] = nil
                        let len = (tv.attributedText?.string as NSString?)?.length ?? (tv.text as NSString?)?.length ?? 0
                        let clamped = self.clampSelection(tv.selectedRange, forLength: len)
                        if tv.selectedRange != clamped {
                            tv.selectedRange = clamped
                            self.didProgrammaticallyAdjustSelection = true
                        }
                        self.isProgrammaticUpdate = false
                        self.lastLinkifiedText = currentString
                    }
                }
                pendingRelinkify = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
            }

            // Ensure typing attributes stay dynamic and never carry a link
            ensureDynamicTypingAttributes(on: textView)

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
            if textView.typingAttributes[.link] != nil {
                textView.typingAttributes[.link] = nil
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
            if shouldDefer || isKeyboardAnimating {
                pendingCaretRect = rect
                return
            }

            pendingCaretRect = rect
            caretPublishWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                let toSend = self.pendingCaretRect
                self.pendingCaretRect = nil
                let apply: () -> Void = {
                    self.parent.caretRect = toSend
                }
                DispatchQueue.main.async { apply() }
            }
            caretPublishWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: work)
        }

        func scrollCaretVisible(_ textView: UITextView) {
            guard !isKeyboardAnimating else { return }
            let range = textView.selectedRange
            if range.location != NSNotFound {
                textView.scrollRangeToVisible(range)
            }
        }

        // MARK: - Helpers

        private func ensureDynamicTypingAttributes(on textView: UITextView) {
            if (textView.typingAttributes[.foregroundColor] as? UIColor) != UIColor.label {
                textView.typingAttributes[.foregroundColor] = UIColor.label
            }
            let bodyFont = parent.resolvedUIFont()
            if (textView.typingAttributes[.font] as? UIFont) != bodyFont {
                textView.typingAttributes[.font] = bodyFont
            }
            if textView.typingAttributes[.link] != nil {
                textView.typingAttributes[.link] = nil
            }
        }

        private func isCaretInsideLink(_ textView: UITextView) -> Bool {
            let sel = textView.selectedRange
            guard sel.length == 0, sel.location != NSNotFound else { return false }
            let loc = max(0, min(sel.location, (textView.attributedText?.length ?? 0)))
            guard loc > 0, let attr = textView.attributedText else { return false }
            var effectiveRange = NSRange(location: 0, length: 0)
            let value = attr.attribute(.link, at: loc - 1, effectiveRange: &effectiveRange)
            if value != nil {
                return NSLocationInRange(loc, NSRange(location: effectiveRange.location, length: effectiveRange.length + 1))
            }
            return false
        }

        // Compare link ranges between two attributed strings; return true if they differ
        func linkRangesChanged(between a: NSAttributedString?, and b: NSAttributedString?) -> Bool {
            let ra = linkRanges(in: a)
            let rb = linkRanges(in: b)
            guard ra.count == rb.count else { return true }
            for (la, lb) in zip(ra, rb) {
                if la.0 != lb.0 { return true }
                if la.1.location != lb.1.location || la.1.length != lb.1.length { return true }
            }
            return false
        }

        private func linkRanges(in s: NSAttributedString?) -> [(AnyHashable, NSRange)] {
            guard let s else { return [] }
            var result: [(AnyHashable, NSRange)] = []
            s.enumerateAttribute(.link, in: NSRange(location: 0, length: s.length), options: []) { value, range, _ in
                if let v = value {
                    if let url = v as? URL {
                        result.append((AnyHashable(url.absoluteString), range))
                    } else if let str = v as? String {
                        result.append((AnyHashable(str), range))
                    } else {
                        result.append((AnyHashable("\(v)"), range))
                    }
                }
            }
            result.sort { $0.1.location < $1.1.location || ($0.1.location == $1.1.location && $0.1.length < $1.1.length) }
            return result
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
                    return false
                }
            }
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
#endif
