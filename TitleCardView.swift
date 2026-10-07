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
                Text(text)
                    .font(font)
                    .foregroundStyle(gradient)
                    .lineLimit(1)
                    .allowsTightening(true)
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

    var body: some View {
        Group {
            if isPad {
                iPadHeader
            } else {
                HeroCard(
                    title: "Word of God",
                    subtitle: nil,
                    icon: "book.fill",
                    tint: .blue,
                    titleFont: titleFont,
                    titleFontWeight: titleWeight,
                    centerHeader: true
                ) {
                    phoneContent
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var iPadHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(greeting)
                .font(.largeTitle.weight(.black))

            Spacer()

            Text(Date(), format: .dateTime.weekday(.wide).month().day())
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var phoneContent: some View {
        VStack(spacing: 8) {
            ProgressFillText(
                text: goalMessage,
                font: .subheadline.weight(.semibold),
                progress: progress
            )
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .accessibilityLabel("\(goalMessage) Daily goal progress \(Int((progress * 100).rounded())) percent. Current streak \(streak) days.")

            phoneActionButtons
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var phoneActionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onSearch) {
                Label("Search", systemImage: "magnifyingglass")
                    .lineLimit(1)
                    .allowsTightening(true)
            }
            .buttonStyle(SubtlePillButtonStyle(emphasized: false, sizeScale: buttonScale))

            Button(action: onRead) {
                Label("Read", systemImage: "book")
                    .lineLimit(1)
                    .allowsTightening(true)
            }
            .buttonStyle(SubtlePillButtonStyle(emphasized: false, sizeScale: buttonScale))

            Button(action: onFavorites) {
                Label("Favorites", systemImage: "heart")
                    .lineLimit(1)
                    .allowsTightening(true)
            }
            .buttonStyle(SubtlePillButtonStyle(emphasized: false, sizeScale: buttonScale))
        }
    }
}
