// TagManagerView.swift
import SwiftUI
import SwiftData

struct TagManagerView: View {
    @Environment(\.modelContext) private var ctx
    @Query private var entries: [JournalEntry]

    // Local editing state
    @State private var items: [TagItem] = []
    @State private var search: String = ""

    // Add-new UI state
    @State private var showAddRow: Bool = false
    @State private var newNameText: String = ""   // User-facing name (we’ll normalize this to a key internally)
    @State private var newColor: Color = .accentColor

    struct TagItem: Identifiable, Hashable {
        var id: String { key }            // normalized key (lowercased)
        var key: String                   // normalized key (internal)
        var displayName: String           // preferred display
        var color: Color                  // current color
    }

    private func titleCase(_ s: String) -> String {
        s.split(separator: " ").map { part in
            let t = String(part)
            guard let f = t.first else { return t }
            return String(f).uppercased() + t.dropFirst().lowercased()
        }.joined(separator: " ")
    }

    private func loadFromEntries() {
        // Aggregate unique normalized tags
        var set: Set<String> = []
        for e in entries {
            for raw in e.tags {
                let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !key.isEmpty { set.insert(key) }
            }
        }
        let sorted = Array(set).sorted()
        items = sorted.map { key in
            let display = TagDisplayNameStore.displayName(for: key) ?? titleCase(key)
            let color = TagColorStore.color(for: key) ?? .accentColor
            return TagItem(key: key, displayName: display, color: color)
        }
    }

    private func saveColor(for key: String, color: Color) {
        TagColorStore.setColor(color, for: key)
    }

    private func saveDisplayName(for key: String, name: String) {
        TagDisplayNameStore.setDisplayName(name, for: key)
    }

    // Internal utility remains available if needed programmatically (not exposed in UI)
    private func renameCanonicalKey(oldKey: String, newKeyRaw: String) {
        let newKey = newKeyRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !newKey.isEmpty, newKey != oldKey else { return }

        // Update all entries
        for e in entries {
            var t = e.tags
            var changed = false
            for i in t.indices {
                if t[i].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == oldKey {
                    t[i] = newKey
                    changed = true
                }
            }
            if changed {
                // Normalize and dedupe
                let normalized = Array(Set(t.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })).sorted()
                e.tags = normalized
                e.updatedAt = Date()
            }
        }
        try? ctx.save()

        // Migrate color and display name stores
        if let color = TagColorStore.color(for: oldKey) {
            TagColorStore.setColor(nil, for: oldKey)
            TagColorStore.setColor(color, for: newKey)
        }
        TagDisplayNameStore.migrateKey(from: oldKey, to: newKey)

        // Reload list
        loadFromEntries()
    }

    private func deleteTagEverywhere(_ key: String) {
        for e in entries {
            let filtered = e.tags.filter { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != key }
            if filtered.count != e.tags.count {
                e.tags = filtered
                e.updatedAt = Date()
            }
        }
        try? ctx.save()
        TagColorStore.removeColor(for: key)
        TagDisplayNameStore.removeDisplayName(for: key)
        loadFromEntries()
    }

    // Add using a single user-facing name (we compute the internal normalized key from it)
    private func addTag(userFacingName rawName: String, color: Color?) {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = trimmed.lowercased()
        guard !key.isEmpty else { return }

        // If tag already exists, just update display/color and refresh
        if items.contains(where: { $0.key == key }) {
            saveDisplayName(for: key, name: trimmed)
            if let color {
                saveColor(for: key, color: color)
            }
            loadFromEntries()
            return
        }

        // Find most recently updated entry, or create a minimal one if none exist.
        let targetEntry: JournalEntry = {
            if let newest = entries.sorted(by: { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }).first {
                return newest
            } else {
                let e = JournalEntry()
                e.title = ""
                e.body = ""
                e.tags = []
                e.updatedAt = Date()
                ctx.insert(e)
                return e
            }
        }()

        // Attach tag to the target entry, normalizing/deduping
        var newTags = targetEntry.tags
        newTags.append(key)
        let normalized = Array(Set(newTags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })).sorted()
        targetEntry.tags = normalized
        targetEntry.updatedAt = Date()
        try? ctx.save()

        // Save preferred display and optional color
        saveDisplayName(for: key, name: trimmed)
        if let color {
            saveColor(for: key, color: color)
        }

        // Reset add UI and refresh
        newNameText = ""
        newColor = .accentColor
        withAnimation(.spring()) {
            showAddRow = false
        }
        loadFromEntries()
    }

    private var filteredItems: [TagItem] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        return items.filter { $0.key.localizedCaseInsensitiveContains(q) || $0.displayName.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        List {
            // Inline "Add new tag" row
            if showAddRow {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add New Tag")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            TextField("Tag name", text: $newNameText)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled(false)

                            ColorPicker("", selection: $newColor, supportsOpacity: false)
                                .labelsHidden()
                        }

                        HStack(spacing: 8) {
                            Button("Cancel") {
                                withAnimation(.spring()) { showAddRow = false }
                            }
                            .buttonStyle(.bordered)

                            Spacer()

                            Button("Add") {
                                addTag(userFacingName: newNameText, color: newColor)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newNameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            if items.isEmpty {
                ContentUnavailableView("No tags yet", systemImage: "tag")
            } else {
                ForEach(filteredItems) { item in
                    TagRow(
                        item: item,
                        onNameChange: { newName in
                            // Update preferred display; keep internal key stable
                            saveDisplayName(for: item.key, name: newName)
                            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                                items[idx].displayName = newName
                            }
                        },
                        onColorChange: { newColor in
                            saveColor(for: item.key, color: newColor)
                            if let idx = items.firstIndex(where: { $0.id == item.id }) {
                                items[idx].color = newColor
                            }
                        },
                        onDelete: {
                            deleteTagEverywhere(item.key)
                        }
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteTagEverywhere(item.key)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("Tag Manager")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring()) {
                        showAddRow.toggle()
                        if showAddRow {
                            newNameText = ""
                            newColor = .accentColor
                        }
                    }
                } label: {
                    Label(showAddRow ? "Close" : "Add", systemImage: showAddRow ? "xmark" : "plus")
                }
            }
        }
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search tags")
        .onAppear { loadFromEntries() }
        // Live refresh when KVS merges arrive from other devices
        .onReceive(NotificationCenter.default.publisher(for: .init("TagDisplayNameMapDidChange"))) { _ in
            loadFromEntries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("TagColorMapDidChange"))) { _ in
            loadFromEntries()
        }
    }
}

private struct TagRow: View {
    let item: TagManagerView.TagItem
    let onNameChange: (String) -> Void
    let onColorChange: (Color) -> Void
    let onDelete: () -> Void

    @State private var name: String

    init(item: TagManagerView.TagItem,
         onNameChange: @escaping (String) -> Void,
         onColorChange: @escaping (Color) -> Void,
         onDelete: @escaping () -> Void) {
        self.item = item
        self.onNameChange = onNameChange
        self.onColorChange = onColorChange
        self.onDelete = onDelete
        _name = State(initialValue: item.displayName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                // Color chip
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(item.color.opacity(0.2))
                    .frame(width: 24, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(item.color.opacity(0.6), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    // Display name editor (single visible field)
                    TextField("Tag name", text: Binding(
                        get: { name },
                        set: { newVal in
                            name = newVal
                            onNameChange(newVal)
                        }
                    ))
                    .font(.headline)
                }

                Spacer(minLength: 8)

                // Color picker
                ColorPicker("", selection: Binding(
                    get: { item.color },
                    set: { onColorChange($0) }
                ), supportsOpacity: false)
                .labelsHidden()

                Menu {
                    Button("Remove from all entries", role: .destructive) { onDelete() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }
}
