import SwiftUI

/// Home card for the reader's focus for the day.
///
/// With nothing saved it is a single prompt field. Once saved it shows the focus as content,
/// with Edit and Clear controls; editing works on a draft until Save.
struct DailyFocusCard: View {
    let focus: FocusViewModel
    let liveActivitiesEnabled: Bool
    let onEnableLiveActivities: () -> Void

    private enum Field { case title, notes }

    @State private var isEditing = false
    @State private var draftTitle = ""
    @State private var draftBody = ""
    @State private var showsNotes = false
    @State private var isConfirmingClear = false
    @FocusState private var focusedField: Field?

    /// The Live Activities reminder appears after a save while they are off, until dismissed once.
    @AppStorage("focusLiveActivitiesHintDismissed") private var liveActivitiesHintDismissed = false

    private var showsSavedFocus: Bool { focus.hasSaved && !isEditing }

    private var canSave: Bool {
        focus.hasNonWhitespaceLetters(in: draftTitle) || focus.hasNonWhitespaceLetters(in: draftBody)
    }

    /// The empty state stays a lone prompt until the reader starts typing.
    private var showsEditorActions: Bool {
        focusedField != nil || canSave || showsNotes || isEditing
    }

    private var showsLiveActivitiesHint: Bool {
        showsSavedFocus && !liveActivitiesEnabled && !liveActivitiesHintDismissed
    }

    var body: some View {
        HeroCard(
            title: "Daily Focus",
            subtitle: nil,
            icon: "target",
            tint: .purple,
            trailingAccessory: { trailingControls }
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if showsSavedFocus {
                    savedFocus
                } else {
                    editor
                }

                if showsLiveActivitiesHint {
                    liveActivitiesHint
                }
            }
        }
        .confirmationDialog("Clear your focus?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear Focus", role: .destructive, action: clear)
        } message: {
            Text("It will also be removed from the Lock Screen.")
        }
    }

    // MARK: - Saved

    @ViewBuilder
    private var trailingControls: some View {
        if showsSavedFocus {
            HStack(spacing: 8) {
                Button("Edit", action: beginEditing)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.purple)
                    .accessibilityLabel("Edit Focus")

                Button("Clear", role: .destructive) {
                    isConfirmingClear = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.red)
                .accessibilityLabel("Clear Focus")
            }
        }
    }

    private var savedFocus: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !focus.title.isEmpty {
                Text(focus.title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !focus.body.isEmpty {
                Text(focus.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's focus")
        .accessibilityValue([focus.title, focus.body].filter { !$0.isEmpty }.joined(separator: ". "))
    }

    private var liveActivitiesHint: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "livephoto.slash")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Turn on Live Activities to see your focus on the Lock Screen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Enable") {
                liveActivitiesHintDismissed = true
                onEnableLiveActivities()
            }
            .buttonStyle(ModernPillButtonStyle(tint: .purple))
            .controlSize(.small)
            Button {
                liveActivitiesHintDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
    }

    // MARK: - Editing

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("What's your focus today?", text: $draftTitle)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.done)
                .focused($focusedField, equals: .title)
                .onSubmit {
                    if canSave { save() }
                }

            if showsNotes {
                ZStack(alignment: .topLeading) {
                    if draftBody.isEmpty {
                        Text("Notes")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .accessibilityHidden(true)
                    }
                    TextEditor(text: $draftBody)
                        .focused($focusedField, equals: .notes)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                        )
                        .accessibilityLabel("Focus Notes")
                }
            }

            if showsEditorActions {
                HStack(spacing: 12) {
                    Button(action: toggleNotes) {
                        Label(
                            showsNotes ? "Hide Notes" : "Add Notes",
                            systemImage: showsNotes ? "chevron.up" : "chevron.down"
                        )
                        .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.purple)

                    Spacer()

                    if isEditing {
                        Button("Cancel", action: cancelEditing)
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }

                    Button("Save", action: save)
                        .buttonStyle(ModernPillButtonStyle(tint: .purple))
                        .controlSize(.regular)
                        .disabled(!canSave)
                        .accessibilityLabel("Save Focus")
                }
            }

            if liveActivitiesEnabled {
                Text("Your saved focus appears on the Lock Screen and in the Dynamic Island.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        // No keyboard toolbar: the title's return key submits, and Home's scroll view
        // dismisses the keyboard interactively (which covers the multi-line notes).
    }

    // MARK: - Actions

    private func beginEditing() {
        draftTitle = focus.title
        draftBody = focus.body
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            // A notes-only focus opens with its notes showing so they can be edited.
            showsNotes = !focus.body.isEmpty
            isEditing = true
        }
        focusSoon(focus.title.isEmpty && !focus.body.isEmpty ? .notes : .title)
    }

    private func toggleNotes() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            showsNotes.toggle()
        }
        if showsNotes {
            focusSoon(.notes)
        } else if focusedField == .notes {
            focusedField = nil
        }
    }

    private func save() {
        guard canSave else { return }
        focus.save(title: draftTitle, body: draftBody)
        Haptics.success()
        endEditing()
    }

    private func cancelEditing() {
        endEditing()
    }

    private func clear() {
        focus.clear()
        Haptics.selection()
        endEditing()
    }

    private func endEditing() {
        focusedField = nil
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            isEditing = false
            showsNotes = false
        }
        draftTitle = ""
        draftBody = ""
    }

    /// Fields that are appearing need a moment to exist before they can take focus.
    private func focusSoon(_ field: Field) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            focusedField = field
        }
    }
}
