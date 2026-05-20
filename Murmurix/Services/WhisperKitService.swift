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
    private var loadingTasks: [String: Task<Void, Error>] = [:]
    private let lock = NSLock()

    /// Closure resolved at each download/load to read the current HuggingFace
    /// token from settings. Keeps WhisperKitService free of a direct settings
    /// reference and re-reads on every call so token updates take effect
    /// without restarting the service.
    private let tokenProvider: @Sendable () -> String?

    init(tokenProvider: @escaping @Sendable () -> String? = { nil }) {
        self.tokenProvider = tokenProvider
    }

    private func currentToken() -> String? {
        guard let raw = tokenProvider(), !raw.isEmpty else { return nil }
        return raw
    }

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
        if isModelLoaded(name: name) { return }

        // Reuse an in-flight Task if one is already loading the same model.
        // Without this, concurrent callers (e.g. keep-loaded prewarm + a Test
        // button press) each kick off their own WhisperKit(config), which
        // serializes badly on a cold ANE and can deadlock after a reboot.
        let task: Task<Void, Error> = lock.withLock {
            if let existing = loadingTasks[name] {
                Logger.Model.debug("Joining in-flight load for model: \(name)")
                return existing
            }
            let newTask = Task { [weak self] () -> Void in
                guard let self = self else { return }
                try await self.performLoad(name: name)
            }
            loadingTasks[name] = newTask
            return newTask
        }

        try await task.value
    }

    private func performLoad(name: String) async throws {
        defer {
            lock.withLock { _ = loadingTasks.removeValue(forKey: name) }
        }

        if isModelLoaded(name: name) { return }

        guard WhisperModel(rawValue: name)?.isInstalled == true else {
            throw MurmurixError.model(.notFound(name))
        }

        Logger.Model.info("Loading WhisperKit model: \(name)")

        let modelFolder = ModelPaths.modelDir(for: name).path
        // swift-transformers (used internally by WhisperKit) caches the
        // tokenizer from openai/whisper-* under HubApi's default base, which
        // resolves to ~/Documents/huggingface/. We redirect it to the same
        // Application Support tree so nothing app-managed lands in Documents.
        let tokenizerFolder = ModelPaths.downloadBaseDir
        let token = currentToken()
        Logger.Model.debug("WhisperKit load path for \(name): \(modelFolder)")
        Logger.Model.debug("WhisperKit tokenizer base for \(name): \(tokenizerFolder.path)")
        Logger.Model.debug("WhisperKit auth token present for \(name): \(token != nil)")

        // Energy-based VAD lets WhisperKit skip purely-silent audio chunks
        // during decoding. Without it Whisper happily hallucinates filler
        // phrases ("Субтитры сделал DimaTorzok", "Спасибо за просмотр", etc.
        // from YouTube training data) over a silent tail when the user trails
        // off at the end of recording. Defaults: 16 kHz, 100 ms frames,
        // 0.02 energy threshold — matches what WhisperKit ships for VAD usage.
        let vad = EnergyVAD()

        let config = WhisperKitConfig(
            modelToken: token,
            modelFolder: modelFolder,
            tokenizerFolder: tokenizerFolder,
            voiceActivityDetector: vad,
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
        // Anti-hallucination on silent tails / pauses:
        // - suppressBlank avoids Whisper emitting blank/whitespace tokens
        //   that get expanded into invented filler phrases.
        // - chunkingStrategy=.vad activates the EnergyVAD configured in the
        //   pipeline so silent chunks are dropped before decoding.
        // Defaults already cover compressionRatioThreshold=2.4,
        // logProbThreshold=-1.0, noSpeechThreshold=0.6 — keep them.
        options.suppressBlank = true
        options.chunkingStrategy = .vad

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
        let token = currentToken()
        Logger.Model.info("Downloading WhisperKit model: \(name)")
        Logger.Model.debug("WhisperKit download variant: \(variant)")
        Logger.Model.debug("WhisperKit download base dir: \(ModelPaths.downloadBaseDir.path)")
        Logger.Model.debug("WhisperKit repo dir: \(ModelPaths.repoDir.path)")
        Logger.Model.debug("WhisperKit auth token present for download: \(token != nil)")

        _ = try await WhisperKit.download(
            variant: variant,
            downloadBase: ModelPaths.downloadBaseDir,
            from: "argmaxinc/whisperkit-coreml",
            token: token,
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
