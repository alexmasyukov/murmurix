import Testing
@testable import Murmurix

struct TranscriptionPromptPolicyTests {
    private let policy = DefaultTranscriptionPromptPolicy.shared

    @Test func openAIPromptIncludesRussianHintForRuLanguage() {
        let prompt = policy.openAIPrompt(language: "ru")
        #expect(prompt.contains("Russian"))
        #expect(prompt.contains("technical terms"))
    }

    @Test func openAIPromptIncludesEnglishHintForEnLanguage() {
        let prompt = policy.openAIPrompt(language: "en")
        #expect(prompt.contains("English"))
    }

    @Test func geminiPromptFallsBackToDetectionHintForUnknownLanguage() {
        let prompt = policy.geminiPrompt(language: "de")
        #expect(prompt.contains("Detect the language"))
    }
}
