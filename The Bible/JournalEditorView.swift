import SwiftUI
import SwiftData
import UIKit

struct JournalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(\.horizontalSizeClass) private var hSize

    // If invoked from a verse, we’ll seed the title smartly
    let verseRef: VerseRef?
    let showTagColors: Bool

    @State private var title: String = ""
    @State private var content: String = ""      // <-- renamed from `body`
    @State private var tagsText: String = ""     // comma-separated

    @State private var previewRef: ScriptureRef? = nil
    @State private var previewContent: (title: String, verses: [Verse])? = nil
    @State private var showPreview: Bool = false

    private var linkedContent: AttributedString { BibleReferenceLinker.linkify(content) }

    private var parsedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func colorBinding(for tag: String) -> Binding<Color> {
        let initial = TagColorStore.color(for: tag) ?? .accentColor
        var current = initial
        return Binding<Color>(
            get: { TagColorStore.color(for: tag) ?? current },
            set: { newValue in
                TagColorStore.setColor(newValue, for: tag)
            }
        )
    }

    @State private var showSaveError = false
    @State private var saveErrorMessage: String = ""
    @State private var showCopyToast: Bool = false

    init(verseRef: VerseRef?, initialBody: String? = nil, showTagColors: Bool = false) {
        self.verseRef = verseRef
        self.showTagColors = showTagColors
        _title = State(initialValue: verseRef?.display ?? "")
        _content = State(initialValue: initialBody ?? "")
    }

    var body: some View {
        NavigationStack {
            Group {
                if hSize == .regular {
                    // iPad split editor: left editor, right live preview
                    HStack(spacing: 0) {
                        // Left: Editor fields
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                TextField("Title", text: $title)
                                    .foregroundStyle(.primary)
                                    .textFieldStyle(.roundedBorder)
                                TextField("sermon notes, prayer, study…", text: $tagsText)
                                    .textInputAutocapitalization(.never)
                                    .foregroundStyle(.primary)
                                    .textFieldStyle(.roundedBorder)
                                if !parsedTags.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(parsedTags, id: \.self) { t in
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
                                ZStack(alignment: .topLeading) {
                                    if content.isEmpty {
                                        Text("Write your thoughts here…")
                                            .foregroundStyle(.secondary)
                                            .padding(.top, 8)
                                            .padding(.leading, 5)
                                    }
                                    TextEditor(text: $content)
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

                        // Right: Live Preview with smart links
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(title.isEmpty ? "Untitled" : title)
                                    .font(.title3).bold()
                                Text("Live Preview")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(linkedContent)
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
                                                // Build formatted scripture text and copy to clipboard
                                                let verseLines = content.verses.map { "\($0.number). \($0.text)" }.joined(separator: "\n")
                                                let copyText = content.title + "\n" + verseLines
                                                UIPasteboard.general.string = copyText
                                                withAnimation(.spring()) { showCopyToast = true }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                    withAnimation(.easeOut) { showCopyToast = false }
                                                }
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

                        if showTagColors {
                            Divider()

                            // Far Right: Tag Colors
                            ScrollView {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Tag Colors")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if parsedTags.isEmpty {
                                        Text("Add comma-separated tags to pick colors.")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        ForEach(parsedTags, id: \.self) { t in
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
                    }
                } else {
                    // Compact: original form layout
                    Form {
                        Section {
                            TextField("Title", text: $title)
                                .foregroundStyle(.primary)
                            if let ref = verseRef {
                                LabeledContent("Linked Verse", value: ref.display)
                            }
                        }
                        Section("Tags") {
                            TextField("sermon notes, prayer, study…", text: $tagsText)
                                .textInputAutocapitalization(.never)
                                .foregroundStyle(.primary)
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(parsedTags, id: \.self) { t in
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
                        Section("Body") {
                            ZStack(alignment: .topLeading) {
                                if content.isEmpty {
                                    Text("Write your thoughts here…")
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
                                }
                                TextEditor(text: $content)
                                    .frame(minHeight: 200)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                                    )
                            }
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Live Preview")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                // Linkified rich text preview that updates while typing
                                Text(linkedContent)
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
                                                withAnimation(.spring()) { showCopyToast = true }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                                    withAnimation(.easeOut) { showCopyToast = false }
                                                }
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
                    }
                }
            }
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: save) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .bold()
                }
            }
            .alert("Couldn’t Save Entry", isPresented: $showSaveError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveErrorMessage)
            }
            .appToast(isPresented: $showCopyToast, symbol: "doc.on.doc", text: "Copied to Clipboard", tint: .blue)
        }
    }

    private func save() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let entry = JournalEntry(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: content.trimmingCharacters(in: .whitespacesAndNewlines),
            verseRef: verseRef,
            tags: tags,
            isPinned: false,
            isFavorite: false
        )
        // Ensure timestamps are current if your model uses them
        entry.updatedAt = Date()
        ctx.insert(entry)
        do {
            try ctx.save()
            // Notify listeners (e.g., JournalTabView) that a new entry was created
            NotificationCenter.default.post(name: Notification.Name("JournalEntryCreated"), object: nil, userInfo: ["id": entry.id.uuidString])
            dismiss()
        } catch {
            saveErrorMessage = error.localizedDescription
            showSaveError = true
        }
    }
}

