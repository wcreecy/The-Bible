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

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:
            return "Good Morning"
        case 12..<18:
            return "Good Afternoon"
        default:
            return "Good Evening"
        }
    }

    private var progressDescription: String {
        let minutesRead = todayReadingSeconds / 60
        return "\(minutesRead) of \(goalMinutes) minutes"
    }

    var body: some View {
        HeroCard(
            title: isPad ? greeting : "Word of God",
            subtitle: isPad ? "Your daily rhythm in Scripture" : nil,
            icon: "book.fill",
            tint: .blue,
            titleFont: titleFont,
            titleFontWeight: titleWeight,
            centerHeader: !isPad
        ) {
            if isPad {
                HStack(alignment: .center, spacing: 28) {
                    VStack(alignment: .leading, spacing: 10) {
                        ProgressFillText(
                            text: "What does God have for YOU today?",
                            font: .title3.weight(.semibold),
                            progress: progress
                        )

                        HStack(spacing: 14) {
                            Label(progressDescription, systemImage: "book.pages")
                            Label("\(streak) day streak", systemImage: "flame.fill")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .labelStyle(.titleAndIcon)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    actionButtons
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Daily goal progress \(Int(round(progress * 100))) percent. Current streak \(streak) days.")
            } else {
                VStack(spacing: 8) {
                    ProgressFillText(
                        text: "What does God have for YOU today?",
                        font: .subheadline.weight(.semibold),
                        progress: progress
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("What does God have for you today? Daily goal progress \(Int(round(progress * 100))) percent. Current streak \(streak) days.")

                    actionButtons
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .frame(maxWidth: isPad ? .infinity : 700)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var actionButtons: some View {
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
    }
}
