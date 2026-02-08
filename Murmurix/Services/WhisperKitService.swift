//
//  WhisperKitService.swift
//  Murmurix
//

import Foundation
import WhisperKit

protocol WhisperKitServiceProtocol: AnyObject, Sendable {
    func isModelLoaded(name: String) -> Bool
    var loadedModels: [String] { get }
    func loadModel(name: String) async throws
    func unloadModel(name: String) async
    func unloadAllModels() async
    func transcribe(audioURL: URL, language: String, model: String) async throws -> String
    func downloadModel(_ name: String, progress: @escaping @Sendable (Double) -> Void) async throws
}

final class WhisperKitService: WhisperKitServiceProtocol, @unchecked Sendable {
    static let shared = WhisperKitService()

    private var pipelines: [String: WhisperKit] = [:]
    private let lock = NSLock()

    func isModelLoaded(name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return pipelines[name] != nil
    }

    var loadedModels: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(pipelines.keys)
    }

    func loadModel(name: String) async throws {
        guard !isModelLoaded(name: name) else { return }

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
        pipelines[name] = pipe
        lock.unlock()

        Logger.Model.info("WhisperKit model loaded: \(name)")
    }

    func unloadModel(name: String) async {
        lock.lock()
        let pipe = pipelines.removeValue(forKey: name)
        lock.unlock()

        if let pipe = pipe {
            await pipe.unloadModels()
            Logger.Model.info("WhisperKit model unloaded: \(name)")
        }
    }

    func unloadAllModels() async {
        lock.lock()
        let allPipelines = pipelines
        pipelines.removeAll()
        lock.unlock()

        for (name, pipe) in allPipelines {
            await pipe.unloadModels()
            Logger.Model.info("WhisperKit model unloaded: \(name)")
        }
    }

    func transcribe(audioURL: URL, language: String, model: String) async throws -> String {
        lock.lock()
        let pipe = pipelines[model]
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
