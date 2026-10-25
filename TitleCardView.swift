import Foundation
import SwiftUI

/// Home header shared by iPhone and iPad with a time-of-day greeting and date.
struct TitleCardView: View {
    let isPad: Bool
    var date: Date = .now

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var iPadGreetingFontSize = 42

    private enum GreetingScene {
        case sunrise
        case afternoon
        case evening
        case night

        var greeting: String {
            switch self {
            case .sunrise:
                "Good Morning"
            case .afternoon:
                "Good Afternoon"
            case .evening:
                "Good Evening"
            case .night:
                "Good Night"
            }
        }

        var imageName: String {
            switch self {
            case .sunrise:
                "GreetingSunrise"
            case .afternoon:
                "GreetingAfternoon"
            case .evening:
                "GreetingEvening"
            case .night:
                "GreetingNight"
            }
        }

        var quickActionForeground: Color {
            switch self {
            case .afternoon:
                .black
            case .sunrise, .evening, .night:
                .white
            }
        }

        var quickActionBackdrop: Color {
            switch self {
            case .afternoon:
                .white.opacity(0.72)
            case .sunrise, .evening, .night:
                .black.opacity(0.52)
            }
        }
    }

    private var greetingScene: GreetingScene {
        let hour = Calendar.current.component(.hour, from: date)

        switch hour {
        case 5..<12:
            return .sunrise
        case 12..<18:
            return .afternoon
        case 18..<21:
            return .evening
        default:
            return .night
        }
    }

    private var greeting: String { greetingScene.greeting }

    var body: some View {
        topRow
        // Keep a generous header while allowing it to expand for larger text sizes.
        .frame(
            maxWidth: .infinity,
            minHeight: isPad ? 88 : 72,
            alignment: .topLeading
        )
        .padding(.horizontal, 20)
        .padding(.vertical, isPad ? 28 : 20)
        .foregroundStyle(.white)
        .background {
            Image(greetingScene.imageName)
                .resizable()
                .scaledToFill()
                .overlay {
                    LinearGradient(
                        colors: [.black.opacity(0.58), .black.opacity(0.18)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .padding(.top, 4)
    }

    // MARK: - Greeting row

    @ViewBuilder
    private var topRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                greetingText
                dateText
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                greetingText
                Spacer(minLength: 8)
                dateText
            }
        }
    }

    private var greetingText: some View {
        Text(greeting)
            .font(
                isPad
                    ? .system(size: iPadGreetingFontSize, weight: .black)
                    : .title.weight(.black)
            )
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityAddTraits(.isHeader)
    }

    private var dateText: some View {
        Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
    }

}


#Preview("Morning greeting") {
    TitleCardView(
        isPad: false,
        date: greetingPreviewDate(hour: 8)
    )
    .padding()
}

#Preview("Afternoon greeting") {
    TitleCardView(
        isPad: false,
        date: greetingPreviewDate(hour: 14)
    )
    .padding()
}

#Preview("Night greeting") {
    TitleCardView(
        isPad: false,
        date: greetingPreviewDate(hour: 21)
    )
    .padding()
}

private func greetingPreviewDate(hour: Int) -> Date {
    Calendar.current.date(
        bySettingHour: hour,
        minute: 0,
        second: 0,
        of: .now
    ) ?? .now
}
