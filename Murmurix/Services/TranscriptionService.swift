//
//  TranscriptionService.swift
//  Murmurix
//

import Foundation

final class TranscriptionService: TranscriptionServiceProtocol, Sendable {
    private let whisperKitService: WhisperKitServiceProtocol
    private let settings: SettingsStorageProtocol
    private let openAIService: OpenAITranscriptionServiceProtocol
    private let geminiService: GeminiTranscriptionServiceProtocol

    static func live(settings: SettingsStorageProtocol) -> TranscriptionService {
        TranscriptionService(
            whisperKitService: WhisperKitService.shared,
            settings: settings,
            openAIService: OpenAITranscriptionService.shared,
            geminiService: GeminiTranscriptionService.shared
        )
    }

    init(
        whisperKitService: WhisperKitServiceProtocol,
        settings: SettingsStorageProtocol,
        openAIService: OpenAITranscriptionServiceProtocol,
        geminiService: GeminiTranscriptionServiceProtocol
    ) {
        self.whisperKitService = whisperKitService
        self.settings = settings
        self.openAIService = openAIService
        self.geminiService = geminiService
    }

    // MARK: - TranscriptionServiceProtocol

    func isModelLoaded(name: String) -> Bool {
        whisperKitService.isModelLoaded(name: name)
    }

    func loadedModelNames() -> [String] {
        whisperKitService.loadedModels
    }

    func loadModel(name: String) async throws {
        try await whisperKitService.loadModel(name: name)
    }

    func unloadModel(name: String) async {
        await whisperKitService.unloadModel(name: name)
    }

    func unloadAllModels() async {
        await whisperKitService.unloadAllModels()
    }

    func transcribe(audioURL: URL, language: String, mode: TranscriptionMode) async throws -> String {
        switch mode {
        case .openai:
            Logger.Transcription.info("Cloud mode (OpenAI)")
            return try await transcribeViaOpenAI(audioURL: audioURL, language: language)

        case .gemini:
            Logger.Transcription.info("Cloud mode (Gemini)")
            return try await transcribeViaGemini(audioURL: audioURL, language: language)

        case .local(let model):
            Logger.Transcription.info("Local mode (WhisperKit), model=\(model)")
            return try await transcribeViaWhisperKit(audioURL: audioURL, language: language, model: model)
        }
    }

    // MARK: - WhisperKit Transcription

    private func transcribeViaWhisperKit(audioURL: URL, language: String, model: String) async throws -> String {
        if !whisperKitService.isModelLoaded(name: model) {
            try await whisperKitService.loadModel(name: model)
        }
        return try await whisperKitService.transcribe(audioURL: audioURL, language: language, model: model)
    }

    // MARK: - OpenAI Transcription

    private func transcribeViaOpenAI(audioURL: URL, language: String) async throws -> String {
        let apiKey = try requireAPIKey(settings.openaiApiKey, providerName: "OpenAI")

        let model = settings.openaiTranscriptionModel
        logCloudMode("OpenAI", model: model, audioURL: audioURL)

        let request = CloudTranscriptionRequest(
            provider: .openAI,
            audioURL: audioURL,
            language: language,
            model: model,
            apiKey: apiKey
        )
        return try await OpenAICloudTranscriptionClient(service: openAIService).transcribe(request: request)
    }

    // MARK: - Gemini Transcription

    private func transcribeViaGemini(audioURL: URL, language: String) async throws -> String {
        let apiKey = try requireAPIKey(settings.geminiApiKey, providerName: "Gemini")

        let model = settings.geminiModel
        logCloudMode("Gemini", model: model, audioURL: audioURL)

        let request = CloudTranscriptionRequest(
            provider: .gemini,
            audioURL: audioURL,
            language: language,
            model: model,
            apiKey: apiKey
        )
        return try await GeminiCloudTranscriptionClient(service: geminiService).transcribe(request: request)
    }

    private func requireAPIKey(_ apiKey: String, providerName: String) throws -> String {
        guard !apiKey.isEmpty else {
            throw MurmurixError.transcription(.failed("\(providerName) API key not set. Please add it in Settings."))
        }
        return apiKey
    }

    private func logCloudMode(_ providerName: String, model: String, audioURL: URL) {
        Logger.Transcription.info("\(providerName) mode, model=\(model), audio=\(audioURL.path)")
    }
}
