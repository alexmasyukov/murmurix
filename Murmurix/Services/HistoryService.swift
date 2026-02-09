//
//  HistoryService.swift
//  Murmurix
//

import Foundation

protocol HistoryServiceProtocol {
    func save(record: TranscriptionRecord)
    func fetchAll() -> [TranscriptionRecord]
    func delete(id: UUID)
    func deleteAll()
}

final class HistoryService: HistoryServiceProtocol {
    static let shared = HistoryService(repository: HistoryService.makeDefaultRepository())

    private let repository: SQLiteTranscriptionRepository

    init(repository: SQLiteTranscriptionRepository) {
        self.repository = repository
    }

    func save(record: TranscriptionRecord) {
        do {
            try repository.save(record)
        } catch {
            Logger.History.error("Failed to save history record \(record.id): \(error.localizedDescription)")
        }
    }

    func fetchAll() -> [TranscriptionRecord] {
        do {
            return try repository.fetchAll()
        } catch {
            Logger.History.error("Failed to fetch history records: \(error.localizedDescription)")
            return []
        }
    }

    func delete(id: UUID) {
        do {
            try repository.delete(id: id)
        } catch {
            Logger.History.error("Failed to delete history record \(id): \(error.localizedDescription)")
        }
    }

    func deleteAll() {
        do {
            try repository.deleteAll()
        } catch {
            Logger.History.error("Failed to delete all history records: \(error.localizedDescription)")
        }
    }

    private static func makeDefaultRepository() -> SQLiteTranscriptionRepository {
        SQLiteTranscriptionRepository(dbPath: defaultDatabasePath())
    }

    private static func defaultDatabasePath() -> String {
        let fileManager = FileManager.default
        let appDir = defaultApplicationSupportDirectory(using: fileManager)
        do {
            try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
        } catch {
            Logger.History.error("Failed to create history directory \(appDir.path): \(error.localizedDescription)")
        }
        return appDir.appendingPathComponent("history.sqlite").path
    }

    private static func defaultApplicationSupportDirectory(using fileManager: FileManager) -> URL {
        let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return supportDir.appendingPathComponent("Murmurix")
    }
}
