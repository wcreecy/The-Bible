import Foundation

// MARK: - Name variants

/// Other spellings the KJV uses for a catalog name: the New Testament's Greek forms ("Elias"
/// for Elijah, "Esaias" for Isaiah), other names for the same person or place ("Abram",
/// "Horeb"), and spellings that differ between books ("Zidon" for Sidon).
///
/// These only keep a book off the board as a wrong choice. They never make a book a right
/// answer, because some are shared with someone else: "mount Sion" in Deuteronomy 4:48 is
/// Hermon, not Zion, and "Jesus" in Hebrews 4:8 is Joshua. Leaving out a book that might
/// mention the name is always safe; offering it as wrong would mark a right tap wrong.
enum BeatTheClockNameVariants {
    /// Keyed by the catalog's name.
    static let spellings: [String: [String]] = [
        // People
        "Abraham": ["Abram"],
        "Ahaz": ["Achaz"],
        "Balak": ["Balac"],
        "Bathsheba": ["Bathshua"],
        "Berenice": ["Bernice"],
        "Bezalel": ["Bezaleel"],
        "Boaz": ["Booz"],
        "Elijah": ["Elias"],
        "Elisha": ["Eliseus"],
        "Enoch": ["Henoch"],
        "Enos": ["Enosh"],
        "Gideon": ["Gedeon", "Jerubbaal"],
        "Hagar": ["Agar"],
        "Herod Agrippa II": ["Agrippa"],
        "Herod Antipas": ["Herod"],
        "Hezekiah": ["Ezekias"],
        "Hiram (king of Tyre)": ["Huram"],
        "Hosea": ["Osee"],
        "Isaiah": ["Esaias"],
        "Jehoiachin": ["Jechonias", "Jeconiah", "Coniah"],
        "Jephthah": ["Jephthae"],
        "Jeremiah": ["Jeremias", "Jeremy"],
        "Jethro": ["Hobab", "Raguel", "Reuel"],
        "John Mark": ["Mark", "Marcus"],
        "John the Baptist": ["John"],
        "Jonadab (son of Rechab)": ["Jehonadab"],
        "Jonah": ["Jonas"],
        "Joshua": ["Jesus", "Jeshua", "Oshea", "Hoshea"],
        "Josiah": ["Josias"],
        "Jotham (king of Judah)": ["Joatham"],
        "Judah": ["Juda", "Judas"],
        "Judas Iscariot": ["Judas"],
        "Korah": ["Core"],
        "Luke": ["Lucas"],
        "Maacah (mother of Abijah)": ["Maachah", "Michaiah"],
        "Manasseh": ["Manasses"],
        "Melchisedec": ["Melchizedek"],
        "Mephibosheth": ["Merib-baal"],
        "Methuselah": ["Mathusala"],
        "Nebuchadnezzar": ["Nebuchadrezzar"],
        "Noah": ["Noe"],
        "Perez": ["Pharez", "Phares"],
        "Phoebe": ["Phebe"],
        "Pontius Pilate": ["Pilate"],
        "Priscilla": ["Prisca"],
        "Queen of Sheba": ["queen of the south"],
        "Rachel": ["Rahel"],
        "Rahab": ["Rachab"],
        "Rebekah": ["Rebecca"],
        "Rehoboam": ["Roboam"],
        "Sarah": ["Sara", "Sarai"],
        "Serah (daughter of Asher)": ["Sarah"],
        "Seth": ["Sheth"],
        "Shem": ["Sem"],
        "Silas": ["Silvanus"],
        "Simon Peter": ["Peter", "Cephas", "Simon"],
        "Tamar (daughter-in-law of Judah)": ["Thamar"],
        "Timotheus": ["Timothy"],
        "Uriah": ["Urias", "Urijah"],
        "Uzzah": ["Uzza"],
        "Uzziah": ["Ozias", "Azariah"],
        "Zebulun": ["Zabulon"],
        "Zerubbabel": ["Zorobabel"],
        // Places
        "Assyria": ["Asshur"],
        "Babel": ["Babylon"],
        "Babylon": ["Babel"],
        "Beth-shean": ["Bethshan"],
        "Bethlehem (Judah)": ["Ephratah", "Bethlehemjudah"],
        "Calvary": ["Golgotha"],
        "Canaan": ["Chanaan"],
        "Edom": ["Idumea", "Idumaea", "Seir"],
        "Gaza": ["Azzah"],
        "Golgotha": ["Calvary"],
        "Gomorrah": ["Gomorrha"],
        "Haran": ["Charran"],
        "Hermon (mountain)": ["Sion", "Sirion", "Shenir"],
        "Horeb (mountain)": ["Sinai", "Sina"],
        "Jerusalem": ["Salem", "Zion", "Sion", "Jebus"],
        "Judea": ["Judaea", "Jewry"],
        "Kadesh-barnea": ["Kadesh"],
        "Kidron (brook)": ["Cedron"],
        "Kirjath-jearim": ["Kirjath-baal", "Baalah"],
        "Megiddo": ["Megiddon"],
        "Midian": ["Madian"],
        "Mizpah (Benjamin)": ["Mizpeh"],
        "Mount of Olives": ["Olivet"],
        "Mount Sinai": ["Sinai", "Sina", "Horeb"],
        "Nineveh": ["Nineve"],
        "Rabbah (Ammon)": ["Rabbath"],
        "Ramah (Benjamin)": ["Rama"],
        "Salt Sea (Dead Sea)": ["sea of the plain", "east sea"],
        "Sea of Galilee": ["Tiberias", "Gennesaret", "Chinnereth", "Chinneroth", "Cinneroth"],
        "Shechem": ["Sychem", "Sichem"],
        "Sidon": ["Zidon"],
        "Sodom": ["Sodoma"],
        "Susa (Shushan)": ["Shushan"],
        "Tarshish (destination)": ["Tharshish"],
        "Timnah": ["Timnath"],
        "Tyre": ["Tyrus"],
        "Ur of the Chaldees": ["Ur"],
        "Valley of Hinnom": ["Hinnom", "Tophet"],
        "Zion (hill)": ["Sion"]
    ]

    /// Each name's other spellings, under the name's ID, ready for `BeatTheClockAnswerIndex`.
    static func variantNames(for names: [(id: Int, name: String)]) -> [(id: Int, name: String)] {
        names.flatMap { entry in
            (spellings[entry.name] ?? []).map { (id: entry.id, name: $0) }
        }
    }
}

// MARK: - Choices

/// The books on the board for one question, and the one to tap.
struct BeatTheClockChoices: Equatable {
    let books: [String]
    let answer: String
}

/// Builds the tap-to-answer boards for Countdown's modes.
enum BeatTheClockChoiceBuilder {
    static let choiceCount = 4

    /// Where a question's wrong books come from. Closer books are harder to rule out.
    enum DecoyScope {
        case anywhere
        case sameTestament
        case sameSection
    }

    /// Which of a name's other books sit beside the first appearance.
    enum Spread {
        /// Books from late in the Bible, so the earliest stands out.
        case far
        case random
        /// The books right after the first appearance, so it takes knowing the order.
        case near
    }

    /// "Which of these books mentions …?": one book that does and three that never do.
    /// Nil when the name has no book in `canon`, or too few books never mention it.
    static func mentionChoices(
        for question: BeatTheClockQuestion,
        scope: DecoyScope,
        prefersBestKnownBook: Bool,
        canon: [String],
        using generator: inout some RandomNumberGenerator
    ) -> BeatTheClockChoices? {
        let rightBooks = canon.filter { question.acceptableBooks.contains($0) }
        let answer: String? = if prefersBestKnownBook, let best = question.bestKnownBook, rightBooks.contains(best) {
            best
        } else {
            rightBooks.randomElement(using: &generator)
        }
        guard let answer else { return nil }

        let pool = canon.filter { !question.unsafeDecoyBooks.contains($0) }
        let testament = BibleBookGroup.group(for: answer).testament
        let section = QuizVerseSection.containing(answer)
        let sameTestament = pool.filter { BibleBookGroup.group(for: $0).testament == testament }
        // Each scope falls back to wider ones when it runs short of wrong books.
        let tiers: [[String]] = switch scope {
        case .anywhere: [pool]
        case .sameTestament: [sameTestament, pool]
        case .sameSection: [pool.filter { section != nil && QuizVerseSection.containing($0) == section }, sameTestament, pool]
        }

        var decoys: [String] = []
        for tier in tiers where decoys.count < choiceCount - 1 {
            let fresh = tier.filter { !decoys.contains($0) }.shuffled(using: &generator)
            decoys += fresh.prefix(choiceCount - 1 - decoys.count)
        }
        guard decoys.count == choiceCount - 1 else { return nil }
        return BeatTheClockChoices(books: ([answer] + decoys).shuffled(using: &generator), answer: answer)
    }

    /// "Where does … first appear?": four books that all mention the name; the earliest is
    /// the answer. Nil when the name is in fewer than four books.
    static func firstAppearanceChoices(
        for question: BeatTheClockQuestion,
        spread: Spread,
        canon: [String],
        using generator: inout some RandomNumberGenerator
    ) -> BeatTheClockChoices? {
        let inOrder = canon.filter { question.acceptableBooks.contains($0) }
        guard inOrder.count >= choiceCount, let answer = inOrder.first else { return nil }
        let later = Array(inOrder.dropFirst())
        let others: [String] = switch spread {
        case .far: Array(later.suffix(max(choiceCount - 1, later.count / 2)).shuffled(using: &generator).prefix(choiceCount - 1))
        case .random: Array(later.shuffled(using: &generator).prefix(choiceCount - 1))
        case .near: Array(later.prefix(choiceCount - 1))
        }
        return BeatTheClockChoices(books: ([answer] + others).shuffled(using: &generator), answer: answer)
    }

    /// "Which is found in more books?": pairs of people, or of places, whose book counts
    /// differ by at least `minimumGap`, so there's never a tie. Each name is used once.
    static func higherOrLowerPairs(
        from questions: [BeatTheClockQuestion],
        minimumGap: Int,
        limit: Int,
        using generator: inout some RandomNumberGenerator
    ) -> [(BeatTheClockQuestion, BeatTheClockQuestion)] {
        var remaining = questions.filter { !$0.acceptableBooks.isEmpty }.shuffled(using: &generator)
        var pairs: [(BeatTheClockQuestion, BeatTheClockQuestion)] = []
        while pairs.count < limit, let first = remaining.popLast() {
            guard let index = remaining.lastIndex(where: {
                $0.subject == first.subject && abs($0.acceptableBooks.count - first.acceptableBooks.count) >= max(1, minimumGap)
            }) else { continue }
            let second = remaining.remove(at: index)
            pairs.append(Bool.random(using: &generator) ? (first, second) : (second, first))
        }
        return pairs
    }
}
