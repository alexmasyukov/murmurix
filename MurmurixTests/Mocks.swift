//
//  Mocks.swift
//  MurmurixTests
//

import Foundation
@testable import Murmurix

// MARK: - Mock Audio Recorder

final class MockAudioRecorder: AudioRecorderProtocol {
    var isRecording: Bool = false
    var audioLevel: Float = 0.0
    var hadVoiceActivity: Bool = true  // Default to true for existing tests

    var startRecordingCallCount = 0
    var stopRecordingCallCount = 0
    var recordingURL = URL(fileURLWithPath: "/tmp/test.wav")

    func startRecording() {
        startRecordingCallCount += 1
        isRecording = true
    }

    func stopRecording() -> URL {
        stopRecordingCallCount += 1
        isRecording = false
        return recordingURL
    }

    /// Creates a real temporary file for testing file deletion
    func createRealTempFile() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_audio_\(UUID().uuidString).wav")
        FileManager.default.createFile(atPath: fileURL.path, contents: Data("test".utf8))
        recordingURL = fileURL
        return fileURL
    }
}

// MARK: - Mock Transcription Service

final class MockTranscriptionService: TranscriptionServiceProtocol, @unchecked Sendable {
    var isDaemonRunning: Bool = false

    var startDaemonCallCount = 0
    var stopDaemonCallCount = 0
    var transcribeCallCount = 0

    var transcriptionResult: Result<String, Error> = .success("Test transcription")
    var transcriptionDelay: TimeInterval = 0

    func startDaemon() {
        startDaemonCallCount += 1
        isDaemonRunning = true
    }

    func stopDaemon() {
        stopDaemonCallCount += 1
        isDaemonRunning = false
    }

    func transcribe(audioURL: URL, useDaemon: Bool, mode: TranscriptionMode = .local) async throws -> String {
        transcribeCallCount += 1

        if transcriptionDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(transcriptionDelay * 1_000_000_000))
        }

        switch transcriptionResult {
        case .success(let text):
            return text
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Mock History Service

final class MockHistoryService: HistoryServiceProtocol {
    var records: [TranscriptionRecord] = []

    var saveCallCount = 0
    var deleteCallCount = 0
    var deleteAllCallCount = 0

    func save(record: TranscriptionRecord) {
        saveCallCount += 1
        if let index = records.firstIndex(where: { $0.id == record.id }) {
            records[index] = record
        } else {
            records.append(record)
        }
    }

    func fetchAll() -> [TranscriptionRecord] {
        return records.sorted { $0.createdAt > $1.createdAt }
    }

    func delete(id: UUID) {
        deleteCallCount += 1
        records.removeAll { $0.id == id }
    }

    func deleteAll() {
        deleteAllCallCount += 1
        records.removeAll()
    }
}

// MARK: - Mock Settings

final class MockSettings: SettingsStorageProtocol {
    var keepDaemonRunning: Bool = true
    var language: String = "ru"
    var transcriptionMode: String = "local"
    var whisperModel: String = "small"
    var openaiApiKey: String = ""
    var openaiTranscriptionModel: String = "gpt-4o-transcribe"
    var geminiApiKey: String = ""
    var geminiModel: String = GeminiTranscriptionModel.flash2.rawValue

    private var toggleLocalHotkey: Hotkey = .toggleLocalDefault
    private var toggleCloudHotkey: Hotkey = .toggleCloudDefault
    private var toggleGeminiHotkey: Hotkey = .toggleGeminiDefault
    private var cancelHotkey: Hotkey = .cancelDefault

    func loadToggleLocalHotkey() -> Hotkey {
        return toggleLocalHotkey
    }

    func saveToggleLocalHotkey(_ hotkey: Hotkey) {
        toggleLocalHotkey = hotkey
    }

    func loadToggleCloudHotkey() -> Hotkey {
        return toggleCloudHotkey
    }

    func saveToggleCloudHotkey(_ hotkey: Hotkey) {
        toggleCloudHotkey = hotkey
    }

    func loadToggleGeminiHotkey() -> Hotkey {
        return toggleGeminiHotkey
    }

    func saveToggleGeminiHotkey(_ hotkey: Hotkey) {
        toggleGeminiHotkey = hotkey
    }

    func loadCancelHotkey() -> Hotkey {
        return cancelHotkey
    }

    func saveCancelHotkey(_ hotkey: Hotkey) {
        cancelHotkey = hotkey
    }
}

// MARK: - Mock Recording Coordinator Delegate

final class MockRecordingCoordinatorDelegate: RecordingCoordinatorDelegate {
    var recordingDidStartCallCount = 0
    var recordingDidStopCallCount = 0
    var recordingDidStopWithoutVoiceCallCount = 0
    var transcriptionDidStartCallCount = 0
    var transcriptionDidCompleteCallCount = 0
    var transcriptionDidFailCallCount = 0
    var transcriptionDidCancelCallCount = 0

    var lastCompletedText: String?
    var lastCompletedDuration: TimeInterval?
    var lastCompletedRecordId: UUID?
    var lastError: Error?

    func recordingDidStart() {
        recordingDidStartCallCount += 1
    }

    func recordingDidStop() {
        recordingDidStopCallCount += 1
    }

    func recordingDidStopWithoutVoice() {
        recordingDidStopWithoutVoiceCallCount += 1
    }

    func transcriptionDidStart() {
        transcriptionDidStartCallCount += 1
    }

    func transcriptionDidComplete(text: String, duration: TimeInterval, recordId: UUID) {
        transcriptionDidCompleteCallCount += 1
        lastCompletedText = text
        lastCompletedDuration = duration
        lastCompletedRecordId = recordId
    }

    func transcriptionDidFail(error: Error) {
        transcriptionDidFailCallCount += 1
        lastError = error
    }

    func transcriptionDidCancel() {
        transcriptionDidCancelCallCount += 1
    }
}

// MARK: - Mock Model Download Service

final class MockModelDownloadService: ModelDownloadServiceProtocol {
    var downloadModelCallCount = 0
    var cancelDownloadCallCount = 0
    var lastDownloadedModel: String?

    func downloadModel(_ modelName: String, onProgress: @escaping (DownloadStatus) -> Void) {
        downloadModelCallCount += 1
        lastDownloadedModel = modelName
        onProgress(.downloading)
    }

    func cancelDownload() {
        cancelDownloadCallCount += 1
    }
}

// MARK: - Mock OpenAI Transcription Service

final class MockOpenAITranscriptionService: OpenAITranscriptionServiceProtocol, @unchecked Sendable {
    var transcribeCallCount = 0
    var validateAPIKeyCallCount = 0

    var transcribeResult: Result<String, Error> = .success("Transcribed text")
    var validateAPIKeyResult: Result<Bool, Error> = .success(true)

    func transcribe(audioURL: URL, language: String, model: String, apiKey: String) async throws -> String {
        transcribeCallCount += 1
        switch transcribeResult {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }

    func validateAPIKey(_ apiKey: String) async throws -> Bool {
        validateAPIKeyCallCount += 1
        switch validateAPIKeyResult {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Mock Gemini Transcription Service

final class MockGeminiTranscriptionService: GeminiTranscriptionServiceProtocol, @unchecked Sendable {
    var transcribeCallCount = 0
    var validateAPIKeyCallCount = 0
    var lastLanguage: String?
    var lastModel: String?

    var transcribeResult: Result<String, Error> = .success("Gemini transcribed text")
    var validateAPIKeyResult: Result<Bool, Error> = .success(true)

    func transcribe(audioURL: URL, language: String, model: String, apiKey: String) async throws -> String {
        transcribeCallCount += 1
        lastLanguage = language
        lastModel = model
        switch transcribeResult {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }

    func validateAPIKey(_ apiKey: String) async throws -> Bool {
        validateAPIKeyCallCount += 1
        switch validateAPIKeyResult {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Mock Daemon Manager

final class MockDaemonManager: DaemonManagerProtocol, @unchecked Sendable {
    var isRunning: Bool = false
    var socketPath: String = "/tmp/test_murmurix.sock"

    var startCallCount = 0
    var stopCallCount = 0

    func start() {
        startCallCount += 1
        isRunning = true
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
    }
}

// MARK: - Mock Hotkey Manager

final class MockHotkeyManager: HotkeyManagerProtocol {
    var onToggleLocalRecording: (() -> Void)?
    var onToggleCloudRecording: (() -> Void)?
    var onToggleGeminiRecording: (() -> Void)?
    var onCancelRecording: (() -> Void)?

    var startCallCount = 0
    var stopCallCount = 0
    var updateHotkeysCallCount = 0
    var lastHotkeys: (local: Hotkey, cloud: Hotkey, gemini: Hotkey, cancel: Hotkey)?
    var isPaused = false

    func start() {
        startCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }

    func updateHotkeys(toggleLocal: Hotkey, toggleCloud: Hotkey, toggleGemini: Hotkey, cancel: Hotkey) {
        updateHotkeysCallCount += 1
        lastHotkeys = (toggleLocal, toggleCloud, toggleGemini, cancel)
    }
}

// MARK: - Mock Transcription Repository

final class MockTranscriptionRepository: TranscriptionRepositoryProtocol {
    var records: [TranscriptionRecord] = []
    var saveCallCount = 0
    var fetchAllCallCount = 0
    var deleteCallCount = 0
    var deleteAllCallCount = 0

    func save(_ item: TranscriptionRecord) {
        saveCallCount += 1
        if let index = records.firstIndex(where: { $0.id == item.id }) {
            records[index] = item
        } else {
            records.append(item)
        }
    }

    func fetchAll() -> [TranscriptionRecord] {
        fetchAllCallCount += 1
        return records.sorted { $0.createdAt > $1.createdAt }
    }

    func delete(id: UUID) {
        deleteCallCount += 1
        records.removeAll { $0.id == id }
    }

    func deleteAll() {
        deleteAllCallCount += 1
        records.removeAll()
    }
}

// MARK: - Mock URL Session

final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    var responseData: Data = Data()
    var responseStatusCode: Int = 200
    var error: Error?
    var lastRequest: URLRequest?
    var requestCallCount = 0

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requestCallCount += 1
        lastRequest = request

        if let error = error {
            throw error
        }

        let url = request.url ?? URL(string: "https://example.com")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: responseStatusCode,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!

        return (responseData, response)
    }

    /// Helper to set up a successful JSON response
    func setSuccessResponse(json: [String: Any]) {
        responseData = (try? JSONSerialization.data(withJSONObject: json)) ?? Data()
        responseStatusCode = 200
        error = nil
    }

    /// Helper to set up an error response
    func setErrorResponse(statusCode: Int, message: String) {
        let errorJson: [String: Any] = ["error": ["message": message]]
        responseData = (try? JSONSerialization.data(withJSONObject: errorJson)) ?? Data()
        responseStatusCode = statusCode
        error = nil
    }
}

// MARK: - Mock Socket Client

final class MockSocketClient: SocketClientProtocol, @unchecked Sendable {
    var response: [String: Any] = [:]
    var error: Error?
    var lastRequest: [String: Any]?
    var lastTimeout: Int?
    var sendCallCount = 0

    func send(request: [String: Any], timeout: Int) throws -> [String: Any] {
        sendCallCount += 1
        lastRequest = request
        lastTimeout = timeout

        if let error = error {
            throw error
        }

        return response
    }

    /// Helper to set up a successful transcription response
    func setTranscriptionResponse(text: String) {
        response = ["text": text]
        error = nil
    }

    /// Helper to set up an error response
    func setErrorResponse(message: String) {
        response = ["error": message]
        error = nil
    }

    /// Helper to set up a socket error
    func setSocketError(_ socketError: SocketError) {
        error = socketError
    }
}
