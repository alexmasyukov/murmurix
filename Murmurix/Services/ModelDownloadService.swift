//
//  ModelDownloadService.swift
//  Murmurix
//

import Foundation

enum DownloadStatus: Equatable {
    case idle
    case downloading
    case completed
    case error(String)
}

final class ModelDownloadService {
    static let shared = ModelDownloadService()

    private var downloadProcess: Process?

    private init() {}

    func downloadModel(_ modelName: String, onProgress: @escaping (DownloadStatus) -> Void) {
        guard let script = PythonResolver.findDaemonScript(), let python = PythonResolver.findPython() else {
            onProgress(.error("Python or script not found"))
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = [script, "--download", modelName]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        self.downloadProcess = process

        // Signal download started
        DispatchQueue.main.async {
            onProgress(.downloading)
        }

        // Run download in background
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try process.run()
                process.waitUntilExit()

                DispatchQueue.main.async {
                    if process.terminationStatus == 0 {
                        // Verify model is installed
                        if let model = WhisperModel(rawValue: modelName), model.isInstalled {
                            onProgress(.completed)
                        } else {
                            onProgress(.error("Download completed but model not found"))
                        }
                    } else {
                        onProgress(.error("Download failed"))
                    }

                    self?.downloadProcess = nil
                }
            } catch {
                DispatchQueue.main.async {
                    onProgress(.error(error.localizedDescription))
                    self?.downloadProcess = nil
                }
            }
        }
    }

    func cancelDownload() {
        downloadProcess?.terminate()
        downloadProcess = nil
    }
}
