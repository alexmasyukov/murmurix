//
//  CloudTranscriptionClient.swift
//  Murmurix
//

import Foundation

enum CloudTranscriptionProvider: Equatable {
    case openAI
    case gemini
}

struct CloudTranscriptionRequest: Equatable {
    let provider: CloudTranscriptionProvider
    let audioURL: URL
    let language: String
    let model: String
    let apiKey: String
}

protocol CloudTranscriptionClient: Sendable {
    var provider: CloudTranscriptionProvider { get }
    func transcribe(request: CloudTranscriptionRequest) async throws -> String
}

struct OpenAICloudTranscriptionClient: CloudTranscriptionClient {
    let provider: CloudTranscriptionProvider = .openAI
    private let service: OpenAITranscriptionServiceProtocol

    init(service: OpenAITranscriptionServiceProtocol) {
        self.service = service
    }

    func transcribe(request: CloudTranscriptionRequest) async throws -> String {
        guard request.provider == provider else {
            throw MurmurixError.transcription(.cloud(.providerMismatch(
                expected: CloudTranscriptionErrorNormalizer.providerName(provider),
                actual: CloudTranscriptionErrorNormalizer.providerName(request.provider)
            )))
        }

        do {
            return try await service.transcribe(
                audioURL: request.audioURL,
                language: request.language,
                model: request.model,
                apiKey: request.apiKey
            )
        } catch {
            throw CloudTranscriptionErrorNormalizer.normalize(error, provider: provider)
        }
    }
}

struct GeminiCloudTranscriptionClient: CloudTranscriptionClient {
    let provider: CloudTranscriptionProvider = .gemini
    private let service: GeminiTranscriptionServiceProtocol

    init(service: GeminiTranscriptionServiceProtocol) {
        self.service = service
    }

    func transcribe(request: CloudTranscriptionRequest) async throws -> String {
        guard request.provider == provider else {
            throw MurmurixError.transcription(.cloud(.providerMismatch(
                expected: CloudTranscriptionErrorNormalizer.providerName(provider),
                actual: CloudTranscriptionErrorNormalizer.providerName(request.provider)
            )))
        }

        do {
            return try await service.transcribe(
                audioURL: request.audioURL,
                language: request.language,
                model: request.model,
                apiKey: request.apiKey
            )
        } catch {
            throw CloudTranscriptionErrorNormalizer.normalize(error, provider: provider)
        }
    }
}

private enum CloudTranscriptionErrorNormalizer {
    static func normalize(_ error: Error, provider: CloudTranscriptionProvider) -> MurmurixError {
        if let murmurixError = error as? MurmurixError {
            return normalizeMurmurixError(murmurixError, provider: provider)
        }

        if let urlError = error as? URLError {
            return MurmurixError.transcription(.cloud(.network(
                provider: providerName(provider),
                reason: urlError.localizedDescription
            )))
        }

        return MurmurixError.transcription(.cloud(.unknown(
            provider: providerName(provider),
            message: error.localizedDescription
        )))
    }

    static func providerName(_ provider: CloudTranscriptionProvider) -> String {
        switch provider {
        case .openAI: return "OpenAI"
        case .gemini: return "Gemini"
        }
    }

    private static func normalizeMurmurixError(_ error: MurmurixError, provider: CloudTranscriptionProvider) -> MurmurixError {
        switch error {
        case .transcription(let transcriptionError):
            switch transcriptionError {
            case .cloud:
                return error
            case .failed(let message):
                return MurmurixError.transcription(.cloud(classifyFailedMessage(message, provider: provider)))
            default:
                return error
            }
        default:
            return error
        }
    }

    private static func classifyFailedMessage(_ message: String, provider: CloudTranscriptionProvider) -> CloudTranscriptionError {
        let lowercased = message.lowercased()
        let name = providerName(provider)

        if lowercased.contains("invalid api key")
            || lowercased.contains("unauthorized")
            || (lowercased.contains("api key") && lowercased.contains("invalid")) {
            return .unauthorized(provider: name)
        }

        if lowercased.contains("rate limit") || lowercased.contains("too many requests") {
            return .rateLimited(provider: name)
        }

        if lowercased.contains("too large") || lowercased.contains("max 25 mb") {
            return .payloadTooLarge(provider: name)
        }

        if lowercased.contains("invalid response") || lowercased.contains("parse response") {
            return .invalidResponse(provider: name)
        }

        if lowercased.contains("network")
            || lowercased.contains("connection")
            || lowercased.contains("offline")
            || lowercased.contains("timed out") {
            return .network(provider: name, reason: message)
        }

        return .unknown(provider: name, message: message)
    }
}
