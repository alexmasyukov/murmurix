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
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDir = supportDir.appendingPathComponent("Murmurix")
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
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
