import SwiftUI
import SwiftData

/// iPad sidebar journal list (multi-select, swipe actions, pinning, delete).
struct SidebarJournalList: View {
    // Data
    let entries: [JournalEntry]
    let headerCountText: String

    // Selection
    @Binding var selection: Set<PersistentIdentifier>
    let selectionMode: Bool

    // Tag filters section
    let selectedTags: Set<String>
    let onToggleTag: (String) -> Void

    // Actions
    let isPinned: (JournalEntry) -> Bool
    let onTogglePin: (JournalEntry) -> Void
    let onRequestDelete: (JournalEntry) -> Void
    let onTapEntry: (JournalEntry) -> Void

    // For iPad selected highlight
    let isEntryCurrentlySelected: (JournalEntry) -> Bool

    var body: some View {
        List(selection: $selection) {
            if !selectedTags.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(selectedTags), id: \.self) { t in
                                HStack(spacing: 6) {
                                    Text(t)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.15), in: Capsule())
                                        .overlay(Capsule().stroke(Color.accentColor.opacity(0.35), lineWidth: 1))
                                    Button(action: { onToggleTag(t) }) {
                                        Image(systemName: "xmark.circle.fill")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            Button("Clear Filters") { // clear all selected tags
                                for t in selectedTags { onToggleTag(t) }
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                ForEach(entries) { entry in
                    if selectionMode {
                        JournalListRow(
                            entry: entry,
                            selectedTags: selectedTags,
                            isPinned: isPinned(entry),
                            onTagTapped: onToggleTag,
                            showPadSelectionBackground: isEntryCurrentlySelected(entry)
                        )
                        .tag(entry.persistentModelID)
                        .listRowInsets(nil)
                    } else {
                        Button {
                            onTapEntry(entry)
                        } label: {
                            JournalListRow(
                                entry: entry,
                                selectedTags: selectedTags,
                                isPinned: isPinned(entry),
                                onTagTapped: onToggleTag,
                                showPadSelectionBackground: isEntryCurrentlySelected(entry)
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onRequestDelete(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                onTogglePin(entry)
                            } label: {
                                Label(isPinned(entry) ? "Unpin" : "Pin", systemImage: "pin.fill")
                            }
                            .tint(.yellow)
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                    }

                    // Removed stray Divider that created an extra blank row per entry.
                }
            } header: {
                Text(headerCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .environment(\.editMode, .constant(selectionMode ? .active : .inactive))
    }
}
