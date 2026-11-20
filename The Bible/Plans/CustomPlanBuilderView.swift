import SwiftUI

/// Builds a plan for one book: choose the book, how to read it, and how many days.
struct CustomPlanBuilderView: View {
    @Environment(\.planNavigation) private var navigation
    @State private var store = ReadingPlanStore.shared

    @State private var bookName: String
    @State private var style: CustomPlanStyle = .inOrder
    @State private var dayCount = 21

    /// Opens with `initialBook` chosen, such as the book being studied.
    init(initialBook: String? = nil) {
        _bookName = State(initialValue: initialBook ?? "John")
    }

    private var verseCounts: [Int] { ReadingPlanStore.verseCounts(forBook: bookName) }
    private var highlights: [CustomPlanGenerator.Highlight] { store.highlights(forBook: bookName) }

    private var dayRange: ClosedRange<Int> {
        CustomPlanGenerator.dayRange(for: style, verseCounts: verseCounts, highlights: highlights)
    }

    private var previewDays: [PlanDay] {
        CustomPlanGenerator.makeDays(
            bookName: bookName,
            verseCounts: verseCounts,
            highlights: highlights,
            style: style,
            dayCount: dayCount
        )
    }

    var body: some View {
        Form {
            Section("Book") {
                Picker("Book", selection: $bookName) {
                    ForEach(BibleData.books, id: \.name) { book in
                        Text(book.name).tag(book.name)
                    }
                }
                .pickerStyle(.navigationLink)

                Text(bookSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(HeroCardListRowBackground())

            Section {
                ForEach(CustomPlanStyle.allCases) { option in
                    styleRow(option)
                }
            } header: {
                Text("Reading Style")
            } footer: {
                if !CustomPlanGenerator.isAvailable(.majorPoints, highlights: highlights) {
                    Text("Major Points and Skip Around aren't available for \(bookName): it's short enough to read in full.")
                }
            }
            .listRowBackground(HeroCardListRowBackground())

            Section {
                Stepper(value: $dayCount, in: dayRange) {
                    HStack {
                        Text("Days")
                        Spacer()
                        Text("\(dayCount)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                let presets = [7, 14, 30, 60, 90].filter { dayRange.contains($0) }
                if !presets.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(presets, id: \.self) { preset in
                            Button("\(preset)") { dayCount = preset }
                                .buttonStyle(PresetButtonStyle(isSelected: dayCount == preset))
                                .accessibilityAddTraits(dayCount == preset ? .isSelected : [])
                        }
                    }
                }
            } header: {
                Text("Finish In")
            } footer: {
                Text(paceSummary)
            }
            .listRowBackground(HeroCardListRowBackground())

            Section("Preview") {
                let days = previewDays
                ForEach(days.prefix(3)) { day in
                    previewRow(day)
                }
                if days.count > 4 {
                    Text("…")
                        .foregroundStyle(.secondary)
                }
                if days.count > 3, let last = days.last {
                    previewRow(last)
                }
            }
            .listRowBackground(HeroCardListRowBackground())

            Section {
                Button {
                    guard let id = store.createCustomPlan(bookName: bookName, dayCount: dayCount, style: style) else { return }
                    Haptics.success()
                    // The new plan takes the builder's place, so Back skips the builder.
                    navigation?.replaceLast(.readingPlan(id: id))
                } label: {
                    // Text only: inside a list row, a filled button's icon takes the button's own color.
                    Text("Create and Start Plan")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .disabled(!store.canCreateCustomPlan)
            } footer: {
                if !store.canCreateCustomPlan {
                    Text(store.limitMessage)
                }
            }
            .listRowBackground(Color.clear)
        }
        .scrollContentBackground(.hidden)
        .tabBarContentClearance()
        .background(AppBackgroundView(tab: .bible))
        .navigationTitle("New Plan")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: resetDays)
        .onChange(of: bookName) {
            if !CustomPlanGenerator.isAvailable(style, highlights: highlights) {
                style = .inOrder
            }
            resetDays()
        }
        .onChange(of: style) { resetDays() }
    }

    private func styleRow(_ option: CustomPlanStyle) -> some View {
        let isAvailable = CustomPlanGenerator.isAvailable(option, highlights: highlights)
        return Button {
            style = option
        } label: {
            HStack(spacing: 12) {
                Image(systemName: option.systemImage)
                    .frame(width: 24)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(option.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                if style == option {
                    Image(systemName: "checkmark")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .opacity(isAvailable ? 1 : 0.45)
        .accessibilityAddTraits(style == option ? .isSelected : [])
    }

    private func previewRow(_ day: PlanDay) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Day \(day.day)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(day.title)
                .font(.subheadline.weight(.semibold))
            if day.title != day.readingSummary {
                Text(day.readingSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var bookSummary: String {
        let chapters = verseCounts.count
        let verses = verseCounts.reduce(0, +)
        let chapterText = chapters == 1 ? "1 chapter" : "\(chapters) chapters"
        let highlightText = switch highlights.count {
        case 0: ""
        case 1: " · 1 key passage"
        default: " · \(highlights.count) key passages"
        }
        return "\(chapterText) · \(verses) verses\(highlightText)"
    }

    /// How much a day holds, such as "About 2 chapters a day."
    private var paceSummary: String {
        let days = previewDays
        guard !days.isEmpty else { return "" }
        let verses = days.reduce(0) { total, day in
            total + day.readings.reduce(0) { $0 + $1.verses(verseCounts: verseCounts).count }
        }
        let versesPerDay = Double(verses) / Double(days.count)
        let averageChapter = Double(verseCounts.reduce(0, +)) / Double(max(1, verseCounts.count))
        let chaptersPerDay = versesPerDay / max(1, averageChapter)
        if chaptersPerDay >= 1.5 {
            return "About \(Int(chaptersPerDay.rounded())) chapters a day."
        }
        if chaptersPerDay >= 0.75 {
            return "About a chapter a day."
        }
        return "About \(Int(versesPerDay.rounded())) verses a day."
    }

    private func resetDays() {
        dayCount = CustomPlanGenerator.suggestedDays(for: style, verseCounts: verseCounts, highlights: highlights)
    }
}

/// A day-count shortcut: outlined, or filled when it's the current length.
private struct PresetButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? Color.white : Color.accentColor)
            .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.12), in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
