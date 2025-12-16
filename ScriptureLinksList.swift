import SwiftUI
import Foundation

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
