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
                // Metadata (title now appears only in the navigation bar)
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
        .navigationTitle(entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : entry.title)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // Share button: shares title + body
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                }

                // Edit button
                Button("Edit") {
                    journalComposer.presentForEditing(entry: entry)
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
