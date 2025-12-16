import SwiftUI
import SwiftData

/// Reusable row used by both compact and sidebar journal lists.
struct JournalListRow: View {
    let entry: JournalEntry
    let selectedTags: Set<String>
    let isPinned: Bool
    let onTagTapped: (String) -> Void

    // Optional iPad selection highlighting (removed per request)
    var showPadSelectionBackground: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundStyle(.yellow)
                        .imageScale(.small)
                }
                Text(entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : entry.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            if !entry.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(entry.tags.prefix(4), id: \.self) { t in
                        let tint = TagColorStore.color(for: t) ?? .accentColor
                        TagChip(text: t, tint: tint, isSelected: selectedTags.contains(t.lowercased())) {
                            onTagTapped(t)
                        }
                    }
                }
            }

            let trimmedBody = entry.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedBody.isEmpty {
                Text(trimmedBody)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2) // two-line preview
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        // Removed the gray selection background fill entirely
    }
}
