import SwiftUI
import SwiftData

struct CompactJournalList: View {
    // Data
    let entries: [JournalEntry]
    let isFiltered: Bool
    let headerCountText: String
    let filteredDescription: String

    // Selection (manual in compact mode)
    @Binding var selection: Set<PersistentIdentifier>
    let selectionMode: Bool

    // Tag filtering UI
    let selectedTags: Set<String>
    let onTagTapped: (String) -> Void
    let onClearFilters: () -> Void

    // Actions provided by parent
    let isPinned: (JournalEntry) -> Bool
    let onTogglePin: (JournalEntry) -> Void
    let onRequestDelete: (JournalEntry) -> Void

    var body: some View {
        List {
            if isFiltered {
                Section {
                    FilterBanner(text: filteredDescription, onClear: onClearFilters)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                }
            }

            Section {
                ForEach(entries) { entry in
                    if selectionMode {
                        // Custom selection UI
                        HStack(spacing: 10) {
                            let id = entry.persistentModelID
                            let isSelected = selection.contains(id)

                            Button {
                                if isSelected { selection.remove(id) } else { selection.insert(id) }
                            } label: {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)

                            JournalListRow(
                                entry: entry,
                                selectedTags: selectedTags,
                                isPinned: isPinned(entry),
                                onTagTapped: onTagTapped
                            )
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let id = entry.persistentModelID
                            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
                    } else {
                        NavigationLink(destination: JournalDetailView(entry: entry)) {
                            JournalListRow(
                                entry: entry,
                                selectedTags: selectedTags,
                                isPinned: isPinned(entry),
                                onTagTapped: onTagTapped
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 2, leading: 12, bottom: 2, trailing: 12))
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
                    }
                }
            } header: {
                Text(headerCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        // Force a clean rebuild when toggling selection mode
        .id(selectionMode)
    }
}
