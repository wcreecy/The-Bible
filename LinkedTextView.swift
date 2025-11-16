// LinkedTextView.swift
import SwiftUI
import Foundation

// NSCache wrapper for linkified content
private final class LinkifyCache {
    static let shared = LinkifyCache()
    private let cache = NSCache<NSString, NSAttributedString>()

    // Thread-safe, synchronous lookup/insert.
    // We return AttributedString for SwiftUI Text.
    func linkified(_ text: String) -> AttributedString {
        let key = text as NSString
        if let cached = cache.object(forKey: key) {
            return AttributedString(cached)
        }
        let attributed = BibleReferenceLinker.linkify(text)
        cache.setObject(NSAttributedString(attributed), forKey: key)
        return attributed
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}

private extension View {
    @ViewBuilder
    func textSelectable(_ isEnabled: Bool) -> some View {
        if isEnabled {
            self.textSelection(.enabled)
        } else {
            self.textSelection(.disabled)
        }
    }
}

struct LinkedTextView: View {
    let text: String
    var font: Font = .body
    var selectable: Bool = true
    // Called when a scripture link is tapped; return true if you handled it.
    var onOpenScripture: ((ScriptureRef) -> Void)? = nil

    @State private var attributed: AttributedString = AttributedString("")
    @State private var task: Task<Void, Never>? = nil

    var body: some View {
        Text(attributed)
            .font(font)
            .textSelectable(selectable)
            .environment(\._openURL, OpenURLAction { (url: URL) -> OpenURLAction.Result in
                if let ref = BibleReferenceLinker.parse(url: url) {
                    onOpenScripture?(ref)
                    return .handled
                }
                return .systemAction
            })
            .onAppear { scheduleLinkify(for: text) }
            .onChange(of: text) { _, newValue in scheduleLinkify(for: newValue) }
            .onDisappear { task?.cancel() }
    }

    private func scheduleLinkify(for value: String) {
        // Cancel any in-flight work
        task?.cancel()
        // If text is small, the sync path is already fast; we still offload to keep UI smooth.
        task = Task(priority: .userInitiated) {
            // Tiny debounce to coalesce rapid changes (typing)
            try? await Task.sleep(nanoseconds: 120_000_000)
            if Task.isCancelled { return }
            let result = LinkifyCache.shared.linkified(value)
            await MainActor.run {
                self.attributed = result
            }
        }
    }
}
