//
//  OpenAITranscriptionService.swift
//  Murmurix
//

import Foundation

protocol OpenAITranscriptionServiceProtocol: Sendable {
    func transcribe(audioURL: URL, language: String, model: String, apiKey: String) async throws -> String
    func validateAPIKey(_ apiKey: String) async throws -> Bool
}

final class OpenAITranscriptionService: OpenAITranscriptionServiceProtocol, Sendable {
    static let shared = OpenAITranscriptionService()

    private let baseURL = "https://api.openai.com/v1/audio/transcriptions"
    private let session: URLSessionProtocol
    private let promptPolicy: any TranscriptionPromptPolicy

    private struct TranscriptionResponse: Decodable {
        let text: String
    }

    private struct ErrorResponse: Decodable {
        struct APIError: Decodable {
            let message: String
        }

        let error: APIError
    }

    init(
        session: URLSessionProtocol = URLSession.shared,
        promptPolicy: any TranscriptionPromptPolicy = DefaultTranscriptionPromptPolicy.shared
    ) {
        self.session = session
        self.promptPolicy = promptPolicy
    }

    // MARK: - Transcription

    func transcribe(audioURL: URL, language: String, model: String, apiKey: String) async throws -> String {
        // Читаем аудио файл
        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioURL)
        } catch {
            throw MurmurixError.transcription(.failed("Failed to read audio file: \(error.localizedDescription)"))
        }

        // Создаем multipart/form-data запрос
        let boundary = UUID().uuidString
        var request = try makeMultipartRequest(apiKey: apiKey, boundary: boundary, timeout: 120)
        request.httpBody = makeTranscriptionBody(
            audioURL: audioURL,
            audioData: audioData,
            model: model,
            language: language,
            boundary: boundary
        )

        // Отправляем запрос
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MurmurixError.transcription(.failed("Invalid response"))
        }

        // Проверяем статус
        switch httpResponse.statusCode {
        case 200:
            return try parseTranscriptionResponse(data)
        case 401:
            throw MurmurixError.transcription(.failed("Invalid OpenAI API key"))
        case 413:
            throw MurmurixError.transcription(.failed("Audio file too large (max 25 MB)"))
        case 429:
            throw MurmurixError.transcription(.failed("Rate limit exceeded"))
        default:
            let errorMessage = parseErrorResponse(data) ?? "HTTP \(httpResponse.statusCode)"
            throw MurmurixError.transcription(.failed(errorMessage))
        }
    }

    // MARK: - Validate API Key

    func validateAPIKey(_ apiKey: String) async throws -> Bool {
        // Проверяем формат ключа
        guard apiKey.hasPrefix("sk-") else {
            throw MurmurixError.transcription(.failed("API key must start with 'sk-'"))
        }

        guard apiKey.count > 20 else {
            throw MurmurixError.transcription(.failed("API key is too short"))
        }

        // Создаём минимальный WAV файл (тишина) для тестового запроса
        let testAudioData = AudioTestUtility.createWavData(duration: 0.1)

        let boundary = UUID().uuidString
        var request = try makeMultipartRequest(apiKey: apiKey, boundary: boundary, timeout: 30)
        request.httpBody = makeValidationBody(testAudioData: testAudioData, boundary: boundary)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MurmurixError.transcription(.failed("Invalid response"))
        }

        switch httpResponse.statusCode {
        case 200:
            return true
        case 401:
            if let errorMessage = parseErrorResponse(data) {
                throw MurmurixError.transcription(.failed(errorMessage))
            }
            throw MurmurixError.transcription(.failed("Invalid API key"))
        case 400:
            // 400 может быть "audio too short" — это ОК, значит ключ валидный
            return true
        default:
            let errorMessage = parseErrorResponse(data) ?? "HTTP \(httpResponse.statusCode)"
            throw MurmurixError.transcription(.failed(errorMessage))
        }
    }

    // MARK: - Helpers

    private func parseTranscriptionResponse(_ data: Data) throws -> String {
        do {
            let response = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
            return response.text
        } catch {
            Logger.Transcription.error("Failed to decode OpenAI transcription response: \(error.localizedDescription)")
            throw MurmurixError.transcription(.failed("Failed to parse response"))
        }
    }

    private func parseErrorResponse(_ data: Data) -> String? {
        do {
            let response = try JSONDecoder().decode(ErrorResponse.self, from: data)
            return response.error.message
        } catch {
            Logger.Transcription.debug("Failed to decode OpenAI error response: \(error.localizedDescription)")
            return nil
        }
    }

    private func makeMultipartRequest(apiKey: String, boundary: String, timeout: TimeInterval) throws -> URLRequest {
        guard let url = URL(string: baseURL) else {
            throw MurmurixError.transcription(.failed("Invalid API URL"))
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        return request
    }

    private func makeTranscriptionBody(
        audioURL: URL,
        audioData: Data,
        model: String,
        language: String,
        boundary: String
    ) -> Data {
        let prompt = promptPolicy.openAIPrompt(language: language)
        var body = Data()
        appendFileField(
            name: "file",
            filename: audioURL.lastPathComponent,
            mimeType: MIMETypeResolver.mimeType(for: audioURL.pathExtension),
            fileData: audioData,
            boundary: boundary,
            to: &body
        )
        appendFormField(name: "model", value: model, boundary: boundary, to: &body)
        appendFormField(name: "language", value: language, boundary: boundary, to: &body)
        appendFormField(name: "prompt", value: prompt, boundary: boundary, to: &body)
        appendFormField(name: "response_format", value: "json", boundary: boundary, to: &body)
        closeBoundary(boundary, to: &body)
        return body
    }

    private func makeValidationBody(testAudioData: Data, boundary: String) -> Data {
        var body = Data()
        appendFileField(
            name: "file",
            filename: "test.wav",
            mimeType: "audio/wav",
            fileData: testAudioData,
            boundary: boundary,
            to: &body
        )
        appendFormField(name: "model", value: "gpt-4o-mini-transcribe", boundary: boundary, to: &body)
        closeBoundary(boundary, to: &body)
        return body
    }

    private func appendFormField(name: String, value: String, boundary: String, to body: inout Data) {
        appendUTF8("--\(boundary)\r\n", to: &body)
        appendUTF8("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n", to: &body)
        appendUTF8("\(value)\r\n", to: &body)
    }

    private func appendFileField(
        name: String,
        filename: String,
        mimeType: String,
        fileData: Data,
        boundary: String,
        to body: inout Data
    ) {
        appendUTF8("--\(boundary)\r\n", to: &body)
        appendUTF8("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n", to: &body)
        appendUTF8("Content-Type: \(mimeType)\r\n\r\n", to: &body)
        body.append(fileData)
        appendUTF8("\r\n", to: &body)
    }

    private func closeBoundary(_ boundary: String, to body: inout Data) {
        appendUTF8("--\(boundary)--\r\n", to: &body)
    }

    private func appendUTF8(_ value: String, to body: inout Data) {
        body.append(Data(value.utf8))
    }
}
