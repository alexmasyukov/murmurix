//
//  HistoryViewModel.swift
//  Murmurix
//

import Foundation

protocol HistoryViewModelProtocol: ObservableObject {
    var records: [TranscriptionRecord] { get }
    var selectedRecord: TranscriptionRecord? { get set }
    var totalDuration: TimeInterval { get }
    var formattedTotalDuration: String { get }
    var totalWords: Int { get }

    func loadRecords()
    func clearHistory()
    func deleteRecord(_ record: TranscriptionRecord)
}

final class HistoryViewModel: ObservableObject, HistoryViewModelProtocol {
    @Published var records: [TranscriptionRecord] = []
    @Published var selectedRecord: TranscriptionRecord?

    private let historyService: HistoryServiceProtocol
    private var pendingSelectionUpdate: DispatchWorkItem?

    init(historyService: HistoryServiceProtocol = HistoryService.shared) {
        self.historyService = historyService
    }

    func loadRecords() {
        pendingSelectionUpdate?.cancel()
        pendingSelectionUpdate = nil

        let fetched = historyService.fetchAll()
        records = fetched

        // Defer selection update to next run loop to avoid multiple updates per frame
        if selectedRecord == nil, let first = fetched.first {
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                guard self.selectedRecord == nil else { return }
                guard self.records.first?.id == first.id else { return }
                self.selectedRecord = first
            }
            pendingSelectionUpdate = workItem
            DispatchQueue.main.async(execute: workItem)
        }
    }

    func clearHistory() {
        pendingSelectionUpdate?.cancel()
        pendingSelectionUpdate = nil
        historyService.deleteAll()
        records = []
        selectedRecord = nil
    }

    func deleteRecord(_ record: TranscriptionRecord) {
        pendingSelectionUpdate?.cancel()
        pendingSelectionUpdate = nil
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
