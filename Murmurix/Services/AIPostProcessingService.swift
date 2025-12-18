//
//  AIPostProcessingService.swift
//  Murmurix
//

import Foundation

enum AIPostProcessingError: LocalizedError {
    case noApiKey
    case apiError(AnthropicError)

    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "Claude API key not configured"
        case .apiError(let error):
            return error.localizedDescription
        }
    }
}

protocol AIPostProcessingServiceProtocol: Sendable {
    func process(text: String) async throws -> String
}

final class AIPostProcessingService: AIPostProcessingServiceProtocol, @unchecked Sendable {
    private let settings: Settings
    private let apiClient: AnthropicAPIClientProtocol

    init(settings: Settings = .shared, apiClient: AnthropicAPIClientProtocol = AnthropicAPIClient.shared) {
        self.settings = settings
        self.apiClient = apiClient
    }

    func process(text: String) async throws -> String {
        guard let apiKey = KeychainService.load(key: "claudeApiKey"), !apiKey.isEmpty else {
            throw AIPostProcessingError.noApiKey
        }

        let model = AIModel(rawValue: settings.aiModel) ?? .haiku
        let prompt = settings.aiPrompt

        do {
            return try await apiClient.processText(
                text,
                systemPrompt: prompt,
                model: model.rawValue,
                apiKey: apiKey
            )
        } catch let error as AnthropicError {
            throw AIPostProcessingError.apiError(error)
        }
    }
}
