//
//  HistoryViewModel.swift
//  Murmurix
//

import Foundation

class HistoryViewModel: ObservableObject {
    @Published var records: [TranscriptionRecord] = []
    @Published var selectedRecord: TranscriptionRecord?

    private let historyService: HistoryServiceProtocol

    init(historyService: HistoryServiceProtocol = HistoryService.shared) {
        self.historyService = historyService
    }

    func loadRecords() {
        let fetched = historyService.fetchAll()
        records = fetched

        // Defer selection update to next run loop to avoid multiple updates per frame
        if selectedRecord == nil, let first = fetched.first {
            DispatchQueue.main.async {
                self.selectedRecord = first
            }
        }
    }

    func clearHistory() {
        historyService.deleteAll()
        records = []
        selectedRecord = nil
    }

    func deleteRecord(_ record: TranscriptionRecord) {
        historyService.delete(id: record.id)
        records.removeAll { $0.id == record.id }
        if selectedRecord?.id == record.id {
            selectedRecord = records.first
        }
    }

    // MARK: - Statistics

    var totalDuration: TimeInterval {
        records.reduce(0) { $0 + $1.duration }
    }

    var formattedTotalDuration: String {
        let total = Int(totalDuration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var totalWords: Int {
        records.reduce(0) { $0 + $1.text.split(separator: " ").count }
    }
}
