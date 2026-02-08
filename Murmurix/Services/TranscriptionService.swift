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

    var isModelLoaded: Bool {
        whisperKitService.isModelLoaded
    }

    func loadModel() async throws {
        try await whisperKitService.loadModel(name: settings.whisperModel)
    }

    func unloadModel() async {
        await whisperKitService.unloadModel()
    }

    func transcribe(audioURL: URL, mode: TranscriptionMode) async throws -> String {
        switch mode {
        case .openai:
            Logger.Transcription.info("Cloud mode (OpenAI)")
            return try await transcribeViaOpenAI(audioURL: audioURL)

        case .gemini:
            Logger.Transcription.info("Cloud mode (Gemini)")
            return try await transcribeViaGemini(audioURL: audioURL)

        case .local:
            Logger.Transcription.info("Local mode (WhisperKit), model=\(settings.whisperModel)")
            return try await transcribeViaWhisperKit(audioURL: audioURL)
        }
    }

    // MARK: - WhisperKit Transcription

    private func transcribeViaWhisperKit(audioURL: URL) async throws -> String {
        if !whisperKitService.isModelLoaded {
            try await whisperKitService.loadModel(name: settings.whisperModel)
        }
        return try await whisperKitService.transcribe(audioURL: audioURL, language: language)
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
