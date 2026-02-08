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
    private let language: String

    init(
        whisperKitService: WhisperKitServiceProtocol = WhisperKitService.shared,
        settings: SettingsStorageProtocol = Settings.shared,
        openAIService: OpenAITranscriptionServiceProtocol = OpenAITranscriptionService.shared,
        geminiService: GeminiTranscriptionServiceProtocol = GeminiTranscriptionService.shared,
        language: String = Defaults.language
    ) {
        self.whisperKitService = whisperKitService
        self.settings = settings
        self.openAIService = openAIService
        self.geminiService = geminiService
        self.language = language
    }

    // MARK: - TranscriptionServiceProtocol

    func isModelLoaded(name: String) -> Bool {
        whisperKitService.isModelLoaded(name: name)
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

    func transcribe(audioURL: URL, mode: TranscriptionMode) async throws -> String {
        switch mode {
        case .openai:
            Logger.Transcription.info("Cloud mode (OpenAI)")
            return try await transcribeViaOpenAI(audioURL: audioURL)

        case .gemini:
            Logger.Transcription.info("Cloud mode (Gemini)")
            return try await transcribeViaGemini(audioURL: audioURL)

        case .local(let model):
            Logger.Transcription.info("Local mode (WhisperKit), model=\(model)")
            return try await transcribeViaWhisperKit(audioURL: audioURL, model: model)
        }
    }

    // MARK: - WhisperKit Transcription

    private func transcribeViaWhisperKit(audioURL: URL, model: String) async throws -> String {
        if !whisperKitService.isModelLoaded(name: model) {
            try await whisperKitService.loadModel(name: model)
        }
        return try await whisperKitService.transcribe(audioURL: audioURL, language: language, model: model)
    }

    // MARK: - OpenAI Transcription

    private func transcribeViaOpenAI(audioURL: URL) async throws -> String {
        let apiKey = settings.openaiApiKey
        guard !apiKey.isEmpty else {
            throw MurmurixError.transcription(.failed("OpenAI API key not set. Please add it in Settings."))
        }

        let model = settings.openaiTranscriptionModel
        Logger.Transcription.info("OpenAI mode, model=\(model), audio=\(audioURL.path)")

        return try await openAIService.transcribe(
            audioURL: audioURL,
            language: language,
            model: model,
            apiKey: apiKey
        )
    }

    // MARK: - Gemini Transcription

    private func transcribeViaGemini(audioURL: URL) async throws -> String {
        let apiKey = settings.geminiApiKey
        guard !apiKey.isEmpty else {
            throw MurmurixError.transcription(.failed("Gemini API key not set. Please add it in Settings."))
        }

        let model = settings.geminiModel
        Logger.Transcription.info("Gemini mode, model=\(model), audio=\(audioURL.path)")

        return try await geminiService.transcribe(
            audioURL: audioURL,
            language: language,
            model: model,
            apiKey: apiKey
        )
    }
}
