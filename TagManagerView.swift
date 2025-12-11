// TagManagerView.swift
import SwiftUI
import SwiftData

struct TagManagerView: View {
    @Environment(\.modelContext) private var ctx
    @Query private var entries: [JournalEntry]

    // Local editing state
    @State private var items: [TagItem] = []
    @State private var search: String = ""

    struct TagItem: Identifiable, Hashable {
        var id: String { key }            // normalized key (lowercased)
        var key: String                   // normalized key
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

    private var filteredItems: [TagItem] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return items }
        return items.filter { $0.key.localizedCaseInsensitiveContains(q) || $0.displayName.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView("No tags yet", systemImage: "tag")
            } else {
                ForEach(filteredItems) { item in
                    TagRow(
                        item: item,
                        onNameChange: { newName in
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
                        onRenameKey: { newKey in
                            renameCanonicalKey(oldKey: item.key, newKeyRaw: newKey)
                        },
                        onDelete: {
                            deleteTagEverywhere(item.key)
                        }
                    )
                }
            }
        }
        .navigationTitle("Tag Manager")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search tags")
        .onAppear { loadFromEntries() }
    }
}

private struct TagRow: View {
    let item: TagManagerView.TagItem
    let onNameChange: (String) -> Void
    let onColorChange: (Color) -> Void
    let onRenameKey: (String) -> Void
    let onDelete: () -> Void

    @State private var name: String
    @State private var showActions: Bool = false
    @State private var renameKeyText: String = ""

    init(item: TagManagerView.TagItem,
         onNameChange: @escaping (String) -> Void,
         onColorChange: @escaping (Color) -> Void,
         onRenameKey: @escaping (String) -> Void,
         onDelete: @escaping () -> Void) {
        self.item = item
        self.onNameChange = onNameChange
        self.onColorChange = onColorChange
        self.onRenameKey = onRenameKey
        self.onDelete = onDelete
        _name = State(initialValue: item.displayName)
        _renameKeyText = State(initialValue: item.key)
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
                    // Display name editor
                    TextField("Display name", text: Binding(
                        get: { name },
                        set: { newVal in
                            name = newVal
                            onNameChange(newVal)
                        }
                    ))
                    .font(.headline)

                    // Normalized key (read-only)
                    Text(item.key)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                // Color picker
                ColorPicker("", selection: Binding(
                    get: { item.color },
                    set: { onColorChange($0) }
                ), supportsOpacity: false)
                .labelsHidden()

                Menu {
                    Button("Rename canonical key…") { showActions = true }
                    Button("Remove from all entries", role: .destructive) { onDelete() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            if showActions {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rename canonical key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        TextField("New key (lowercased)", text: $renameKeyText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        Button("Apply") {
                            onRenameKey(renameKeyText)
                            showActions = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 6)
    }
}
