//
//  GeminiTests.swift
//  MurmurixTests
//

import Testing
import Foundation
import Carbon
@testable import Murmurix

struct GeminiTranscriptionModelTests {

    // MARK: - Model Properties

    @Test func flash2ModelProperties() {
        let model = GeminiTranscriptionModel.flash2
        #expect(model.rawValue == "gemini-2.0-flash")
        #expect(model.displayName == "Gemini 2.0 Flash (recommended)")
        #expect(model.description == "Fast and efficient, best for voice transcription")
    }

    @Test func flashModelProperties() {
        let model = GeminiTranscriptionModel.flash
        #expect(model.rawValue == "gemini-1.5-flash")
        #expect(model.displayName == "Gemini 1.5 Flash")
        #expect(model.description == "Previous generation, stable")
    }

    @Test func proModelProperties() {
        let model = GeminiTranscriptionModel.pro
        #expect(model.rawValue == "gemini-1.5-pro")
        #expect(model.displayName == "Gemini 1.5 Pro (best quality)")
        #expect(model.description == "Best accuracy for complex audio")
    }

    @Test func allCasesContainsAllModels() {
        let allCases = GeminiTranscriptionModel.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.flash2))
        #expect(allCases.contains(.flash))
        #expect(allCases.contains(.pro))
    }

    // MARK: - Default Model

    @Test func defaultModelIsFlash2() {
        // flash2 should be the first case (recommended)
        let firstCase = GeminiTranscriptionModel.allCases.first
        #expect(firstCase == .flash2)
    }
}

struct MockGeminiTranscriptionServiceTests {

    @Test func transcribeCallsServiceCorrectly() async throws {
        let service = MockGeminiTranscriptionService()
        service.transcribeResult = .success("Test transcription")

        let result = try await service.transcribe(
            audioURL: URL(fileURLWithPath: "/tmp/test.wav"),
            language: "ru",
            model: "gemini-2.0-flash",
            apiKey: "test-key"
        )

        #expect(result == "Test transcription")
        #expect(service.transcribeCallCount == 1)
        #expect(service.lastLanguage == "ru")
        #expect(service.lastModel == "gemini-2.0-flash")
    }

    @Test func transcribeThrowsOnFailure() async {
        let service = MockGeminiTranscriptionService()
        struct TestError: Error {}
        service.transcribeResult = .failure(TestError())

        do {
            _ = try await service.transcribe(
                audioURL: URL(fileURLWithPath: "/tmp/test.wav"),
                language: "en",
                model: "gemini-2.0-flash",
                apiKey: "test-key"
            )
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(service.transcribeCallCount == 1)
        }
    }

    @Test func validateAPIKeySuccess() async throws {
        let service = MockGeminiTranscriptionService()
        service.validateAPIKeyResult = .success(true)

        let isValid = try await service.validateAPIKey("test-key")

        #expect(isValid == true)
        #expect(service.validateAPIKeyCallCount == 1)
    }

    @Test func validateAPIKeyFailure() async throws {
        let service = MockGeminiTranscriptionService()
        service.validateAPIKeyResult = .success(false)

        let isValid = try await service.validateAPIKey("invalid-key")

        #expect(isValid == false)
        #expect(service.validateAPIKeyCallCount == 1)
    }
}

struct HotkeyDefaultsTests {

    @Test func hotkeyDisplayPartsShowsKeys() {
        let hotkey = Hotkey(keyCode: 5, modifiers: UInt32(controlKey))
        #expect(hotkey.keyCode == 5) // G key
        #expect(hotkey.modifiers == UInt32(controlKey))
        #expect(hotkey.displayParts.contains("⌃"))
        #expect(hotkey.displayParts.contains("G"))
    }

    @Test func hotkeyEqualityWorks() {
        let a = Hotkey(keyCode: 5, modifiers: UInt32(controlKey))
        let b = Hotkey(keyCode: 5, modifiers: UInt32(controlKey))
        let c = Hotkey(keyCode: 8, modifiers: UInt32(controlKey))

        #expect(a == b)
        #expect(a != c)
    }
}
