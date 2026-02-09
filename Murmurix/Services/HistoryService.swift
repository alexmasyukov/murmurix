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
        if let repository = repository {
            self.repository = repository
        } else {
            let fileManager = FileManager.default
            let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
            let appDir = supportDir.appendingPathComponent("Murmurix")
            do {
                try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
            } catch {
                Logger.History.error("Failed to create history directory \(appDir.path): \(error.localizedDescription)")
            }
            let dbPath = appDir.appendingPathComponent("history.sqlite").path
            self.repository = SQLiteTranscriptionRepository(dbPath: dbPath)
        }
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
}
