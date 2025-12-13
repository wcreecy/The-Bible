import SwiftUI

struct WhoAmIGameView: View {
    @StateObject private var vm = WhoAmIGameViewModel()
    @State private var maxChoiceHeight: CGFloat = 0

    // Collects the maximum measured height from all choice cells
    private struct ChoiceHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if !vm.started {
                    Spacer(minLength: 24)
                    Text("Match Bible names and descriptions.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        GroupBox {
                            DisclosureGroup(isExpanded: $vm.howToExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Choose a mode and difficulty, then tap Start.")
                                    Text("• Names: You’ll see a name; pick the correct description.")
                                    Text("• Reverse: You’ll see a description; pick the correct name.")
                                    Text("• In timed modes, answer before the clock runs out.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("How to Play").font(.headline)
                            }
                        }

                        GroupBox {
                            DisclosureGroup(isExpanded: $vm.difficultyExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Easy: No timer.")
                                    Text("• Normal: 30 seconds per question.")
                                    Text("• Hard: 15 seconds per question.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("Difficulty Levels").font(.headline)
                            }
                        }
                    }
                    .padding(.horizontal)

                    Picker("Mode", selection: $vm.mode) {
                        ForEach(WhoAmIGameViewModel.Mode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Picker("Difficulty", selection: $vm.difficulty) {
                        ForEach(WhoAmIGameViewModel.Difficulty.allCases) { d in
                            switch d {
                            case .easy: Text("Easy").tag(d)
                            case .normal: Text("Normal").tag(d)
                            case .hard: Text("Hard").tag(d)
                            }
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Button("Start") { vm.startGame() }
                        .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                        .controlSize(.large)
                        .frame(maxWidth: 240)
                    Spacer(minLength: 24)
                } else {
                    // Scoreboard
                    GameScoreboardCard(
                        currentCorrect: vm.score,
                        currentAnswered: vm.answered,
                        currentStreak: vm.currentStreak,
                        allTimeCorrect: vm.allTimeCorrect,
                        allTimeAnswered: vm.allTimeAnswered,
                        allTimeBestStreak: vm.allTimeBestStreak
                    )

                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(vm.mode == .names ? "Name" : "Description")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if vm.difficulty.timeLimit > 0 && !vm.roundOver && vm.selectedChoice == nil {
                                    HStack(spacing: 6) {
                                        Image(systemName: "timer")
                                        Text("\(vm.remainingSeconds)s")
                                            .monospacedDigit()
                                    }
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(timerTint(vm.remainingSeconds))
                                    .scaleEffect(vm.pulseOn ? 1.12 : 1.0)
                                    .animation(.easeInOut(duration: 0.25), value: vm.pulseOn)
                                }
                            }
                            Text(vm.promptTitle)
                                .font(vm.mode == .names ? .title2.weight(.semibold) : .body)
                                .lineLimit(6)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose one:")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            ForEach(vm.choices, id: \.self) { choice in
                                Button {
                                    vm.select(choice)
                                } label: {
                                    // Uniform-sized, leading-aligned, multi-line text inside each cell
                                    Text(choice)
                                        .font(.footnote) // smaller to fit more text
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(6) // allow one more line
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(
                                            maxWidth: .infinity,
                                            minHeight: max(maxChoiceHeight, 78),
                                            maxHeight: max(maxChoiceHeight, 78),
                                            alignment: .leading
                                        )
                                        .padding()
                                        .foregroundStyle(.primary)
                                        .background(
                                            GeometryReader { geo in
                                                Color.clear
                                                    .preference(key: ChoiceHeightKey.self, value: geo.size.height)
                                            }
                                        )
                                }
                                .disabled(vm.roundOver)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(backgroundColor(for: choice))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(
                                            borderColor(for: choice),
                                            lineWidth: vm.roundOver && choice == vm.correctChoice ? 2 : 1
                                        )
                                )
                            }
                        }
                        .onPreferenceChange(ChoiceHeightKey.self) { value in
                            // Update max height from measured cells
                            maxChoiceHeight = value
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Skip") { vm.skipOrTimeout() }
                            .buttonStyle(ModernPillButtonStyle(tint: .orange))
                            .disabled(vm.roundOver)
                        Button("Next") { vm.nextRound() }
                            .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                            .disabled(!vm.roundOver)
                    }

                    if vm.showReveal {
                        Text(revealText())
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Who am I?")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.onAppear() }
        .onChange(of: vm.choices) { _, _ in
            // Reset measurement when the choices set changes (new question)
            maxChoiceHeight = 0
        }
    }

    private func backgroundColor(for choice: String) -> Color {
        guard vm.roundOver else { return Color(.secondarySystemBackground) }
        if choice == vm.correctChoice { return .green.opacity(0.25) }
        if let sel = vm.selectedChoice, sel == choice, choice != vm.correctChoice { return .red.opacity(0.25) }
        return Color(.secondarySystemBackground)
    }

    private func borderColor(for choice: String) -> Color {
        guard vm.roundOver else { return Color.primary.opacity(0.15) }
        if choice == vm.correctChoice { return .green }
        if let sel = vm.selectedChoice, sel == choice, choice != vm.correctChoice { return .red }
        return Color.primary.opacity(0.15)
    }

    private func revealText() -> String {
        if vm.mode == .names {
            return "Correct description: \(vm.correctChoice)"
        } else {
            return "Correct name: \(vm.correctChoice)"
        }
    }

    private func timerTint(_ secs: Int) -> Color {
        if secs <= 5 { return .red }
        if secs <= 10 { return .yellow }
        return .green
    }
}

#Preview {
    NavigationStack {
        WhoAmIGameView()
    }
}
