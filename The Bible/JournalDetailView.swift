import SwiftUI
import SwiftData

struct JournalDetailView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    // Use @Bindable when editing a SwiftData model inside a View
    var entry: JournalEntry

    @State private var editing = false
    @State private var editedTitle = ""
    @State private var editedBody = ""
    @State private var editedTagsText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let ref = entry.verseRef {
                    Text(ref.display)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                }

                if !entry.body.isEmpty {
                    Text(entry.body)
                        .font(.body)
                        .textSelection(.enabled)
                }

                if !entry.tags.isEmpty {
                    // ✅ Fix: add the argument label `tags:`
                    WrapTags(tags: entry.tags)
                        .padding(.top, 8)
                }
                
                Divider().padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                        Text("Created ") + Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened)).bold()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                        Text("Last edited ") + Text(entry.updatedAt.formatted(date: .abbreviated, time: .shortened)).bold()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(entry.title.isEmpty ? "Untitled" : entry.title)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    entry.isFavorite.toggle(); entry.updatedAt = Date()
                    try? ctx.save()
                } label: {
                    Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                }

                Button {
                    entry.isPinned.toggle(); entry.updatedAt = Date()
                    try? ctx.save()
                } label: {
                    Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                }

                Menu {
                    Button(role: .destructive) {
                        entry.isArchived = true
                        entry.updatedAt = Date()
                        try? ctx.save()
                        dismiss()
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }

                    Button {
                        editing = true
                        editedTitle = entry.title
                        editedBody = entry.body
                        editedTagsText = entry.tags.joined(separator: ", ")
                    } label: {
                        Label("Edit", systemImage: "square.and.pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $editing) {
            NavigationStack {
                Form {
                    TextField("Title", text: $editedTitle)
                    TextEditor(text: $editedBody)
                        .frame(minHeight: 200)
                    Section("Tags") {
                        TextField("faith, prayer, study…", text: $editedTagsText)
                            .textInputAutocapitalization(.never)
                    }
                }
                .navigationTitle("Edit Entry")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { editing = false }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            entry.title = editedTitle
                            entry.body = editedBody
                            let tags = editedTagsText
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                            entry.tags = tags
                            entry.updatedAt = Date()
                            try? ctx.save()
                            editing = false
                        }.bold()
                    }
                }
            }
        }
    }
}

// Simple tag chips with deterministic colors
private struct WrapTags: View {
    let tags: [String]

    private let tagPalette: [Color] = [
        .blue, .green, .orange, .pink, .purple, .teal, .indigo, .red, .mint, .brown
    ]
    private func tagColor(for tag: String) -> Color {
        let cleaned = tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleaned.isEmpty else { return .gray }
        var hasher = Hasher(); hasher.combine(cleaned)
        let idx = abs(hasher.finalize()) % max(1, tagPalette.count)
        return tagPalette[idx]
    }

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { t in
                let tint = tagColor(for: t)
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
        }
    }
}

// Minimal flexible layout for tags
private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        var width = CGFloat.zero
        var rows: [CGFloat] = [0]

        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                content
                    .alignmentGuide(.leading) { d in
                        if (width + d.width) > geo.size.width {
                            width = 0
                            rows.append(0)
                        }
                        let result = width
                        width += d.width + spacing
                        return -result
                    }
                    .alignmentGuide(.top) { d in
                        let result = rows.reduce(0, +)
                        rows[rows.count - 1] = max(rows.last ?? 0, d.height + spacing)
                        return -result
                    }
            }
        }
        .frame(minHeight: 24)
    }
}
