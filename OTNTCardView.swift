import SwiftUI

struct OTNTCardView: View {
    enum TimeScope: String, CaseIterable, Identifiable {
        case allTime = "All Time"
        case thisMonth = "This Month"
        case last7 = "Last 7 Days"
        var id: String { rawValue }
    }

    @Binding var timeScope: TimeScope
    let otSeconds: Int
    let ntSeconds: Int
    let formatSeconds: (Int) -> String

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("OT vs NT — \(timeScope.rawValue)")
                        .font(.headline)
                    Spacer()
                }

                Picker("Scope", selection: $timeScope) {
                    ForEach(TimeScope.allCases) { scope in
                        Text(scope.rawValue).tag(scope)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 8) {
                    Text("OT")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    bar
                    Text("NT")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("OT \(formatSeconds(max(0, otSeconds)))")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("NT \(formatSeconds(max(0, ntSeconds)))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var bar: some View {
        // Clamp inputs to avoid negative or non-finite widths
        let otSafe = max(0, otSeconds)
        let ntSafe = max(0, ntSeconds)
        let total = max(1, otSafe + ntSafe)

        let otRaw = CGFloat(otSafe) / CGFloat(total)
        let ntRaw = CGFloat(ntSafe) / CGFloat(total)

        let otFrac = otRaw.isFinite ? min(max(0, otRaw), 1) : 0
        let ntFrac = ntRaw.isFinite ? min(max(0, ntRaw), 1) : 0

        return GeometryReader { geo in
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: max(0, geo.size.width * otFrac))
                Rectangle()
                    .fill(Color.green.opacity(0.6))
                    .frame(width: max(0, geo.size.width * ntFrac))
            }
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .frame(height: 12)
    }
}
