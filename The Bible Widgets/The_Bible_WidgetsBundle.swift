//
//  The_Bible_WidgetsBundle.swift
//  The Bible Widgets
//
//  Created by William Creecy on 11/7/25.
//

import WidgetKit
import SwiftUI

struct VerseWidget: Widget {
    let kind: String = "VerseWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: VerseWidgetAppearanceIntent.self,
            provider: VerseProvider()
        ) { (entry: VerseWidgetEntry) in
            VerseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Verse of the Day")
        .description("Displays a daily Bible verse.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

struct LastReadWidget: Widget {
    let kind: String = "LastReadWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: LastReadWidgetAppearanceIntent.self,
            provider: LastReadProvider()
        ) { (entry: LastReadEntry) in
            LastReadWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Continue Reading")
        .description("Shows the chapter you were last reading.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

@main
struct The_Bible_WidgetsBundle: WidgetBundle {
    var body: some Widget {
        VerseWidget()
        LastReadWidget()
        PinnedVerseWidget()        // <- existing pinned verse widget
        RandomVerseLockScreenWidget() // Lock Screen random verse
        PrayerTimerLiveActivity()
    }
}

#if DEBUG
private extension LastReadEntry {
    static let bookmarkLeads = LastReadEntry(
        date: .now,
        isBookmark: true,
        text: "After this manner therefore pray ye: Our Father which art in heaven, Hallowed be thy name.",
        book: "Matthew",
        chapter: 6,
        verse: 9,
        backgroundStyleRaw: "black"
    )

    static let movedOn = LastReadEntry(
        date: .now,
        text: "Jesus answered and said unto her, Whosoever drinketh of this water shall thirst again:",
        book: "John",
        chapter: 4,
        verse: 13,
        bookmarkReference: "Matthew 6:9",
        bookmarkText: "After this manner therefore pray ye: Our Father which art in heaven, Hallowed be thy name.",
        backgroundStyleRaw: "black"
    )
}

#Preview("Continue Reading – medium", as: .systemMedium) {
    LastReadWidget()
} timeline: {
    LastReadEntry.bookmarkLeads
    LastReadEntry.movedOn
}

#Preview("Continue Reading – small", as: .systemSmall) {
    LastReadWidget()
} timeline: {
    LastReadEntry.bookmarkLeads
    LastReadEntry.movedOn
}
#endif
