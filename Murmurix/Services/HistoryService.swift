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
    static let shared = HistoryService()

    private let repository: SQLiteTranscriptionRepository

    init(repository: SQLiteTranscriptionRepository? = nil) {
        self.repository = repository ?? Self.makeDefaultRepository()
    }

    func save(record: TranscriptionRecord) {
        repository.save(record)
    }

    func fetchAll() -> [TranscriptionRecord] {
        return repository.fetchAll()
    }

    func delete(id: UUID) {
        repository.delete(id: id)
    }

    func deleteAll() {
        repository.deleteAll()
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
