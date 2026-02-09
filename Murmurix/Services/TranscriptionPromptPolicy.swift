//
//  TranscriptionPromptPolicy.swift
//  Murmurix
//

import Foundation

protocol TranscriptionPromptPolicy: Sendable {
    func openAIPrompt(language: String) -> String
    func geminiPrompt(language: String) -> String
}

struct DefaultTranscriptionPromptPolicy: TranscriptionPromptPolicy {
    static let shared = DefaultTranscriptionPromptPolicy()

    private let technicalTermsHint = """
    Preserve technical terms exactly when possible: Anthropic, Claude, Bun, React, Docker, Kubernetes, Golang, Python, Swift, Xcode, GitHub, API, JSON, REST, GraphQL, PostgreSQL, MongoDB, Redis, AWS, Azure, GCP.
    """

    func openAIPrompt(language: String) -> String {
        """
        Transcribe programmer speech accurately.
        Output only transcription text with no extra commentary.
        \(languageHint(for: language))
        \(technicalTermsHint)
        """
    }

    func geminiPrompt(language: String) -> String {
        """
        Transcribe this audio to text precisely.
        Output ONLY the transcription text, without additional commentary, timestamps, or formatting.
        \(languageHint(for: language))
        \(technicalTermsHint)
        """
    }

    private func languageHint(for language: String) -> String {
        switch language {
        case "ru":
            return "The audio is in Russian."
        case "en":
            return "The audio is in English."
        default:
            return "Detect the language and transcribe accurately."
        }
    }
}
