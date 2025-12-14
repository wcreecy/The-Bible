import SwiftUI

struct TitleCardView: View {
    let isPad: Bool
    let goalMinutes: Int
    let todayReadingSeconds: Int
    let streak: Int
    let onSearch: () -> Void
    let onRead: () -> Void
    let onFavorites: () -> Void

    private var buttonScale: CGFloat { isPad ? 1.25 : 1.0 }
    private var titleFont: Font { isPad ? .system(.largeTitle, design: .default) : .largeTitle }
    private var titleWeight: Font.Weight { .black }

    // Progress fraction 0...1 for gradient fill text
    private var progress: Double {
        let goalSeconds = max(1, goalMinutes) * 60
        return min(1.0, Double(max(0, todayReadingSeconds)) / Double(goalSeconds))
    }

    private struct ProgressFillText: View {
        let text: String
        let font: Font
        let progress: Double // 0...1
        private var gradient: LinearGradient {
            LinearGradient(colors: [.blue, .red], startPoint: .leading, endPoint: .trailing)
        }
        var body: some View {
            ZStack(alignment: .leading) {
                Text(text)
                    .font(font)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(font)
                    .foregroundStyle(gradient)
                    .mask(
                        GeometryReader { geo in
                            let width = max(0, min(1, progress)) * geo.size.width
                            Rectangle()
                                .frame(width: width, height: geo.size.height)
                                .alignmentGuide(.leading) { d in d[.leading] }
                        }
                    )
            }
            .accessibilityLabel(text)
        }
    }

    var body: some View {
        HeroCard(
            title: "Word of God",
            subtitle: nil,
            icon: "book.fill",
            tint: .blue,
            titleFont: titleFont,
            titleFontWeight: titleWeight,
            centerHeader: true
        ) {
            VStack(spacing: isPad ? 16 : 8) {
                ProgressFillText(
                    text: "What does God have for YOU today?",
                    font: isPad ? .title3.weight(.semibold) : .subheadline.weight(.semibold),
                    progress: progress
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .accessibilityLabel("What does God have for you today? Daily goal progress \(Int(round(progress * 100))) percent. Current streak \(streak) days.")

                HStack(spacing: isPad ? 16 : 12) {
                    Button(action: onSearch) {
                        Label("Search", systemImage: "magnifyingglass")
                            .lineLimit(1)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.85)
                    }
                    .buttonStyle(SubtlePillButtonStyle(emphasized: false, sizeScale: buttonScale))

                    Button(action: onRead) {
                        Label("Read", systemImage: "book")
                            .lineLimit(1)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.85)
                    }
                    .buttonStyle(SubtlePillButtonStyle(emphasized: true, sizeScale: buttonScale))

                    Button(action: onFavorites) {
                        Label("Favorites", systemImage: "heart")
                            .lineLimit(1)
                            .allowsTightening(true)
                            .minimumScaleFactor(0.85)
                    }
                    .buttonStyle(SubtlePillButtonStyle(emphasized: false, sizeScale: buttonScale))
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
