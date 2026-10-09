import SwiftUI

/// Home header shared by iPhone and iPad: a time-of-day greeting, today's reading goal
/// and streak, and quick actions. The layout adapts to the available width.
struct TitleCardView: View {
    let isPad: Bool
    let goalMinutes: Int
    let todayReadingSeconds: Int
    let streak: Int
    let onSearch: () -> Void
    let onFavorites: () -> Void
    let onOpenGoal: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var goalSeconds: Int { max(1, goalMinutes) * 60 }
    private var readingMinutes: Int { max(0, todayReadingSeconds) / 60 }
    private var isGoalMet: Bool { todayReadingSeconds >= goalSeconds }

    // Progress fraction 0...1 toward today's goal
    private var progress: Double {
        min(1.0, Double(max(0, todayReadingSeconds)) / Double(goalSeconds))
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
        VStack(alignment: .leading, spacing: 10) {
            topRow
            goalSummary
            if !isPad {
                actionButtons
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .adaptiveBackgroundForeground(tab: .home)
    }

    // MARK: - Greeting row

    @ViewBuilder
    private var topRow: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 4) {
                greetingText
                dateText
                if isPad { actionButtons }
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                greetingText
                Spacer(minLength: 8)
                dateText
                if isPad { actionButtons }
            }
        }
    }

    private var greetingText: some View {
        Text(greeting)
            .font(.largeTitle.weight(.black))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .accessibilityAddTraits(.isHeader)
    }

    private var dateText: some View {
        Text(Date(), format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
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
                Text("Goal met · \(readingMinutes) min today\(streakSuffix)")
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        } else if streak > 0 {
            Label {
                Text("\(streak)-day streak · \(readingMinutes) of \(goalMinutes) min today")
            } icon: {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
            }
        } else {
            // A zero streak is left out rather than shown as discouraging feedback.
            Label {
                Text("\(readingMinutes) of \(goalMinutes) min today")
            } icon: {
                Image(systemName: "book")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var streakSuffix: String {
        streak > 0 ? " · \(streak)-day streak" : ""
    }

    private var goalAccessibilityLabel: String {
        var parts = ["\(readingMinutes) of \(goalMinutes) minutes read today"]
        if isGoalMet { parts.insert("Daily goal met", at: 0) }
        if streak > 0 { parts.append("\(streak) day streak") }
        return parts.joined(separator: ". ")
    }

    // MARK: - Quick actions

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: onSearch) {
                Label("Search", systemImage: "magnifyingglass")
                    .lineLimit(1)
            }
            .buttonStyle(SubtlePillButtonStyle(emphasized: false))

            Button(action: onFavorites) {
                Label("Favorites", systemImage: "heart")
                    .lineLimit(1)
            }
            .buttonStyle(SubtlePillButtonStyle(emphasized: false))
        }
    }
}

#Preview("In progress") {
    TitleCardView(
        isPad: false,
        goalMinutes: 30,
        todayReadingSeconds: 12 * 60,
        streak: 4,
        onSearch: {},
        onFavorites: {},
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
        onSearch: {},
        onFavorites: {},
        onOpenGoal: {}
    )
    .padding()
}
