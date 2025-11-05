import SwiftUI

struct BookOrderGameView: View {
    @StateObject private var vm = BookOrderGameViewModel()

    struct GameProminentButtonStyle: ButtonStyle {
        var tint: Color = .accentColor

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(tint)
                        .shadow(color: .black.opacity(configuration.isPressed ? 0.05 : 0.12), radius: configuration.isPressed ? 2 : 6, x: 0, y: configuration.isPressed ? 1 : 3)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
        }
    }

    struct ModernPillButtonStyle: ButtonStyle {
        var tint: Color

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(tint)
                .padding(.vertical, 10)
                .padding(.horizontal, 14)
                .background(
                    .ultraThinMaterial,
                    in: Capsule(style: .continuous)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(tint.opacity(configuration.isPressed ? 0.6 : 0.35), lineWidth: configuration.isPressed ? 2 : 1)
                )
                .shadow(color: .black.opacity(configuration.isPressed ? 0.04 : 0.08), radius: configuration.isPressed ? 1 : 3, x: 0, y: configuration.isPressed ? 0 : 2)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.85), value: configuration.isPressed)
        }
    }

    private var currentPercent: Double { vm.answered > 0 ? Double(vm.score) / Double(vm.answered) : 0 }
    private var allTimePercent: Double { vm.allTimeAnswered > 0 ? Double(vm.allTimeCorrect) / Double(vm.allTimeAnswered) : 0 }

    var body: some View {
        VStack {
            if !vm.started {
                VStack(spacing: 16) {
                    Text("Book Order")
                        .font(.largeTitle)
                        .bold()
                    Text("Rearrange the books in the correct order.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Source on top: OT/NT, OT, NT
                    Picker("Source", selection: $vm.source) {
                        Text("OT/NT").tag(BookSourceScope.both)
                        Text("OT").tag(BookSourceScope.ot)
                        Text("NT").tag(BookSourceScope.nt)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Difficulty below: Easy, Normal, Hard, All Books
                    Picker("Difficulty", selection: $vm.difficulty) {
                        ForEach(BookOrderDifficulty.allCases) { difficulty in
                            switch difficulty {
                            case .easy: Text("Easy").tag(difficulty)
                            case .normal: Text("Normal").tag(difficulty)
                            case .hard: Text("Hard").tag(difficulty)
                            case .all: Text("All Books").tag(difficulty)
                            }
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    Button("Start") {
                        vm.startGame()
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                    .controlSize(.large)
                    .frame(maxWidth: 240)
                }
                .padding()
                Spacer()
            } else {
                VStack(spacing: 12) {
                    // Scoreboard
                    VStack(alignment: .leading, spacing: 8) {
                        // Header labels
                        HStack {
                            Text("")
                                .frame(width: 80, alignment: .leading)
                            Text("Correct").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                            Text("Total").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                            Text("Streak").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                            Text("Percent").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        // Current session row
                        HStack {
                            Text("Current").font(.subheadline).frame(width: 80, alignment: .leading)
                            Text("\(vm.score)").frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(vm.answered)").frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(vm.currentBestStreak)")
                                .foregroundStyle(vm.currentStreak == vm.currentBestStreak && vm.currentBestStreak > 0 ? .green : .primary)
                                .animation(.easeInOut(duration: 0.2), value: vm.currentBestStreak)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(String(format: "%d%%", Int(round(currentPercent * 100)))).frame(maxWidth: .infinity, alignment: .leading)
                        }
                        // All-time row
                        HStack {
                            Text("All-time").font(.subheadline).frame(width: 80, alignment: .leading)
                            Text("\(vm.allTimeCorrect)").frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(vm.allTimeAnswered)").frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(vm.allTimeBestStreak)").frame(maxWidth: .infinity, alignment: .leading)
                            Text(String(format: "%d%%", Int(round(allTimePercent * 100)))).frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)

                    List {
                        ForEach(vm.currentItems, id: \.self) { item in
                            Text(item)
                                .font(.footnote)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .onMove(perform: vm.move)
                    }
                    .environment(\.editMode, .constant(EditMode.active))

                    HStack(spacing: 16) {
                        Button(action: { vm.checkOrder() }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Check")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(GameProminentButtonStyle(tint: .accentColor))
                        .disabled(vm.showResult)
                        .controlSize(.regular)

                        if vm.showResult {
                            Button(action: {
                                vm.showResult = false
                                vm.showingCorrectOrder = false
                                vm.nextRound()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.right.circle.fill")
                                    Text("Next")
                                }
                            }
                            .buttonStyle(ModernPillButtonStyle(tint: .accentColor))
                            .controlSize(.regular)
                        }
                    }
                    .padding(.top)

                    if vm.showResult {
                        if vm.wasCorrect {
                            Text("Correct!")
                                .font(.headline)
                                .foregroundColor(.green)
                                .padding(.top)
                        } else {
                            VStack(spacing: 8) {
                                Text("Not quite.")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                if vm.showingCorrectOrder {
                                    GroupBox("Your Order vs Correct") {
                                        if vm.shouldShowComparison {
                                            VStack(alignment: .leading, spacing: 8) {
                                                HStack {
                                                    Text("Your order").font(.subheadline).foregroundStyle(.secondary)
                                                    Spacer()
                                                    Text("Correct order").font(.subheadline).foregroundStyle(.secondary)
                                                }
                                                ForEach(Array(vm.comparisonRows.enumerated()), id: \.offset) { _, row in
                                                    HStack {
                                                        Text(row.your)
                                                            .foregroundStyle(row.isMatch ? .green : .red)
                                                        Spacer()
                                                        Text(row.correct)
                                                    }
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        } else {
                                            // Fallback: show only the correct order if we don't have a submission
                                            VStack(alignment: .leading, spacing: 4) {
                                                ForEach(vm.correctOrder, id: \.self) { book in
                                                    Text(book)
                                                }
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                            }
                            .padding(.top)
                        }
                    }
                }
                .padding()
                Spacer()
            }
        }
        .navigationTitle("Book Order")
        .toolbar {
            if vm.started {
                EditButton()
            }
        }
    }
}

#Preview {
    NavigationStack {
        BookOrderGameView()
    }
}
