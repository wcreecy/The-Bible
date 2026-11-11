import SwiftUI

// Home's scrolling container and the Edit Home toolbar button and onboarding arrow.

struct HomeScrollContent<Dashboard: View, Compact: View>: View {
    let usesDashboard: Bool
    let contentWidth: CGFloat
    let availableHeight: CGFloat
    let horizontalPadding: CGFloat
    let dismissCue: () -> Void
    private let dashboard: () -> Dashboard
    private let compact: () -> Compact

    init(
        usesDashboard: Bool,
        contentWidth: CGFloat,
        availableHeight: CGFloat,
        horizontalPadding: CGFloat,
        dismissCue: @escaping () -> Void,
        @ViewBuilder dashboard: @escaping () -> Dashboard,
        @ViewBuilder compact: @escaping () -> Compact
    ) {
        self.usesDashboard = usesDashboard
        self.contentWidth = contentWidth
        self.availableHeight = availableHeight
        self.horizontalPadding = horizontalPadding
        self.dismissCue = dismissCue
        self.dashboard = dashboard
        self.compact = compact
    }

    var body: some View {
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
