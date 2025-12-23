//
//  AISettingsViewModel.swift
//  Murmurix
//

import Foundation

enum APITestResult: Equatable {
    case success
    case failure(String)
}

@MainActor
protocol AISettingsViewModelProtocol: ObservableObject {
    var apiKey: String { get set }
    var prompt: String { get set }
    var isTesting: Bool { get }
    var testResult: APITestResult? { get }

    func loadSettings()
    func saveAPIKey(_ key: String)
    func savePrompt(_ newPrompt: String)
    func resetPromptToDefault()
    func testConnection()
}

@MainActor
final class AISettingsViewModel: ObservableObject, AISettingsViewModelProtocol {
    @Published var apiKey: String = ""
    @Published var prompt: String = ""
    @Published var isTesting = false
    @Published var testResult: APITestResult?

    private let settings: SettingsStorageProtocol
    private let apiClient: AnthropicAPIClientProtocol

    init(settings: SettingsStorageProtocol = Settings.shared, apiClient: AnthropicAPIClientProtocol = AnthropicAPIClient.shared) {
        self.settings = settings
        self.apiClient = apiClient
    }

    func loadSettings() {
        apiKey = settings.claudeApiKey
        prompt = settings.aiPrompt
    }

    func saveAPIKey(_ key: String) {
        apiKey = key
        settings.claudeApiKey = key
        testResult = nil
    }

    func savePrompt(_ newPrompt: String) {
        prompt = newPrompt
        settings.aiPrompt = newPrompt
    }

    func resetPromptToDefault() {
        prompt = Settings.defaultAIPrompt
        settings.aiPrompt = prompt
    }

    func testConnection() {
        guard !apiKey.isEmpty else { return }

        isTesting = true
        testResult = nil

        Task {
            do {
                let result = try await apiClient.validateAPIKey(apiKey)
                isTesting = false
                testResult = result ? .success : .failure("Invalid response")
            } catch {
                isTesting = false
                testResult = .failure(error.localizedDescription)
            }
        }
    }
}
