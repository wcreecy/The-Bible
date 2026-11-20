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
    var earnedSpeedBonus = false

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

            if earnedSpeedBonus {
                Label("+1 speed bonus", systemImage: "bolt.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
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


/// The four answers, shared by iPhone and iPad. Answers in a row match the taller one's
/// height, and each grows with its text, so nothing is cut off at large text sizes.
struct WhoAmIChoiceGrid: View {
    let vm: WhoAmIGameViewModel
    let columnCount: Int
    /// iPad uses slightly larger text for clue answers.
    let usesLargeText: Bool
    let onShowPencilMenu: () -> Void

    @Environment(\.preferredPencilSqueezeAction) private var preferredPencilSqueezeAction
    /// Each answer's frame, so a Pencil squeeze while hovering can pick the answer under it.
    @State private var optionFrames: [String: CGRect] = [:]
    private static let coordinateSpace = "whoChoiceGrid"

    var body: some View {
        let choices = vm.choices
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            ForEach(Array(stride(from: 0, to: choices.count, by: columnCount)), id: \.self) { start in
                GridRow {
                    ForEach(start..<min(start + columnCount, choices.count), id: \.self) { index in
                        option(at: index, choice: choices[index])
                    }
                }
            }
        }
        .coordinateSpace(.named(Self.coordinateSpace))
        // Squeezing while hovering over an answer chooses it; anywhere else opens the actions menu.
        .onPencilSqueeze { phase in
            guard preferredPencilSqueezeAction != .ignore, case .ended(let value) = phase else { return }
            if !vm.roundOver, let location = value.hoverPose?.location,
               let choice = optionFrames.first(where: { choices.contains($0.key) && $0.value.contains(location) })?.key,
               !vm.removedChoices.contains(choice) {
                vm.select(choice)
            } else {
                onShowPencilMenu()
            }
        }
        .onChange(of: choices) { _, _ in
            optionFrames = [:]
        }
    }

    private func option(at index: Int, choice: String) -> some View {
        let promptIsName = vm.currentPromptIsName
        let isRemoved = vm.removedChoices.contains(choice)
        let letter = GameAnswerLetter.letter(for: index)

        return Button {
            vm.select(choice)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(letter)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Color.primary.opacity(0.08), in: Circle())

                Text(choice)
                    .font(promptIsName ? (usesLargeText ? .subheadline : .footnote) : .body.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .strikethrough(isRemoved)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(promptIsName ? 16 : 12)
            .frame(maxWidth: .infinity, minHeight: promptIsName ? 88 : 44, maxHeight: .infinity, alignment: .leading)
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(vm.roundOver || isRemoved)
        .opacity(isRemoved ? 0.35 : 1)
        .accessibilityLabel("\(letter), \(choice)")
        .accessibilityValue(accessibilityState(for: choice, isRemoved: isRemoved))
        .background(backgroundColor(for: choice), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(borderColor(for: choice), lineWidth: vm.roundOver && choice == vm.correctChoice ? 2 : 1)
        }
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(Self.coordinateSpace))
        } action: { frame in
            optionFrames[choice] = frame
        }
    }

    private func accessibilityState(for choice: String, isRemoved: Bool) -> String {
        if isRemoved { return String(localized: "Removed") }
        guard vm.roundOver else { return "" }
        if choice == vm.correctChoice {
            return choice == vm.selectedChoice ? String(localized: "Your answer, correct") : String(localized: "Correct answer")
        }
        if choice == vm.selectedChoice { return String(localized: "Your answer, incorrect") }
        return ""
    }

    private func backgroundColor(for choice: String) -> Color {
        guard vm.roundOver else { return Color(.secondarySystemBackground) }
        if choice == vm.correctChoice { return .green.opacity(0.25) }
        if choice == vm.selectedChoice { return .red.opacity(0.25) }
        return Color(.secondarySystemBackground)
    }

    private func borderColor(for choice: String) -> Color {
        guard vm.roundOver else { return Color.primary.opacity(0.15) }
        if choice == vm.correctChoice { return .green }
        if choice == vm.selectedChoice { return .red }
        return Color.primary.opacity(0.15)
    }
}
