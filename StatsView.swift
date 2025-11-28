import SwiftUI
import Combine

struct StatsView: View {
    private enum SortMode: String, CaseIterable, Identifiable {
        case canonical = "Canonical"
        case mostRead = "Most Read"
        var id: String { rawValue }
    }

    @State private var expanded: Bool = false
    @State private var sortMode: SortMode = .canonical

    @State private var perBookTotals: [String: Int] = [:]
    @State private var totalSeconds: Int = 0
    @State private var cancellable: AnyCancellable?

    // New derived stats
    @State private var todaySeconds: Int = 0
    @State private var thisWeekSeconds: Int = 0
    @State private var lastWeekSeconds: Int = 0
    @State private var otSeconds: Int = 0
    @State private var ntSeconds: Int = 0
    @State private var visitedCount: Int = 0
    @State private var lastReadText: String = "—"

    private var orderedAllBooks: [String] {
        // Prefer BibleData order if available, else fallback canonical order
        if !BibleData.books.isEmpty {
            return BibleData.books.map { $0.name }
        }
        return BibleCanon.canonicalOrder()
    }

    private func refreshTotals() {
        let store = BibleStatsStore.shared
        let totals = store.loadTotals()
        perBookTotals = totals
        totalSeconds = totals.values.reduce(0, +)

        // Daily
        todaySeconds = store.totalForLast(days: 1)
        thisWeekSeconds = store.totalForLast(days: 7)
        lastWeekSeconds = store.totalForLast(days: 14) - thisWeekSeconds

        // OT/NT
        let split = store.splitOTNT(totals: totals)
        otSeconds = split.ot
        ntSeconds = split.nt

        // Visited chapters
        visitedCount = store.loadVisitedChapters().count

        // Last read
        if let last = store.loadLastRead() {
            let rel = relativeDateString(last.date)
            lastReadText = "\(last.bookName) \(last.chapterNumber) • \(rel)"
        } else {
            lastReadText = "—"
        }
    }

    private func relativeDateString(_ date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .short
        return fmt.localizedString(for: date, relativeTo: Date())
    }

    // Build rows with selected sort
    private var rows: [(book: String, seconds: Int)] {
        let canonical = orderedAllBooks
        let canonicalPos = Dictionary(uniqueKeysWithValues: canonical.enumerated().map { ($1, $0) })

        switch sortMode {
        case .canonical:
            // Keep canonical order; show all 66 with default 0 if missing
            return canonical.map { name in
                (book: name, seconds: perBookTotals[name, default: 0])
            }
        case .mostRead:
            // Sort by seconds desc, with canonical order as tie-breaker; still show all 66
            let all: [(book: String, seconds: Int)] = canonical.map { name in
                (book: name, seconds: perBookTotals[name, default: 0])
            }
            return all.sorted { lhs, rhs in
                if lhs.seconds == rhs.seconds {
                    // Stable by canonical order
                    return (canonicalPos[lhs.book] ?? .max) < (canonicalPos[rhs.book] ?? .max)
                }
                return lhs.seconds > rhs.seconds
            }
        }
    }

    var body: some View {
        List {
            // Quick summary cards
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(BibleStatsStore.shared.format(todaySeconds))
                            .font(.title3).monospacedDigit()
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Week")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(BibleStatsStore.shared.format(thisWeekSeconds))
                            .font(.title3).monospacedDigit()
                        Text(weekDeltaText)
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Read")
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(lastReadText)
                            .font(.footnote)
                            .lineLimit(2)
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("OT vs NT")
                        .font(.subheadline).foregroundStyle(.secondary)
                    HStack {
                        let total = max(1, otSeconds + ntSeconds)
                        let otFrac = CGFloat(otSeconds) / CGFloat(total)
                        let ntFrac = CGFloat(ntSeconds) / CGFloat(total)
                        GeometryReader { geo in
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.blue.opacity(0.6))
                                    .frame(width: geo.size.width * otFrac)
                                Rectangle()
                                    .fill(Color.green.opacity(0.6))
                                    .frame(width: geo.size.width * ntFrac)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .frame(height: 10)
                    }
                    HStack {
                        Text("OT \(BibleStatsStore.shared.format(otSeconds))")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("NT \(BibleStatsStore.shared.format(ntSeconds))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Coverage")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("\(visitedCount) chapters visited")
                        .font(.footnote).foregroundStyle(.primary)
                }
                .padding(.top, 6)
            }

            Section {
                DisclosureGroup(isExpanded: $expanded) {
                    // Sort picker visible when expanded
                    Picker("Sort", selection: $sortMode) {
                        ForEach(SortMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 6)

                    // Expanded list of all 66 books with their time
                    ForEach(rows, id: \.book) { entry in
                        HStack {
                            Text(entry.book)
                            Spacer()
                            Text(BibleStatsStore.shared.format(entry.seconds))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(entry.book) \(BibleStatsStore.shared.format(entry.seconds))")
                    }
                } label: {
                    HStack {
                        Text("Total Bible Time")
                            .font(.headline)
                        Spacer()
                        Text(BibleStatsStore.shared.format(totalSeconds))
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .accessibilityHidden(true)
                            .overlay(
                                Color.clear
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("Total \(BibleStatsStore.shared.format(totalSeconds))")
                            )
                    }
                }
            } header: {
                Text("Bible Stats")
            }
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshTotals()
            // Subscribe to tracker version bumps to keep stats fresh
            if cancellable == nil {
                cancellable = ReadingTimeTracker.shared.$lastTotalsVersion
                    .receive(on: RunLoop.main)
                    .sink { _ in
                        refreshTotals()
                    }
            }
        }
        .onDisappear {
            // Optional: keep subscription; or release when leaving
            // cancellable?.cancel(); cancellable = nil
        }
    }

    private var weekDeltaText: String {
        let delta = thisWeekSeconds - lastWeekSeconds
        if delta == 0 { return "vs last week: —" }
        let sign = delta > 0 ? "+" : "−"
        let absVal = abs(delta)
        return "vs last week: \(sign)\(BibleStatsStore.shared.format(absVal))"
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
}
