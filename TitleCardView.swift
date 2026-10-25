import Foundation
import SwiftUI

/// Home header shared by iPhone and iPad: a time-of-day greeting, today's reading goal
/// and streak, and quick actions. The layout adapts to the available width.
struct TitleCardView: View {
    let isPad: Bool
    let goalMinutes: Int
    let todayReadingSeconds: Int
    let streak: Int
    var date: Date = .now
    let onOpenGoal: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var iPadGreetingFontSize = 42

    private var goalSeconds: Int { max(1, goalMinutes) * 60 }
    private var readingMinutes: Int { max(0, todayReadingSeconds) / 60 }

    private var readingProgressValue: String {
        let seconds = max(0, todayReadingSeconds)
        guard seconds < 60 else { return "\(readingMinutes)" }
        return "0:\(String(format: "%02d", seconds))"
    }

    private var readingProgressAccessibilityValue: String {
        let seconds = max(0, todayReadingSeconds)
        if seconds < 60 {
            return "\(seconds) seconds"
        }
        return "\(readingMinutes) minutes"
    }

    private var isGoalMet: Bool { todayReadingSeconds >= goalSeconds }

    // Progress fraction 0...1 toward today's goal
    private var progress: Double {
        min(1.0, Double(max(0, todayReadingSeconds)) / Double(goalSeconds))
    }

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
        VStack(alignment: .leading, spacing: 10) {
            topRow
            goalSummary
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Goal and streak

    private var goalSummary: some View {
        Button(action: onOpenGoal) {
            VStack(alignment: .leading, spacing: 6) {
                goalText
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)

                ProgressView(value: progress)
                    .tint(isGoalMet ? .green : .accentColor)
                    .accessibilityHidden(true)

                if streak > 0 {
                    streakText
                        .font(.subheadline.weight(.semibold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(goalAccessibilityLabel)
        .accessibilityHint("Opens your reading stats")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var goalText: some View {
        if isGoalMet {
            Label {
                Text("Goal met · \(readingMinutes) min today")
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        } else {
            Label {
                Text("\(readingProgressValue) of \(goalMinutes) min today")
            } icon: {
                Image(systemName: "book")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var streakText: some View {
        Label {
            Text("\(streak)-day streak")
        } icon: {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
        }
    }

    private var goalAccessibilityLabel: String {
        var parts = ["\(readingProgressAccessibilityValue) of \(goalMinutes) minutes read today"]
        if isGoalMet { parts.insert("Daily goal met", at: 0) }
        if streak > 0 { parts.append("\(streak) day streak") }
        return parts.joined(separator: ". ")
    }

}


#Preview("In progress") {
    TitleCardView(
        isPad: false,
        goalMinutes: 30,
        todayReadingSeconds: 12 * 60,
        streak: 4,
        onOpenGoal: {}
    )
    .padding()
}

#Preview("Goal met") {
    TitleCardView(
        isPad: false,
        goalMinutes: 30,
        todayReadingSeconds: 34 * 60,
        streak: 5,
        onOpenGoal: {}
    )
    .padding()
}

#Preview("Afternoon greeting") {
    TitleCardView(
        isPad: false,
        goalMinutes: 30,
        todayReadingSeconds: 12 * 60,
        streak: 4,
        date: greetingPreviewDate(hour: 14),
        onOpenGoal: {}
    )
    .padding()
}

#Preview("Night greeting") {
    TitleCardView(
        isPad: false,
        goalMinutes: 30,
        todayReadingSeconds: 12 * 60,
        streak: 4,
        date: greetingPreviewDate(hour: 21),
        onOpenGoal: {}
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
