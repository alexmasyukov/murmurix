//
//  WhisperKitService.swift
//  Murmurix
//

import Foundation
import WhisperKit

protocol WhisperKitServiceProtocol: AnyObject, Sendable {
    var isModelLoaded: Bool { get }
    func loadModel(name: String) async throws
    func unloadModel() async
    func transcribe(audioURL: URL, language: String) async throws -> String
    func downloadModel(_ name: String, progress: @escaping @Sendable (Double) -> Void) async throws
}

final class WhisperKitService: WhisperKitServiceProtocol, @unchecked Sendable {
    static let shared = WhisperKitService()

    private var whisperKit: WhisperKit?
    private var currentModelName: String?
    private let lock = NSLock()

    var isModelLoaded: Bool {
        lock.lock()
        defer { lock.unlock() }
        return whisperKit != nil
    }

    func loadModel(name: String) async throws {
        // Unload previous model if different
        if currentModelName != name {
            await unloadModel()
        }

        guard !isModelLoaded else { return }

        // Verify model is downloaded before loading
        guard WhisperModel(rawValue: name)?.isInstalled == true else {
            throw MurmurixError.model(.notFound(name))
        }

        Logger.Model.info("Loading WhisperKit model: \(name)")

        let modelFolder = ModelPaths.modelDir(for: name).path

        let config = WhisperKitConfig(
            modelFolder: modelFolder,
            verbose: false,
            logLevel: .error,
            download: false
        )

        let pipe = try await WhisperKit(config)

        lock.lock()
        whisperKit = pipe
        currentModelName = name
        lock.unlock()

        Logger.Model.info("WhisperKit model loaded: \(name)")
    }

    func unloadModel() async {
        lock.lock()
        let pipe = whisperKit
        whisperKit = nil
        currentModelName = nil
        lock.unlock()

        if let pipe = pipe {
            await pipe.unloadModels()
            Logger.Model.info("WhisperKit model unloaded")
        }
    }

    func transcribe(audioURL: URL, language: String) async throws -> String {
        lock.lock()
        let pipe = whisperKit
        lock.unlock()

        guard let pipe = pipe else {
            throw MurmurixError.transcription(.modelNotLoaded)
        }

        var options = DecodingOptions()
        options.language = language == "auto" ? nil : language
        options.task = .transcribe
        options.wordTimestamps = false

        let results = try await pipe.transcribe(
            audioPath: audioURL.path,
            decodeOptions: options
        )

        let text = results.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text.isEmpty ? "(no speech detected)" : text
    }

    func downloadModel(_ name: String, progress: @escaping @Sendable (Double) -> Void) async throws {
        Logger.Model.info("Downloading WhisperKit model: \(name)")

        _ = try await WhisperKit.download(
            variant: "openai_whisper-\(name)",
            from: "argmaxinc/whisperkit-coreml",
            progressCallback: { downloadProgress in
                progress(downloadProgress.fractionCompleted)
            }
        )

        Logger.Model.info("WhisperKit model downloaded: \(name)")
    }
}
