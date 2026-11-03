import SwiftUI

// Home's scrolling container and the Edit Home toolbar button and onboarding arrow.

struct HomeScrollContent<Dashboard: View, Compact: View>: View {
    let usesDashboard: Bool
    let contentWidth: CGFloat
    let availableHeight: CGFloat
    let horizontalPadding: CGFloat
    let searchScrollRequest: Int
    let dismissCue: () -> Void
    private let dashboard: () -> Dashboard
    private let compact: () -> Compact

    init(
        usesDashboard: Bool,
        contentWidth: CGFloat,
        availableHeight: CGFloat,
        horizontalPadding: CGFloat,
        searchScrollRequest: Int,
        dismissCue: @escaping () -> Void,
        @ViewBuilder dashboard: @escaping () -> Dashboard,
        @ViewBuilder compact: @escaping () -> Compact
    ) {
        self.usesDashboard = usesDashboard
        self.contentWidth = contentWidth
        self.availableHeight = availableHeight
        self.horizontalPadding = horizontalPadding
        self.searchScrollRequest = searchScrollRequest
        self.dismissCue = dismissCue
        self.dashboard = dashboard
        self.compact = compact
    }

    /// When the Search card last asked to be scrolled into view, so the keyboard appearing
    /// afterward can finish that scroll without reacting to unrelated keyboards.
    @State private var searchScrollRequestedAt: Date?

    private func scrollSearchIntoView(_ scrollProxy: ScrollViewProxy) {
        withAnimation(.snappy) {
            scrollProxy.scrollTo(HomeCardID.search, anchor: .top)
        }
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(spacing: 16) {
                    if usesDashboard {
                        dashboard()
                    } else {
                        compact()
                    }
                }
                .frame(width: contentWidth, alignment: .leading)
                .padding(.horizontal, horizontalPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .tabBarContentClearance()
            .simultaneousGesture(DragGesture(minimumDistance: 1).onChanged { _ in dismissCue() })
            .simultaneousGesture(TapGesture().onEnded { dismissCue() })
            .task(id: searchScrollRequest) {
                guard searchScrollRequest > 0 else { return }
                searchScrollRequestedAt = .now
                // Let the card's new height lay out before scrolling to it.
                await Task.yield()
                guard !Task.isCancelled else { return }
                scrollSearchIntoView(scrollProxy)
            }
            // The keyboard changes how far the content can scroll, so finish the scroll
            // once it is fully up.
            .onNotification(UIResponder.keyboardDidShowNotification) {
                guard let requestedAt = searchScrollRequestedAt,
                      Date.now.timeIntervalSince(requestedAt) < 2 else { return }
                searchScrollRequestedAt = nil
                scrollSearchIntoView(scrollProxy)
            }
        }
    }
}

struct EditHomeToolbarButton: View {
    let showsCue: Bool
    let circleProgress: CGFloat
    let arrowProgress: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if showsCue {
                    EditHomeToolbarArrow()
                        .trim(from: 0, to: arrowProgress)
                        .stroke(
                            .red,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: 34, height: 22)
                        .accessibilityHidden(true)
                }
                Image(systemName: "square.grid.2x2")
                    .overlay {
                        Circle()
                            .trim(from: 0, to: circleProgress)
                            .stroke(
                                .red,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .padding(-8)
                            .opacity(showsCue ? 1 : 0)
                            .accessibilityHidden(true)
                            .allowsHitTesting(false)
                    }
            }
        }
        .accessibilityLabel("Edit Home")
        .accessibilityIdentifier("homeEditButton")
    }
}

/// A short arrow that ends immediately beside the highlighted Edit Home grid icon.
struct EditHomeToolbarArrow: Shape {
    func path(in rect: CGRect) -> Path {
        let tip = CGPoint(x: rect.maxX - 2, y: rect.midY)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + 2, y: rect.midY))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: tip.x - 8, y: tip.y - 6))
        path.move(to: tip)
        path.addLine(to: CGPoint(x: tip.x - 8, y: tip.y + 6))

        return path
    }
}
