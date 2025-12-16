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

    // Use a Color (not ShapeStyle) for separator tint to satisfy older listRowSeparatorTint signatures.
    private var separatorTint: Color {
        #if os(iOS) || os(tvOS) || os(visionOS)
        return Color(.quaternaryLabel)
        #elseif os(macOS)
        return Color(NSColor.quaternaryLabelColor)
        #else
        return .gray.opacity(0.35)
        #endif
    }

    // Card-like background used inside each row for a more polished look
    @ViewBuilder
    private func rowCardBackground(selected: Bool) -> some View {
        let base = RoundedRectangle(cornerRadius: 12, style: .continuous)
        // Use very light selection fill to keep text readable in light mode
        let fillColor: Color = selected ? Color.accentColor.opacity(0.08) : Color(.secondarySystemBackground)
        let strokeColor: Color = selected ? Color.accentColor.opacity(0.35) : Color.black.opacity(0.06)
        base
            .fill(fillColor)
            .overlay(base.stroke(strokeColor, lineWidth: 1))
            .shadow(color: .black.opacity(selected ? 0.05 : 0.04), radius: selected ? 5 : 3, x: 0, y: selected ? 3 : 2)
    }

    // Reduce default section spacing so the top separator isn’t visually jarring
    private var listSectionSpacing: CGFloat { 4 }

    var body: some View {
        List(selection: $selection) {
            // Compact filter chips row
            if !selectedTags.isEmpty {
                Section {
                    FilterChipsRow(
                        selectedTags: Array(selectedTags).sorted(),
                        onToggleTag: onToggleTag
                    )
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 4, trailing: 12))
                .listRowSeparator(.hidden)
            }

            Section {
                ForEach(entries) { entry in
                    EntryRow(
                        entry: entry,
                        selectionMode: selectionMode,
                        selectedTags: selectedTags,
                        isPinned: isPinned(entry),
                        onToggleTag: onToggleTag,
                        onTapEntry: onTapEntry,
                        onTogglePin: onTogglePin,
                        onRequestDelete: onRequestDelete,
                        isEntryCurrentlySelected: isEntryCurrentlySelected(entry),
                        rowBackground: { selected in
                            rowCardBackground(selected: selected)
                        }
                    )
                    .tag(entry.persistentModelID)
                }
            } header: {
                Text(headerCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(selectionMode ? .active : .inactive))
        .listSectionSpacingCompat(listSectionSpacing)
        .tint(.accentColor)
    }
}

// MARK: - Subviews to reduce type-checker complexity

private struct FilterChipsRow: View {
    let selectedTags: [String]
    let onToggleTag: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedTags, id: \.self) { t in
                    HStack(spacing: 6) {
                        Text(t)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.12))
                            )
                            .overlay(
                                Capsule().stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                            )
                        Button(action: { onToggleTag(t) }) {
                            Image(systemName: "xmark.circle.fill")
                                .imageScale(.medium)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                Button("Clear Filters") {
                    for t in selectedTags { onToggleTag(t) }
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(Color(.tertiarySystemFill))
                )
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
    }
}

private struct EntryRow<RowBackground: View>: View {
    let entry: JournalEntry
    let selectionMode: Bool
    let selectedTags: Set<String>
    let isPinned: Bool
    let onToggleTag: (String) -> Void
    let onTapEntry: (JournalEntry) -> Void
    let onTogglePin: (JournalEntry) -> Void
    let onRequestDelete: (JournalEntry) -> Void
    let isEntryCurrentlySelected: Bool
    let rowBackground: (Bool) -> RowBackground

    var body: some View {
        // Determine selection highlight (only in non-selectionMode)
        let showSelectedBackground = !selectionMode && isEntryCurrentlySelected

        Group {
            if selectionMode {
                // Native multi-select row (let system manage selection visuals)
                JournalListRow(
                    entry: entry,
                    selectedTags: selectedTags,
                    isPinned: isPinned,
                    onTagTapped: onToggleTag,
                    showPadSelectionBackground: false
                )
                .contentShape(Rectangle())
            } else {
                // Build the row content and overlay a full-size tap target
                ZStack(alignment: .topLeading) {
                    // The visible row
                    JournalListRow(
                        entry: entry,
                        selectedTags: selectedTags,
                        isPinned: isPinned,
                        onTagTapped: onToggleTag,
                        showPadSelectionBackground: false
                    )
                    // Full-size, transparent tap target so tapping anywhere selects the entry
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTapEntry(entry)
                        }
                }
                // Prevent default button/list selection tint from altering text colors
                .tintCompat(nil)
                .applyNoListRowSelectionEffects()
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
                        Label(isPinned ? "Unpin" : "Pin", systemImage: "pin.fill")
                    }
                    .tint(.yellow)
                }
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
        .listRowBackground(
            rowBackground(showSelectedBackground)
        )
        .listRowSeparator(.hidden)
    }
}

// Helper to consistently disable system list-row selection visuals on iOS versions
private extension View {
    @ViewBuilder
    func applyNoListRowSelectionEffects() -> some View {
        // Simplify: no-op across toolchains to avoid unavailable APIs breaking builds
        self
    }

    // Safely apply listSectionSpacing only when available in the SDK/runtime.
    @ViewBuilder
    func listSectionSpacingCompat(_ spacing: CGFloat) -> some View {
        #if swift(>=5.9)
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) {
            self.listSectionSpacing(spacing)
        } else {
            self
        }
        #else
        self
        #endif
    }

    // Compatibility wrapper for tint to avoid EnvironmentValues.tint access issues.
    @ViewBuilder
    func tintCompat(_ style: Color?) -> some View {
        // When style is nil, we want to effectively "clear" the tint influence.
        // On modern SDKs, .tint(nil) removes the emphasis; otherwise, no-op.
        #if swift(>=5.8)
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
            if let style {
                self.tint(style)
            } else {
                self.tint(nil as Color?)
            }
        } else {
            self
        }
        #else
        self
        #endif
    }
}
