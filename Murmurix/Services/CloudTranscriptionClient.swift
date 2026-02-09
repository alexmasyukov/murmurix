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
            throw MurmurixError.transcription(.failed("Mismatched cloud provider for OpenAI client"))
        }

        return try await service.transcribe(
            audioURL: request.audioURL,
            language: request.language,
            model: request.model,
            apiKey: request.apiKey
        )
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
            throw MurmurixError.transcription(.failed("Mismatched cloud provider for Gemini client"))
        }

        return try await service.transcribe(
            audioURL: request.audioURL,
            language: request.language,
            model: request.model,
            apiKey: request.apiKey
        )
    }
}
