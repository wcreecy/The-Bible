import SwiftUI

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

    var body: some View {
        List {
            Section("Available Games") {
                // 1. Bible Quiz
                NavigationLink(value: GameRoute.quiz) {
                    HStack(spacing: 12) {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bible Quiz").font(.headline)
                            Text("Guess which book the given verse is from").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                
                // 2. Hangman
                NavigationLink(value: GameRoute.hangman) {
                    HStack(spacing: 12) {
                        Image(systemName: "text.word.spacing")
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hangman").font(.headline)
                            Text("Guess a person, place or book from the Bible").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                
                // 3. Verse Match
                NavigationLink(value: GameRoute.verseMatch) {
                    HStack(spacing: 12) {
                        Image(systemName: "text.quote")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Verse Match").font(.headline)
                            Text("Match the verse to its reference").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                // 4. Who am I?
                NavigationLink(value: GameRoute.whoAmI) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.text.rectangle")
                            .foregroundStyle(.brown)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Who am I?").font(.headline)
                            Text("Match names and descriptions").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                // 5. Wordle (Bible) — soft green glow when Daily is available
                NavigationLink(value: GameRoute.wordle) {
                    ZStack {
                        if shouldGlowWordle {
                            // Layered blurred glows for a soft aura effect
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.green.opacity(0.28))
                                .blur(radius: pulse ? 18 : 12)
                                .scaleEffect(pulse ? 1.02 : 1.0)
                                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.green.opacity(0.18))
                                .blur(radius: pulse ? 30 : 22)
                                .scaleEffect(pulse ? 1.03 : 1.0)
                                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "square.grid.3x3")
                                .foregroundStyle(.mint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Wordle (Bible)").font(.headline)
                                Text("Guess the 5‑letter word in 6 tries").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .onAppear {
                        if shouldGlowWordle {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                pulse = true
                            }
                        }
                    }
                }
                
                // 6. Book Order
                NavigationLink(value: GameRoute.bookOrder) {
                    HStack(spacing: 12) {
                        Image(systemName: "list.number")
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Book Order").font(.headline)
                            Text("Drag books into order").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                // 7. Beat the Clock
                NavigationLink(value: GameRoute.beatTheClock) {
                    HStack(spacing: 12) {
                        Image(systemName: "hourglass")
                            .foregroundStyle(.indigo)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Beat the Clock").font(.headline)
                            Text("Name a Bible book before time runs out").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                
                // 8. Word Search
                NavigationLink(value: GameRoute.wordSearch) {
                    HStack(spacing: 12) {
                        Image(systemName: "grid")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Word Search").font(.headline)
                            Text("Find 3–6 hidden words from a verse").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }

                // 9. Favorites Flashcards
                NavigationLink(value: GameRoute.favoritesFlashcards) {
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
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Games")
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
        .onAppear { selection = nil }
    }
}

#Preview {
    NavigationStack { GamesView() }
}

