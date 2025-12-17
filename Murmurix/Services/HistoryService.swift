//
//  HistoryService.swift
//  Murmurix
//

import Foundation
import SQLite3

protocol HistoryServiceProtocol {
    func save(record: TranscriptionRecord)
    func fetchAll() -> [TranscriptionRecord]
    func delete(id: UUID)
    func deleteAll()
}

final class HistoryService: HistoryServiceProtocol {
    static let shared = HistoryService()

    private var db: OpaquePointer?
    private let dbPath: String

    init(dbPath: String? = nil) {
        if let path = dbPath {
            self.dbPath = path
        } else {
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDir = supportDir.appendingPathComponent("Murmurix")
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
            self.dbPath = appDir.appendingPathComponent("history.sqlite").path
        }

        openDatabase()
        createTable()
    }

    deinit {
        sqlite3_close(db)
    }

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("HistoryService: Failed to open database at \(dbPath)")
        }
    }

    private func createTable() {
        let sql = """
            CREATE TABLE IF NOT EXISTS transcriptions (
                id TEXT PRIMARY KEY,
                text TEXT NOT NULL,
                language TEXT NOT NULL,
                duration REAL NOT NULL,
                created_at REAL NOT NULL
            )
            """

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                print("HistoryService: Failed to create table")
            }
        }
        sqlite3_finalize(statement)
    }

    func save(record: TranscriptionRecord) {
        let sql = "INSERT OR REPLACE INTO transcriptions (id, text, language, duration, created_at) VALUES (?, ?, ?, ?, ?)"

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, record.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, record.text, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 3, record.language, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(statement, 4, record.duration)
            sqlite3_bind_double(statement, 5, record.createdAt.timeIntervalSince1970)

            if sqlite3_step(statement) != SQLITE_DONE {
                print("HistoryService: Failed to save record")
            }
        }
        sqlite3_finalize(statement)
    }

    func fetchAll() -> [TranscriptionRecord] {
        let sql = "SELECT id, text, language, duration, created_at FROM transcriptions ORDER BY created_at DESC"

        var statement: OpaquePointer?
        var records: [TranscriptionRecord] = []

        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let idCString = sqlite3_column_text(statement, 0),
                      let textCString = sqlite3_column_text(statement, 1),
                      let languageCString = sqlite3_column_text(statement, 2) else {
                    continue
                }

                let id = UUID(uuidString: String(cString: idCString)) ?? UUID()
                let text = String(cString: textCString)
                let language = String(cString: languageCString)
                let duration = sqlite3_column_double(statement, 3)
                let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 4))

                let record = TranscriptionRecord(
                    id: id,
                    text: text,
                    language: language,
                    duration: duration,
                    createdAt: createdAt
                )
                records.append(record)
            }
        }
        sqlite3_finalize(statement)

        return records
    }

    func delete(id: UUID) {
        let sql = "DELETE FROM transcriptions WHERE id = ?"

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            sqlite3_bind_text(statement, 1, id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }

    func deleteAll() {
        let sql = "DELETE FROM transcriptions"

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_step(statement)
        }
        sqlite3_finalize(statement)
    }
}
