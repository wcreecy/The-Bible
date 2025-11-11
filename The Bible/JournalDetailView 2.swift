import SwiftUI
import SwiftData

struct JournalDetailView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.horizontalSizeClass) private var hSize
    var entry: JournalEntry

    @State private var showEditSheet: Bool = false
    @State private var draftTitle: String = ""
    @State private var draftBody: String = ""
    @State private var draftTagsText: String = ""

    @State private var previewRef: ScriptureRef? = nil
    @State private var previewContent: (title: String, verses: [Verse])? = nil
    @State private var showPreview: Bool = false

    private var linkedDraft: AttributedString { BibleReferenceLinker.linkify(draftBody) }
    private var linkedBody: AttributedString { BibleReferenceLinker.linkify(entry.body) }
    // Overlay that renders only the linked portions (so we can show inline smart links while typing)
    private var linkOverlayDraft: AttributedString {
        var s = linkedDraft
        // Make everything transparent first
        s.foregroundColor = .clear
        // Re-color and underline only link ranges
        for run in s.runs {
            if run.link != nil {
                s[run.range].foregroundColor = .blue
                s[run.range].underlineStyle = .single
            }
        }
        return s
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Title + metadata
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.title.isEmpty ? "Untitled" : entry.title)
                        .font(.title).bold()
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        if let ref = entry.verseRef {
                            Label(ref.display, systemImage: "bookmark")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if entry.isFavorite {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                                .accessibilityLabel("Favorited")
                        }
                        if entry.isPinned {
                            Image(systemName: "pin.fill")
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Pinned")
                        }
                    }
                }

                if !entry.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags").font(.caption).foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(entry.tags, id: \.self) { t in
                                    Text(t)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                                        .overlay(Capsule().stroke(Color.accentColor.opacity(0.35), lineWidth: 1))
                                }
                            }
                        }
                    }
                }

                // Body
                if entry.body.isEmpty {
                    Text("No content")
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(linkedBody)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                            .textSelection(.enabled)
                            .environment(\._openURL, OpenURLAction { url in
                                if let ref = BibleReferenceLinker.parse(url: url), let content = BibleReferenceLinker.loadVerses(for: ref) {
                                    previewRef = ref
                                    previewContent = content
                                    withAnimation(.spring()) { showPreview = true }
                                    return .handled
                                }
                                return .systemAction
                            })

                        if hSize == .regular, showPreview, let content = previewContent {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Text(content.title)
                                        .font(.headline)
                                    Spacer()
                                    Button(action: {
                                        let verseLines = content.verses.map { "\($0.number). \($0.text)" }.joined(separator: "\n")
                                        let copyText = content.title + "\n" + verseLines
                                        UIPasteboard.general.string = copyText
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundStyle(.blue)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Copy scripture")

                                    Button(action: { withAnimation(.easeOut) { showPreview = false } }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                ForEach(content.verses, id: \.number) { v in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(v.text)
                                            .font(.body)
                                        Text("\(previewRef?.bookName ?? "") \(previewRef?.chapter ?? 0):\(v.number)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if v.number != content.verses.last?.number { Divider().padding(.vertical, 4) }
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                            )
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }

                Divider()
                // Dates
                VStack(alignment: .leading, spacing: 4) {
                    Text("Created: \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Updated: \(entry.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .navigationTitle("Entry")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    // Seed drafts from current entry and present editor
                    draftTitle = entry.title
                    draftBody = entry.body
                    draftTagsText = entry.tags.joined(separator: ", ")
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                }
                Button {
                    entry.isFavorite.toggle()
                    entry.updatedAt = Date()
                    try? ctx.save()
                } label: {
                    Image(systemName: entry.isFavorite ? "heart.fill" : "heart")
                }
                Button {
                    entry.isPinned.toggle()
                    entry.updatedAt = Date()
                    try? ctx.save()
                } label: {
                    Image(systemName: entry.isPinned ? "pin.fill" : "pin")
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { hSize != .regular && showEditSheet },
                set: { newValue in if hSize != .regular { showEditSheet = newValue } }
            )
        ) {
            NavigationStack { editContentCompact }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { hSize == .regular && showEditSheet },
                set: { newValue in if hSize == .regular { showEditSheet = newValue } }
            )
        ) {
            NavigationStack { editContentRegular }
        }
    }

    @ViewBuilder
    private var editContentCompact: some View {
        Form {
            Section {
                TextField("Title", text: $draftTitle)
            }
            Section("Tags") {
                TextField("sermon notes, prayer, study…", text: $draftTagsText)
                    .textInputAutocapitalization(.never)
            }
            Section("Body") {
                ZStack(alignment: .topLeading) {
                    if draftBody.isEmpty {
                        Text("Write your thoughts here…")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                    // Inline smart link overlay
                    Text(linkOverlayDraft)
                        .font(.body)
                        .frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                    TextEditor(text: $draftBody)
                        .frame(minHeight: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Live Preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(linkedDraft)
                    .frame(minHeight: 60, alignment: .topLeading)
                    .textSelection(.enabled)
                    .environment(\._openURL, OpenURLAction { url in
                        if let ref = BibleReferenceLinker.parse(url: url), let content = BibleReferenceLinker.loadVerses(for: ref) {
                            previewRef = ref
                            previewContent = content
                            withAnimation(.spring()) { showPreview = true }
                            return .handled
                        }
                        return .systemAction
                    })

                if showPreview, let content = previewContent {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(content.title)
                                .font(.headline)
                            Spacer()
                            Button(action: {
                                let verseLines = content.verses.map { "\($0.number). \($0.text)" }.joined(separator: "\n")
                                let copyText = content.title + "\n" + verseLines
                                UIPasteboard.general.string = copyText
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Copy scripture")

                            Button(action: { withAnimation(.easeOut) { showPreview = false } }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(content.verses, id: \.number) { v in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(v.text)
                                    .font(.body)
                                Text("\(previewRef?.bookName ?? "") \(previewRef?.chapter ?? 0):\(v.number)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if v.number != content.verses.last?.number { Divider().padding(.vertical, 4) }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.top, 8)
        }
        .navigationTitle("Edit Entry")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { showEditSheet = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    entry.title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    entry.body = draftBody.trimmingCharacters(in: .whitespacesAndNewlines)
                    let tags = draftTagsText
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    entry.tags = tags
                    entry.updatedAt = Date()
                    try? ctx.save()
                    showEditSheet = false
                } label: {
                    Text("Save").bold()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var editContentRegular: some View {
        HStack(spacing: 0) {
            // Left: Editor
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Title", text: $draftTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("sermon notes, prayer, study…", text: $draftTagsText)
                        .textInputAutocapitalization(.never)
                        .textFieldStyle(.roundedBorder)
                    ZStack(alignment: .topLeading) {
                        if draftBody.isEmpty {
                            Text("Write your thoughts here…")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                        // Inline smart link overlay
                        Text(linkOverlayDraft)
                            .font(.body)
                            .frame(maxWidth: .infinity, minHeight: 400, alignment: .topLeading)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                        TextEditor(text: $draftBody)
                            .frame(minHeight: 400)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                            )
                    }
                }
                .padding(20)
            }
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            // Right: Live Preview
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(draftTitle.isEmpty ? "Untitled" : draftTitle)
                        .font(.title3).bold()
                    Text("Live Preview")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(linkedDraft)
                        .frame(minHeight: 60, alignment: .topLeading)
                        .textSelection(.enabled)
                        .environment(\._openURL, OpenURLAction { url in
                            if let ref = BibleReferenceLinker.parse(url: url), let content = BibleReferenceLinker.loadVerses(for: ref) {
                                previewRef = ref
                                previewContent = content
                                withAnimation(.spring()) { showPreview = true }
                                return .handled
                            }
                            return .systemAction
                        })

                    if showPreview, let content = previewContent {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Text(content.title)
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    let verseLines = content.verses.map { "\($0.number). \($0.text)" }.joined(separator: "\n")
                                    let copyText = content.title + "\n" + verseLines
                                    UIPasteboard.general.string = copyText
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Copy scripture")

                                Button(action: { withAnimation(.easeOut) { showPreview = false } }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            ForEach(content.verses, id: \.number) { v in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(v.text)
                                        .font(.body)
                                    Text("\(previewRef?.bookName ?? "") \(previewRef?.chapter ?? 0):\(v.number)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if v.number != content.verses.last?.number { Divider().padding(.vertical, 4) }
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(20)
            }
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            // Far Right: Tag Colors
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tag Colors")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if parsedDraftTags.isEmpty {
                        Text("Add comma-separated tags to pick colors.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(parsedDraftTags, id: \.self) { t in
                            HStack(spacing: 8) {
                                let color = TagColorStore.color(for: t) ?? .accentColor
                                Text(t)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(color.opacity(0.15), in: Capsule())
                                    .overlay(
                                        Capsule().stroke(color.opacity(0.4), lineWidth: 1)
                                    )
                                    .foregroundStyle(color)
                                ColorPicker("", selection: colorBinding(for: t), supportsOpacity: false)
                                    .labelsHidden()
                            }
                        }
                    }
                }
                .padding(20)
            }
            .frame(minWidth: 280, idealWidth: 300, maxWidth: 340, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationTitle("Edit Entry")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { showEditSheet = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    entry.title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    entry.body = draftBody.trimmingCharacters(in: .whitespacesAndNewlines)
                    let tags = draftTagsText
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    entry.tags = tags
                    entry.updatedAt = Date()
                    try? ctx.save()
                    showEditSheet = false
                } label: {
                    Text("Save").bold()
                }
            }
        }
    }

    private var parsedDraftTags: [String] {
        draftTagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func colorBinding(for tag: String) -> Binding<Color> {
        let initial = TagColorStore.color(for: tag) ?? .accentColor
        var current = initial
        return Binding<Color>(
            get: { TagColorStore.color(for: tag) ?? current },
            set: { newValue in TagColorStore.setColor(newValue, for: tag) }
        )
    }
}

#Preview {
    let entry = JournalEntry(
        title: "Morning Devotional",
        body: "Today I reflected on faith and patience. The scripture reminded me to be steadfast.",
        verseRef: VerseRef(book: "James", chapter: 1, verse: 3, translation: "ESV"),
        tags: ["devotional", "prayer"],
        isPinned: true,
        isFavorite: true
    )
    NavigationStack { JournalDetailView(entry: entry) }
}

