import SwiftUI

struct WhoAmITimingSummary: View {
    let timeouts: Int
    let remainingTimes: [Int]

    private var averageRemaining: Int {
        guard !remainingTimes.isEmpty else { return 0 }
        return remainingTimes.reduce(0, +) / remainingTimes.count
    }

    var body: some View {
        HStack {
            Label("\(timeouts) timeouts", systemImage: "clock.badge.exclamationmark")
            Spacer()
            Label("\(averageRemaining)s avg left", systemImage: "timer")
            if let fastest = remainingTimes.max() {
                Spacer()
                Label("\(fastest)s fastest", systemImage: "bolt.fill")
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(12)
        .background(Color.brown.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct WhoAmISetupControls: View {
    @Binding var mode: WhoAmIGameViewModel.Mode

    var body: some View {
        GameSettingsGroup {
            GameChoiceSetting(
                title: "How to play",
                systemImage: "person.text.rectangle",
                tint: .brown,
                selection: $mode,
                choices: WhoAmIGameViewModel.Mode.allCases.map {
                    GameChoice(value: $0, title: $0.title, detail: $0.detail, icon: $0.icon)
                }
            )
        }
    }
}

/// Who the answer was, and where they appear in the Bible.
struct WhoAmIRevealCard: View {
    let wasCorrect: Bool
    let wasTimedOut: Bool
    let person: WhoAmIGameViewModel.Entry
    let secondsRemaining: Int

    private static let shownBookCount = 6

    private var booksText: String {
        let shown = person.books.prefix(Self.shownBookCount).joined(separator: ", ")
        let remaining = person.books.count - Self.shownBookCount
        return remaining > 0 ? String(localized: "\(shown), and \(remaining) more") : shown
    }

    private var title: LocalizedStringKey {
        if wasCorrect { return "Correct!" }
        return wasTimedOut ? "Time’s up" : "Not quite"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.headline)
            .foregroundStyle(wasCorrect ? Color.green : Color.red)

            if wasCorrect, secondsRemaining > 0 {
                Text("Correct — \(secondsRemaining) seconds remaining")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
            }

            if let qualifier = person.qualifier {
                Text("\(person.name) (\(qualifier))")
                    .font(.title3.weight(.bold))
            } else {
                Text(person.name)
                    .font(.title3.weight(.bold))
            }

            DisclosureGroup("Why this answer?") {
                Text(person.clue)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !person.books.isEmpty {
                    Label("Appears in \(booksText)", systemImage: "books.vertical")
                        .font(.subheadline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            (wasCorrect ? Color.green : Color.red).opacity(0.1),
            in: RoundedRectangle(cornerRadius: AppDesignMetrics.cardCornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

struct WhoAmITimerCard: View {
    let isTimed: Bool
    let remainingSeconds: Int
    let tint: Color
    let isActive: Bool
    let isTimerDisabled: Bool
    let isPulsing: Bool
    let resultIsCorrect: Bool?
    @Binding var usesMutedStyle: Bool
    let onSwapSides: () -> Void
    let onToggleTimer: () -> Void

    private var usesVividStyle: Bool {
        isTimed && !isTimerDisabled && !usesMutedStyle
    }

    private var timerTextColor: Color {
        tint == .yellow ? .black : .white
    }

    private var displayTint: Color {
        if isTimerDisabled, resultIsCorrect == nil { return .secondary }
        guard !isActive, let resultIsCorrect else { return tint }
        return resultIsCorrect ? .green : .red
    }

    private var vividTextColor: Color {
        isActive ? timerTextColor : .white
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            VStack(spacing: 24) {
                Image(systemName: statusSystemImage)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(
                        usesVividStyle
                            ? vividTextColor.opacity(0.85)
                            : statusTint
                    )

                Text(statusTitle)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(
                        usesVividStyle
                            ? vividTextColor.opacity(0.85)
                            : statusTint
                    )

                if isTimed && isActive {
                    Text("\(remainingSeconds)s")
                        .font(.largeTitle.weight(.bold))
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(usesVividStyle ? vividTextColor : displayTint)
                }
            }
            .scaleEffect(isPulsing ? 1.04 : 1)
            .animation(.easeOut(duration: 0.18), value: isPulsing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(statusTitle)
            .accessibilityValue(isTimed && isActive ? "\(remainingSeconds) seconds" : "")
            .contentShape(Rectangle())
            .onTapGesture {
                if isTimed && resultIsCorrect == nil {
                    onToggleTimer()
                }
            }
            .accessibilityAddTraits(isTimed && resultIsCorrect == nil ? .isButton : [])
            .accessibilityHint(
                isTimed && resultIsCorrect == nil
                    ? (isTimerDisabled ? "Tap to turn the timer on." : "Tap to turn the timer off.")
                    : ""
            )

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                if isTimed, resultIsCorrect == nil {
                    Button(
                        isTimerDisabled ? "Turn timer on" : "Turn timer off",
                        systemImage: isTimerDisabled ? "timer" : "timer.slash",
                        action: onToggleTimer
                    )
                }

                Button(
                    "Swap card sides",
                    systemImage: "arrow.left.arrow.right",
                    action: onSwapSides
                )

                if isTimed {

                    Button(
                        usesMutedStyle ? "Use vivid timer background" : "Use muted timer background",
                        systemImage: "circle.lefthalf.filled"
                    ) {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            usesMutedStyle.toggle()
                        }
                    }
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glass(.clear))
            .controlSize(.small)
            .tint(usesVividStyle ? vividTextColor : displayTint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(
            usesVividStyle ? displayTint : Color.clear,
            in: RoundedRectangle(
                cornerRadius: AppDesignMetrics.cardCornerRadius,
                style: .continuous
            )
        )
        .heroCardSurface()
    }

    /// Untimed games still show the result once the question is answered.
    private var statusTitle: LocalizedStringKey {
        if let resultIsCorrect, !isActive {
            return resultIsCorrect ? "Correct" : "Incorrect"
        }
        if isTimerDisabled { return "Timer Off" }
        return isTimed ? "Time Remaining" : "Untimed"
    }

    private var statusSystemImage: String {
        if let resultIsCorrect, !isActive {
            return resultIsCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
        }
        if isTimerDisabled { return "timer.slash" }
        return isTimed ? "timer" : "infinity"
    }

    private var statusTint: Color {
        if let resultIsCorrect, !isActive {
            return resultIsCorrect ? .green : .red
        }
        if isTimerDisabled { return .secondary }
        return isTimed ? tint : .secondary
    }
}

