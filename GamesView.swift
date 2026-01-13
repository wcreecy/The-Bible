import SwiftUI

extension Notification.Name {
    // New cross-tab route to open a specific game start from Stats (or elsewhere)
    static let openGameStart = Notification.Name("openGameStart")
}

struct GamesView: View {
    private enum GameRoute: Hashable {
        case quiz
        case hangman
        case beatTheClock
        case verseMatch
        case favoritesFlashcards
        case bookOrder
        case wordSearch
        case whoAmI // NEW
        case wordle  // NEW
    }

    @State private var selection: GameRoute? = nil
    @State private var pulse: Bool = false
    // Drives the programmatic push without deprecated APIs
    @State private var isPresentingProgrammatic: Bool = false

    // NEW: Debug flag to allow Daily Wordle replay
    @AppStorage("wordleAllowDailyReplay") private var wordleAllowDailyReplay: Bool = false

    // Local-day key helper (yyyy-MM-dd in the user’s current time zone)
    private func localDayKey(for date: Date = Date(), calendar: Calendar = .autoupdatingCurrent) -> String {
        var cal = calendar
        cal.timeZone = .autoupdatingCurrent
        let start = cal.startOfDay(for: date)
        let comps = cal.dateComponents([.year, .month, .day], from: start)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private var hasPlayedDailyWordleTodayRaw: Bool {
        let today = localDayKey()
        let stored = UserDefaults.standard.string(forKey: "wordleDailyCompletedDay")
        return stored == today
    }

    // Glow whenever Daily Wordle is available:
    // - Not played today (normal availability), OR
    // - Debug flag allows replay (forced availability)
    private var shouldGlowWordle: Bool {
        return !hasPlayedDailyWordleTodayRaw || wordleAllowDailyReplay
    }

    // NEW: Load today's WORD daily result (if any)
    private struct DailyResult: Codable { let won: Bool; let guesses: Int; let elapsed: Int; let word: String }

    @State private var todayWordResult: DailyResult? = nil
    @State private var refreshToken: Int = 0

    private func loadTodayWordResult() {
        let today = localDayKey()
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: "wordleDailyResultMap"),
           let map = try? JSONDecoder().decode([String: DailyResult].self, from: data) {
            todayWordResult = map[today]
        } else {
            todayWordResult = nil
        }
    }

    private func formatElapsed(_ s: Int) -> String {
        let seconds = max(0, s)
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let sec = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        } else {
            return String(format: "%d:%02d", m, sec)
        }
    }

    // Map display names to routes for cross-tab open
    private func route(forDisplayName name: String) -> GameRoute? {
        switch name {
        case "Bible Quiz": return .quiz
        case "Hangman": return .hangman
        case "Verse Match": return .verseMatch
        case "Beat the Clock": return .beatTheClock
        case "Book Order": return .bookOrder
        case "Who am I?": return .whoAmI
        case "WORD": return .wordle
        default: return nil
        }
    }

    // Display name for sorting and row labels
    private func displayName(for route: GameRoute) -> String {
        switch route {
        case .quiz: return "Bible Quiz"
        case .hangman: return "Hangman"
        case .verseMatch: return "Verse Match"
        case .whoAmI: return "Who am I?"
        case .wordle: return "WORD"
        case .bookOrder: return "Book Order"
        case .beatTheClock: return "Beat the Clock"
        case .wordSearch: return "Word Search"
        case .favoritesFlashcards: return "Favorites Flashcards"
        }
    }

    // Row content builder preserving per-game UI (WORD special case)
    @ViewBuilder
    private func rowView(for route: GameRoute) -> some View {
        switch route {
        case .quiz:
            HStack(spacing: 12) {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bible Quiz").font(.headline)
                    Text("Guess which book the given verse is from").font(.subheadline).foregroundStyle(.secondary)
                }
            }

        case .hangman:
            HStack(spacing: 12) {
                Image(systemName: "text.word.spacing")
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hangman").font(.headline)
                    Text("Guess a person, place or book from the Bible").font(.subheadline).foregroundStyle(.secondary)
                }
            }

        case .verseMatch:
            HStack(spacing: 12) {
                Image(systemName: "text.quote")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Verse Match").font(.headline)
                    Text("Match the verse to its reference").font(.subheadline).foregroundStyle(.secondary)
                }
            }

        case .whoAmI:
            HStack(spacing: 12) {
                Image(systemName: "person.text.rectangle")
                    .foregroundStyle(.brown)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Who am I?").font(.headline)
                    Text("Match names and descriptions").font(.subheadline).foregroundStyle(.secondary)
                }
            }

        case .wordle:
            HStack(spacing: 12) {
                Image(systemName: "square.grid.3x3")
                    .foregroundStyle(.mint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WORD").font(.headline)
                    if let result = todayWordResult {
                        if result.won {
                            // Win line: green
                            Text("Solved in \(result.guesses) \(result.guesses == 1 ? "guess" : "guesses") – \(formatElapsed(result.elapsed)); \(result.word.uppercased())")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                                .lineLimit(1)
                        } else {
                            // Loss line: red (entire line)
                            HStack(spacing: 4) {
                                Text("Not solved –")
                                    .font(.subheadline)
                                Text(result.word.uppercased())
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(.red)
                            .lineLimit(1)
                        }
                    } else {
                        Text("Guess the 5‑letter word in 6 tries").font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                if shouldGlowWordle {
                    // Trailing subtle indicator dot
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.25))
                            .frame(width: 14, height: 14)
                            .blur(radius: 4)
                            .opacity(pulse ? 1.0 : 0.8)
                            .scaleEffect(pulse ? 1.06 : 1.0)
                            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .opacity(0.95)
                    }
                    .accessibilityLabel("Daily available")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onAppear {
                loadTodayWordResult()
                if shouldGlowWordle {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        pulse = true
                    }
                }
            }

        case .bookOrder:
            HStack(spacing: 12) {
                Image(systemName: "list.number")
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Book Order").font(.headline)
                    Text("Drag books into order").font(.subheadline).foregroundStyle(.secondary)
                }
            }

        case .beatTheClock:
            HStack(spacing: 12) {
                Image(systemName: "hourglass")
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Beat the Clock").font(.headline)
                    Text("Name a Bible book before time runs out").font(.subheadline).foregroundStyle(.secondary)
                }
            }

        case .wordSearch:
            HStack(spacing: 12) {
                Image(systemName: "grid")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Word Search").font(.headline)
                    Text("Find 3–6 hidden words from a verse").font(.subheadline).foregroundStyle(.secondary)
                }
            }

        case .favoritesFlashcards:
            HStack(spacing: 12) {
                Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                    .foregroundStyle(.pink)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Favorites Flashcards").font(.headline)
                    Text("Practice your favorited verses with flashcards").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }

    var body: some View {
        // Build and sort all routes by display name (case-insensitive; WORD caps don’t affect order)
        let allRoutes: [GameRoute] = [
            .quiz, .hangman, .verseMatch, .whoAmI, .wordle, .bookOrder, .beatTheClock, .wordSearch, .favoritesFlashcards
        ]
        let sortedRoutes = allRoutes.sorted {
            displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending
        }

        List {
            Section("Available Games") {
                ForEach(sortedRoutes, id: \.self) { route in
                    NavigationLink(value: route) {
                        rowView(for: route)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden) // Allow our background to show behind the list
        .background(
            Image("games")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
        )
        .navigationTitle("Games")
        // Value-based destinations for user-tapped links
        .navigationDestination(for: GameRoute.self) { route in
            switch route {
            case .quiz:
                QuizView()
            case .hangman:
                HangmanGameView()
            case .beatTheClock:
                BeatTheClockGameView()
            case .verseMatch:
                VerseMatchGameView()
            case .favoritesFlashcards:
                FavoritesFlashcardsGameView()
            case .bookOrder:
                BookOrderGameView()
            case .wordSearch:
                WordSearchGameView()
            case .whoAmI:
                WhoAmIGameView() // NEW
            case .wordle:
                WordleView() // NEW
            }
        }
        // Programmatic destination without deprecated APIs
        .navigationDestination(isPresented: $isPresentingProgrammatic) {
            Group {
                if selection == .quiz {
                    QuizView()
                } else if selection == .hangman {
                    HangmanGameView()
                } else if selection == .beatTheClock {
                    BeatTheClockGameView()
                } else if selection == .verseMatch {
                    VerseMatchGameView()
                } else if selection == .favoritesFlashcards {
                    FavoritesFlashcardsGameView()
                } else if selection == .bookOrder {
                    BookOrderGameView()
                } else if selection == .wordSearch {
                    WordSearchGameView()
                } else if selection == .whoAmI {
                    WhoAmIGameView()
                } else if selection == .wordle {
                    WordleView()
                } else {
                    EmptyView()
                }
            }
            .onDisappear {
                // Reset when user navigates back
                selection = nil
            }
        }
        .onAppear {
            selection = nil
            loadTodayWordResult()
        }
        // Respond to cross-tab "open game" requests
        .onReceive(NotificationCenter.default.publisher(for: .openGameStart)) { note in
            guard let name = note.userInfo?["gameName"] as? String,
                  let route = route(forDisplayName: name) else { return }
            DispatchQueue.main.async {
                selection = route
                isPresentingProgrammatic = true
            }
        }
        // Refresh when Word results/statistics change (including when WordleView writes the result)
        .onReceive(NotificationCenter.default.publisher(for: .gameStatsExternallyUpdated)) { _ in
            refreshToken &+= 1
            loadTodayWordResult()
        }
        // Refresh when app becomes active (covers crossing midnight)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshToken &+= 1
            loadTodayWordResult()
        }
    }
}

#Preview {
    NavigationStack { GamesView() }
}
