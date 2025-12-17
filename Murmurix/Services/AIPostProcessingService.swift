//
//  AIPostProcessingService.swift
//  Murmurix
//

import Foundation

enum AIModel: String, CaseIterable {
    case haiku = "claude-3-5-haiku-latest"
    case sonnet = "claude-sonnet-4-20250514"
    case opus = "claude-opus-4-20250514"

    var displayName: String {
        switch self {
        case .haiku: return "Haiku (Fast)"
        case .sonnet: return "Sonnet"
        case .opus: return "Opus (Best)"
        }
    }
}

enum AIPostProcessingError: LocalizedError {
    case noApiKey
    case invalidResponse
    case apiError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "Claude API key not configured"
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .apiError(let message):
            return "Claude API error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

protocol AIPostProcessingServiceProtocol: Sendable {
    func process(text: String) async throws -> String
}

final class AIPostProcessingService: AIPostProcessingServiceProtocol, @unchecked Sendable {
    private let settings: Settings

    init(settings: Settings = .shared) {
        self.settings = settings
    }

    func process(text: String) async throws -> String {
        guard let apiKey = KeychainService.load(key: "claudeApiKey"), !apiKey.isEmpty else {
            throw AIPostProcessingError.noApiKey
        }

        let model = AIModel(rawValue: settings.aiModel) ?? .haiku
        let prompt = settings.aiPrompt

        let requestBody: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 4096,
            "messages": [
                [
                    "role": "user",
                    "content": "\(prompt)\n\nText to process:\n\(text)"
                ]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw AIPostProcessingError.invalidResponse
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = jsonData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIPostProcessingError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw AIPostProcessingError.apiError(message)
            }
            throw AIPostProcessingError.apiError("HTTP \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let processedText = firstBlock["text"] as? String else {
            throw AIPostProcessingError.invalidResponse
        }

        return processedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
