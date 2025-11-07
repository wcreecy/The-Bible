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
        StaticConfiguration(kind: kind, provider: VerseProvider()) { entry in
            VerseWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Verse of the Day")
        .description("Displays a daily Bible verse.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@main
struct The_Bible_WidgetsBundle: WidgetBundle {
    var body: some Widget {
        VerseWidget()
        PrayerTimerLiveActivity()
        StopwatchLiveActivity()
    }
}
