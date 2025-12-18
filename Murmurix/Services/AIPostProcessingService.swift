//
//  AIPostProcessingService.swift
//  Murmurix
//

import Foundation

enum AIModel: String, CaseIterable {
    case haiku = "claude-haiku-4-5"
    case sonnet = "claude-sonnet-4-5"
    case opus = "claude-opus-4-5"

    var displayName: String {
        switch self {
        case .haiku: return "Haiku 4.5 (Fast)"
        case .sonnet: return "Sonnet 4.5"
        case .opus: return "Opus 4.5 (Best)"
        }
    }
}

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
