import SwiftUI

struct TitleCardView: View {
    let isPad: Bool
    let goalMinutes: Int
    let todayReadingSeconds: Int
    let streak: Int
    let goalMessage: String
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
                    .lineLimit(1)
                    .allowsTightening(true)
                    .minimumScaleFactor(0.75)
                Text(text)
                    .font(font)
                    .foregroundStyle(gradient)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .minimumScaleFactor(0.75)
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

    private var progressPercent: Int {
        Int((progress * 100).rounded())
    }

    var body: some View {
        HeroCard(
            title: isPad ? greeting : "Word of God",
            subtitle: nil,
            icon: "book.fill",
            tint: .blue,
            titleFont: titleFont,
            titleFontWeight: titleWeight,
            centerHeader: !isPad
        ) {
            if isPad {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Today’s Reading Goal")
                            .font(.title3.weight(.semibold))
                        Spacer()
                        Text("\(progressPercent)%")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.blue)
                    }

                    ProgressView(value: progress)
                        .tint(.blue)
                        .scaleEffect(x: 1, y: 1.5, anchor: .center)

                    HStack(spacing: 18) {
                        Label(progressDescription, systemImage: "book.pages")
                        Label("\(streak) day streak", systemImage: "flame.fill")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)

                    Divider()
                    actionButtons
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Daily goal progress \(progressPercent) percent. Current streak \(streak) days.")
            } else {
                VStack(spacing: 8) {
                    ProgressFillText(
                        text: goalMessage,
                        font: .subheadline.weight(.semibold),
                        progress: progress
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .accessibilityLabel("\(goalMessage) Daily goal progress \(progressPercent) percent. Current streak \(streak) days.")

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
            .buttonStyle(SubtlePillButtonStyle(emphasized: false, sizeScale: buttonScale))

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
