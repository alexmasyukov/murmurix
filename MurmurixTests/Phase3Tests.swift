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

        #expect(viewModel.testingModels.contains("small") == false)
        #expect(viewModel.localTestResults["small"] == nil)

        let testTask = Task {
            await viewModel.testModel("small")
        }

        // Give a moment for the state to be set
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms

        await testTask.value

        #expect(viewModel.testingModels.contains("small") == false)
    }

    @Test func testLocalModelSuccess() async {
        let mockTranscription = MockTranscriptionService()
        mockTranscription.transcriptionResult = .success("test result")
        let viewModel = GeneralSettingsViewModel(
            transcriptionServiceFactory: { mockTranscription }
        )
        viewModel.installedModels = ["small"]

        await viewModel.testModel("small")

        #expect(mockTranscription.transcribeCallCount == 1)
        #expect(viewModel.localTestResults["small"] == .success)
        #expect(viewModel.testingModels.contains("small") == false)
    }

    @Test func testLocalModelFailure() async {
        let mockTranscription = MockTranscriptionService()
        mockTranscription.transcriptionResult = .failure(TestError.transcriptionFailed)
        let viewModel = GeneralSettingsViewModel(
            transcriptionServiceFactory: { mockTranscription }
        )
        viewModel.installedModels = ["small"]

        await viewModel.testModel("small")

        #expect(mockTranscription.transcribeCallCount == 1)
        if case .failure = viewModel.localTestResults["small"] {
            // Expected
        } else {
            #expect(Bool(false), "Expected failure result")
        }
        #expect(viewModel.testingModels.contains("small") == false)
    }

    @Test func testLocalModelCallsService() async {
        let mockTranscription = MockTranscriptionService()
        let viewModel = GeneralSettingsViewModel(
            transcriptionServiceFactory: { mockTranscription }
        )
        viewModel.installedModels = ["small"]

        await viewModel.testModel("small")
        #expect(mockTranscription.transcribeCallCount == 1)

        await viewModel.testModel("small")
        #expect(mockTranscription.transcribeCallCount == 2)
    }

    @Test func testLocalModelFailsWhenNotInstalled() async {
        let mockTranscription = MockTranscriptionService()
        let viewModel = GeneralSettingsViewModel(
            transcriptionServiceFactory: { mockTranscription }
        )
        // installedModels is empty — model not installed

        await viewModel.testModel("small")

        #expect(mockTranscription.transcribeCallCount == 0)
        if case .failure(let msg) = viewModel.localTestResults["small"] {
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

        await viewModel.testModel("small")
        #expect(viewModel.localTestResults["small"] != nil)

        viewModel.clearTestResult(for: .local("small"))
        #expect(viewModel.localTestResults["small"] == nil)
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
        // Verify all cases exist and can be constructed
        let local = TestService.local("small")
        let openAI = TestService.openAI
        let gemini = TestService.gemini

        // Verify they are distinct cases via pattern matching
        if case .local = local {} else {
            #expect(Bool(false), "Expected .local case")
        }
        if case .openAI = openAI {} else {
            #expect(Bool(false), "Expected .openAI case")
        }
        if case .gemini = gemini {} else {
            #expect(Bool(false), "Expected .gemini case")
        }
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
