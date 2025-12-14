import SwiftUI
import SwiftData

/// Reusable row used by both compact and sidebar journal lists.
struct JournalListRow: View {
    let entry: JournalEntry
    let selectedTags: Set<String>
    let isPinned: Bool
    let onTagTapped: (String) -> Void

    // Optional iPad selection highlighting
    var showPadSelectionBackground: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundStyle(.yellow)
                            .imageScale(.small)
                    }
                    Text(entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : entry.title)
                }
                .font(.subheadline)

                if !entry.tags.isEmpty {
                    HStack(spacing: 3) {
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
                        .lineLimit(1)
                        .multilineTextAlignment(.leading)
                }

                if let ref = entry.verseRef {
                    Text(ref.display)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(
                showPadSelectionBackground
                ? AnyView(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.tertiarySystemFill))
                )
                : AnyView(EmptyView())
            )
        }
        .padding(.vertical, 1)
    }
}
