#if DEBUG
import SwiftUI

struct DailyWordScheduleRegenerationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onRegenerate: (Date) -> Void

    @State private var startDate = Date()
    @State private var confirmationText = ""

    private var isConfirmed: Bool {
        confirmationText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "continue"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule Start") {
                    DatePicker("First Daily WORD", selection: $startDate, in: Date()..., displayedComponents: .date)
                    Text("This is the first date the new shuffled schedule is used in production.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Confirm") {
                    Text("This will change the Daily WORD list for the next production release.")
                    TextField("Type continue to proceed", text: $confirmationText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("New Daily WORD Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Regenerate & Export") {
                        onRegenerate(startDate)
                        dismiss()
                    }
                    .disabled(!isConfirmed)
                }
            }
        }
    }
}
#endif
