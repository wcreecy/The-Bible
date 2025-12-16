import SwiftUI

// Shared UI: tag chip row
struct TagChipRow: View {
    let tags: [String]
    let selectedTags: Set<String>
    let showColorPicker: Bool
    let onTap: ((String) -> Void)?
    let onColorChange: ((String, Color) -> Void)?

    init(tags: [String], selectedTags: Set<String> = [], showColorPicker: Bool = false, onTap: ((String) -> Void)? = nil, onColorChange: ((String, Color) -> Void)? = nil) {
        self.tags = tags
        self.selectedTags = selectedTags
        self.showColorPicker = showColorPicker
        self.onTap = onTap
        self.onColorChange = onColorChange
    }

    private func displayName(for tag: String) -> String {
        if let preferred = TagDisplayNameStore.displayName(for: tag) {
            return preferred
        }
        // Fallback: Title Case each word for nicer appearance
        return tag
            .split(separator: " ")
            .map { part in
                let s = String(part)
                guard let f = s.first else { return s }
                return String(f).uppercased() + s.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ForEach(tags, id: \.self) { t in
                HStack(spacing: 8) {
                    let tint = TagColorStore.color(for: t) ?? .accentColor
                    TagChip(text: displayName(for: t), tint: tint, isSelected: selectedTags.contains(t.lowercased())) {
                        onTap?(t)
                    }
                    if showColorPicker, let onColorChange {
                        ColorPicker("", selection: Binding(
                            get: { TagColorStore.color(for: t) ?? .accentColor },
                            set: { newValue in onColorChange(t, newValue) }
                        ), supportsOpacity: false)
                        .labelsHidden()
                    }
                }
            }
        }
    }
}
