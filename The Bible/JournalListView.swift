import SwiftUI
import SwiftData

struct JournalListView: View {
    @Environment(\.modelContext) private var ctx
    
    private static let activeFilter: Predicate<JournalEntry> = #Predicate { !$0.isArchived }
    
    // Show active (non-archived), newest first, pins on top in UI
    @Query(filter: Self.activeFilter)
    private var entries: [JournalEntry]
    
    @State private var search = ""
    @State private var showComposer = false
    @State private var draftVerse: VerseRef? = nil
    @State private var selectedTag: String? = nil
    
    var body: some View {
        NavigationStack {
            List {
                if let tag = selectedTag {
                    HStack(spacing: 8) {
                        Text(tag)
                            .font(.subheadline).bold()
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .layoutPriority(1)
                        Spacer()
                        Button {
                            selectedTag = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .imageScale(.medium)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear tag filter")
                    }
                    .padding(.vertical, 6)
                }
                
                if !pinned.isEmpty {
                    Section("Pinned (\(pinned.count))") {
                        ForEach(pinned) { entry in
                            NavigationLink(value: entry) { row(entry) }
                                .swipeActions {
                                    favToggle(entry)
                                    Button(role: .destructive) {
                                        delete(entry)
                                    } label: { Label("Delete", systemImage: "trash") }
                                }
                        }
                    }
                }
                
                Section("All (\(allCount))") {
                    ForEach(filtered(orderedEntries)) { entry in
                        NavigationLink(value: entry) { row(entry) }
                            .swipeActions {
                                favToggle(entry)
                                Button(role: .destructive) {
                                    delete(entry)
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
            }
            .navigationTitle("Journal")
            .searchable(text: $search, placement: .navigationBarDrawer, prompt: Text("Search title, body, tags…"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        draftVerse = nil
                        showComposer = true
                    } label: { Label("New Entry", systemImage: "square.and.pencil") }
                }
            }
            .sheet(isPresented: $showComposer) {
                JournalEditorView(verseRef: draftVerse)
            }
            .navigationDestination(for: JournalEntry.self) { entry in
                JournalDetailView(entry: entry)
            }
        }
    }
    
    // MARK: - Helpers
    private func filtered(_ list: [JournalEntry]) -> [JournalEntry] {
        var base = list
        if !search.isEmpty {
            let key = search.lowercased()
            base = base.filter {
                $0.title.lowercased().contains(key)
                || $0.body.lowercased().contains(key)
                || $0.tags.joined(separator: " ").lowercased().contains(key)
                || ($0.verseRef?.display.lowercased().contains(key) ?? false)
            }
        }
        if let tag = selectedTag, !tag.isEmpty {
            base = base.filter { $0.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) }
        }
        return base
    }
    
    private var orderedEntries: [JournalEntry] {
        entries.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
    
    private var allCount: Int { filtered(orderedEntries).count }
    
    private var selectedTagCount: Int {
        guard let tag = selectedTag, !tag.isEmpty else { return 0 }
        return entries.filter { $0.tags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) }.count
    }
    
    private var pinned: [JournalEntry] {
        entries.filter { $0.isPinned }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
    
    // Deterministic color per tag
    private let tagPalette: [Color] = [
        .blue, .green, .orange, .pink, .purple, .teal, .indigo, .red, .mint, .brown
    ]
    private func tagColor(for tag: String) -> Color {
        let cleaned = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return .gray }
        var hasher = Hasher()
        hasher.combine(cleaned)
        let idx = abs(hasher.finalize()) % max(1, tagPalette.count)
        return tagPalette[idx]
    }
    
    @ViewBuilder
    private func row(_ e: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(e.title.isEmpty ? "Untitled" : e.title)
                    .font(.headline)
                if e.isFavorite { Image(systemName: "heart.fill").imageScale(.small) }
                Button(action: {
                    e.isPinned.toggle()
                    e.updatedAt = Date()
                    try? ctx.save()
                }) {
                    Image(systemName: e.isPinned ? "pin.fill" : "pin")
                        .imageScale(.small)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(e.isPinned ? "Unpin" : "Pin")
            }
            // Inline tags as tappable chips to filter
            if !e.tags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(e.tags, id: \.self) { t in
                        let tint = tagColor(for: t)
                        Button(action: { selectedTag = t }) {
                            Text(t)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(tint.opacity(0.15), in: Capsule())
                                .overlay(
                                    Capsule().stroke(tint.opacity(0.4), lineWidth: 1)
                                )
                                .foregroundStyle(tint)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Filter by tag \(t)")
                    }
                }
            }
            if let ref = e.verseRef {
                Text(ref.display)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !e.body.isEmpty {
                Text(e.body)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func favToggle(_ e: JournalEntry) -> some View {
        Button {
            e.isFavorite.toggle()
            e.updatedAt = Date()
            try? ctx.save()
        } label: { Label(e.isFavorite ? "Unfavorite" : "Favorite", systemImage: "heart") }
            .tint(.pink)
    }
    
    private func archive(_ e: JournalEntry) {
        e.isArchived = true
        e.updatedAt = Date()
        try? ctx.save()
    }
    
    private func delete(_ e: JournalEntry) {
        ctx.delete(e)
        try? ctx.save()
    }
}
