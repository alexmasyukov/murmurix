import Testing
import Foundation
@testable import Murmurix

struct CloudTranscriptionClientTests {
    @Test func openAIClientForwardsRequestToService() async throws {
        let service = MockOpenAITranscriptionService()
        service.transcribeResult = .success("openai-ok")
        let client = OpenAICloudTranscriptionClient(service: service)

        let request = CloudTranscriptionRequest(
            provider: .openAI,
            audioURL: URL(fileURLWithPath: "/tmp/openai.wav"),
            language: "en",
            model: "gpt-4o-mini-transcribe",
            apiKey: "sk-test"
        )

        let text = try await client.transcribe(request: request)

        #expect(text == "openai-ok")
        #expect(service.transcribeCallCount == 1)
        #expect(service.lastAudioURL == request.audioURL)
        #expect(service.lastLanguage == "en")
        #expect(service.lastModel == "gpt-4o-mini-transcribe")
        #expect(service.lastApiKey == "sk-test")
    }

    @Test func geminiClientForwardsRequestToService() async throws {
        let service = MockGeminiTranscriptionService()
        service.transcribeResult = .success("gemini-ok")
        let client = GeminiCloudTranscriptionClient(service: service)

        let request = CloudTranscriptionRequest(
            provider: .gemini,
            audioURL: URL(fileURLWithPath: "/tmp/gemini.wav"),
            language: "ru",
            model: "gemini-2.0-flash",
            apiKey: "gem-key"
        )

        let text = try await client.transcribe(request: request)

        #expect(text == "gemini-ok")
        #expect(service.transcribeCallCount == 1)
        #expect(service.lastAudioURL == request.audioURL)
        #expect(service.lastLanguage == "ru")
        #expect(service.lastModel == "gemini-2.0-flash")
        #expect(service.lastApiKey == "gem-key")
    }

    @Test func openAIClientRejectsMismatchedProvider() async {
        let client = OpenAICloudTranscriptionClient(service: MockOpenAITranscriptionService())
        let request = CloudTranscriptionRequest(
            provider: .gemini,
            audioURL: URL(fileURLWithPath: "/tmp/test.wav"),
            language: "en",
            model: "m",
            apiKey: "k"
        )

        do {
            _ = try await client.transcribe(request: request)
            #expect(Bool(false), "Expected provider mismatch error")
        } catch {
            #expect(error.localizedDescription.contains("Mismatched cloud provider"))
        }
    }

    @Test func geminiClientRejectsMismatchedProvider() async {
        let client = GeminiCloudTranscriptionClient(service: MockGeminiTranscriptionService())
        let request = CloudTranscriptionRequest(
            provider: .openAI,
            audioURL: URL(fileURLWithPath: "/tmp/test.wav"),
            language: "en",
            model: "m",
            apiKey: "k"
        )

        do {
            _ = try await client.transcribe(request: request)
            #expect(Bool(false), "Expected provider mismatch error")
        } catch {
            #expect(error.localizedDescription.contains("Mismatched cloud provider"))
        }
    }
}
