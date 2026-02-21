//
//  Repository.swift
//  Murmurix
//

import Foundation
import SQLite3

// MARK: - Transcription Repository Protocol

/// Specific protocol for TranscriptionRecord repository, easier to mock
protocol TranscriptionRepositoryProtocol {
    func save(_ item: TranscriptionRecord) throws
    func fetchAll() throws -> [TranscriptionRecord]
    func delete(id: UUID) throws
    func deleteAll() throws
}

enum TranscriptionRepositoryError: LocalizedError {
    case statementPreparationFailed(operation: String, sqliteCode: Int32, sqliteMessage: String)
    case statementExecutionFailed(operation: String, sqliteCode: Int32, sqliteMessage: String)
    case rowDecodingFailed

    var errorDescription: String? {
        switch self {
        case .statementPreparationFailed(let operation, let sqliteCode, let sqliteMessage):
            return "Failed to prepare SQLite statement for operation: \(operation). SQLite code \(sqliteCode): \(sqliteMessage)"
        case .statementExecutionFailed(let operation, let sqliteCode, let sqliteMessage):
            return "Failed to execute SQLite statement for operation: \(operation). SQLite code \(sqliteCode): \(sqliteMessage)"
        case .rowDecodingFailed:
            return "Failed to decode transcription row from SQLite"
        }
    }
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

    func columnInt(_ statement: OpaquePointer?, index: Int32) -> Int32 {
        return sqlite3_column_int(statement, index)
    }

    func userVersion() -> Int32 {
        guard let statement = prepareStatement("PRAGMA user_version") else { return 0 }
        defer { finalize(statement) }
        guard stepRow(statement) else { return 0 }
        return columnInt(statement, index: 0)
    }

    func setUserVersion(_ version: Int32) {
        execute("PRAGMA user_version = \(version)")
    }

    func lastErrorCode() -> Int32 {
        sqlite3_errcode(db)
    }

    func lastErrorMessage() -> String {
        guard let message = sqlite3_errmsg(db) else {
            return "Unknown SQLite error"
        }
        return String(cString: message)
    }
}

// MARK: - Transcription Repository

final class SQLiteTranscriptionRepository: TranscriptionRepositoryProtocol {
    private enum Migration {
        static let currentSchemaVersion: Int32 = 1
    }

    private let database: SQLiteDatabase

    init(database: SQLiteDatabase) {
        self.database = database
        migrateSchemaIfNeeded()
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

    private func migrateSchemaIfNeeded() {
        let currentVersion = database.userVersion()

        if currentVersion < 1 {
            createTable()
            database.setUserVersion(Migration.currentSchemaVersion)
            Logger.History.debug("Applied SQLite schema migration to version \(Migration.currentSchemaVersion)")
        }
    }

    func save(_ item: TranscriptionRecord) throws {
        let sql = "INSERT OR REPLACE INTO transcriptions (id, text, language, duration, created_at) VALUES (?, ?, ?, ?, ?)"
        let operation = "save"
        guard let statement = database.prepareStatement(sql) else {
            throw makePreparationError(operation: operation)
        }
        defer { database.finalize(statement) }

        database.bindText(statement, index: 1, value: item.id.uuidString)
        database.bindText(statement, index: 2, value: item.text)
        database.bindText(statement, index: 3, value: item.language)
        database.bindDouble(statement, index: 4, value: item.duration)
        database.bindDouble(statement, index: 5, value: item.createdAt.timeIntervalSince1970)

        if !database.step(statement) {
            throw makeExecutionError(operation: operation)
        }
    }

    func fetchAll() throws -> [TranscriptionRecord] {
        let sql = "SELECT id, text, language, duration, created_at FROM transcriptions ORDER BY created_at DESC"
        let operation = "fetchAll"
        guard let statement = database.prepareStatement(sql) else {
            throw makePreparationError(operation: operation)
        }
        defer { database.finalize(statement) }

        var records: [TranscriptionRecord] = []

        while database.stepRow(statement) {
            guard let idString = database.columnText(statement, index: 0),
                  let text = database.columnText(statement, index: 1),
                  let language = database.columnText(statement, index: 2) else {
                throw TranscriptionRepositoryError.rowDecodingFailed
            }

            guard let id = UUID(uuidString: idString) else {
                throw TranscriptionRepositoryError.rowDecodingFailed
            }
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

        return records
    }

    func delete(id: UUID) throws {
        let sql = "DELETE FROM transcriptions WHERE id = ?"
        let operation = "delete"
        guard let statement = database.prepareStatement(sql) else {
            throw makePreparationError(operation: operation)
        }
        defer { database.finalize(statement) }
        database.bindText(statement, index: 1, value: id.uuidString)
        guard database.step(statement) else {
            throw makeExecutionError(operation: operation)
        }
    }

    func deleteAll() throws {
        let sql = "DELETE FROM transcriptions"
        let operation = "deleteAll"
        guard let statement = database.prepareStatement(sql) else {
            throw makePreparationError(operation: operation)
        }
        defer { database.finalize(statement) }
        guard database.step(statement) else {
            throw makeExecutionError(operation: operation)
        }
    }

    private func makePreparationError(operation: String) -> TranscriptionRepositoryError {
        .statementPreparationFailed(
            operation: operation,
            sqliteCode: database.lastErrorCode(),
            sqliteMessage: database.lastErrorMessage()
        )
    }

    private func makeExecutionError(operation: String) -> TranscriptionRepositoryError {
        .statementExecutionFailed(
            operation: operation,
            sqliteCode: database.lastErrorCode(),
            sqliteMessage: database.lastErrorMessage()
        )
    }
}
