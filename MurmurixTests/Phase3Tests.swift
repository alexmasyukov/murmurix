//
//  Phase3Tests.swift
//  MurmurixTests
//
//  Tests for Phase 3 refactoring: ViewModel test logic, Settings DI
//

import Testing
import Foundation
@testable import Murmurix

// MARK: - GeneralSettingsViewModel API Testing Tests

@MainActor
struct GeneralSettingsViewModelAPITests {

    // MARK: - Local Model Testing

    @Test func testLocalModelSetsLoadingState() async {
        let mockTranscription = MockTranscriptionService()
        let viewModel = GeneralSettingsViewModel(
            transcriptionServiceFactory: { mockTranscription }
        )
        viewModel.installedModels = ["small"]

        #expect(viewModel.isTestingLocal == false)
        #expect(viewModel.localTestResult == nil)

        let testTask = Task {
            await viewModel.testLocalModel()
        }

        // Give a moment for the state to be set
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        await testTask.value

        #expect(viewModel.isTestingLocal == false)
    }

    @Test func testLocalModelSuccess() async {
        let mockTranscription = MockTranscriptionService()
        mockTranscription.transcriptionResult = .success("test result")
        let viewModel = GeneralSettingsViewModel(
            transcriptionServiceFactory: { mockTranscription }
        )
        viewModel.installedModels = ["small"]

        await viewModel.testLocalModel()

        #expect(mockTranscription.transcribeCallCount == 1)
        #expect(viewModel.localTestResult == .success)
        #expect(viewModel.isTestingLocal == false)
    }

    @Test func testLocalModelFailure() async {
        let mockTranscription = MockTranscriptionService()
        mockTranscription.transcriptionResult = .failure(TestError.transcriptionFailed)
        let viewModel = GeneralSettingsViewModel(
            transcriptionServiceFactory: { mockTranscription }
        )
        viewModel.installedModels = ["small"]

        await viewModel.testLocalModel()

        #expect(mockTranscription.transcribeCallCount == 1)
        if case .failure = viewModel.localTestResult {
            // Expected
        } else {
            #expect(Bool(false), "Expected failure result")
        }
        #expect(viewModel.isTestingLocal == false)
    }

    @Test func testLocalModelCallsService() async {
        let mockTranscription = MockTranscriptionService()
        let viewModel = GeneralSettingsViewModel(
            transcriptionServiceFactory: { mockTranscription }
        )
        viewModel.installedModels = ["small"]

        await viewModel.testLocalModel()
        #expect(mockTranscription.transcribeCallCount == 1)

        await viewModel.testLocalModel()
        #expect(mockTranscription.transcribeCallCount == 2)
    }

    @Test func testLocalModelFailsWhenNotInstalled() async {
        let mockTranscription = MockTranscriptionService()
        let viewModel = GeneralSettingsViewModel(
            transcriptionServiceFactory: { mockTranscription }
        )
        // installedModels is empty — model not installed

        await viewModel.testLocalModel()

        #expect(mockTranscription.transcribeCallCount == 0)
        if case .failure(let msg) = viewModel.localTestResult {
            #expect(msg.contains("not installed"))
        } else {
            #expect(Bool(false), "Expected failure result for uninstalled model")
        }
    }

    // MARK: - OpenAI Testing

    @Test func testOpenAISetsLoadingState() async {
        let mockOpenAI = MockOpenAITranscriptionService()
        let viewModel = GeneralSettingsViewModel(openAIService: mockOpenAI)

        #expect(viewModel.isTestingOpenAI == false)
        #expect(viewModel.openaiTestResult == nil)

        let testTask = Task {
            await viewModel.testOpenAI(apiKey: "sk-test1234567890")
        }

        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        await testTask.value

        #expect(viewModel.isTestingOpenAI == false)
    }

    @Test func testOpenAIValidationSuccess() async {
        let mockOpenAI = MockOpenAITranscriptionService()
        mockOpenAI.validateAPIKeyResult = .success(true)
        let viewModel = GeneralSettingsViewModel(openAIService: mockOpenAI)

        await viewModel.testOpenAI(apiKey: "sk-valid1234567890")

        #expect(mockOpenAI.validateAPIKeyCallCount == 1)
        #expect(viewModel.openaiTestResult == .success)
        #expect(viewModel.isTestingOpenAI == false)
    }

    @Test func testOpenAIValidationInvalidKey() async {
        let mockOpenAI = MockOpenAITranscriptionService()
        mockOpenAI.validateAPIKeyResult = .success(false)
        let viewModel = GeneralSettingsViewModel(openAIService: mockOpenAI)

        await viewModel.testOpenAI(apiKey: "sk-invalid123456789")

        #expect(mockOpenAI.validateAPIKeyCallCount == 1)
        if case .failure(let message) = viewModel.openaiTestResult {
            #expect(message == "Invalid API key")
        } else {
            #expect(Bool(false), "Expected failure result")
        }
    }

    @Test func testOpenAIValidationNetworkError() async {
        let mockOpenAI = MockOpenAITranscriptionService()
        mockOpenAI.validateAPIKeyResult = .failure(TestError.networkError)
        let viewModel = GeneralSettingsViewModel(openAIService: mockOpenAI)

        await viewModel.testOpenAI(apiKey: "sk-test1234567890")

        #expect(mockOpenAI.validateAPIKeyCallCount == 1)
        if case .failure = viewModel.openaiTestResult {
            // Expected
        } else {
            #expect(Bool(false), "Expected failure result")
        }
    }

    // MARK: - Gemini Testing

    @Test func testGeminiSetsLoadingState() async {
        let mockGemini = MockGeminiTranscriptionService()
        let viewModel = GeneralSettingsViewModel(geminiService: mockGemini)

        #expect(viewModel.isTestingGemini == false)
        #expect(viewModel.geminiTestResult == nil)

        let testTask = Task {
            await viewModel.testGemini(apiKey: "AI-test1234567890")
        }

        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        await testTask.value

        #expect(viewModel.isTestingGemini == false)
    }

    @Test func testGeminiValidationSuccess() async {
        let mockGemini = MockGeminiTranscriptionService()
        mockGemini.validateAPIKeyResult = .success(true)
        let viewModel = GeneralSettingsViewModel(geminiService: mockGemini)

        await viewModel.testGemini(apiKey: "AI-valid1234567890")

        #expect(mockGemini.validateAPIKeyCallCount == 1)
        #expect(viewModel.geminiTestResult == .success)
        #expect(viewModel.isTestingGemini == false)
    }

    @Test func testGeminiValidationInvalidKey() async {
        let mockGemini = MockGeminiTranscriptionService()
        mockGemini.validateAPIKeyResult = .success(false)
        let viewModel = GeneralSettingsViewModel(geminiService: mockGemini)

        await viewModel.testGemini(apiKey: "AI-invalid123456789")

        #expect(mockGemini.validateAPIKeyCallCount == 1)
        if case .failure(let message) = viewModel.geminiTestResult {
            #expect(message == "Invalid API key")
        } else {
            #expect(Bool(false), "Expected failure result")
        }
    }

    @Test func testGeminiValidationNetworkError() async {
        let mockGemini = MockGeminiTranscriptionService()
        mockGemini.validateAPIKeyResult = .failure(TestError.networkError)
        let viewModel = GeneralSettingsViewModel(geminiService: mockGemini)

        await viewModel.testGemini(apiKey: "AI-test1234567890")

        #expect(mockGemini.validateAPIKeyCallCount == 1)
        if case .failure = viewModel.geminiTestResult {
            // Expected
        } else {
            #expect(Bool(false), "Expected failure result")
        }
    }

    // MARK: - Clear Test Result

    @Test func clearTestResultClearsLocalResult() async {
        let mockTranscription = MockTranscriptionService()
        let viewModel = GeneralSettingsViewModel(
            transcriptionServiceFactory: { mockTranscription }
        )

        await viewModel.testLocalModel()
        #expect(viewModel.localTestResult != nil)

        viewModel.clearTestResult(for: .local)
        #expect(viewModel.localTestResult == nil)
    }

    @Test func clearTestResultClearsOpenAIResult() async {
        let mockOpenAI = MockOpenAITranscriptionService()
        let viewModel = GeneralSettingsViewModel(openAIService: mockOpenAI)

        await viewModel.testOpenAI(apiKey: "sk-test1234567890")
        #expect(viewModel.openaiTestResult != nil)

        viewModel.clearTestResult(for: .openAI)
        #expect(viewModel.openaiTestResult == nil)
    }

    @Test func clearTestResultClearsGeminiResult() async {
        let mockGemini = MockGeminiTranscriptionService()
        let viewModel = GeneralSettingsViewModel(geminiService: mockGemini)

        await viewModel.testGemini(apiKey: "AI-test1234567890")
        #expect(viewModel.geminiTestResult != nil)

        viewModel.clearTestResult(for: .gemini)
        #expect(viewModel.geminiTestResult == nil)
    }
}

// MARK: - GeneralSettingsViewModel Settings DI Tests

@MainActor
struct GeneralSettingsViewModelSettingsDITests {

    @Test func viewModelAcceptsCustomSettings() {
        let mockSettings = MockSettings()
        let viewModel = GeneralSettingsViewModel(settings: mockSettings)

        #expect(viewModel.settings === mockSettings)
    }

    @Test func viewModelUsesDefaultSettingsWhenNotProvided() {
        let viewModel = GeneralSettingsViewModel()

        // Should use Settings.shared by default
        #expect(viewModel.settings is Settings)
    }
}

// MARK: - TestService Enum Tests

struct TestServiceEnumTests {

    @Test func testServiceHasAllCases() {
        // Verify all cases exist
        let local = TestService.local
        let openAI = TestService.openAI
        let gemini = TestService.gemini

        #expect(local != openAI)
        #expect(openAI != gemini)
        #expect(local != gemini)
    }
}

// MARK: - Test Helpers

enum TestError: Error, LocalizedError {
    case transcriptionFailed
    case networkError

    var errorDescription: String? {
        switch self {
        case .transcriptionFailed:
            return "Transcription failed"
        case .networkError:
            return "Network error"
        }
    }
}
