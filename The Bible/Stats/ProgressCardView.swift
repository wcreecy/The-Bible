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

    // UI state bindings
    @Binding var isExpanded: Bool
    @Binding var filter: BookFilter
    @Binding var search: String
    @Binding var selectedBookForChapters: String?

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
        HeroCard(title: "Reading Progress", icon: "books.vertical", tint: .green) {
            VStack(alignment: .leading, spacing: 10) {
                // Unified header tap target
                headerView
                    .contentShape(Rectangle())
                    .onTapGesture { toggleExpanded() }

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

    // MARK: - Header

    /// The same header whether or not the details are open, so expanding doesn't make the
    /// top of the card jump.
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Books and chapters count once every verse in them is viewed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Side by side when the three fit, otherwise one per row.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    ForEach(metrics) { metric in
                        metricTile(metric, axis: .vertical)
                    }
                }
                VStack(spacing: 8) {
                    ForEach(metrics) { metric in
                        metricTile(metric, axis: .horizontal)
                    }
                }
            }
        }
    }

    private struct Metric: Identifiable {
        let title: String
        let count: Int
        let total: Int
        let percent: Int
        let tint: Color

        var id: String { title }
    }

    private var metrics: [Metric] {
        [
            Metric(title: "Books", count: booksCompleted, total: totalBooks, percent: booksPercent, tint: .green),
            Metric(title: "Chapters", count: visitedCount, total: totalChapters, percent: chaptersPercent, tint: .blue),
            Metric(title: "Verses", count: completedVerses, total: totalVerses, percent: versesPercent, tint: .accentColor)
        ]
    }

    /// A ring with the percent, the metric's name, and its count. `axis` places the ring
    /// above the text (.vertical) or beside it (.horizontal).
    private func metricTile(_ metric: Metric, axis: Axis) -> some View {
        let ring = ProgressRing(
            progress: Double(metric.percent) / 100.0,
            lineWidth: 7,
            size: 40,
            tint: metric.tint,
            track: Color.primary.opacity(0.12),
            label: {
                Text("\(metric.percent)%")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
            }
        )
        let text = VStack(alignment: axis == .vertical ? .center : .leading, spacing: 2) {
            Text(metric.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(formatInt(metric.count))/\(formatInt(metric.total))")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
        }
        .lineLimit(1)

        return Group {
            if axis == .vertical {
                VStack(spacing: 6) {
                    ring
                    text
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(spacing: 12) {
                    ring
                    text
                    Spacer(minLength: 0)
                }
            }
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metric.title) fully viewed: \(metric.count) of \(metric.total), \(metric.percent) percent")
        .allowsHitTesting(false) // the tile never steals the header tap
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
