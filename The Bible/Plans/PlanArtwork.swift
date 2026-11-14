import SwiftUI
import UIKit

/// The colors and symbol a plan's artwork is drawn with.
struct PlanArtworkStyle {
    let colors: [Color]
    let symbol: String

    /// Each category has its own gradient and symbol, so a row of cards reads as a group.
    static func forCategory(_ category: String) -> PlanArtworkStyle {
        switch category {
        case "Getting Started":
            PlanArtworkStyle(colors: [Color(red: 0.98, green: 0.62, blue: 0.33), Color(red: 0.91, green: 0.36, blue: 0.47)], symbol: "sunrise.fill")
        case "Spiritual Growth":
            PlanArtworkStyle(colors: [Color(red: 0.36, green: 0.72, blue: 0.47), Color(red: 0.13, green: 0.52, blue: 0.56)], symbol: "leaf.fill")
        case "Life Challenges":
            PlanArtworkStyle(colors: [Color(red: 0.35, green: 0.56, blue: 0.91), Color(red: 0.31, green: 0.30, blue: 0.75)], symbol: "mountain.2.fill")
        case "Relationships":
            PlanArtworkStyle(colors: [Color(red: 0.95, green: 0.50, blue: 0.55), Color(red: 0.86, green: 0.40, blue: 0.27)], symbol: "heart.fill")
        case "People of the Bible":
            PlanArtworkStyle(colors: [Color(red: 0.84, green: 0.62, blue: 0.30), Color(red: 0.64, green: 0.38, blue: 0.20)], symbol: "person.2.fill")
        case "Books of the Bible":
            PlanArtworkStyle(colors: [Color(red: 0.49, green: 0.43, blue: 0.86), Color(red: 0.34, green: 0.22, blue: 0.63)], symbol: "book.fill")
        case "Whole Bible":
            PlanArtworkStyle(colors: [Color(red: 0.20, green: 0.33, blue: 0.62), Color(red: 0.36, green: 0.20, blue: 0.52)], symbol: "books.vertical.fill")
        case ReadingPlan.customCategory:
            PlanArtworkStyle(colors: [Color(red: 0.40, green: 0.55, blue: 0.68), Color(red: 0.25, green: 0.38, blue: 0.52)], symbol: "square.and.pencil")
        default:
            PlanArtworkStyle(colors: [Color.accentColor, Color.accentColor.opacity(0.7)], symbol: "calendar.badge.checkmark")
        }
    }

    /// A series keeps its category's colors with a symbol of its own.
    static func forSeries(_ series: String, category: String) -> PlanArtworkStyle {
        let base = forCategory(category)
        switch series {
        case "Fruit of the Spirit":
            return PlanArtworkStyle(colors: [Color(red: 0.62, green: 0.76, blue: 0.29), Color(red: 0.20, green: 0.58, blue: 0.38)], symbol: "leaf.fill")
        default:
            return PlanArtworkStyle(colors: base.colors, symbol: "square.stack.3d.up.fill")
        }
    }

    /// The plan's own symbol over its category's colors. Fruit of the Spirit parts share the
    /// series colors so they read as a set.
    static func forPlan(_ plan: ReadingPlan) -> PlanArtworkStyle {
        let base = plan.series.map { forSeries($0, category: plan.category) } ?? forCategory(plan.category)
        guard let symbol = plan.symbol, UIImage(systemName: symbol) != nil else { return base }
        return PlanArtworkStyle(colors: base.colors, symbol: symbol)
    }
}

/// A plan's artwork: its image when the asset catalog has one, otherwise a gradient with a
/// large symbol. Decorative, so VoiceOver skips it.
struct PlanArtwork: View {
    let style: PlanArtworkStyle
    var imageName: String?

    init(plan: ReadingPlan) {
        style = .forPlan(plan)
        imageName = plan.image
    }

    init(style: PlanArtworkStyle) {
        self.style = style
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let imageName, UIImage(named: imageName) != nil {
                    Image(imageName)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(colors: style.colors, startPoint: .topLeading, endPoint: .bottomTrailing)

                    // A large, partly cropped symbol on the trailing side, with a soft glow
                    // behind it, so the band reads as art rather than an icon.
                    Circle()
                        .fill(.white.opacity(0.14))
                        .frame(width: proxy.size.height * 1.6)
                        .offset(x: proxy.size.width * 0.32, y: proxy.size.height * 0.2)

                    Image(systemName: style.symbol)
                        .font(.system(size: proxy.size.height * 0.62, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .padding(.trailing, proxy.size.height * 0.28)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }
}

/// A small square of a plan's artwork, for rows that list plans.
struct PlanArtworkTile: View {
    let plan: ReadingPlan
    var size: CGFloat = 40

    var body: some View {
        let style = PlanArtworkStyle.forPlan(plan)
        ZStack {
            LinearGradient(colors: style.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            if let image = plan.image, UIImage(named: image) != nil {
                Image(image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: style.symbol)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
        .accessibilityHidden(true)
    }
}

extension View {
    /// Clips the top of a card's artwork band to the card's rounded corners.
    func planCardTopCorners() -> some View {
        clipShape(UnevenRoundedRectangle(
            topLeadingRadius: AppDesignMetrics.cardCornerRadius,
            topTrailingRadius: AppDesignMetrics.cardCornerRadius,
            style: .continuous
        ))
    }
}
