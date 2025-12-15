import Foundation
import SwiftData

enum ReadingProgressStore {
    static func save(in context: ModelContext, bookName: String, chapter: Int, verse: Int) {
        // Fetch newest record if any
        let sort = [SortDescriptor(\ReadingProgress.updatedAt, order: .reverse)]
        var fetch = FetchDescriptor<ReadingProgress>(sortBy: sort)
        fetch.fetchLimit = 1
        if let existing = try? context.fetch(fetch).first {
            existing.bookName = bookName
            existing.chapterNumber = chapter
            existing.verseNumber = verse
            existing.updatedAt = Date()
            try? context.save()
        } else {
            let p = ReadingProgress()
            p.singletonKey = "global"
            p.bookName = bookName
            p.chapterNumber = chapter
            p.verseNumber = verse
            p.updatedAt = Date()
            context.insert(p)
            try? context.save()
        }
    }

    static func dedupe(in context: ModelContext) {
        // Keep newest by updatedAt, delete the rest
        let sort = [SortDescriptor(\ReadingProgress.updatedAt, order: .reverse)]
        let fetch = FetchDescriptor<ReadingProgress>(sortBy: sort)
        guard let all = try? context.fetch(fetch), all.count > 1 else { return }
        for p in all.dropFirst() {
            context.delete(p)
        }
        try? context.save()
    }
}

