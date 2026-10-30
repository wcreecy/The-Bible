import Foundation

/// Per-book and per-category accuracy for Quiz, Trivia, Verse Match, Hangman and Countdown, plus book mastery.
extension GameStats {
    // MARK: - Per-book analytics (Quiz, Trivia, Verse Match)
    //
    // The three games record the same four maps per book (see `PerBookKeys`), so one set of
    // helpers serves all of them.

    private func perBookMaps(_ keys: PerBookKeys) -> (answered: [String: Int], correct: [String: Int]) {
        (loadJSONMap(forKey: keys.answered), loadJSONMap(forKey: keys.correct))
    }

    private func perBookDailyMaps(_ keys: PerBookKeys) -> (answered: [String: [String: Int]], correct: [String: [String: Int]]) {
        (loadNestedJSONMap(forKey: keys.dailyAnswered), loadNestedJSONMap(forKey: keys.dailyCorrect))
    }

    private static func percentage(correct: Int, answered: Int) -> Double {
        guard answered > 0 else { return 0 }
        return min(100, max(0, (Double(correct) / Double(answered)) * 100))
    }

    /// Whether each Bible book is in the Old Testament (true) or New (false).
    private func testamentByBook() -> [String: Bool] {
        let books = BibleData.books
        guard let matthew = books.firstIndex(where: { $0.name == "Matthew" }) else { return [:] }
        return Dictionary(uniqueKeysWithValues: books.enumerated().map { ($1.name, $0 < matthew) })
    }

    private func perBookTestamentSummary(
        answeredMap: [String: Int],
        correctMap: [String: Int]
    ) -> (otAnswered: Int, otCorrect: Int, ntAnswered: Int, ntCorrect: Int, otPct: Double, ntPct: Double) {
        let isOldTestament = testamentByBook()
        var otA = 0, otC = 0, ntA = 0, ntC = 0
        for book in Set(answeredMap.keys).union(correctMap.keys) {
            let answered = max(0, answeredMap[book] ?? 0)
            let correct = max(0, correctMap[book] ?? 0)
            switch isOldTestament[book] {
            case true?: otA += answered; otC += correct
            case false?: ntA += answered; ntC += correct
            case nil: break
            }
        }
        return (otA, otC, ntA, ntC, Self.percentage(correct: otC, answered: otA), Self.percentage(correct: ntC, answered: ntA))
    }

    /// Accuracy for each genre, in canonical genre order. Verse Match counts every book it
    /// has recorded; the other games count only names found in the Bible.
    private func perBookGenreAccuracy(
        answeredMap: [String: Int],
        correctMap: [String: Int],
        requiresKnownBook: Bool
    ) -> [(genre: String, answered: Int, correct: Int, pct: Double)] {
        let knownBooks = Set(BibleData.books.map(\.name))
        var buckets: [StatsSeriesBuilder.Genre: (answered: Int, correct: Int)] = [:]
        for book in Set(answeredMap.keys).union(correctMap.keys) {
            let answered = max(0, answeredMap[book] ?? 0)
            guard answered > 0, !requiresKnownBook || knownBooks.contains(book) else { continue }
            let genre = StatsSeriesBuilder.genreForBook(book)
            var bucket = buckets[genre] ?? (0, 0)
            bucket.answered += answered
            bucket.correct += max(0, correctMap[book] ?? 0)
            buckets[genre] = bucket
        }
        let order: [StatsSeriesBuilder.Genre] = [.Law, .History, .Poetry, .MajorProphets, .MinorProphets, .Gospels, .Acts, .Epistles, .Apocalypse]
        return order.map { genre in
            let values = buckets[genre] ?? (0, 0)
            return (genre.rawValue, values.answered, values.correct, Self.percentage(correct: values.correct, answered: values.answered))
        }
    }

    /// Every book in a genre, in canonical order, with its all-time accuracy.
    private func perBookAccuracy(
        inGenre genreName: String,
        answeredMap: [String: Int],
        correctMap: [String: Int]
    ) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        BibleData.books.compactMap { book in
            guard StatsSeriesBuilder.genreForBook(book.name).rawValue == genreName else { return nil }
            let answered = max(0, answeredMap[book.name] ?? 0)
            let correct = max(0, correctMap[book.name] ?? 0)
            return (book.name, answered, correct, Self.percentage(correct: correct, answered: answered))
        }
    }

    /// Books ranked by accuracy over the last N days, ignoring books with too few attempts.
    private func rankedPerBookRows(
        dailyAnswered: [String: [String: Int]],
        dailyCorrect: [String: [String: Int]],
        lastNDays: Int,
        minAttempts: Int,
        strongestFirst: Bool
    ) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        let start = calendar.startOfDay(for: Date())
        var answered: [String: Int] = [:]
        var correct: [String: Int] = [:]
        for dayOffset in stride(from: lastNDays - 1, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: start) else { continue }
            let key = Self.localDayKey(for: date, calendar: calendar)
            dailyAnswered[key]?.forEach { answered[$0.key, default: 0] += max(0, $0.value) }
            dailyCorrect[key]?.forEach { correct[$0.key, default: 0] += max(0, $0.value) }
        }
        return Set(answered.keys).union(correct.keys).compactMap { book in
            let count = max(0, answered[book] ?? 0)
            guard count >= minAttempts else { return nil }
            let correctCount = max(0, correct[book] ?? 0)
            return (book, count, correctCount, Self.percentage(correct: correctCount, answered: count))
        }
        .sorted {
            if $0.pct == $1.pct { return $0.book < $1.book }
            return strongestFirst ? $0.pct > $1.pct : $0.pct < $1.pct
        }
    }

    // MARK: Trivia

    func triviaOTNTSummary() -> (otAnswered: Int, otCorrect: Int, ntAnswered: Int, ntCorrect: Int, otPct: Double, ntPct: Double) {
        let maps = perBookMaps(.trivia)
        return perBookTestamentSummary(answeredMap: maps.answered, correctMap: maps.correct)
    }

    func triviaAccuracyByGenre() -> [(genre: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookMaps(.trivia)
        return perBookGenreAccuracy(answeredMap: maps.answered, correctMap: maps.correct, requiresKnownBook: true)
    }

    func triviaAccuracyByBook(inGenre genreName: String) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookMaps(.trivia)
        return perBookAccuracy(inGenre: genreName, answeredMap: maps.answered, correctMap: maps.correct)
    }

    func triviaWeakBooks(lastNDays: Int, minAttempts: Int) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookDailyMaps(.trivia)
        return rankedPerBookRows(dailyAnswered: maps.answered, dailyCorrect: maps.correct, lastNDays: lastNDays, minAttempts: minAttempts, strongestFirst: false)
    }

    func triviaStrongBooks(lastNDays: Int, minAttempts: Int) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookDailyMaps(.trivia)
        return rankedPerBookRows(dailyAnswered: maps.answered, dailyCorrect: maps.correct, lastNDays: lastNDays, minAttempts: minAttempts, strongestFirst: true)
    }

    // MARK: Quiz

    func quizOTNTSummary() -> (otAnswered: Int, otCorrect: Int, ntAnswered: Int, ntCorrect: Int, otPct: Double, ntPct: Double) {
        let maps = perBookMaps(.quiz)
        return perBookTestamentSummary(answeredMap: maps.answered, correctMap: maps.correct)
    }

    func quizAccuracyByGenre() -> [(genre: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookMaps(.quiz)
        return perBookGenreAccuracy(answeredMap: maps.answered, correctMap: maps.correct, requiresKnownBook: true)
    }

    func quizAccuracyByBook(inGenre genreName: String) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookMaps(.quiz)
        return perBookAccuracy(inGenre: genreName, answeredMap: maps.answered, correctMap: maps.correct)
    }

    func quizWeakBooks(lastNDays: Int, minAttempts: Int) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookDailyMaps(.quiz)
        return rankedPerBookRows(dailyAnswered: maps.answered, dailyCorrect: maps.correct, lastNDays: lastNDays, minAttempts: minAttempts, strongestFirst: false)
    }

    func quizStrongBooks(lastNDays: Int, minAttempts: Int) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookDailyMaps(.quiz)
        return rankedPerBookRows(dailyAnswered: maps.answered, dailyCorrect: maps.correct, lastNDays: lastNDays, minAttempts: minAttempts, strongestFirst: true)
    }

    func hangmanAccuracyByCategory() -> [(category: String, answered: Int, correct: Int, pct: Double)] {
        let aMap = loadJSONMap(forKey: "hangmanPerCategoryAnsweredMap")
        let cMap = loadJSONMap(forKey: "hangmanPerCategoryCorrectMap")
        let order = ["People", "Places", "Books"]
        return order.map { cat in
            let a = max(0, aMap[cat] ?? 0)
            let c = max(0, cMap[cat] ?? 0)
            let pct = a > 0 ? min(100, max(0, (Double(c) / Double(a)) * 100.0)) : 0
            return (cat, a, c, pct)
        }
    }

    func beatclockAccuracyByType() -> [(type: String, answered: Int, correct: Int, pct: Double)] {
        let aMap = loadJSONMap(forKey: "beatclockPerTypeAnsweredMap")
        let cMap = loadJSONMap(forKey: "beatclockPerTypeCorrectMap")
        let order = ["People", "Places"]
        return order.map { t in
            let a = max(0, aMap[t] ?? 0)
            let c = max(0, cMap[t] ?? 0)
            let pct = a > 0 ? min(100, max(0, (Double(c) / Double(a)) * 100.0)) : 0
            return (t, a, c, pct)
        }
    }

    // MARK: Verse Match

    func verseMatchOTNTSummary() -> (otAnswered: Int, otCorrect: Int, ntAnswered: Int, ntCorrect: Int, otPct: Double, ntPct: Double) {
        let maps = perBookMaps(.verseMatch)
        return perBookTestamentSummary(answeredMap: maps.answered, correctMap: maps.correct)
    }

    func verseMatchAccuracyByGenre() -> [(genre: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookMaps(.verseMatch)
        return perBookGenreAccuracy(answeredMap: maps.answered, correctMap: maps.correct, requiresKnownBook: false)
    }

    func verseMatchAccuracyByBook(inGenre genreName: String) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookMaps(.verseMatch)
        return perBookAccuracy(inGenre: genreName, answeredMap: maps.answered, correctMap: maps.correct)
    }

    func verseMatchWeakBooks(lastNDays: Int, minAttempts: Int) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookDailyMaps(.verseMatch)
        return rankedPerBookRows(dailyAnswered: maps.answered, dailyCorrect: maps.correct, lastNDays: lastNDays, minAttempts: minAttempts, strongestFirst: false)
    }

    func verseMatchStrongBooks(lastNDays: Int, minAttempts: Int) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let maps = perBookDailyMaps(.verseMatch)
        return rankedPerBookRows(dailyAnswered: maps.answered, dailyCorrect: maps.correct, lastNDays: lastNDays, minAttempts: minAttempts, strongestFirst: true)
    }

    /// Combined book mastery from the two games that record canonical Bible-book results.
    func bookMastery(minAttempts: Int = 5) -> [(book: String, answered: Int, correct: Int, pct: Double)] {
        let quizMaps = perBookMaps(.quiz)
        let verseMaps = perBookMaps(.verseMatch)
        return BibleData.books.compactMap { book in
            let name = book.name
            let answered = max(0, quizMaps.answered[name] ?? 0) + max(0, verseMaps.answered[name] ?? 0)
            guard answered >= minAttempts else { return nil }
            let correct = max(0, quizMaps.correct[name] ?? 0) + max(0, verseMaps.correct[name] ?? 0)
            return (name, answered, correct, min(100, max(0, Double(correct) / Double(answered) * 100)))
        }
        .sorted { lhs, rhs in
            if lhs.pct == rhs.pct { return lhs.book < rhs.book }
            return lhs.pct > rhs.pct
        }
    }
}
