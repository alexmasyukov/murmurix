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
    private var pipelines: [String: WhisperKit] = [:]
    private let lock = NSLock()

    func isModelLoaded(name: String) -> Bool {
        lock.withLock {
            pipelines[name] != nil
        }
    }

    var loadedModels: [String] {
        lock.withLock {
            Array(pipelines.keys)
        }
    }

    func loadModel(name: String) async throws {
        guard !isModelLoaded(name: name) else { return }

        guard WhisperModel(rawValue: name)?.isInstalled == true else {
            throw MurmurixError.model(.notFound(name))
        }

        Logger.Model.info("Loading WhisperKit model: \(name)")

        let modelFolder = ModelPaths.modelDir(for: name).path
        Logger.Model.debug("WhisperKit load path for \(name): \(modelFolder)")

        let config = WhisperKitConfig(
            modelFolder: modelFolder,
            verbose: false,
            logLevel: .error,
            download: false
        )

        let pipe = try await WhisperKit(config)

        lock.withLock {
            pipelines[name] = pipe
        }

        Logger.Model.info("WhisperKit model loaded: \(name)")
    }

    func unloadModel(name: String) async {
        Logger.Model.debug("Requested WhisperKit unload for model: \(name)")
        let pipe = lock.withLock {
            pipelines.removeValue(forKey: name)
        }

        if let pipe = pipe {
            await unloadPipeline(pipe, name: name)
        } else {
            Logger.Model.debug("WhisperKit unload skipped because model was not loaded: \(name)")
        }
    }

    func unloadAllModels() async {
        let allPipelines = lock.withLock {
            let current = pipelines
            pipelines.removeAll()
            return current
        }

        for (name, pipe) in allPipelines {
            await unloadPipeline(pipe, name: name)
        }
    }

    func transcribe(audioURL: URL, language: String, model: String) async throws -> String {
        let pipe = lock.withLock {
            pipelines[model]
        }

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
        let variant = "openai_whisper-\(name)"
        Logger.Model.info("Downloading WhisperKit model: \(name)")
        Logger.Model.debug("WhisperKit download variant: \(variant)")
        Logger.Model.debug("WhisperKit download base dir: \(ModelPaths.downloadBaseDir.path)")
        Logger.Model.debug("WhisperKit repo dir: \(ModelPaths.repoDir.path)")

        _ = try await WhisperKit.download(
            variant: variant,
            downloadBase: ModelPaths.downloadBaseDir,
            from: "argmaxinc/whisperkit-coreml",
            progressCallback: { downloadProgress in
                progress(downloadProgress.fractionCompleted)
            }
        )

        Logger.Model.info("WhisperKit model downloaded: \(name)")
        Logger.Model.debug("WhisperKit downloaded model dir exists: \(FileManager.default.fileExists(atPath: ModelPaths.modelDir(for: name).path))")
    }

    private func unloadPipeline(_ pipeline: WhisperKit, name: String) async {
        await pipeline.unloadModels()
        Logger.Model.info("WhisperKit model unloaded: \(name)")
    }
}
