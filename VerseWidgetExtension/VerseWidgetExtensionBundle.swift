//
//  VerseWidgetExtensionBundle.swift
//  VerseWidgetExtension
//
//  Created by William Creecy on 11/1/25.
//

import WidgetKit
import SwiftUI

@main
struct VerseWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        VerseWidgetExtension()
        VerseWidgetExtensionControl()
        VerseWidgetExtensionLiveActivity()
    }
}
