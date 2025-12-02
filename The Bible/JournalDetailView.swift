import SwiftUI
import SwiftData
import UIKit

struct JournalDetailView: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.horizontalSizeClass) private var hSize
    @EnvironmentObject private var journalComposer: JournalComposer
    var entry: JournalEntry

    @State private var previewRef: ScriptureRef? = nil
    @State private var previewContent: (title: String, verses: [Verse])? = nil
    @State private var showPreview: Bool = false

    // Cache/debounce linkified body to avoid recomputation each render
    @State private var linkedBody: AttributedString = AttributedString("")
    @State private var linkifyTask: Task<Void, Never>? = nil

    private func computeLinkedBodyDebounced(for text: String) {
        // Cancel any in-flight task
        linkifyTask?.cancel()

        let currentText = text
        linkifyTask = Task { @MainActor in
            // Simple debounce
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }

            // linkify is @MainActor-isolated; call it on the main actor
            let result = BibleReferenceLinker.linkify(currentText)
            self.linkedBody = result
        }
    }

    // Compose share text: title + blank line + body (if present)
    private var shareText: String {
        let titleText = entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : entry.title
        let bodyText = entry.body.trimmingCharacters(in: .whitespacesAndNewlines)
        if bodyText.isEmpty {
            return titleText
        } else {
            return "\(titleText)\n\n\(bodyText)"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                metadataRow()
                tagsSection()
                bodySection()
                Divider()
                datesSection()
            }
            .padding(16)
            // Tap anywhere in the note to edit on iPhone (compact width)
            .contentShape(Rectangle())
            .onTapGesture {
                if hSize != .regular {
                    journalComposer.presentForEditing(entry: entry)
                }
            }
        }
        .navigationTitle(entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : entry.title)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Share button: shares title + body
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }
                // Only show Edit on iPad/regular width; hide on iPhone/compact
                if hSize == .regular {
                    Button("Edit") {
                        journalComposer.presentForEditing(entry: entry)
                    }
                }
            }
        }
        .onAppear {
            computeLinkedBodyDebounced(for: entry.body)
        }
        .onChange(of: entry.body) { _, newValue in
            computeLinkedBodyDebounced(for: newValue)
        }
        .onDisappear {
            linkifyTask?.cancel()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func metadataRow() -> some View {
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

    @ViewBuilder
    private func tagsSection() -> some View {
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
    }

    @ViewBuilder
    private func bodySection() -> some View {
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
                        if let ref = BibleReferenceLinker.parse(url: url),
                           let content = BibleReferenceLinker.loadVerses(for: ref) {
                            previewRef = ref
                            previewContent = content
                            withAnimation(.spring()) { showPreview = true }
                            return .handled
                        }
                        return .systemAction
                    })

                scripturePreviewCard()
            }
        }
    }

    @ViewBuilder
    private func scripturePreviewCard() -> some View {
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

    @ViewBuilder
    private func datesSection() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            let created = entry.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "—"
            let updated = entry.updatedAt?.formatted(date: .abbreviated, time: .shortened) ?? "—"
            Text("Created: \(created)")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Updated: \(updated)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

@MainActor
private let previewJournalContainer: ModelContainer = {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: JournalEntry.self, configurations: configuration)
    let context = container.mainContext

    // Create a sample entry
    let sample = JournalEntry()
    sample.title = "Preview Entry"
    sample.body = """
    This is a sample journal entry body. John 3:16; Ps 23:1 (ESV).
    Tap references to preview and copy.
    """
    sample.verseRef = VerseRef(book: "John", chapter: 3, verse: 16, translation: "ESV")
    sample.tags = ["Prayer", "Faith"]
    sample.isFavorite = true
    sample.isPinned = true
    context.insert(sample)
    try? context.save()
    return container
}()

#Preview {
    // Fetch the inserted sample from the in-memory container or make a fresh one
    let entry = {
        let ctx = previewJournalContainer.mainContext
        let fetch = FetchDescriptor<JournalEntry>()
        if let first = try? ctx.fetch(fetch).first {
            return first
        } else {
            let e = JournalEntry()
            e.title = "Preview Entry"
            e.body = "Sample body"
            ctx.insert(e)
            return e
        }
    }()

    return NavigationStack {
        JournalDetailView(entry: entry)
            .environmentObject(JournalComposer())
    }
    .modelContainer(previewJournalContainer)
}
