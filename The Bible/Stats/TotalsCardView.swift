import SwiftUI
import Charts

struct TotalsCardView: View {
    // Inputs
    @Binding var timeScope: StatsTimeScope
    let totalSeconds: Int
    let series: [(date: Date, seconds: Int)]
    let chartSubtitle: String
    let currentBarUnit: Calendar.Component
    let showValueLabels: Bool
    let xAxis: () -> AnyAxisContent

    // Quick chips
    let activeBucketLabel: String
    let activeBucketCount: Int
    let avgPerActiveBucketLabel: String
    let avgSecondsPerActiveBucket: Int
    let topBook: String

    // Details
    @Binding var isExpanded: Bool
    @Binding var sortMode: StatsSortMode
    let rows: [(book: String, seconds: Int)]

    // Formatting helper (seconds -> H:MM:SS or M:SS)
    let formatSeconds: (Int) -> String

    @Environment(\.colorScheme) private var colorScheme
    /// The date under the Apple Pencil, pointer or finger on the chart.
    @State private var selectedDate: Date?

    private var segmentedTint: Color {
        colorScheme == .light ? Color.black.opacity(0.85) : Color.accentColor
    }

    var body: some View {
        // The scope picker names the period, so the title doesn't repeat it.
        HeroCard(
            title: "Bible Reading Time",
            icon: "clock",
            tint: .blue,
            trailingAccessory: {
                Text(formatSeconds(totalSeconds))
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .accessibilityLabel("Total \(formatSeconds(totalSeconds)) \(timeScope.rawValue)")
            }
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Scope", selection: $timeScope) {
                    ForEach(StatsTimeScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .tint(segmentedTint)

                // Chips
                LazyVGrid(columns: chipGridColumns, spacing: 8) {
                    metricChip(title: activeBucketLabel, value: "\(activeBucketCount)")
                    metricChip(title: avgPerActiveBucketLabel, value: formatSeconds(avgSecondsPerActiveBucket))
                    metricChip(title: "Top book", value: topBook)
                }

                // Chart
                if !series.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(chartSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Chart {
                            if let selectedBar {
                                RuleMark(x: .value("Selected", selectedBar.date, unit: currentBarUnit))
                                    .foregroundStyle(Color.secondary.opacity(0.35))
                                    .annotation(
                                        position: .top,
                                        spacing: 4,
                                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                                    ) {
                                        selectionLabel(for: selectedBar)
                                    }
                            }
                            ForEach(series, id: \.date) { item in
                                let minutes = Double(item.seconds) / 60.0
                                BarMark(
                                    x: .value("Date", item.date, unit: currentBarUnit),
                                    y: .value("Minutes", minutes)
                                )
                                .foregroundStyle(Color.accentColor.opacity(0.85))
                                .cornerRadius(3)
                                .annotation(position: .top, alignment: .center) {
                                    if minutes > 0, showValueLabels, selectedBar == nil {
                                        Text(minutes.formatted(.number.precision(.fractionLength(minutes < 1 ? 1 : 0))))
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                }
                            }
                        }
                        // Hovering a bar (or touching it) shows its exact date and time.
                        .chartXSelection(value: $selectedDate)
                        // Ensure a non-zero y-domain even when all values are zero
                        .chartYScale(domain: 0...max(1, maxMinutesInSeries))
                        .chartYAxisLabel("Minutes")
                        .chartXAxis { xAxis() }
                        .frame(height: 160)
                    }
                } else {
                    ContentUnavailableView("No data in this period", systemImage: "chart.bar.xaxis")
                }

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        isExpanded.toggle()
                    }
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
                    Picker("Sort", selection: $sortMode) {
                        ForEach(StatsSortMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(segmentedTint)

                    ForEach(rows, id: \.book) { entry in
                        HStack {
                            Text(entry.book)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(formatSeconds(entry.seconds))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .fixedSize()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(entry.book) \(formatSeconds(entry.seconds))")
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        // NOTE: Removed "entire card is tappable" gesture. It could intercept touches intended
        // for other controls (like the top mode picker) if view bounds overlap during animations.
    }

    /// The bar under the pointer: the one whose day, month or year holds the selected date.
    private var selectedBar: (date: Date, seconds: Int)? {
        guard let selectedDate else { return nil }
        return series.first { Calendar.current.isDate($0.date, equalTo: selectedDate, toGranularity: currentBarUnit) }
    }

    private func selectionLabel(for bar: (date: Date, seconds: Int)) -> some View {
        VStack(spacing: 2) {
            Text(barDateText(bar.date))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(bar.seconds > 0 ? formatSeconds(bar.seconds) : "No reading")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// The bar's date in the size of the bar: a day, a month, or a year.
    private func barDateText(_ date: Date) -> String {
        switch currentBarUnit {
        case .year: date.formatted(.dateTime.year())
        case .month: date.formatted(.dateTime.month(.wide).year())
        default: date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
    }

    // Max minutes helper for a safe y-domain
    private var maxMinutesInSeries: Double {
        guard !series.isEmpty else { return 0 }
        let maxSeconds = series.map { max(0, $0.seconds) }.max() ?? 0
        return Double(maxSeconds) / 60.0
    }

    // Responsive chip grid (simple heuristic)
    private var chipGridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 8),
         GridItem(.flexible(), spacing: 8),
         GridItem(.flexible(), spacing: 8)]
    }

    private func metricChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }
}
