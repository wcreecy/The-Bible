# The Bible (iOS) — Developer Guide

Welcome! This document orients new contributors to the app’s structure, patterns, and key components.

## Overview
- SwiftUI app targeting iOS 17+
- SwiftData for persistence (ReaderSettings, ReadingProgress, Favorite, Bookmark, VerseNote, JournalEntry)
- Tabs: Home, Bible, Journal, Games, Favorites, Search, Settings
- iPad: Dedicated split view for Bible (`BibleSplitView`)

## Key Files
- `The_Bible__iOS_App.swift`: App entry, Launch diagnostics overlay, SwiftData container bootstrap.
- `ContentView.swift`: Main tab structure and navigation routing.
- `BibleSplitView.swift`: iPad split UI; sidebar (books) + detail (chapters/readers) with search.
- `ReadingView.swift`: Reader UI with verse selection, favorite toggles, and progress tracking.
- `JournalTabView.swift`, `JournalEditorView.swift`, `JournalDetailView.swift`: Journal list, editor, and detail.
- `HomeView.swift`: Verse of the Day, Timer/Stopwatch/Focus cards, and Live Activities.
- `WidgetReloadManager.swift`: Throttles widget reloads and coalesces updates.
- `BibleReferenceLinker.swift`: Detects and links scripture references in text.
- `BibleBookResolver.swift`: Shared resolver for book name normalization and abbreviations.
- `ReaderFontToolbar.swift`: Reusable toolbar component for reader font sizing.
- `AppConfig.swift`: Centralized App Group identifier and UserDefaults keys.

## App Group & Defaults
- App Group: `AppGroupID.identifier` (see `AppConfig.swift`)
- Shared defaults accessor: `UserDefaults.appGroup`
- Canonical keys: `DefaultsKeys.*`
  - Verse of Day: `verseBook`, `verseChapter`, `verseNumber`, `verseText`
  - Focus: `focusTitle`, `focusBody`
  - Timer actions: `prayerTimerPendingAction`, `stopwatchPendingAction`

## Verse of the Day Policy
- Refreshes only at 6:00 AM and 6:00 PM (unless manually refreshed).
- `HomeView.scheduleNextAutoVerseRefresh()` computes the next boundary and schedules a single timer.
- On foreground activation, we ensure a timer is scheduled if needed; no background polling.

## Editing & Performance
- Journal editor uses buffered state; saves once on Done.
- Inline editor in `JournalTabView` force-saves when navigating away from the selected entry, no idle autosave.
- Avoids per-keystroke SwiftData saves to keep typing smooth.

## Navigation
- Phone: `NavigationStack` per tab; routes defined in `ContentView`.
- iPad: `NavigationSplitView` in `BibleSplitView` with search and routing to `ReadingView`.

## Games
- `HangmanGameView`, `BeatTheClockGameView`, `BookOrderGameView`.
- Use `BibleBookResolver` to normalize references where needed.

## Code Style Notes
- Prefer `ToolbarItem`/`ToolbarItemGroup` for toolbars.
- Use shared components (e.g., `ReaderFontToolbar`) to avoid duplication.
- Avoid hard-coded strings for defaults and suite names; use `AppConfig`.

## Deletions & Legacy
- `CloudKitManager.swift` is marked SAFE_TO_DELETE — unused in current app.
- User guides have been removed from the target and disk (see `Docs/SAFE_TO_DELETE_UserGuides.md`).

## Contributing
- Use #Preview for SwiftUI previews.
- Keep long-running work off the main actor.
- When adding new defaults keys, add them to `DefaultsKeys`.

