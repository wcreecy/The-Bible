//
//  VerseWidgetExtensionLiveActivity.swift
//  VerseWidgetExtension
//
//  Created by William Creecy on 11/1/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct VerseWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct VerseWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VerseWidgetExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension VerseWidgetExtensionAttributes {
    fileprivate static var preview: VerseWidgetExtensionAttributes {
        VerseWidgetExtensionAttributes(name: "World")
    }
}

extension VerseWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: VerseWidgetExtensionAttributes.ContentState {
        VerseWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: VerseWidgetExtensionAttributes.ContentState {
         VerseWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: VerseWidgetExtensionAttributes.preview) {
   VerseWidgetExtensionLiveActivity()
} contentStates: {
    VerseWidgetExtensionAttributes.ContentState.smiley
    VerseWidgetExtensionAttributes.ContentState.starEyes
}
