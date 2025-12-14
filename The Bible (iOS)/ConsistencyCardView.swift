import SwiftUI

struct ConsistencyCardView: View {
    let last30Daily: [(date: Date, seconds: Int)]

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text("Consistency — last 30 days")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(last30Daily, id: \.date) { item in
                            square(for: item.seconds)
                        }
                    }
                    .padding(.vertical, 4)
                }

                HStack(spacing: 16) {
                    legendItem(color: color(for: 0), label: "0")
                    legendItem(color: color(for: 5*60), label: "5m")
                    legendItem(color: color(for: 15*60), label: "15m")
                    legendItem(color: color(for: 30*60), label: "30m")
                    legendItem(color: color(for: 60*60), label: "1h+")
                }
            }
        }
    }

    private func square(for seconds: Int) -> some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color(for: seconds))
            .frame(width: 20, height: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .accessibilityHidden(true)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color)
                .frame(width: 18, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func color(for seconds: Int) -> Color {
        if seconds <= 0 { return Color.gray.opacity(0.28) }
        if seconds >= 60*60 { return .red }
        if seconds >= 30*60 { return .orange }
        if seconds >= 15*60 { return .teal }
        return .blue
    }
}
