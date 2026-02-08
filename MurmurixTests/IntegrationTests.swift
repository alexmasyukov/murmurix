//
//  IntegrationTests.swift
//  MurmurixTests
//

import Testing
import Foundation
@testable import Murmurix

// MARK: - TranscriptionService Integration Tests (with mocked backends)

struct TranscriptionServiceIntegrationTests {

    // MARK: - Local Mode (WhisperKit)

    @Test func localModeTranscribesViaWhisperKit() async throws {
        let mockWhisperKit = MockWhisperKitService()
        mockWhisperKit.transcribeResult = .success("Hello from WhisperKit")
        let mockSettings = MockSettings()
        mockSettings.whisperModel = "small"

        let service = TranscriptionService(
            whisperKitService: mockWhisperKit,
            settings: mockSettings
        )

        let audioURL = URL(fileURLWithPath: "/tmp/test_audio.wav")
        let result = try await service.transcribe(audioURL: audioURL, mode: .local)

        #expect(result == "Hello from WhisperKit")
        #expect(mockWhisperKit.transcribeCallCount == 1)
    }

    @Test func localModeThrowsWhenWhisperKitFails() async {
        let mockWhisperKit = MockWhisperKitService()
        mockWhisperKit.transcribeResult = .failure(MurmurixError.transcription(.failed("Model error")))
        let mockSettings = MockSettings()

        let service = TranscriptionService(
            whisperKitService: mockWhisperKit,
            settings: mockSettings
        )

        let audioURL = URL(fileURLWithPath: "/tmp/test_audio.wav")

        await #expect(throws: Error.self) {
            try await service.transcribe(audioURL: audioURL, mode: .local)
        }
    }

    // MARK: - OpenAI Mode

    @Test func openaiModeTranscribesViaOpenAI() async throws {
        let mockOpenAI = MockOpenAITranscriptionService()
        mockOpenAI.transcribeResult = .success("Hello from OpenAI")
        let mockSettings = MockSettings()
        mockSettings.openaiApiKey = "sk-test-key"
        mockSettings.openaiTranscriptionModel = "gpt-4o-transcribe"

        let service = TranscriptionService(
            whisperKitService: MockWhisperKitService(),
            settings: mockSettings,
            openAIService: mockOpenAI
        )

        let audioURL = URL(fileURLWithPath: "/tmp/test_audio.wav")
        let result = try await service.transcribe(audioURL: audioURL, mode: .openai)

        #expect(result == "Hello from OpenAI")
        #expect(mockOpenAI.transcribeCallCount == 1)
    }

    @Test func openaiModeThrowsWhenApiKeyMissing() async {
        let mockOpenAI = MockOpenAITranscriptionService()
        let mockSettings = MockSettings()
        mockSettings.openaiApiKey = ""

        let service = TranscriptionService(
            whisperKitService: MockWhisperKitService(),
            settings: mockSettings,
            openAIService: mockOpenAI
        )

        let audioURL = URL(fileURLWithPath: "/tmp/test_audio.wav")

        await #expect(throws: Error.self) {
            try await service.transcribe(audioURL: audioURL, mode: .openai)
        }
        #expect(mockOpenAI.transcribeCallCount == 0)
    }

    // MARK: - Gemini Mode

    @Test func geminiModeTranscribesViaGemini() async throws {
        let mockGemini = MockGeminiTranscriptionService()
        mockGemini.transcribeResult = .success("Hello from Gemini")
        let mockSettings = MockSettings()
        mockSettings.geminiApiKey = "test-gemini-key"
        mockSettings.geminiModel = GeminiTranscriptionModel.flash2.rawValue

        let service = TranscriptionService(
            whisperKitService: MockWhisperKitService(),
            settings: mockSettings,
            geminiService: mockGemini
        )

        let audioURL = URL(fileURLWithPath: "/tmp/test_audio.wav")
        let result = try await service.transcribe(audioURL: audioURL, mode: .gemini)

        #expect(result == "Hello from Gemini")
        #expect(mockGemini.transcribeCallCount == 1)
    }

    @Test func geminiModeThrowsWhenApiKeyMissing() async {
        let mockGemini = MockGeminiTranscriptionService()
        let mockSettings = MockSettings()
        mockSettings.geminiApiKey = ""

        let service = TranscriptionService(
            whisperKitService: MockWhisperKitService(),
            settings: mockSettings,
            geminiService: mockGemini
        )

        let audioURL = URL(fileURLWithPath: "/tmp/test_audio.wav")

        await #expect(throws: Error.self) {
            try await service.transcribe(audioURL: audioURL, mode: .gemini)
        }
        #expect(mockGemini.transcribeCallCount == 0)
    }

    // MARK: - Model Loading

    @Test func loadModelDelegatesToWhisperKit() async throws {
        let mockWhisperKit = MockWhisperKitService()
        let mockSettings = MockSettings()
        mockSettings.whisperModel = "tiny"

        let service = TranscriptionService(
            whisperKitService: mockWhisperKit,
            settings: mockSettings
        )

        try await service.loadModel()

        #expect(mockWhisperKit.loadModelCallCount == 1)
        #expect(mockWhisperKit.lastModelName == "tiny")
        #expect(service.isModelLoaded == true)
    }

    @Test func unloadModelDelegatesToWhisperKit() async {
        let mockWhisperKit = MockWhisperKitService()
        mockWhisperKit.isModelLoaded = true
        let mockSettings = MockSettings()

        let service = TranscriptionService(
            whisperKitService: mockWhisperKit,
            settings: mockSettings
        )

        await service.unloadModel()

        #expect(mockWhisperKit.unloadModelCallCount == 1)
        #expect(service.isModelLoaded == false)
    }

    @Test func isModelLoadedReflectsWhisperKitState() async throws {
        let mockWhisperKit = MockWhisperKitService()
        let mockSettings = MockSettings()
        mockSettings.whisperModel = "base"

        let service = TranscriptionService(
            whisperKitService: mockWhisperKit,
            settings: mockSettings
        )

        #expect(service.isModelLoaded == false)

        try await service.loadModel()
        #expect(service.isModelLoaded == true)

        await service.unloadModel()
        #expect(service.isModelLoaded == false)
    }
}
