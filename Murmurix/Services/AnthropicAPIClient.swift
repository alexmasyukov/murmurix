//
//  AnthropicAPIClient.swift
//  Murmurix
//

import Foundation

enum AnthropicError: LocalizedError {
    case invalidAPIKey
    case invalidResponse
    case apiError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key"
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .apiError(let message):
            return "Claude API error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

protocol AnthropicAPIClientProtocol: Sendable {
    func validateAPIKey(_ apiKey: String) async throws -> Bool
    func processText(_ text: String, systemPrompt: String, model: String, apiKey: String) async throws -> String
}

final class AnthropicAPIClient: AnthropicAPIClientProtocol, @unchecked Sendable {
    static let shared = AnthropicAPIClient()

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"
    private let structuredOutputsBeta = "structured-outputs-2025-11-13"

    private init() {}

    // MARK: - Public API

    func validateAPIKey(_ apiKey: String) async throws -> Bool {
        let requestBody: [String: Any] = [
            "model": "claude-haiku-4-5",
            "max_tokens": 10,
            "messages": [
                ["role": "user", "content": "Hi"]
            ]
        ]

        let request = try buildRequest(body: requestBody, apiKey: apiKey, timeout: 30)
        let (data, response) = try await URLSession.shared.data(for: request)

        let statusCode = try getStatusCode(from: response)

        switch statusCode {
        case 200:
            return true
        case 401:
            throw AnthropicError.invalidAPIKey
        default:
            throw parseError(from: data, statusCode: statusCode)
        }
    }

    func processText(_ text: String, systemPrompt: String, model: String, apiKey: String) async throws -> String {
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": text]
            ],
            "output_format": [
                "type": "json_schema",
                "schema": [
                    "type": "object",
                    "properties": [
                        "text": [
                            "type": "string",
                            "description": "The processed text with technical terms fixed"
                        ]
                    ],
                    "required": ["text"],
                    "additionalProperties": false
                ]
            ]
        ]

        let request = try buildRequest(
            body: requestBody,
            apiKey: apiKey,
            timeout: 60,
            includeBetaHeader: true
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = try getStatusCode(from: response)

        guard statusCode == 200 else {
            throw parseError(from: data, statusCode: statusCode)
        }

        return try parseStructuredTextResponse(from: data)
    }

    // MARK: - Private Helpers

    private func buildRequest(
        body: [String: Any],
        apiKey: String,
        timeout: TimeInterval,
        includeBetaHeader: Bool = false
    ) throws -> URLRequest {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            throw AnthropicError.invalidResponse
        }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        if includeBetaHeader {
            request.setValue(structuredOutputsBeta, forHTTPHeaderField: "anthropic-beta")
        }

        request.httpBody = jsonData
        request.timeoutInterval = timeout

        return request
    }

    private func getStatusCode(from response: URLResponse) throws -> Int {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }
        return httpResponse.statusCode
    }

    private func parseError(from data: Data, statusCode: Int) -> AnthropicError {
        if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = errorJson["error"] as? [String: Any],
           let message = error["message"] as? String {
            return .apiError(message)
        }
        return .apiError("HTTP \(statusCode)")
    }

    private func parseStructuredTextResponse(from data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let jsonText = firstBlock["text"] as? String,
              let outputData = jsonText.data(using: .utf8),
              let outputJson = try? JSONSerialization.jsonObject(with: outputData) as? [String: Any],
              let processedText = outputJson["text"] as? String else {
            throw AnthropicError.invalidResponse
        }

        return processedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
