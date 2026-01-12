import SwiftUI

struct SettingsDailyGoalSection: View {
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 30

    @State private var isDailyGoalSheetPresented: Bool = false
    @State private var localDailyGoalMinutes: Int = 30

    var body: some View {
        Section(
            header: Text("Daily Goal").foregroundStyle(.white),
            footer: Text("Set the number of minutes you want to spend in the app each day. Your Daily Bible Streak is based on meeting this goal.")
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.7))
        ) {
            // Wrap in a container and attach .sheet here to avoid Section-hosting conflicts
            VStack(spacing: 0) {
                Button {
                    guard !isDailyGoalSheetPresented else { return }
                    localDailyGoalMinutes = dailyGoalMinutes
                    isDailyGoalSheetPresented = true
                } label: {
                    HStack {
                        Label("Daily Goal", systemImage: "target")
                            .foregroundStyle(.blue)
                        Spacer()
                        Text("\(dailyGoalMinutes) min")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("dailyGoalMinutesPickerLink")
            }
            .sheet(isPresented: $isDailyGoalSheetPresented) {
                NavigationStack {
                    VStack {
                        Picker("", selection: $localDailyGoalMinutes) {
                            ForEach(1...240, id: \.self) { m in
                                Text("\(m) minute\(m == 1 ? "" : "s")").tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .accessibilityIdentifier("dailyGoalMinutesWheel")
                    }
                    .navigationTitle("Daily Goal")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isDailyGoalSheetPresented = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                dailyGoalMinutes = localDailyGoalMinutes
                                // Record a change effective today so past days keep their prior goal
                                DailyGoalHistoryStore.shared.recordChange(minutes: localDailyGoalMinutes, at: Date())
                                // Also push the simple key for legacy consumers and other devices
                                iCloudSyncCoordinator.shared.pushKey("dailyGoalMinutes")
                                isDailyGoalSheetPresented = false
                            }
                        }
                    }
                    .presentationDetents([.medium, .large])
                }
            }
        }
        .headerProminence(.increased)
        .onAppear {
            // Ensure there is a baseline history so older days evaluate consistently
            DailyGoalHistoryStore.shared.ensureSeededIfNeeded()
        }
    }
}
