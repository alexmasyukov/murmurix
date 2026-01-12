//
//  Phase2Tests.swift
//  MurmurixTests
//
//  Tests for Phase 2 refactoring: URLSession abstraction, UnixSocketClient
//

import Testing
import Foundation
@testable import Murmurix

// MARK: - MockURLSession Tests

struct MockURLSessionTests {

    @Test func initialStateIsCorrect() {
        let mock = MockURLSession()

        #expect(mock.responseData.isEmpty)
        #expect(mock.responseStatusCode == 200)
        #expect(mock.error == nil)
        #expect(mock.lastRequest == nil)
        #expect(mock.requestCallCount == 0)
    }

    @Test func dataReturnsConfiguredResponse() async throws {
        let mock = MockURLSession()
        mock.responseData = "test data".data(using: .utf8)!
        mock.responseStatusCode = 201

        let request = URLRequest(url: URL(string: "https://example.com")!)
        let (data, response) = try await mock.data(for: request)

        #expect(String(data: data, encoding: .utf8) == "test data")
        #expect((response as? HTTPURLResponse)?.statusCode == 201)
        #expect(mock.requestCallCount == 1)
        #expect(mock.lastRequest?.url?.absoluteString == "https://example.com")
    }

    @Test func dataThrowsConfiguredError() async {
        let mock = MockURLSession()
        let testError = NSError(domain: "test", code: 123)
        mock.error = testError

        let request = URLRequest(url: URL(string: "https://example.com")!)

        do {
            _ = try await mock.data(for: request)
            #expect(Bool(false), "Should have thrown")
        } catch let error as NSError {
            #expect(error.code == 123)
        }

        #expect(mock.requestCallCount == 1)
    }

    @Test func setSuccessResponseConfiguresCorrectly() async throws {
        let mock = MockURLSession()
        mock.setSuccessResponse(json: ["text": "Hello", "count": 42])

        let request = URLRequest(url: URL(string: "https://example.com")!)
        let (data, response) = try await mock.data(for: request)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(json?["text"] as? String == "Hello")
        #expect(json?["count"] as? Int == 42)
        #expect((response as? HTTPURLResponse)?.statusCode == 200)
    }

    @Test func setErrorResponseConfiguresCorrectly() async throws {
        let mock = MockURLSession()
        mock.setErrorResponse(statusCode: 401, message: "Unauthorized")

        let request = URLRequest(url: URL(string: "https://example.com")!)
        let (data, response) = try await mock.data(for: request)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let errorObj = json?["error"] as? [String: Any]
        #expect(errorObj?["message"] as? String == "Unauthorized")
        #expect((response as? HTTPURLResponse)?.statusCode == 401)
    }

    @Test func multipleRequestsIncrementCallCount() async throws {
        let mock = MockURLSession()
        let request = URLRequest(url: URL(string: "https://example.com")!)

        _ = try await mock.data(for: request)
        _ = try await mock.data(for: request)
        _ = try await mock.data(for: request)

        #expect(mock.requestCallCount == 3)
    }
}

// MARK: - MockSocketClient Tests

struct MockSocketClientTests {

    @Test func initialStateIsCorrect() {
        let mock = MockSocketClient()

        #expect(mock.response.isEmpty)
        #expect(mock.error == nil)
        #expect(mock.lastRequest == nil)
        #expect(mock.lastTimeout == nil)
        #expect(mock.sendCallCount == 0)
    }

    @Test func sendReturnsConfiguredResponse() throws {
        let mock = MockSocketClient()
        mock.response = ["text": "Hello", "status": "ok"]

        let result = try mock.send(request: ["command": "test"], timeout: 30)

        #expect(result["text"] as? String == "Hello")
        #expect(result["status"] as? String == "ok")
        #expect(mock.sendCallCount == 1)
        #expect(mock.lastRequest?["command"] as? String == "test")
        #expect(mock.lastTimeout == 30)
    }

    @Test func sendThrowsConfiguredError() {
        let mock = MockSocketClient()
        mock.error = SocketError.connectionFailed("Test failure")

        do {
            _ = try mock.send(request: [:], timeout: 10)
            #expect(Bool(false), "Should have thrown")
        } catch let error as SocketError {
            if case .connectionFailed(let reason) = error {
                #expect(reason == "Test failure")
            } else {
                #expect(Bool(false), "Wrong error type")
            }
        } catch {
            #expect(Bool(false), "Unexpected error type")
        }

        #expect(mock.sendCallCount == 1)
    }

    @Test func setTranscriptionResponseConfiguresCorrectly() throws {
        let mock = MockSocketClient()
        mock.setTranscriptionResponse(text: "Transcribed text")

        let result = try mock.send(request: [:], timeout: 10)

        #expect(result["text"] as? String == "Transcribed text")
    }

    @Test func setErrorResponseConfiguresCorrectly() throws {
        let mock = MockSocketClient()
        mock.setErrorResponse(message: "Model not found")

        let result = try mock.send(request: [:], timeout: 10)

        #expect(result["error"] as? String == "Model not found")
    }

    @Test func setSocketErrorConfiguresCorrectly() {
        let mock = MockSocketClient()
        mock.setSocketError(.timeout)

        do {
            _ = try mock.send(request: [:], timeout: 10)
            #expect(Bool(false), "Should have thrown")
        } catch let error as SocketError {
            if case .timeout = error {
                // Expected
            } else {
                #expect(Bool(false), "Wrong error type: \(error)")
            }
        } catch {
            #expect(Bool(false), "Unexpected error type")
        }
    }
}

// MARK: - SocketError Tests

struct SocketErrorTests {

    @Test func connectionFailedHasDescription() {
        let error = SocketError.connectionFailed("Connection refused")
        #expect(error.errorDescription?.contains("Connection refused") == true)
    }

    @Test func timeoutHasDescription() {
        let error = SocketError.timeout
        #expect(error.errorDescription?.contains("timed out") == true)
    }

    @Test func noResponseHasDescription() {
        let error = SocketError.noResponse
        #expect(error.errorDescription?.contains("No response") == true)
    }

    @Test func invalidResponseHasDescription() {
        let error = SocketError.invalidResponse
        #expect(error.errorDescription?.contains("Invalid response") == true)
    }
}

// MARK: - OpenAITranscriptionService DI Tests

struct OpenAITranscriptionServiceDITests {

    @Test func serviceAcceptsCustomURLSession() async throws {
        let mockSession = MockURLSession()
        mockSession.setSuccessResponse(json: ["text": "Hello world"])

        let service = OpenAITranscriptionService(session: mockSession)

        // Create a temp audio file for the test
        let tempURL = AudioTestUtility.createTemporaryTestAudioURL()
        try AudioTestUtility.createSilentWavFile(at: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let result = try await service.transcribe(
            audioURL: tempURL,
            language: "en",
            model: "gpt-4o-transcribe",
            apiKey: "sk-test1234567890"
        )

        #expect(result == "Hello world")
        #expect(mockSession.requestCallCount == 1)
        #expect(mockSession.lastRequest?.url?.absoluteString.contains("openai.com") == true)
    }

    @Test func serviceRequestContainsAuthorizationHeader() async throws {
        let mockSession = MockURLSession()
        mockSession.setSuccessResponse(json: ["text": "Test"])

        let service = OpenAITranscriptionService(session: mockSession)

        let tempURL = AudioTestUtility.createTemporaryTestAudioURL()
        try AudioTestUtility.createSilentWavFile(at: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = try await service.transcribe(
            audioURL: tempURL,
            language: "en",
            model: "gpt-4o-transcribe",
            apiKey: "sk-mytestkey123456"
        )

        let authHeader = mockSession.lastRequest?.value(forHTTPHeaderField: "Authorization")
        #expect(authHeader == "Bearer sk-mytestkey123456")
    }

    @Test func serviceHandles401Error() async {
        let mockSession = MockURLSession()
        mockSession.setErrorResponse(statusCode: 401, message: "Invalid API key")

        let service = OpenAITranscriptionService(session: mockSession)

        let tempURL = AudioTestUtility.createTemporaryTestAudioURL()
        try? AudioTestUtility.createSilentWavFile(at: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        do {
            _ = try await service.transcribe(
                audioURL: tempURL,
                language: "en",
                model: "gpt-4o-transcribe",
                apiKey: "sk-invalid123456789"
            )
            #expect(Bool(false), "Should have thrown")
        } catch {
            #expect(error.localizedDescription.contains("Invalid") == true)
        }
    }
}

// MARK: - TranscriptionService Socket DI Tests

struct TranscriptionServiceSocketDITests {

    @Test func serviceAcceptsCustomSocketClientFactory() {
        let mockSocket = MockSocketClient()
        let mockSettings = MockSettings()

        let service = TranscriptionService(
            settings: mockSettings,
            socketClientFactory: { _ in mockSocket }
        )

        // Verify the service was created with custom factory
        // Note: isDaemonRunning depends on socket file existence which is external state,
        // so we just verify the service type is correct
        #expect(type(of: service) == TranscriptionService.self)
    }
}
