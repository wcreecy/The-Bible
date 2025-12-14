import SwiftUI

public struct SegmentedPicker<T: Hashable>: View {
    public let options: [T]
    public let titleForOption: (T) -> String
    @Binding public var selection: T

    public init(options: [T], titleForOption: @escaping (T) -> String, selection: Binding<T>) {
        self.options = options
        self.titleForOption = titleForOption
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { idx, opt in
                Button(action: { selection = opt }) {
                    Text(titleForOption(opt))
                        .font(.subheadline)
                        .fontWeight(selection == opt ? .semibold : .regular)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(selection == opt ? Color.accentColor.opacity(0.15) : Color.clear)

                if idx < options.count - 1 {
                    Rectangle()
                        .fill(Color.gray.opacity(0.25))
                        .frame(width: 1, height: 24)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.gray.opacity(0.25), lineWidth: 1)
        )
    }
}

#Preview {
    StatefulPreviewWrapper("a") { binding in
        VStack(spacing: 16) {
            SegmentedPicker(options: ["a","b","c"], titleForOption: { $0.uppercased() }, selection: binding)
        }
        .padding()
    }
}

// Helper to preview bindings
public struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content

    public init(_ value: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: value)
        self.content = content
    }

    public var body: some View { content($value) }
}
