import SwiftUI

/// The sort control on the Game Stats cards: a compact segmented control, or a menu at
/// accessibility text sizes where the segments would be cut off. Right-aligned either way.
struct StatsSortPicker<Option>: View
where Option: CaseIterable & Identifiable & Hashable & RawRepresentable,
      Option.AllCases: RandomAccessCollection,
      Option.RawValue == String {
    @Binding var selection: Option

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var segmentedTint: Color {
        colorScheme == .light ? Color.black.opacity(0.85) : Color.accentColor
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                picker
                    .pickerStyle(.menu)
            } else {
                picker
                    .pickerStyle(.segmented)
                    .tint(segmentedTint)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var picker: some View {
        Picker("Sort", selection: $selection) {
            ForEach(Option.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
    }
}
