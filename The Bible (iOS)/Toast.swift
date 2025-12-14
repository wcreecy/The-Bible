import SwiftUI

public struct AppToast: View {
    public let symbol: String?
    public let text: String
    public let tint: Color

    public init(symbol: String? = nil, text: String, tint: Color = .accentColor) {
        self.symbol = symbol
        self.text = text
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 10) {
            if let symbol {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: Capsule())
        .overlay(
            Capsule().strokeBorder(.quaternary, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
    }
}

public struct ToastPresenter: ViewModifier {
    @Binding var isPresented: Bool
    let symbol: String?
    let text: String
    let tint: Color

    // Auto-dismiss task so we can cancel/reschedule when the toast is re-shown
    @State private var dismissTask: Task<Void, Never>? = nil
    private let autoDismissSeconds: Double = 2.0

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    AppToast(symbol: symbol, text: text, tint: tint)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .onChange(of: isPresented) { oldValue, newValue in
                if newValue {
                    scheduleAutoDismiss()
                } else {
                    cancelAutoDismiss()
                }
            }
            .onDisappear {
                cancelAutoDismiss()
            }
    }

    private func scheduleAutoDismiss() {
        cancelAutoDismiss()
        dismissTask = Task {
            // Sleep for the configured duration, then hide if still presented
            let ns = UInt64(autoDismissSeconds * 1_000_000_000)
            try? await Task.sleep(nanoseconds: ns)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if isPresented {
                    withAnimation(.easeOut) { isPresented = false }
                }
            }
        }
    }

    private func cancelAutoDismiss() {
        dismissTask?.cancel()
        dismissTask = nil
    }
}

public extension View {
    func appToast(isPresented: Binding<Bool>, symbol: String? = nil, text: String, tint: Color = .accentColor) -> some View {
        self.modifier(ToastPresenter(isPresented: isPresented, symbol: symbol, text: text, tint: tint))
    }
}
