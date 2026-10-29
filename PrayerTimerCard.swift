import SwiftUI
import SwiftData

/// Where the verse shown during a prayer session comes from.
enum PrayerVerseSource: String, CaseIterable, Identifiable {
    case verseOfDay
    case pinned
    case favorite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .verseOfDay: "Verse of the Day"
        case .pinned: "Pinned Verse"
        case .favorite: "A Favorite"
        }
    }

    var systemImage: String {
        switch self {
        case .verseOfDay: "sun.max"
        case .pinned: "pin"
        case .favorite: "heart"
        }
    }
}

struct PrayerTimerCard: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Timer state
    let isTimerRunning: Bool
    let isPaused: Bool
    let remainingSeconds: Int
    let totalSeconds: Int
    let formattedTime: (Int) -> String
    /// Shown as a meditation verse when chosen as the source.
    let verseOfDay: HomeVerseRef?
    /// True for a few seconds after Stop.
    let canUndoStop: Bool

    // Actions
    let onOpenSetup: () -> Void
    let onStartPreset: (Int) -> Void
    let onTogglePause: () -> Void
    let onAddOne: () -> Void
    let onAddFive: () -> Void
    let onStop: () -> Void
    let onUndoStop: () -> Void

    /// Uses the standard foreground color so timer controls stay neutral and legible.
    private let tint = Color.primary
    private static let presets = [5, 10, 15, 20]

    @AppStorage(PrayerTimerController.lastMinutesKey) private var lastMinutes: Int = 0
    /// The kind of the next session; it matches the running one while a timer runs.
    @AppStorage(PrayerTimerKind.preferenceKey) private var kindRaw = PrayerTimerKind.prayer.rawValue

    private var kind: PrayerTimerKind {
        PrayerTimerKind(rawValue: kindRaw) ?? .prayer
    }

    var body: some View {
        HeroCard(
            // Names the running session; the generic name invites a choice while idle.
            title: isTimerRunning ? kind.sessionName : "Prayer & Study Timer",
            subtitle: nil,
            icon: kind.systemImage,
            tint: tint
        ) {
            if isTimerRunning {
                runningContent
            } else {
                idleContent
            }
        }
        .animation(.snappy, value: isTimerRunning)
        .animation(.snappy, value: canUndoStop)
    }

    // MARK: - Running

    private var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1, max(0, Double(remainingSeconds) / Double(totalSeconds)))
    }

    private var runningContent: some View {
        VStack(spacing: 16) {
            timerRing
                .frame(maxWidth: .infinity)

            HStack(spacing: 14) {
                Button(action: onTogglePause) {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .foregroundStyle(isPaused ? Color.white : Color.black)
                }
                .buttonStyle(.glass(.regular.tint(isPaused ? .green : .yellow)))
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityLabel(isPaused ? "Resume" : "Pause")

                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                }
                .buttonStyle(.glass(.regular.tint(.red)))
                .buttonBorderShape(.circle)
                .controlSize(.large)
                .accessibilityLabel("Stop")

                addTimeButton("+1", label: "Add 1 minute", action: onAddOne)
                addTimeButton("+5", label: "Add 5 minutes", action: onAddFive)
            }
            .frame(maxWidth: .infinity)

            PrayerMeditationVerse(verseOfDay: verseOfDay, tint: tint)
        }
    }

    private var timerRing: some View {
        let ringSize: CGFloat = horizontalSizeClass == .compact ? 150 : 170

        return ZStack {
            Circle()
                .stroke(tint.opacity(0.15), lineWidth: 8)

            ringProgress

            VStack(spacing: 2) {
                Text(formattedTime(remainingSeconds))
                    .font(.system(size: horizontalSizeClass == .compact ? 34 : 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(isPaused ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint))
                    .contentTransition(.numericText(countsDown: true))

                if isPaused {
                    Text("Paused")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(width: ringSize, height: ringSize)
        .animation(.linear(duration: 1), value: remainingSeconds)
        .animation(.easeInOut, value: isPaused)
        .contentShape(Circle())
        .onTapGesture(perform: onTogglePause)
        // VoiceOver reads the remaining time; pausing is offered as an action.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timeAccessibilityLabel)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityAction(named: isPaused ? "Resume" : "Pause", onTogglePause)
    }

    @ViewBuilder
    private var ringProgress: some View {
        let ring = Circle()
            .trim(from: 0, to: progress)
            .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .rotationEffect(.degrees(-90))

        if isPaused {
            // A slow pulse makes a paused timer easy to spot.
            ring.phaseAnimator([1.0, 0.35]) { content, opacity in
                content.opacity(opacity)
            } animation: { _ in
                .easeInOut(duration: 1.1)
            }
        } else {
            ring
        }
    }

    private var timeAccessibilityLabel: String {
        let remaining = Duration.seconds(remainingSeconds)
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide))
        return isPaused ? "\(remaining) remaining, paused" : "\(remaining) remaining"
    }

    private func addTimeButton(_ title: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
        }
        .buttonStyle(.glass(.clear))
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .accessibilityLabel(label)
    }

    // MARK: - Idle

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // One tap chooses what the session is for; presets and Start use it.
            Picker("Timer type", selection: $kindRaw) {
                ForEach(PrayerTimerKind.allCases) { kind in
                    Text(kind.title).tag(kind.rawValue)
                }
            }
            .pickerStyle(.segmented)

            // Presets, your last duration (when it isn't a preset), and Custom share one row.
            // Circles and spacing shrink on narrow cards so the row never wraps.
            ViewThatFits(in: .horizontal) {
                durationRow(spacing: 12, diameter: 56)
                durationRow(spacing: 8, diameter: 52)
                durationRow(spacing: 6, diameter: 46)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

            if canUndoStop {
                HStack {
                    Label("\(kind.title) timer stopped", systemImage: "stop.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Undo", action: onUndoStop)
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.borderless)
                }
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: AppDesignMetrics.compactControlCornerRadius, style: .continuous)
                        .fill(tint.opacity(0.1))
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()

            PrayerStatsSummaryRow(tint: tint)
        }
    }

    private var showsLastDuration: Bool {
        lastMinutes > 0 && !Self.presets.contains(lastMinutes)
    }

    private func durationRow(spacing: CGFloat, diameter: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(Self.presets, id: \.self) { minutes in
                Button { onStartPreset(minutes) } label: {
                    durationLabel(minutes, diameter: diameter)
                }
                .buttonStyle(ModernCircleButtonStyle(tint: tint, diameter: diameter))
                .accessibilityLabel("Start \(minutes) minutes")
            }

            if showsLastDuration {
                // Keeps your usual length alongside the standard presets.
                Button { onStartPreset(lastMinutes) } label: {
                    durationLabel(lastMinutes, diameter: diameter)
                }
                .buttonStyle(ModernCircleButtonStyle(tint: tint, diameter: diameter))
                .accessibilityLabel("Start \(lastMinutes) minutes, your last duration")
            }

            Button(action: onOpenSetup) {
                circleLabel(diameter: diameter) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: diameter * 0.3, weight: .bold))
                        // Match the number's height so the caption lines up with the presets.
                        .frame(height: diameter * 0.36)
                } caption: {
                    Text("More")
                }
            }
            .buttonStyle(ModernCircleButtonStyle(tint: tint, diameter: diameter))
            .accessibilityLabel("Custom timer duration")
        }
    }

    private func durationLabel(_ minutes: Int, diameter: CGFloat) -> some View {
        circleLabel(diameter: diameter) {
            Text("\(minutes)")
                .font(.system(size: diameter * 0.36, weight: .bold, design: .rounded))
                .monospacedDigit()
        } caption: {
            Text("min")
        }
    }

    /// A large value over a small uppercase caption, sized to sit inside a circle
    /// of the given diameter with even breathing room on every side.
    private func circleLabel<Value: View, Caption: View>(
        diameter: CGFloat,
        @ViewBuilder value: () -> Value,
        @ViewBuilder caption: () -> Caption
    ) -> some View {
        VStack(spacing: 0) {
            value()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            caption()
                .font(.system(size: max(8, diameter * 0.17), weight: .semibold, design: .rounded))
                .textCase(.uppercase)
                .tracking(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .opacity(0.75)
        }
        // Keep text inside the circle's inscribed area rather than its bounding box.
        .frame(width: diameter * 0.72)
    }
}

// MARK: - Stats summary

/// This week's time, streak, and last session for the chosen kind of session; or an
/// invitation before any history.
private struct PrayerStatsSummaryRow: View {
    let tint: Color

    @AppStorage(PrayerTimerKind.preferenceKey) private var kindRaw = PrayerTimerKind.prayer.rawValue

    private var kind: PrayerTimerKind {
        PrayerTimerKind(rawValue: kindRaw) ?? .prayer
    }

    /// Bumped when prayer stats change (including from another device).
    @State private var revision = 0

    var body: some View {
        let _ = revision
        let summary = PrayerStatsStore.store(for: kind).summary()

        content(summary)
            // Refresh on appear too, in case stats changed while Home was hidden.
            .onAppear { revision += 1 }
            .onNotification(.prayerStatsUpdated) {
                revision += 1
            }
    }

    @ViewBuilder
    private func content(_ summary: PrayerStatsSummary) -> some View {
        if summary.hasHistory {
            HStack(spacing: 0) {
                stat(prayerMinutesText(summary.weekSeconds), caption: "This week", systemImage: "clock.fill")
                stat(
                    summary.currentStreak == 1 ? "1 day" : "\(summary.currentStreak) days",
                    caption: "\(kind.title) streak",
                    systemImage: "flame.fill"
                )
                stat(prayerMinutesText(summary.lastSessionSeconds), caption: "Last session", systemImage: "clock.arrow.circlepath")
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("“Be still, and know that I am God.”")
                    .font(.callout.italic())
                Text("Psalm 46:10")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private func stat(_ value: String, caption: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
            }
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Meditation verse

/// A verse to dwell on while the timer runs: Verse of the Day, the pinned verse, or a
/// favorite. Falls back to the Verse of the Day when the chosen source is empty.
private struct PrayerMeditationVerse: View {
    let verseOfDay: HomeVerseRef?
    let tint: Color

    @AppStorage("prayerTimerVerseSource") private var sourceRaw = PrayerVerseSource.verseOfDay.rawValue
    @Query(sort: [SortDescriptor(\Favorite.createdAt)]) private var favorites: [Favorite]

    private var source: PrayerVerseSource {
        PrayerVerseSource(rawValue: sourceRaw) ?? .verseOfDay
    }

    private var pinnedVerse: HomeVerseRef? {
        guard let shared = UserDefaults(suiteName: "group.bible.app"),
              let book = shared.string(forKey: "pinnedVerseBook"), !book.isEmpty else { return nil }
        let chapter = shared.integer(forKey: "pinnedVerseChapter")
        let verse = shared.integer(forKey: "pinnedVerseNumber")
        let text = shared.string(forKey: "pinnedVerseText") ?? ""
        guard chapter > 0, verse > 0, !text.isEmpty else { return nil }
        return HomeVerseRef(bookName: book, chapterNumber: chapter, verseNumber: verse, verseText: text)
    }

    /// One favorite per day, so the verse stays put through a session.
    private var favoriteVerse: HomeVerseRef? {
        guard !favorites.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let favorite = favorites[day % favorites.count]
        return HomeVerseRef(
            bookName: favorite.bookName,
            chapterNumber: favorite.chapterNumber,
            verseNumber: favorite.verseNumber,
            verseText: favorite.verseText
        )
    }

    private func verse(for source: PrayerVerseSource) -> HomeVerseRef? {
        switch source {
        case .verseOfDay: verseOfDay
        case .pinned: pinnedVerse
        case .favorite: favoriteVerse
        }
    }

    var body: some View {
        let shown = verse(for: source) ?? verseOfDay

        if let shown, !shown.verseText.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(shown.bookName) \(shown.chapterNumber):\(shown.verseNumber)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)

                    Spacer()

                    Menu {
                        Picker("Verse", selection: $sourceRaw) {
                            ForEach(PrayerVerseSource.allCases) { option in
                                Label(option.title, systemImage: option.systemImage)
                                    .tag(option.rawValue)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Choose verse")
                }

                Text("“\(shown.verseText)”")
                    .font(.callout.italic())
                    .foregroundStyle(.primary)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: AppDesignMetrics.compactControlCornerRadius, style: .continuous)
                    .fill(tint.opacity(0.08))
            }
            .accessibilityElement(children: .contain)
        }
    }
}
