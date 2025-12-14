import SwiftUI

struct DailyFocusCard: View {
    @Binding var focusTitle: String
    @Binding var focusBody: String
    @Binding var hasSavedFocus: Bool
    @Binding var focusSavedAt: Date?

    // Accept focus bindings from parent instead of declaring local @FocusState
    var focusTitleIsFocused: FocusState<Bool>.Binding
    var focusBodyIsFocused: FocusState<Bool>.Binding

    @Binding var isFocusBodyExpanded: Bool

    let liveActivitiesEnabled: Bool

    // Actions provided by HomeView to keep behavior centralized
    let onSave: () -> Void
    let onClear: () -> Void
    let onEnableLiveActivities: () -> Void

    // Local popover state
    @State private var showFocusInfoPopover: Bool = false

    private var hasTitle: Bool {
        !focusTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasTypedLetter: Bool {
        let letters = CharacterSet.letters
        let t = focusTitle.unicodeScalars.contains { letters.contains($0) }
        let b = focusBody.unicodeScalars.contains { letters.contains($0) }
        return t || b
    }

    var body: some View {
        HeroCard(
            title: "Daily Focus",
            subtitle: nil,
            icon: "target",
            tint: .purple,
            trailingAccessory: {
                HStack(spacing: 8) {
                    if hasSavedFocus {
                        Text("Saved")
                            .font(.caption2).bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.green.opacity(0.15)))
                            .overlay(Capsule().stroke(Color.green.opacity(0.5), lineWidth: 1))
                            .foregroundStyle(.green)
                            .accessibilityHidden(false)
                            .accessibilityLabel("Saved Focus")
                    }
                    Button {
                        showFocusInfoPopover.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showFocusInfoPopover) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("About Daily Focus")
                                    .font(.headline)
                                Text("Type a title and optional notes, then save. Your focus will appear on the dynamic island (iPhone only) and the lock screen when live activities are enabled (enable/disable live activities from the app's settings menu).")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button("Got it") { showFocusInfoPopover = false }
                                    .buttonStyle(.borderedProminent)
                            }
                            .padding()
                        }
                        .presentationDetents([.medium, .large])
                    }
                }
            }
        ) {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Focus")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextField("What's your focus on today?", text: $focusTitle)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .focused(focusTitleIsFocused)
                }

                if hasTitle && isFocusBodyExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ZStack(alignment: .topLeading) {
                            if focusBody.isEmpty {
                                Text("Enter your focus notes…")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                            TextEditor(text: $focusBody)
                                .focused(focusBodyIsFocused)
                                .frame(minHeight: 120)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                                )
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button(action: onSave) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .green))
                    .controlSize(.regular)
                    .accessibilityLabel("Save Focus")
                    .accessibilityHint("Saves your daily focus and shows it on the Dynamic Island")
                    .disabled(!hasTypedLetter)

                    Button(action: onClear) {
                        Label("Clear", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(ModernPillButtonStyle(tint: .red))
                    .controlSize(.regular)
                    .accessibilityLabel("Clear Focus")
                    .accessibilityHint("Clears your daily focus and removes it from the Dynamic Island")
                    .disabled(!hasTitle)

                    if hasTitle {
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                isFocusBodyExpanded = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                focusBodyIsFocused.wrappedValue = true
                            }
                        } label: {
                            Image(systemName: "chevron.down.circle")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Show Notes")
                        .accessibilityHint("Opens the focus notes field")
                    }
                }
                .padding(.top, 4)
                .toolbar {
                    ToolbarItem(placement: .keyboard) {
                        Button("Done") {
                            focusTitleIsFocused.wrappedValue = false
                            focusBodyIsFocused.wrappedValue = false
                        }
                    }
                }

                if hasSavedFocus, let savedAt = focusSavedAt {
                    let cal = Calendar.current
                    let isToday = cal.isDateInToday(savedAt)
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(isToday ? "Today’s Focus saved at \(savedAt.formatted(date: .omitted, time: .shortened))"
                                     : "Focus saved on \(savedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.top, 2)
                }

                if !liveActivitiesEnabled {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "livephoto.slash")
                            .foregroundStyle(.secondary)
                        Text("Live Activities are off. Enable in Settings to show your Focus on the Lock Screen and Dynamic Island.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Button("Enable", action: onEnableLiveActivities)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(.purple)
                    }
                    .padding(.top, 6)
                }
            }
        }
    }
}
