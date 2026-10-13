import SwiftUI

/// Per-book header artwork shown above the chapter grid on iPhone and iPad.
struct BookChapterTheme {
    let primarySymbol: String
    let accentSymbol: String?
    let colors: [Color]

    static let themes: [String: BookChapterTheme] = [
        "Genesis": .init(primarySymbol: "sun.max.fill", accentSymbol: "leaf.fill", colors: [.orange, .yellow, .green]),
        "Exodus": .init(primarySymbol: "water.waves", accentSymbol: "figure.walk", colors: [.blue, .cyan, .teal]),
        "Leviticus": .init(primarySymbol: "flame.fill", accentSymbol: nil, colors: [.red, .orange, .yellow]),
        "Numbers": .init(primarySymbol: "list.number", accentSymbol: nil, colors: [.indigo, .blue, .cyan]),
        "Deuteronomy": .init(primarySymbol: "book.closed.fill", accentSymbol: nil, colors: [.brown, .orange, .yellow]),
        "Joshua": .init(primarySymbol: "shield.fill", accentSymbol: nil, colors: [.blue, .indigo, .purple]),
        "Judges": .init(primarySymbol: "scale.3d", accentSymbol: nil, colors: [.purple, .indigo, .blue]),
        "Ruth": .init(primarySymbol: "heart.fill", accentSymbol: nil, colors: [.pink, .red, .orange]),
        "1 Samuel": .init(primarySymbol: "crown.fill", accentSymbol: nil, colors: [.yellow, .orange, .brown]),
        "2 Samuel": .init(primarySymbol: "crown.fill", accentSymbol: nil, colors: [.orange, .red, .pink]),
        "1 Kings": .init(primarySymbol: "crown.fill", accentSymbol: nil, colors: [.yellow, .orange, .red]),
        "2 Kings": .init(primarySymbol: "crown.fill", accentSymbol: nil, colors: [.orange, .red, .purple]),
        "1 Chronicles": .init(primarySymbol: "clock.arrow.circlepath", accentSymbol: nil, colors: [.brown, .orange, .yellow]),
        "2 Chronicles": .init(primarySymbol: "clock.arrow.circlepath", accentSymbol: nil, colors: [.orange, .yellow, .green]),
        "Ezra": .init(primarySymbol: "building.columns.fill", accentSymbol: nil, colors: [.brown, .orange, .yellow]),
        "Nehemiah": .init(primarySymbol: "hammer.fill", accentSymbol: nil, colors: [.gray, .blue, .teal]),
        "Esther": .init(primarySymbol: "sparkles", accentSymbol: nil, colors: [.purple, .pink, .yellow]),
        "Job": .init(primarySymbol: "cloud.bolt.rain.fill", accentSymbol: nil, colors: [.gray, .blue, .indigo]),
        "Psalms": .init(primarySymbol: "music.note", accentSymbol: nil, colors: [.purple, .pink, .red]),
        "Proverbs": .init(primarySymbol: "lightbulb.fill", accentSymbol: nil, colors: [.yellow, .orange, .red]),
        "Ecclesiastes": .init(primarySymbol: "hourglass", accentSymbol: nil, colors: [.brown, .gray, .blue]),
        "Song of Solomon": .init(primarySymbol: "heart.fill", accentSymbol: nil, colors: [.pink, .red, .purple]),
        "Isaiah": .init(primarySymbol: "megaphone.fill", accentSymbol: nil, colors: [.blue, .indigo, .purple]),
        "Jeremiah": .init(primarySymbol: "drop.fill", accentSymbol: nil, colors: [.blue, .indigo, .gray]),
        "Lamentations": .init(primarySymbol: "cloud.rain.fill", accentSymbol: nil, colors: [.gray, .blue, .indigo]),
        "Ezekiel": .init(primarySymbol: "eye.fill", accentSymbol: nil, colors: [.teal, .blue, .indigo]),
        "Daniel": .init(primarySymbol: "pawprint.fill", accentSymbol: nil, colors: [.orange, .yellow, .brown]),
        "Hosea": .init(primarySymbol: "heart.circle.fill", accentSymbol: nil, colors: [.pink, .red, .purple]),
        "Joel": .init(primarySymbol: "cloud.bolt.fill", accentSymbol: nil, colors: [.gray, .blue, .purple]),
        "Amos": .init(primarySymbol: "bell.fill", accentSymbol: nil, colors: [.orange, .yellow, .red]),
        "Obadiah": .init(primarySymbol: "bird.fill", accentSymbol: nil, colors: [.blue, .cyan, .teal]),
        "Jonah": .init(primarySymbol: "fish.fill", accentSymbol: nil, colors: [.blue, .cyan, .teal]),
        "Micah": .init(primarySymbol: "scale.3d", accentSymbol: nil, colors: [.purple, .indigo, .blue]),
        "Nahum": .init(primarySymbol: "cloud.bolt.fill", accentSymbol: nil, colors: [.gray, .blue, .indigo]),
        "Habakkuk": .init(primarySymbol: "questionmark.circle.fill", accentSymbol: nil, colors: [.indigo, .purple, .pink]),
        "Zephaniah": .init(primarySymbol: "sun.max.fill", accentSymbol: nil, colors: [.orange, .yellow, .red]),
        "Haggai": .init(primarySymbol: "hammer.fill", accentSymbol: nil, colors: [.brown, .orange, .yellow]),
        "Zechariah": .init(primarySymbol: "eye.fill", accentSymbol: nil, colors: [.purple, .blue, .teal]),
        "Malachi": .init(primarySymbol: "flame.fill", accentSymbol: nil, colors: [.red, .orange, .yellow]),
        "Matthew": .init(primarySymbol: "person.crop.circle.badge.checkmark", accentSymbol: nil, colors: [.blue, .indigo, .purple]),
        "Mark": .init(primarySymbol: "bolt.fill", accentSymbol: nil, colors: [.orange, .yellow, .red]),
        "Luke": .init(primarySymbol: "cross.case.fill", accentSymbol: nil, colors: [.green, .teal, .blue]),
        "John": .init(primarySymbol: "heart.fill", accentSymbol: nil, colors: [.pink, .red, .purple]),
        "Acts": .init(primarySymbol: "figure.walk", accentSymbol: nil, colors: [.blue, .cyan, .teal]),
        "Romans": .init(primarySymbol: "building.columns.fill", accentSymbol: nil, colors: [.orange, .red, .purple]),
        "1 Corinthians": .init(primarySymbol: "person.2.fill", accentSymbol: nil, colors: [.blue, .indigo, .purple]),
        "2 Corinthians": .init(primarySymbol: "person.2.fill", accentSymbol: nil, colors: [.purple, .indigo, .blue]),
        "Galatians": .init(primarySymbol: "link", accentSymbol: nil, colors: [.green, .teal, .blue]),
        "Ephesians": .init(primarySymbol: "shield.fill", accentSymbol: nil, colors: [.blue, .indigo, .purple]),
        "Philippians": .init(primarySymbol: "hands.clap.fill", accentSymbol: nil, colors: [.yellow, .orange, .pink]),
        "Colossians": .init(primarySymbol: "circle.grid.cross.fill", accentSymbol: nil, colors: [.blue, .teal, .green]),
        "1 Thessalonians": .init(primarySymbol: "sun.and.horizon.fill", accentSymbol: nil, colors: [.orange, .yellow, .pink]),
        "2 Thessalonians": .init(primarySymbol: "sun.and.horizon.fill", accentSymbol: nil, colors: [.yellow, .orange, .red]),
        "1 Timothy": .init(primarySymbol: "person.crop.circle.badge.checkmark", accentSymbol: nil, colors: [.blue, .indigo, .teal]),
        "2 Timothy": .init(primarySymbol: "person.crop.circle.badge.checkmark", accentSymbol: nil, colors: [.indigo, .purple, .blue]),
        "Titus": .init(primarySymbol: "person.crop.circle", accentSymbol: nil, colors: [.teal, .blue, .indigo]),
        "Philemon": .init(primarySymbol: "envelope.fill", accentSymbol: nil, colors: [.blue, .cyan, .teal]),
        "Hebrews": .init(primarySymbol: "scroll.fill", accentSymbol: nil, colors: [.brown, .orange, .yellow]),
        "James": .init(primarySymbol: "hammer.fill", accentSymbol: nil, colors: [.orange, .red, .brown]),
        "1 Peter": .init(primarySymbol: "key.fill", accentSymbol: nil, colors: [.blue, .cyan, .teal]),
        "2 Peter": .init(primarySymbol: "key.fill", accentSymbol: nil, colors: [.teal, .blue, .indigo]),
        "1 John": .init(primarySymbol: "heart.fill", accentSymbol: nil, colors: [.pink, .red, .purple]),
        "2 John": .init(primarySymbol: "heart.fill", accentSymbol: nil, colors: [.purple, .pink, .red]),
        "3 John": .init(primarySymbol: "heart.fill", accentSymbol: nil, colors: [.red, .pink, .purple]),
        "Jude": .init(primarySymbol: "shield.fill", accentSymbol: nil, colors: [.blue, .indigo, .purple]),
        "Revelation": .init(primarySymbol: "crown.fill", accentSymbol: nil, colors: [.purple, .pink, .yellow])
    ]
}

struct ThemedBookChaptersHeader: View {
    let title: String
    let theme: BookChapterTheme

    var body: some View {
        HStack(spacing: 16) {
            BookChapterEmblem(theme: theme)

            Text(title)
                .font(.system(.largeTitle, design: .serif, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: theme.colors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(AppDesignMetrics.cardPadding)
        .heroCardSurface()
        .accessibilityElement(children: .combine)
    }
}

struct BookChapterEmblem: View {
    let theme: BookChapterTheme
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: theme.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: theme.primarySymbol)
                .font(.system(size: size * 4 / 9, weight: .bold))
                .foregroundStyle(.white)
                .offset(y: theme.accentSymbol == nil ? 0 : -size / 9)

            if let accentSymbol = theme.accentSymbol {
                Image(systemName: accentSymbol)
                    .font(.system(size: size * 11 / 36, weight: .bold))
                    .foregroundStyle(.white.opacity(0.94))
                    .offset(x: size / 6, y: size / 6)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
