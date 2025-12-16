import SwiftUI
import Foundation

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
