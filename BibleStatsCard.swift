import SwiftUI

struct BibleStatsCard: View {
    @ObservedObject var bibleVM: HomeBibleStatsViewModel
    let scenePhase: ScenePhase
    let onOpenStats: () -> Void

    private func statMiniPill(title: String, value: String, subtitle: String? = nil, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            if let subtitle, !subtitle.isEmpty {
                let prefix = (title == "This Week") ? "vs lst wk: " : (title == "Today" ? "vs yday: " : (title == "This Month" ? "vs lst mo: " : ""))
                if !prefix.isEmpty {
                    Text("\(prefix)\(subtitle)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }

    private func lastReadMiniPill(title: String, ref: String, relative: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption).foregroundStyle(.secondary)
            Text(ref)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(relative)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    var body: some View {
        HeroCard(
            title: "Bible Stats",
            subtitle: "At a glance",
            icon: "chart.bar.fill",
            tint: .teal
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    statMiniPill(title: "Today", value: bibleVM.formatted(bibleVM.todaySeconds), subtitle: bibleVM.todayDeltaOnlyValue, tint: .blue)
                    statMiniPill(title: "This Week", value: bibleVM.formatted(bibleVM.thisWeekSeconds), subtitle: bibleVM.weekDeltaOnlyValue, tint: .green)

                    let monthSeconds = BibleStatsStore.shared.totalForMonth(containing: Date())
                    let lastMonthDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                    let lastMonthSeconds = BibleStatsStore.shared.totalForMonth(containing: lastMonthDate)
                    let monthDeltaOnlyValue: String = {
                        let delta = monthSeconds - lastMonthSeconds
                        if delta == 0 { return "—" }
                        let sign = delta > 0 ? "+" : "−"
                        return "\(sign)\(bibleVM.formatted(abs(delta)))"
                    }()
                    statMiniPill(title: "This Month", value: bibleVM.formatted(monthSeconds), subtitle: monthDeltaOnlyValue, tint: .mint)

                    // New: Last Session pill
                    statMiniPill(title: "Last Session", value: bibleVM.lastSessionSeconds > 0 ? bibleVM.formatted(bibleVM.lastSessionSeconds) : "—", tint: .indigo)

                    statMiniPill(title: "All-time", value: bibleVM.formatted(bibleVM.totalSeconds), subtitle: nil, tint: .purple)

                    lastReadMiniPill(title: "Last Read", ref: bibleVM.lastReadBookChapter, relative: bibleVM.lastReadRelativeTime)
                }
                .padding(.vertical, 2)
            }
            .onAppear { bibleVM.refresh() }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { bibleVM.refresh() }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenStats)
    }
}

