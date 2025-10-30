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

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isPresented {
                    AppToast(symbol: symbol, text: text, tint: tint)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
    }
}

public extension View {
    func appToast(isPresented: Binding<Bool>, symbol: String? = nil, text: String, tint: Color = .accentColor) -> some View {
        self.modifier(ToastPresenter(isPresented: isPresented, symbol: symbol, text: text, tint: tint))
    }
}
