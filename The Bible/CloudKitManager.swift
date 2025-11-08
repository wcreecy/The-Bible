// CloudKitManager.swift
// Centralized manager for CloudKit operations (fetch, save, update, delete) for all data models to enable sync across devices

import Foundation
import CloudKit

class CloudKitManager {
    static let shared = CloudKitManager()
    let privateDB = CKContainer.default().privateCloudDatabase
    
    // MARK: - Generic Save
    func save(record: CKRecord, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        privateDB.save(record, completionHandler: { savedRecord, error in
            if let error = error {
                completion(.failure(error))
            } else if let savedRecord = savedRecord {
                completion(.success(savedRecord))
            } else {
                completion(.failure(NSError(domain: "CKSave", code: 500, userInfo: nil)))
            }
        })
    }

    // MARK: - Generic Fetch
    func fetch(recordType: String, predicate: NSPredicate = NSPredicate(value: true), completion: @escaping (Result<[CKRecord], Error>) -> Void) {
        let query = CKQuery(recordType: recordType, predicate: predicate)
        privateDB.perform(query, inZoneWith: nil) { records, error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(records ?? []))
            }
        }
    }

    // MARK: - Generic Delete
    func delete(recordID: CKRecord.ID, completion: @escaping (Result<CKRecord.ID, Error>) -> Void) {
        privateDB.delete(withRecordID: recordID) { deletedID, error in
            if let error = error {
                completion(.failure(error))
            } else if let deletedID = deletedID {
                completion(.success(deletedID))
            } else {
                completion(.failure(NSError(domain: "CKDelete", code: 500, userInfo: nil)))
            }
        }
    }
    
    // MARK: - Generic Update (by overwriting, must have record ID)
    func update(record: CKRecord, completion: @escaping (Result<CKRecord, Error>) -> Void) {
        save(record: record, completion: completion)
    }
}

// Example pattern for a syncable model (Favorite);
// Replicate for Bookmark, VerseNote, game stats etc.
struct CKFavorite {
    static let recordType = "Favorite"
    let id: String
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let verseText: String
    
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: CKFavorite.recordType, recordID: CKRecord.ID(recordName: id))
        record["bookName"] = bookName as CKRecordValue
        record["chapterNumber"] = chapterNumber as CKRecordValue
        record["verseNumber"] = verseNumber as CKRecordValue
        record["verseText"] = verseText as CKRecordValue
        return record
    }
    
    static func from(record: CKRecord) -> CKFavorite? {
        guard let bookName = record["bookName"] as? String,
              let chapterNumber = record["chapterNumber"] as? Int,
              let verseNumber = record["verseNumber"] as? Int,
              let verseText = record["verseText"] as? String else {
            return nil
        }
        return CKFavorite(id: record.recordID.recordName, bookName: bookName, chapterNumber: chapterNumber, verseNumber: verseNumber, verseText: verseText)
    }
}

struct CKBookmark {
    static let recordType = "Bookmark"
    let id: String
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let note: String?

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: CKBookmark.recordType, recordID: CKRecord.ID(recordName: id))
        record["bookName"] = bookName as CKRecordValue
        record["chapterNumber"] = chapterNumber as CKRecordValue
        record["verseNumber"] = verseNumber as CKRecordValue
        if let note = note {
            record["note"] = note as CKRecordValue
        }
        return record
    }

    static func from(record: CKRecord) -> CKBookmark? {
        guard let bookName = record["bookName"] as? String,
              let chapterNumber = record["chapterNumber"] as? Int,
              let verseNumber = record["verseNumber"] as? Int else {
            return nil
        }
        let note = record["note"] as? String
        return CKBookmark(id: record.recordID.recordName, bookName: bookName, chapterNumber: chapterNumber, verseNumber: verseNumber, note: note)
    }
}

struct CKVerseNote {
    static let recordType = "VerseNote"
    let id: String
    let bookName: String
    let chapterNumber: Int
    let verseNumber: Int
    let noteText: String

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: CKVerseNote.recordType, recordID: CKRecord.ID(recordName: id))
        record["bookName"] = bookName as CKRecordValue
        record["chapterNumber"] = chapterNumber as CKRecordValue
        record["verseNumber"] = verseNumber as CKRecordValue
        record["noteText"] = noteText as CKRecordValue
        return record
    }

    static func from(record: CKRecord) -> CKVerseNote? {
        guard let bookName = record["bookName"] as? String,
              let chapterNumber = record["chapterNumber"] as? Int,
              let verseNumber = record["verseNumber"] as? Int,
              let noteText = record["noteText"] as? String else {
            return nil
        }
        return CKVerseNote(id: record.recordID.recordName, bookName: bookName, chapterNumber: chapterNumber, verseNumber: verseNumber, noteText: noteText)
    }
}

// Generic structure for game statistics (e.g., quiz/hangman/refmatch stats)
struct CKGameStat {
    static let recordType = "GameStat"
    let id: String
    let gameType: String    // e.g., "quiz", "hangman", "refmatch"
    let difficulty: String? // e.g., "easy", "normal", "hard" (optional)
    let key: String         // stat type, e.g., "correct", "answered", "bestStreak"
    let value: Int

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: CKGameStat.recordType, recordID: CKRecord.ID(recordName: id))
        record["gameType"] = gameType as CKRecordValue
        if let difficulty = difficulty {
            record["difficulty"] = difficulty as CKRecordValue
        }
        record["key"] = key as CKRecordValue
        record["value"] = value as CKRecordValue
        return record
    }

    static func from(record: CKRecord) -> CKGameStat? {
        guard let gameType = record["gameType"] as? String,
              let key = record["key"] as? String,
              let value = record["value"] as? Int else {
            return nil
        }
        let difficulty = record["difficulty"] as? String
        return CKGameStat(id: record.recordID.recordName, gameType: gameType, difficulty: difficulty, key: key, value: value)
    }
}
