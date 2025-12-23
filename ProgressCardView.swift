import SwiftUI

struct ProgressCardView: View {
    // Inputs
    let booksCompleted: Int
    let totalBooks: Int
    let visitedCount: Int
    let totalChapters: Int
    let completedVerses: Int
    let totalVerses: Int

    // Grid data
    let orderedBookNames: [String]
    let bookProgress: [String: (read: Int, total: Int, fraction: Double)]

    // Actions
    let onContinue: () -> Void
    let onOpenNextUnread: () -> Void

    // Optional state
    let hasLastRead: Bool

    // UI state bindings
    @Binding var isExpanded: Bool
    @Binding var filter: BookFilter
    @Binding var search: String
    @Binding var selectedBookForChapters: String?

    @Environment(\.horizontalSizeClass) private var hSizeClass

    // Helpers
    private func formatInt(_ v: Int) -> String { v.formatted(.number.grouping(.automatic)) }

    // Derived percentages
    private var booksPercent: Int {
        let denom = max(1, totalBooks)
        let pct = Int(round((Double(booksCompleted) / Double(denom)) * 100.0))
        return max(0, min(100, pct))
    }
    private var chaptersPercent: Int {
        let denom = max(1, totalChapters)
        let pct = Int(round((Double(visitedCount) / Double(denom)) * 100.0))
        return max(0, min(100, pct))
    }
    private var versesPercent: Int {
        let denom = max(1, totalVerses)
        let pct = Int(round((Double(completedVerses) / Double(denom)) * 100.0))
        return max(0, min(100, pct))
    }

    // Filtering
    private func filteredBooks() -> [String] {
        let canonicalIndexMap = Dictionary(uniqueKeysWithValues: orderedBookNames.enumerated().map { ($1, $0) })
        let matthewIndex = canonicalIndexMap["Matthew"] ?? Int.max

        let base: [String] = {
            switch filter {
            case .all: return orderedBookNames
            case .ot: return orderedBookNames.filter { (canonicalIndexMap[$0] ?? Int.max) < matthewIndex }
            case .nt: return orderedBookNames.filter { (canonicalIndexMap[$0] ?? Int.max) >= matthewIndex }
            }
        }()
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return base }
        return base.filter { $0.localizedCaseInsensitiveContains(q) }
    }

    private var bookGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 150), spacing: 10)]
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                // Unified header tap target
                headerView
                    .contentShape(Rectangle())
                    .onTapGesture { toggleExpanded() }

                // Actions (kept)
                HStack(spacing: 10) {
                    Button(action: onContinue) {
                        Label("Continue Reading", systemImage: "arrowtriangle.right.fill")
                            .font(.footnote.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .disabled(!hasLastRead)

                    Button(action: onOpenNextUnread) {
                        Label("Next Unread", systemImage: "sparkles")
                            .font(.footnote.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }

                Button {
                    toggleExpanded()
                } label: {
                    HStack {
                        Text(isExpanded ? "Hide details" : "Show details")
                            .font(.footnote.weight(.semibold))
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.footnote.weight(.semibold))
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    filtersAndSearch
                    grid
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        // IMPORTANT: Do NOT attach a tap gesture to the entire card.
        // It conflicts with inner TextField/Picker gestures and can cause UIKit recognizers to hang.
    }

    private func toggleExpanded() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            isExpanded.toggle()
        }
    }

    // MARK: - Unified header
    @ViewBuilder
    private var headerView: some View {
        if isExpanded {
            if hSizeClass == .compact {
                compactHeader
            } else {
                regularHeader
            }
        } else {
            collapsedHeader
        }
    }

    // MARK: - Collapsed header (polished summary)

    private var collapsedHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bible Reading Progress")
                .font(.headline)

            if hSizeClass == .regular {
                HStack(spacing: 12) {
                    summaryTile(
                        title: "Books",
                        countText: "\(formatInt(booksCompleted))/\(formatInt(totalBooks))",
                        percent: booksPercent,
                        tint: .green
                    )
                    summaryTile(
                        title: "Chapters",
                        countText: "\(formatInt(visitedCount))/\(formatInt(totalChapters))",
                        percent: chaptersPercent,
                        tint: .blue
                    )
                    summaryTile(
                        title: "Verses",
                        countText: "\(formatInt(completedVerses))/\(formatInt(totalVerses))",
                        percent: versesPercent,
                        tint: .accentColor
                    )
                }
            } else {
                VStack(spacing: 8) {
                    summaryTile(
                        title: "Books",
                        countText: "\(formatInt(booksCompleted))/\(formatInt(totalBooks))",
                        percent: booksPercent,
                        tint: .green
                    )
                    summaryTile(
                        title: "Chapters",
                        countText: "\(formatInt(visitedCount))/\(formatInt(totalChapters))",
                        percent: chaptersPercent,
                        tint: .blue
                    )
                    summaryTile(
                        title: "Verses",
                        countText: "\(formatInt(completedVerses))/\(formatInt(totalVerses))",
                        percent: versesPercent,
                        tint: .accentColor
                    )
                }
            }
        }
    }

    private func summaryTile(title: String, countText: String, percent: Int, tint: Color) -> some View {
        HStack(spacing: 12) {
            ProgressRing(
                progress: Double(percent) / 100.0,
                lineWidth: 7,
                size: 40,
                tint: tint,
                track: Color.primary.opacity(0.12),
                label: {
                    Text("\(percent)%")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                }
            )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    // Small accent chip for percent — mark decorative to avoid intercepting taps
                    Text("\(percent)%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule(style: .continuous)
                                .fill(tint.opacity(0.12))
                        )
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
                Text(countText + " " + title.lowercased())
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) \(countText), \(percent) percent complete")
        .allowsHitTesting(false) // ensure the tile never steals the header tap
    }

    // MARK: - Original headers (kept for expanded view)

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bible Reading Progress")
                .font(.headline)

            VStack(spacing: 8) {
                metricRow(title: "Books", countText: "\(formatInt(booksCompleted))/\(formatInt(totalBooks))", percent: booksPercent, tint: .green)
                metricRow(title: "Chapters", countText: "\(formatInt(visitedCount))/\(formatInt(totalChapters))", percent: chaptersPercent, tint: .blue)
                metricRow(title: "Verses", countText: "\(formatInt(completedVerses))/\(formatInt(totalVerses))", percent: versesPercent, tint: .accentColor)
            }
        }
    }

    private var regularHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Bible Reading Progress")
                    .font(.headline)
                HStack(spacing: 8) {
                    Text("\(formatInt(booksCompleted))/\(formatInt(totalBooks)) books")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text("• \(formatInt(visitedCount))/\(formatInt(totalChapters)) chapters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Text("• \(formatInt(completedVerses))/\(formatInt(totalVerses)) verses")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer()
            HStack(spacing: 12) {
                labeledRing(title: "Books", percent: booksPercent, tint: .green)
                labeledRing(title: "Chapters", percent: chaptersPercent, tint: .blue)
                labeledRing(title: "Verses", percent: versesPercent, tint: .accentColor)
            }
            .allowsHitTesting(false) // decorative cluster; avoid stealing taps
        }
    }

    private func labeledRing(title: String, percent: Int, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            ProgressRing(
                progress: Double(percent) / 100.0,
                lineWidth: 7,
                size: 40,
                tint: tint,
                track: Color.primary.opacity(0.12),
                label: {
                    Text("\(percent)%")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                }
            )
            .accessibilityLabel(Text("\(title) \(percent) percent complete"))
        }
    }

    private func metricRow(title: String, countText: String, percent: Int, tint: Color) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(countText)
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            ProgressRing(
                progress: Double(percent) / 100.0,
                lineWidth: 7,
                size: 36,
                tint: tint,
                track: Color.primary.opacity(0.12),
                label: {
                    Text("\(percent)%")
                        .font(.caption2.weight(.semibold))
                        .monospacedDigit()
                }
            )
            .accessibilityLabel(Text("\(title) \(percent) percent complete"))
        }
        .padding(.vertical, 2)
        .allowsHitTesting(false) // decorative; keep header tap unified
    }

    // MARK: - Expanded content (kept)

    private var filtersAndSearch: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Filter", selection: $filter) {
                ForEach(BookFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search books", text: $search)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
        }
    }

    private var grid: some View {
        LazyVGrid(columns: bookGridColumns, spacing: 10) {
            ForEach(filteredBooks(), id: \.self) { name in
                let prog = bookProgress[name] ?? (0, 1, 0.0)
                Button {
                    selectedBookForChapters = name
                } label: {
                    HStack(spacing: 10) {
                        ProgressRing(
                            progress: prog.fraction,
                            lineWidth: 6,
                            size: 34,
                            tint: .accentColor,
                            track: Color.primary.opacity(0.12),
                            label: {
                                Text("\(Int(round(prog.fraction * 100)))%")
                                    .font(.caption2.weight(.semibold))
                                    .monospacedDigit()
                            }
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text("\(formatInt(prog.read))/\(formatInt(prog.total)) chapters")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(name) \(prog.read) of \(prog.total) chapters")
            }
        }
    }
}
