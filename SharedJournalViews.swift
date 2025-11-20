import SwiftUI
import Foundation
import UIKit

// Shared notifications for the Journal feature
enum JournalNotifications {
    static let openScripturePreview = Notification.Name("OpenScripturePreview")
    static let entryCreated = Notification.Name("JournalEntryCreated")
    static let entryUpdated = Notification.Name("JournalEntryUpdated")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(tags, id: \.self) { t in
                HStack(spacing: 8) {
                    let tint = TagColorStore.color(for: t) ?? .accentColor
                    TagChip(text: t, tint: tint, isSelected: selectedTags.contains(t.lowercased())) {
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

