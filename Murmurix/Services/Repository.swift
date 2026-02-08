//
//  Repository.swift
//  Murmurix
//

import Foundation
import SQLite3

// MARK: - Transcription Repository Protocol

/// Specific protocol for TranscriptionRecord repository, easier to mock
protocol TranscriptionRepositoryProtocol {
    func save(_ item: TranscriptionRecord)
    func fetchAll() -> [TranscriptionRecord]
    func delete(id: UUID)
    func deleteAll()
}

// MARK: - SQLite Helper

final class SQLiteDatabase {
    private var db: OpaquePointer?
    let path: String

    init(path: String) {
        self.path = path
        openDatabase()
    }

    deinit {
        sqlite3_close(db)
    }

    private func openDatabase() {
        if sqlite3_open(path, &db) != SQLITE_OK {
            Logger.History.error("Failed to open database at \(path)")
        }
    }

    func execute(_ sql: String) {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                Logger.History.error("Failed to execute: \(sql)")
            }
        }
        sqlite3_finalize(statement)
    }

    func prepareStatement(_ sql: String) -> OpaquePointer? {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            return statement
        }
        return nil
    }

    func bindText(_ statement: OpaquePointer?, index: Int32, value: String) {
        let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
    }

    func bindDouble(_ statement: OpaquePointer?, index: Int32, value: Double) {
        sqlite3_bind_double(statement, index, value)
    }

    func step(_ statement: OpaquePointer?) -> Bool {
        return sqlite3_step(statement) == SQLITE_DONE
    }

    func stepRow(_ statement: OpaquePointer?) -> Bool {
        return sqlite3_step(statement) == SQLITE_ROW
    }

    func finalize(_ statement: OpaquePointer?) {
        sqlite3_finalize(statement)
    }

    func columnText(_ statement: OpaquePointer?, index: Int32) -> String? {
        guard let cString = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: cString)
    }

    func columnDouble(_ statement: OpaquePointer?, index: Int32) -> Double {
        return sqlite3_column_double(statement, index)
    }
}

// MARK: - Transcription Repository

final class SQLiteTranscriptionRepository: TranscriptionRepositoryProtocol {
    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
        createTable()
    }

    convenience init(dbPath: String) {
        self.init(database: SQLiteDatabase(path: dbPath))
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
        database.execute(sql)
    }

    func save(_ item: TranscriptionRecord) {
        let sql = "INSERT OR REPLACE INTO transcriptions (id, text, language, duration, created_at) VALUES (?, ?, ?, ?, ?)"

        guard let statement = database.prepareStatement(sql) else { return }

        database.bindText(statement, index: 1, value: item.id.uuidString)
        database.bindText(statement, index: 2, value: item.text)
        database.bindText(statement, index: 3, value: item.language)
        database.bindDouble(statement, index: 4, value: item.duration)
        database.bindDouble(statement, index: 5, value: item.createdAt.timeIntervalSince1970)

        if !database.step(statement) {
            Logger.History.error("Failed to save record")
        }
        database.finalize(statement)
    }

    func fetchAll() -> [TranscriptionRecord] {
        let sql = "SELECT id, text, language, duration, created_at FROM transcriptions ORDER BY created_at DESC"

        guard let statement = database.prepareStatement(sql) else { return [] }

        var records: [TranscriptionRecord] = []

        while database.stepRow(statement) {
            guard let idString = database.columnText(statement, index: 0),
                  let text = database.columnText(statement, index: 1),
                  let language = database.columnText(statement, index: 2) else {
                continue
            }

            let id = UUID(uuidString: idString) ?? UUID()
            let duration = database.columnDouble(statement, index: 3)
            let createdAt = Date(timeIntervalSince1970: database.columnDouble(statement, index: 4))

            let record = TranscriptionRecord(
                id: id,
                text: text,
                language: language,
                duration: duration,
                createdAt: createdAt
            )
            records.append(record)
        }

        database.finalize(statement)
        return records
    }

    func delete(id: UUID) {
        let sql = "DELETE FROM transcriptions WHERE id = ?"

        guard let statement = database.prepareStatement(sql) else { return }
        database.bindText(statement, index: 1, value: id.uuidString)
        database.step(statement)
        database.finalize(statement)
    }

    func deleteAll() {
        database.execute("DELETE FROM transcriptions")
    }
}
