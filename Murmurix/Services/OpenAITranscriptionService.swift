//
//  OpenAITranscriptionService.swift
//  Murmurix
//

import Foundation

final class OpenAITranscriptionService: @unchecked Sendable {
    static let shared = OpenAITranscriptionService()

    private let baseURL = "https://api.openai.com/v1/audio/transcriptions"
    private let modelsURL = "https://api.openai.com/v1/models"

    // Промпт для улучшения распознавания технических терминов
    private let defaultPrompt = "Диалог на темы программирования. Технические термины: Anthropic, Claude, Bun, React, Docker, Kubernetes, Golang, Python, Swift, Xcode, GitHub, API, JSON, REST, GraphQL, PostgreSQL, MongoDB, Redis, AWS, Azure, GCP."

    private init() {}

    // MARK: - Transcription

    func transcribe(audioURL: URL, language: String, model: String, apiKey: String) async throws -> String {
        guard let url = URL(string: baseURL) else {
            throw MurmurixError.transcription(.failed("Invalid API URL"))
        }

        // Читаем аудио файл
        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioURL)
        } catch {
            throw MurmurixError.transcription(.failed("Failed to read audio file: \(error.localizedDescription)"))
        }

        // Создаем multipart/form-data запрос
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        // Собираем body
        var body = Data()

        // file
        let filename = audioURL.lastPathComponent
        let mimeType = mimeTypeForPath(audioURL.pathExtension)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(model)\r\n".data(using: .utf8)!)

        // language (обязательно для русского!)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(language)\r\n".data(using: .utf8)!)

        // prompt
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(defaultPrompt)\r\n".data(using: .utf8)!)

        // response_format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("json\r\n".data(using: .utf8)!)

        // Закрываем boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        // Отправляем запрос
        let (data, response) = try await URLSession.shared.data(for: request)

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
        let testAudioData = createMinimalWavFile()

        guard let url = URL(string: baseURL) else {
            throw MurmurixError.transcription(.failed("Invalid API URL"))
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        var body = Data()

        // file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"test.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(testAudioData)
        body.append("\r\n".data(using: .utf8)!)

        // model
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("gpt-4o-mini-transcribe\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

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

    /// Создаёт минимальный WAV файл (0.1 сек тишины)
    private func createMinimalWavFile() -> Data {
        let sampleRate: UInt32 = 16000
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let duration: Double = 0.1 // 100ms

        let numSamples = Int(Double(sampleRate) * duration)
        let dataSize = UInt32(numSamples * Int(numChannels) * Int(bitsPerSample / 8))
        let fileSize = 36 + dataSize

        var wav = Data()

        // RIFF header
        wav.append("RIFF".data(using: .ascii)!)
        wav.append(withUnsafeBytes(of: fileSize.littleEndian) { Data($0) })
        wav.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        wav.append("fmt ".data(using: .ascii)!)
        wav.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // chunk size
        wav.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })  // PCM format
        wav.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        let byteRate = sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)
        wav.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        let blockAlign = numChannels * (bitsPerSample / 8)
        wav.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        wav.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })

        // data chunk
        wav.append("data".data(using: .ascii)!)
        wav.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })

        // Silence (zeros)
        wav.append(Data(count: Int(dataSize)))

        return wav
    }

    // MARK: - Helpers

    private func parseTranscriptionResponse(_ data: Data) throws -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            throw MurmurixError.transcription(.failed("Failed to parse response"))
        }
        return text
    }

    private func parseErrorResponse(_ data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }

    private func mimeTypeForPath(_ pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "mp3":
            return "audio/mpeg"
        case "mp4", "m4a":
            return "audio/mp4"
        case "wav":
            return "audio/wav"
        case "webm":
            return "audio/webm"
        case "mpeg", "mpga":
            return "audio/mpeg"
        default:
            return "audio/mpeg"
        }
    }
}
