import SwiftUI
import Charts

struct TotalsCardView: View {
    enum SortMode: String, CaseIterable, Identifiable {
        case canonical = "Canonical"
        case mostRead = "Most Read"
        var id: String { rawValue }
    }

    enum TimeScope: String, CaseIterable, Identifiable {
        case allTime = "All Time"
        case thisMonth = "This Month"
        case last7 = "Last 7 Days"
        var id: String { rawValue }
    }

    // Inputs
    @Binding var timeScope: TimeScope
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
    @Binding var sortMode: SortMode
    let rows: [(book: String, seconds: Int)]

    // Formatting helper (seconds -> H:MM:SS or M:SS)
    let formatSeconds: (Int) -> String

    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Bible Reading Time — \(timeScope.rawValue)")
                        .font(.headline)
                    Spacer()
                    Text(formatSeconds(totalSeconds))
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)
                        .overlay(
                            Color.clear
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Total \(formatSeconds(totalSeconds))")
                        )
                }

                Picker("Scope", selection: $timeScope) {
                    ForEach(TimeScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)

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
                            ForEach(series, id: \.date) { item in
                                let minutes = Int(round(Double(item.seconds) / 60.0))
                                BarMark(
                                    x: .value("Date", item.date, unit: currentBarUnit),
                                    y: .value("Minutes", minutes)
                                )
                                .foregroundStyle(Color.accentColor.opacity(0.85))
                                .cornerRadius(3)
                                .annotation(position: .top, alignment: .center) {
                                    if minutes > 0, showValueLabels {
                                        // Smaller font on iPhone (compact) for legibility with many bars
                                        if hSizeClass == .compact {
                                            Text("\(minutes)")
                                                .font(.system(size: 9, weight: .semibold))
                                                .foregroundStyle(.secondary)
                                                .monospacedDigit()
                                        } else {
                                            Text("\(minutes)")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                                .monospacedDigit()
                                        }
                                    }
                                }
                            }
                        }
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
                        ForEach(SortMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    ForEach(rows, id: \.book) { entry in
                        HStack {
                            Text(entry.book)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(formatSeconds(entry.seconds))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 80, alignment: .trailing)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(entry.book) \(formatSeconds(entry.seconds))")
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        // Make the entire card clickable to expand/collapse
        .contentShape(Rectangle())
        .highPriorityGesture(
            TapGesture().onEnded {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    isExpanded.toggle()
                }
            }
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(isExpanded ? "Hide details" : "Show details"))
    }

    // Max minutes helper for a safe y-domain
    private var maxMinutesInSeries: Int {
        guard !series.isEmpty else { return 0 }
        let maxSeconds = series.map { max(0, $0.seconds) }.max() ?? 0
        return Int(round(Double(maxSeconds) / 60.0))
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
