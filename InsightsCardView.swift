import SwiftUI

struct InsightsCardView: View {
    let title: String
    let tiles: [InsightChipModel]
    let onRefresh: () -> Void

    init(title: String = "Smart Insights", tiles: [InsightChipModel], onRefresh: @escaping () -> Void) {
        self.title = title
        self.tiles = tiles
        self.onRefresh = onRefresh
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Button(action: onRefresh) {
                        Label("Refresh insights", systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                if tiles.isEmpty {
                    ContentUnavailableView("No insights yet", systemImage: "sparkles")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        ForEach(tiles) { model in
                            InsightTile(model: model)
                        }
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}
