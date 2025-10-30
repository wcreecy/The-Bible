import SwiftUI
import SwiftData
import Combine
import UserNotifications
import AudioToolbox
import UIKit

struct HomeView: View {
    @Query private var progressList: [ReadingProgress]
    @State private var showPrayerStudySheet: Bool = false
    
    @State private var isTimerRunning: Bool = false
    @State private var isPaused: Bool = false
    @State private var remainingSeconds: Int = 0
    private let prayerTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @AppStorage("prayerTimerEndDate") private var storedEndDate: Double = 0
    @AppStorage("prayerTimerRunning") private var storedRunning: Bool = false
    @AppStorage("prayerTimerPaused") private var storedPaused: Bool = false
    @AppStorage("prayerTimerRemainingWhenPaused") private var storedRemainingWhenPaused: Int = 0
    @AppStorage("verseOfDayScope") private var verseScopeRaw: String = "whole"

    @State private var showFinishedAlert: Bool = false
    @State private var finishHapticTimer: Timer? = nil

    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [Favorite]
    @State private var verseOfDay: VerseRef? = nil
    
    var progress: ReadingProgress? {
        progressList.first
    }
    
    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("Verse of the Day")
                    .font(.title3)
                    .bold()

                if let v = verseOfDay {
                    Text(v.verseText)
                        .font(.body)
                        .italic()
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(v.bookName) \(v.chapterNumber):\(v.verseNumber)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)

                    HStack(spacing: 24) {
                        Button(action: { loadRandomVerse() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Refresh")

                        Button(action: { copyVerse(v) }) {
                            Image(systemName: "doc.on.doc")
                        }
                        .help("Copy")

                        ShareLink(item: shareText(for: v)) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .help("Share")

                        Button(action: { toggleFavorite(for: v) }) {
                            Image(systemName: isFavorited(v) ? "heart.fill" : "heart")
                                .foregroundStyle(.red)
                        }
                        .help("Favorite")
                    }
                    .font(.title3)
                } else {
                    // Placeholder while loading
                    Text("Tap refresh to get today's verse.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 24) {
                        Button(action: { loadRandomVerse() }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help("Refresh")
                    }
                    .font(.title3)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
            )
            .padding([.horizontal, .top])
            
            Spacer()
            if isTimerRunning {
                VStack(spacing: 8) {
                    HStack { Spacer() }
                    VStack(spacing: 8) {
                        Text("Prayer/Study")
                            .font(.headline)
                            .bold()
                        Text(formattedTime(remainingSeconds))
                            .font(.system(size: 32, weight: .semibold, design: .monospaced))
                        HStack(spacing: 12) {
                            Button(action: { togglePause() }) {
                                Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button(role: .destructive, action: stopTimer) {
                                Label("Stop", systemImage: "stop.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .multilineTextAlignment(.center)
                    HStack { Spacer() }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.25), lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
            } else {
                Button(action: { showPrayerStudySheet = true }) {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text("Prayer/Study")
                                .font(.headline)
                                .bold()
                            Text("Set a timer to focus")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.center)
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.bottom, 8)
            }
            VStack(spacing: 8) {
                if let progress = progress,
                   let book = BibleData.books.first(where: { $0.name == progress.bookName }),
                   let chapter = book.chapters.first(where: { $0.number == progress.chapterNumber }) {
                    NavigationLink(
                        destination: ReadingView(book: book, chapter: chapter, startVerse: progress.verseNumber)
                    ) {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Text("Resume")
                                    .font(.headline)
                                    .bold()
                                Text("Continue where you left off")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let p = progressList.first {
                                    Text("\(p.bookName) \(p.chapterNumber):\(p.verseNumber)")
                                        .font(.footnote)
                                        .foregroundStyle(.tertiary)
                                } else {
                                    Text("No recent reading")
                                        .font(.footnote)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .multilineTextAlignment(.center)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    NavigationLink(destination: EmptyView()) {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Text("Resume")
                                    .font(.headline)
                                    .bold()
                                Text("Continue where you left off")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if let p = progressList.first {
                                    Text("\(p.bookName) \(p.chapterNumber):\(p.verseNumber)")
                                        .font(.footnote)
                                        .foregroundStyle(.tertiary)
                                } else {
                                    Text("No recent reading")
                                        .font(.footnote)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .multilineTextAlignment(.center)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(true)
                }
            }
            .padding()
            .padding(.bottom)
        }
        .onAppear {
            // Request notification permission once
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }

            // Restore persisted state
            isTimerRunning = storedRunning
            isPaused = storedPaused
            if storedRunning {
                if isPaused {
                    remainingSeconds = storedRemainingWhenPaused
                } else if storedEndDate > 0 {
                    let remaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
                    remainingSeconds = remaining
                    if remaining == 0 {
                        handleTimerFinished()
                    }
                }
            }
            loadRandomVerse()
        }
        .onReceive(prayerTimer) { _ in
            guard isTimerRunning else { return }
            if isPaused {
                // Keep remaining time as stored
                return
            }
            if storedEndDate > 0 {
                let remaining = Int(max(0, storedEndDate - Date().timeIntervalSince1970))
                remainingSeconds = remaining
                if remaining == 0 {
                    handleTimerFinished()
                }
            }
        }
        .sheet(isPresented: $showPrayerStudySheet) {
            PrayerStudyTimerSetupView(onStart: { minutes in
                startTimer(minutes: minutes)
                showPrayerStudySheet = false
            })
            .presentationDetents([.medium, .large])
        }
        .alert("Prayer/Study Finished", isPresented: $showFinishedAlert) {
            Button("Dismiss", role: .cancel) {
                stopFinishAlerts()
                showFinishedAlert = false
            }
        } message: {
            Text("Your prayer/study timer has completed.")
        }
    }
    
    private func startTimer(minutes: Int) {
        let secs = max(1, minutes) * 60
        let end = Date().addingTimeInterval(TimeInterval(secs))
        remainingSeconds = secs
        isPaused = false
        isTimerRunning = true

        // Persist
        storedRunning = true
        storedPaused = false
        storedEndDate = end.timeIntervalSince1970
        storedRemainingWhenPaused = 0

        scheduleNotification(at: end)
    }

    private func togglePause() {
        guard isTimerRunning else { return }
        isPaused.toggle()
        storedPaused = isPaused
        if isPaused {
            // Freeze remaining
            storedRemainingWhenPaused = remainingSeconds
            cancelNotification()
        } else {
            // Resume: compute new end date from remaining
            let newEnd = Date().addingTimeInterval(TimeInterval(remainingSeconds))
            storedEndDate = newEnd.timeIntervalSince1970
            storedRemainingWhenPaused = 0
            scheduleNotification(at: Date(timeIntervalSince1970: storedEndDate))
        }
    }

    private func stopTimer() {
        isTimerRunning = false
        isPaused = false
        remainingSeconds = 0

        storedRunning = false
        storedPaused = false
        storedEndDate = 0
        storedRemainingWhenPaused = 0

        cancelNotification()
        stopFinishAlerts()
        showFinishedAlert = false
    }

    private func formattedTime(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func scheduleNotification(at date: Date) {
        let center = UNUserNotificationCenter.current()
        // Remove any existing pending timer notification
        center.removePendingNotificationRequests(withIdentifiers: ["PrayerStudyTimerFinished"]) 

        let content = UNMutableNotificationContent()
        content.title = "Prayer/Study Finished"
        content.body = "Your prayer/study timer has completed."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        let request = UNNotificationRequest(identifier: "PrayerStudyTimerFinished", content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    private func cancelNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["PrayerStudyTimerFinished"]) 
    }

    private func handleTimerFinished() {
        // Ensure we only fire once
        if !isTimerRunning { return }
        isTimerRunning = false
        storedRunning = false
        isPaused = false
        storedPaused = false
        remainingSeconds = 0
        storedEndDate = 0
        storedRemainingWhenPaused = 0

        // Start foreground alert with repeating vibration if app is active
        showFinishedAlert = true
        startFinishAlerts()
    }

    private func startFinishAlerts() {
        stopFinishAlerts()
        // Repeating vibration every 1.5 seconds while alert is shown
        finishHapticTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
        // Also vibrate immediately
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }

    private func stopFinishAlerts() {
        finishHapticTimer?.invalidate()
        finishHapticTimer = nil
    }

    private func loadRandomVerse() {
        let allBooks = BibleData.books
        guard !allBooks.isEmpty else { return }

        // Define Old Testament book names
        let oldTestament: Set<String> = [
            "Genesis","Exodus","Leviticus","Numbers","Deuteronomy",
            "Joshua","Judges","Ruth",
            "1 Samuel","2 Samuel",
            "1 Kings","2 Kings",
            "1 Chronicles","2 Chronicles",
            "Ezra","Nehemiah","Esther",
            "Job","Psalms","Proverbs","Ecclesiastes","Song of Solomon",
            "Isaiah","Jeremiah","Lamentations","Ezekiel","Daniel",
            "Hosea","Joel","Amos","Obadiah","Jonah",
            "Micah","Nahum","Habakkuk","Zephaniah",
            "Haggai","Zechariah","Malachi"
        ]

        enum VerseScope: String { case old, new, whole }
        let scope = VerseScope(rawValue: verseScopeRaw) ?? .whole

        let books: [Book]
        switch scope {
        case .old:
            books = allBooks.filter { oldTestament.contains($0.name) }
        case .new:
            books = allBooks.filter { !oldTestament.contains($0.name) }
        case .whole:
            books = allBooks
        }

        guard let book = books.randomElement(), let chapter = book.chapters.randomElement(), !chapter.verses.isEmpty, let verse = chapter.verses.randomElement() else { return }
        verseOfDay = VerseRef(bookName: book.name, chapterNumber: chapter.number, verseNumber: verse.number, verseText: verse.text)
    }

    private func shareText(for v: VerseRef) -> String {
        "\"\(v.verseText)\" — \(v.bookName) \(v.chapterNumber):\(v.verseNumber)"
    }

    private func copyVerse(_ v: VerseRef) {
        UIPasteboard.general.string = shareText(for: v)
    }

    private func isFavorited(_ v: VerseRef) -> Bool {
        favorites.contains { fav in
            fav.bookName == v.bookName && fav.chapterNumber == v.chapterNumber && fav.verseNumber == v.verseNumber
        }
    }

    private func toggleFavorite(for v: VerseRef) {
        if let existing = favorites.first(where: { $0.bookName == v.bookName && $0.chapterNumber == v.chapterNumber && $0.verseNumber == v.verseNumber }) {
            modelContext.delete(existing)
            try? modelContext.save()
        } else {
            let fav = Favorite(bookName: v.bookName, chapterNumber: v.chapterNumber, verseNumber: v.verseNumber, verseText: v.verseText)
            modelContext.insert(fav)
            try? modelContext.save()
        }
    }
}

private struct VerseRef {
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String
}

private struct PrayerStudyTimerSetupView: View {
    @Environment(\.dismiss) private var dismiss
    let onStart: (Int) -> Void

    @State private var selectedMinutes: Int = 15

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("Prayer/Study Timer")
                .font(.title2)
                .bold()

            VStack(spacing: 16) {
                Text("Duration: \(selectedMinutes) minute\(selectedMinutes == 1 ? "" : "s")")
                    .font(.headline)

                Slider(value: Binding(
                    get: { Double(selectedMinutes) },
                    set: { selectedMinutes = max(1, min(120, Int($0))) }
                ), in: 1...120, step: 1)

                HStack {
                    Text("1 min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("120 min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                onStart(selectedMinutes)
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Text("Start Timer")
                        .font(.headline)
                        .bold()
                    Spacer()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }
}
