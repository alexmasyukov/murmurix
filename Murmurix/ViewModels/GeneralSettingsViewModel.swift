//
//  GeneralSettingsViewModel.swift
//  Murmurix
//

import Foundation
import Combine

final class GeneralSettingsViewModel: ObservableObject {
    @Published var installedModels: Set<String> = []
    @Published var downloadStatus: DownloadStatus = .idle

    var onModelChanged: (() -> Void)?

    private let downloadService: ModelDownloadService

    init(downloadService: ModelDownloadService = .shared) {
        self.downloadService = downloadService
    }

    func loadInstalledModels() {
        installedModels = Set(WhisperModel.allCases.filter { $0.isInstalled }.map { $0.rawValue })
    }

    func isModelInstalled(_ modelName: String) -> Bool {
        installedModels.contains(modelName)
    }

    func handleModelChange(_ newModel: String) {
        downloadStatus = .idle
        if let model = WhisperModel(rawValue: newModel), model.isInstalled {
            onModelChanged?()
        }
    }

    func startDownload(for modelName: String) {
        downloadStatus = .downloading

        downloadService.downloadModel(modelName) { [weak self] status in
            guard let self = self else { return }

            self.downloadStatus = status

            if case .completed = status {
                self.loadInstalledModels()
                self.onModelChanged?()
                self.scheduleStatusReset()
            }
        }
    }

    func cancelDownload() {
        downloadService.cancelDownload()
        downloadStatus = .idle
    }

    private func scheduleStatusReset() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            if case .completed = self.downloadStatus {
                self.downloadStatus = .idle
            }
        }
    }
}
