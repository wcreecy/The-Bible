import SwiftUI

struct BookOrderGameView: View {
    @StateObject private var vm = BookOrderGameViewModel()

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
                    Button("Start") {
                        vm.startGame()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                Spacer()
            } else {
                VStack(spacing: 12) {
                    // Scoreboard
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Current")
                                    .font(.subheadline)
                                    .bold()
                                HStack {
                                    Text("Score:")
                                    Spacer()
                                    Text("\(vm.currentScore)")
                                }
                                HStack {
                                    Text("Answered:")
                                    Spacer()
                                    Text("\(vm.currentAnswered)")
                                }
                                HStack {
                                    Text("Streak:")
                                    Spacer()
                                    Text("\(vm.currentStreak)")
                                }
                                HStack {
                                    Text("Percent:")
                                    Spacer()
                                    Text(vm.currentPercent, format: .percent)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("All-time")
                                    .font(.subheadline)
                                    .bold()
                                HStack {
                                    Text("Score:")
                                    Spacer()
                                    Text("\(vm.allTimeScore)")
                                }
                                HStack {
                                    Text("Answered:")
                                    Spacer()
                                    Text("\(vm.allTimeAnswered)")
                                }
                                HStack {
                                    Text("Streak:")
                                    Spacer()
                                    Text("\(vm.allTimeStreak)")
                                }
                                HStack {
                                    Text("Percent:")
                                    Spacer()
                                    Text(vm.allTimePercent, format: .percent)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .font(.footnote)
                        .padding(8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }

                    // Prompt
                    Text(vm.prompt)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding(.vertical)

                    // Reorderable list
                    List {
                        ForEach(vm.currentItems, id: \.self) { item in
                            Text(item)
                        }
                        .onMove(perform: vm.move)
                    }
                    .environment(\.editMode, .constant(EditMode.active))
                    .toolbar {
                        EditButton()
                    }

                    // Check Button
                    Button("Check") {
                        vm.checkOrder()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.currentItems.isEmpty || vm.showResult)

                    // Result feedback
                    if vm.showResult {
                        if vm.correct {
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
                                    GroupBox("Correct Order") {
                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(vm.correctOrder, id: \.self) { book in
                                                Text(book)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            .padding(.top)
                        }
                        Button("Next") {
                            vm.nextRound()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 10)
                    }
                }
                .padding()
                Spacer()
            }
        }
        .navigationTitle("Book Order")
    }
}

#Preview {
    NavigationStack {
        BookOrderGameView()
    }
}
