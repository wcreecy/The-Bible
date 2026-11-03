import SwiftUI

// Home's Today card: three small challenges from `TodayChallengeStore`.

struct HomeTodayCard: View {
    private var store = TodayChallengeStore.shared
    @State private var studyChallenge: TodayChallenge?

    /// Starts the Home prayer timer for the given number of minutes.
    let onStartPrayerTimer: (Int) -> Void

    var body: some View {
        HeroCard(title: "Today", icon: "checklist", tint: .teal) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Three small ways to grow today")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)

                    #if DEBUG
                    Button {
                        store.regenerateForDebug()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Refresh Today challenges")
                    .accessibilityHint("Available only in debug builds.")
                    #endif
                }

                ForEach(store.challenges) { challenge in
                    TodayChallengeRow(challenge: challenge) {
                        perform(challenge)
                    }
                }
            }
        }
        .sheet(item: $studyChallenge) { challenge in
            NavigationStack {
                if let bookName = challenge.bookName, let chapterNumber = challenge.chapterNumber {
                    ChapterInsightsView(bookName: bookName, chapterNumber: chapterNumber)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    studyChallenge = nil
                                }
                            }
                        }
                } else {
                    ContentUnavailableView("Study unavailable", systemImage: "text.book.closed")
                }
            }
        }
        .onAppear {
            store.refresh()
        }
        .task {
            await refreshAtNextDayBoundary()
        }
    }

    /// Refreshes the card at each local calendar-day boundary while it remains visible.
    private func refreshAtNextDayBoundary() async {
        let calendar = Calendar.autoupdatingCurrent

        while !Task.isCancelled {
            let now = Date()
            let startOfTomorrow = calendar.date(
                byAdding: .day,
                value: 1,
                to: calendar.startOfDay(for: now)
            ) ?? now.addingTimeInterval(86_400)
            let interval = max(1, startOfTomorrow.timeIntervalSince(now))

            do {
                try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            store.refresh()
        }
    }

    /// Takes the person straight to the activity a challenge describes.
    private func perform(_ challenge: TodayChallenge) {
        switch challenge.kind {
        case .readChapter:
            guard let bookName = challenge.bookName, let chapter = challenge.chapterNumber else { return }
            Haptics.selection()
            AppRouter.shared.openBibleReference(book: bookName, chapter: chapter, verse: 1)
        case .studyChapter:
            guard challenge.bookName != nil, challenge.chapterNumber != nil else { return }
            Haptics.selection()
            store.completeStudyChallenge(id: challenge.id)
            studyChallenge = challenge
        case .playGame:
            guard let gameName = challenge.gameName else { return }
            Haptics.selection()
            GameLaunchRequest.open(gameName: gameName)
        case .prayerTimer:
            guard !challenge.isCompleted, let minutes = challenge.minimumMinutes else { return }
            Haptics.selection()
            onStartPrayerTimer(minutes)
        case .reflection:
            store.toggleManualChallenge(id: challenge.id)
        case .favoriteVerse, .highlightVerse:
            break
        }
    }
}

struct TodayChallengeRow: View {
    let challenge: TodayChallenge
    let action: () -> Void

    /// Completed prayer challenges have nothing left to start.
    private var isActionable: Bool {
        ![.favoriteVerse, .highlightVerse].contains(challenge.kind) &&
            !(challenge.kind == .prayerTimer && challenge.isCompleted)
    }

    var body: some View {
        Button(action: action) {
            rowContent
        }
        .buttonStyle(.plain)
        .disabled(!isActionable)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: challenge.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(challenge.isCompleted ? Color.green : Color.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(challenge.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(challenge.isCompleted ? .secondary : .primary)
                    .strikethrough(challenge.isCompleted, color: .secondary)

                Text(challenge.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if let actionLabel {
                Label(actionLabel.title, systemImage: actionLabel.systemImage)
                    .labelStyle(.iconOnly)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }

    /// The trailing affordance for rows that open another part of the app.
    private var actionLabel: (title: String, systemImage: String)? {
        switch challenge.kind {
        case .readChapter: ("Read", "book")
        case .studyChapter: ("Study", "text.book.closed")
        case .playGame: ("Play", "gamecontroller")
        case .prayerTimer: challenge.isCompleted ? nil : ("Start", "timer")
        case .reflection: nil
        case .favoriteVerse: ("Favorite verse", "heart")
        case .highlightVerse: ("Highlight verse", "highlighter")
        }
    }

    private var accessibilityLabel: String {
        challenge.isCompleted ? "\(challenge.title), completed" : challenge.title
    }

    private var accessibilityHint: String {
        switch challenge.kind {
        case .readChapter:
            "Opens the chapter."
        case .studyChapter:
            "Opens chapter insights and marks this study complete."
        case .playGame:
            "Opens the game."
        case .prayerTimer:
            challenge.isCompleted ? "" : "Starts a prayer timer."
        case .reflection:
            challenge.isCompleted ? "Double tap to mark incomplete." : "Double tap to mark complete."
        case .favoriteVerse:
            challenge.isCompleted ? "Completed automatically when a verse was added to Favorites." : "Add a verse to Favorites to complete this automatically."
        case .highlightVerse:
            challenge.isCompleted ? "Completed automatically when a verse was highlighted." : "Highlight a verse to complete this automatically."
        }
    }
}
