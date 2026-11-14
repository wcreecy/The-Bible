import SwiftUI
import UIKit

/// The colors and symbol a plan's artwork is drawn with.
struct PlanArtworkStyle {
    let colors: [Color]
    let symbol: String
    /// A small symbol scattered faintly behind the main one; the category's symbol.
    var motif: String? = nil
    /// Varies where the motif falls, so cards in a row don't look stamped from one mold.
    var seed: Int = 0

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

    /// SF Symbols has no Christian cross (`cross` is the medical plus sign), so this name
    /// draws one instead.
    static let latinCross = "latin.cross"

    static func isDrawable(_ symbol: String) -> Bool {
        symbol == latinCross || UIImage(systemName: symbol) != nil
    }

    /// The plan's own symbol over its category's colors. Fruit of the Spirit parts share the
    /// series colors so they read as a set.
    static func forPlan(_ plan: ReadingPlan) -> PlanArtworkStyle {
        let base = plan.series.map { forSeries($0, category: plan.category) } ?? forCategory(plan.category)
        let symbol = plan.symbol.flatMap { isDrawable($0) ? $0 : nil } ?? base.symbol
        let motif = forCategory(plan.category).symbol
        return PlanArtworkStyle(
            colors: base.colors,
            symbol: symbol,
            motif: motif == symbol ? nil : motif,
            seed: plan.id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        )
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

                    if let motif = style.motif {
                        motifPattern(motif, in: proxy.size)
                    }

                    // A large, partly cropped symbol on the trailing side, with a soft glow
                    // behind it, so the band reads as art rather than an icon.
                    Circle()
                        .fill(.white.opacity(0.14))
                        .frame(width: proxy.size.height * 1.6)
                        .offset(x: proxy.size.width * 0.32, y: proxy.size.height * 0.2)

                    PlanSymbol(name: style.symbol, size: proxy.size.height * 0.62)
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

private extension PlanArtwork {
    /// A few faint copies of the motif across the leading side, placed by the style's seed.
    func motifPattern(_ motif: String, in size: CGSize) -> some View {
        let spots: [(x: Double, y: Double, scale: Double)] = (0..<5).map { index in
            let value = (style.seed &* (index + 7) &* 2_654_435_761) & 0xFFFF
            let x = 0.06 + Double(value % 100) / 100 * 0.52
            let y = 0.12 + Double((value / 100) % 100) / 100 * 0.76
            let scale = 0.16 + Double((value / 10_000) % 4) * 0.04
            return (x, y, scale)
        }
        return ZStack {
            ForEach(spots.indices, id: \.self) { index in
                Image(systemName: motif)
                    .font(.system(size: size.height * spots[index].scale, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.13))
                    .rotationEffect(.degrees(Double((style.seed + index * 37) % 50) - 25))
                    .position(x: size.width * spots[index].x, y: size.height * spots[index].y)
            }
        }
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
                PlanSymbol(name: style.symbol, size: size * 0.45)
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// An SF Symbol, or the drawn Latin cross.
private struct PlanSymbol: View {
    let name: String
    let size: CGFloat

    var body: some View {
        if name == PlanArtworkStyle.latinCross {
            LatinCross()
                .frame(width: size * 0.62, height: size)
        } else {
            Image(systemName: name)
                .font(.system(size: size, weight: .semibold))
        }
    }
}

/// A Latin cross: the crossbar a third of the way down, arms shorter than the upright.
private struct LatinCross: Shape {
    func path(in rect: CGRect) -> Path {
        let beam = rect.width * 0.26
        let barY = rect.height * 0.24
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: rect.midX - beam / 2, y: rect.minY, width: beam, height: rect.height),
            cornerSize: CGSize(width: beam * 0.2, height: beam * 0.2)
        )
        path.addRoundedRect(
            in: CGRect(x: rect.minX, y: rect.minY + barY, width: rect.width, height: beam),
            cornerSize: CGSize(width: beam * 0.2, height: beam * 0.2)
        )
        return path
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

#Preview("Plan cards") {
    let plans = ReadingPlanStore.loadCatalog()
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
            ForEach(plans) { plan in
                PlanCard(plan: plan, status: plan.id == "gospel-of-john" ? .inProgress(0.4) : .notStarted)
            }
        }
        .padding()
    }
}

extension PlanArtworkStyle {
    /// Bible Study's tile on the Bible tab.
    static let bibleStudy = PlanArtworkStyle(
        colors: [Color(red: 0.27, green: 0.47, blue: 0.85), Color(red: 0.42, green: 0.30, blue: 0.78)],
        symbol: "graduationcap.fill",
        motif: "book.fill",
        seed: 7
    )

    /// Reading Plans' tile when no plan is in progress.
    static let readingPlans = PlanArtworkStyle(
        colors: [Color(red: 0.36, green: 0.72, blue: 0.47), Color(red: 0.13, green: 0.52, blue: 0.56)],
        symbol: "calendar.badge.checkmark",
        motif: "book.closed.fill",
        seed: 11
    )
}

/// A small square of artwork for any style, for compact rows.
struct ArtworkSquare: View {
    let style: PlanArtworkStyle
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            LinearGradient(colors: style.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: style.symbol)
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// A half-width card with an artwork band, used side by side on the Bible tab.
struct FeatureTile: View {
    let style: PlanArtworkStyle
    let title: String
    let subtitle: String
    /// Shown as a bar under the subtitle, such as a plan's progress.
    var progress: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlanArtwork(style: style)
                .frame(height: 64)
                .planCardTopCorners()

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if let progress {
                    ProgressView(value: progress)
                        .tint(.accentColor)
                        .padding(.top, 2)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .heroCardSurface()
        .contentShape(.rect(cornerRadius: AppDesignMetrics.cardCornerRadius))
        .accessibilityElement(children: .combine)
    }
}

/// A sidebar card with its artwork in a strip down the leading edge, for the iPad Books
/// sidebar where cards are too narrow for a band across the top. The caller adds the surface.
struct SidebarFeatureCard: View {
    let style: PlanArtworkStyle
    let title: String
    let subtitle: String
    var progress: Double? = nil
    /// Marks the strip with a checkmark, such as while Study mode is on.
    var isOn = false
    var trailingSymbol = "chevron.right"

    /// Fixed rather than a share of the width, so the strip stays modest in a wide sidebar.
    static let stripWidth: CGFloat = 64

    var body: some View {
        HStack(spacing: 0) {
            strip

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let progress {
                    ProgressView(value: progress)
                        .tint(.accentColor)
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 12)
            .padding(.leading, 12)

            Spacer(minLength: 8)

            Image(systemName: trailingSymbol)
                .font(isOn ? .body : .caption.weight(.semibold))
                .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                .padding(.trailing, 12)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        // Sized by the text; the strip then fills that height rather than growing the card.
        .fixedSize(horizontal: false, vertical: true)
    }

    private var strip: some View {
        ZStack {
            LinearGradient(colors: style.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: style.symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .frame(width: Self.stripWidth)
        .frame(maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            if isOn {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white, Color.accentColor)
                    .padding(5)
            }
        }
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: AppDesignMetrics.cardCornerRadius,
            bottomLeadingRadius: AppDesignMetrics.cardCornerRadius,
            style: .continuous
        ))
        .accessibilityHidden(true)
    }
}

#Preview("Sidebar cards") {
    VStack(spacing: 12) {
        SidebarFeatureCard(style: .bibleStudy, title: "Bible Study", subtitle: "Overviews and insights")
            .heroCardSurface()
        SidebarFeatureCard(
            style: .bibleStudy,
            title: "Studying",
            subtitle: "Books open their study pages",
            isOn: true,
            trailingSymbol: "xmark.circle.fill"
        )
        .heroCardSurface()
        SidebarFeatureCard(style: .readingPlans, title: "Reading Plans", subtitle: "A day at a time")
            .heroCardSurface()
        SidebarFeatureCard(
            style: .readingPlans,
            title: "Reading Plans",
            subtitle: "The Gospel of John · Day 6 of 21",
            progress: 0.24
        )
        .heroCardSurface()
    }
    .padding()
    .frame(width: 320)
}
