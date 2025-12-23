//
//  AIPostProcessingService.swift
//  Murmurix
//

import Foundation

protocol AIPostProcessingServiceProtocol: Sendable {
    func process(text: String) async throws -> String
}

final class AIPostProcessingService: AIPostProcessingServiceProtocol, @unchecked Sendable {
    private let settings: SettingsStorageProtocol
    private let apiClient: AnthropicAPIClientProtocol

    init(settings: SettingsStorageProtocol = Settings.shared, apiClient: AnthropicAPIClientProtocol = AnthropicAPIClient.shared) {
        self.settings = settings
        self.apiClient = apiClient
    }

    func process(text: String) async throws -> String {
        let apiKey = settings.claudeApiKey
        guard !apiKey.isEmpty else {
            throw MurmurixError.ai(.noApiKey)
        }

        let model = AIModel(rawValue: settings.aiModel) ?? .haiku
        let prompt = settings.aiPrompt

        return try await apiClient.processText(
            text,
            systemPrompt: prompt,
            model: model.rawValue,
            apiKey: apiKey
        )
    }
}
