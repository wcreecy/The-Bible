import SwiftUI

struct BookOrderGameView: View {
    @StateObject private var vm = BookOrderGameViewModel()
    @State private var howToExpanded: Bool = false
    @State private var difficultyExpanded: Bool = false

    private var currentPercent: Double { vm.answered > 0 ? Double(vm.score) / Double(vm.answered) : 0 }
    private var allTimePercent: Double { vm.allTimeAnswered > 0 ? Double(vm.allTimeCorrect) / Double(vm.allTimeAnswered) : 0 }

    var body: some View {
        VStack {
            if !vm.started {
                VStack(spacing: 16) {
                    Text("Rearrange the books in the correct order.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 10) {
                        GroupBox {
                            DisclosureGroup(isExpanded: $howToExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Choose a source (OT/NT) and difficulty, then tap Start.")
                                    Text("• Drag the rows to arrange the books in canonical order.")
                                    Text("• Tap Check to see results; then tap Next for a new round.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("How to Play").font(.headline)
                            }
                        }

                        GroupBox {
                            DisclosureGroup(isExpanded: $difficultyExpanded) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("• Easy: Arrange 5 books.")
                                    Text("• Normal: Arrange 10 books.")
                                    Text("• Hard: Arrange 15 books.")
                                    Text("• All Books: Arrange the entire selected canon.")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } label: {
                                Text("Difficulty Levels").font(.headline)
                            }
                        }
                    }
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
