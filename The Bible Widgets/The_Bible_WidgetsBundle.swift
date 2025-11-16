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
        StaticConfiguration(kind: kind, provider: VerseProvider()) { (entry: VerseWidgetEntry) in
            VerseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Verse of the Day")
        .description("Displays a daily Bible verse.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct LastReadWidget: Widget {
    let kind: String = "LastReadWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LastReadProvider()) { (entry: LastReadEntry) in
            LastReadWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Last Read")
        .description("Shows the last verse you bookmarked/read.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct The_Bible_WidgetsBundle: WidgetBundle {
    var body: some Widget {
        VerseWidget()
        LastReadWidget()
        PinnedVerseWidget()        // <- New pinned verse widget
        PrayerTimerLiveActivity()
        StopwatchLiveActivity()
    }
}
