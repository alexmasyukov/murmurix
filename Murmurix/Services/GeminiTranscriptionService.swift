//
//  GeminiTranscriptionService.swift
//  Murmurix
//

import Foundation
import GoogleGenerativeAI

protocol GeminiTranscriptionServiceProtocol: Sendable {
    func transcribe(audioURL: URL, language: String, model: String, apiKey: String) async throws -> String
    func validateAPIKey(_ apiKey: String) async throws -> Bool
}

final class GeminiTranscriptionService: @unchecked Sendable, GeminiTranscriptionServiceProtocol {
    static let shared = GeminiTranscriptionService()

    private init() {}

    // MARK: - Transcription

    func transcribe(audioURL: URL, language: String, model: String, apiKey: String) async throws -> String {
        Logger.Transcription.info("Gemini transcription started, model=\(model)")

        // Read audio file
        let audioData: Data
        do {
            audioData = try Data(contentsOf: audioURL)
        } catch {
            throw MurmurixError.transcription(.failed("Failed to read audio file: \(error.localizedDescription)"))
        }

        // Determine MIME type
        let mimeType = mimeTypeForPath(audioURL.pathExtension)
        Logger.Transcription.debug("Audio MIME type: \(mimeType), size: \(audioData.count) bytes")

        // Create Gemini model
        let generativeModel = GenerativeModel(name: model, apiKey: apiKey)

        // Build prompt with language hint
        let languageHint: String
        switch language {
        case "ru":
            languageHint = "The audio is in Russian. Transcribe it accurately, preserving technical terms like Anthropic, Claude, Docker, Kubernetes, React, Swift, Xcode."
        case "en":
            languageHint = "The audio is in English. Transcribe it accurately."
        default:
            languageHint = "Detect the language and transcribe accurately."
        }

        let prompt = """
        Transcribe this audio to text precisely.
        Output ONLY the transcription text, without any additional commentary, timestamps, or formatting.
        \(languageHint)
        """

        // Create audio content part
        let audioPart = ModelContent.Part.data(mimetype: mimeType, audioData)

        // Execute request
        do {
            let response = try await generativeModel.generateContent(prompt, audioPart)

            guard let text = response.text, !text.isEmpty else {
                throw MurmurixError.transcription(.failed("Empty response from Gemini"))
            }

            // Clean up text from possible artifacts
            let cleanedText = text
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            Logger.Transcription.info("Gemini transcription completed, length=\(cleanedText.count)")
            return cleanedText

        } catch let error as GenerateContentError {
            Logger.Transcription.error("Gemini API error: \(error)")
            throw MurmurixError.transcription(.failed("Gemini error: \(error.localizedDescription)"))
        } catch {
            Logger.Transcription.error("Gemini transcription failed: \(error)")
            throw MurmurixError.transcription(.failed(error.localizedDescription))
        }
    }

    // MARK: - API Key Validation

    func validateAPIKey(_ apiKey: String) async throws -> Bool {
        guard !apiKey.isEmpty else {
            throw MurmurixError.transcription(.failed("API key is empty"))
        }

        // Basic format check (Gemini keys usually start with "AI")
        guard apiKey.count > 10 else {
            throw MurmurixError.transcription(.failed("API key is too short"))
        }

        // Test request to Gemini
        let model = GenerativeModel(name: "gemini-2.0-flash", apiKey: apiKey)

        do {
            // Simple text request to verify key
            let response = try await model.generateContent("Say 'ok'")
            return response.text != nil
        } catch {
            // Analyze error
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("api key") || errorMessage.contains("invalid") || errorMessage.contains("unauthorized") {
                return false
            }
            throw MurmurixError.transcription(.failed("Gemini validation error: \(error.localizedDescription)"))
        }
    }

    // MARK: - Helpers

    private func mimeTypeForPath(_ pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "mp3":
            return "audio/mp3"
        case "mp4", "m4a":
            return "audio/mp4"
        case "wav":
            return "audio/wav"
        case "webm":
            return "audio/webm"
        case "ogg":
            return "audio/ogg"
        case "flac":
            return "audio/flac"
        default:
            return "audio/mpeg"
        }
    }
}
