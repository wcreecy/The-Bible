import SwiftUI

struct SettingsDailyGoalSection: View {
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 30

    @State private var isDailyGoalSheetPresented: Bool = false

    var body: some View {
        Section(
            header: Text("Daily Goal").foregroundStyle(.primary),
            footer: Text("Set the number of minutes you want to spend in the app each day. Your Daily Bible Streak is based on meeting this goal.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        ) {
            // Wrap in a container and attach .sheet here to avoid Section-hosting conflicts
            VStack(spacing: 0) {
                Button {
                    guard !isDailyGoalSheetPresented else { return }
                    isDailyGoalSheetPresented = true
                } label: {
                    HStack {
                        Label("Daily Goal", systemImage: "target")
                            .foregroundStyle(Color.accentColor)
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
                DailyGoalEditorView()
            }
        }
        .headerProminence(.increased)
        .onAppear {
            // Ensure there is a baseline history so older days evaluate consistently
            DailyGoalHistoryStore.shared.ensureSeededIfNeeded()
        }
    }
}

struct DailyGoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("dailyGoalMinutes") private var dailyGoalMinutes: Int = 30

    @State private var selectedMinutes: Int = 30

    var body: some View {
        NavigationStack {
            Picker("Daily Goal", selection: $selectedMinutes) {
                ForEach(1...240, id: \.self) { minutes in
                    Text("\(minutes) minute\(minutes == 1 ? "" : "s")").tag(minutes)
                }
            }
            .pickerStyle(.wheel)
            .accessibilityIdentifier("dailyGoalMinutesWheel")
            .navigationTitle("Daily Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dailyGoalMinutes = selectedMinutes
                        DailyGoalHistoryStore.shared.recordChange(minutes: selectedMinutes, at: Date())
                        iCloudSyncCoordinator.shared.pushKey("dailyGoalMinutes")
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedMinutes = dailyGoalMinutes
            }
        }
        .presentationDetents([.medium, .large])
    }
}
