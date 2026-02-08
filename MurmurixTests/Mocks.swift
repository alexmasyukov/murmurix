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
    var loadedModels: Set<String> = []

    var loadModelCallCount = 0
    var unloadModelCallCount = 0
    var unloadAllModelsCallCount = 0
    var transcribeCallCount = 0

    var transcriptionResult: Result<String, Error> = .success("Test transcription")
    var transcriptionDelay: TimeInterval = 0

    func isModelLoaded(name: String) -> Bool {
        loadedModels.contains(name)
    }

    func loadModel(name: String) async throws {
        loadModelCallCount += 1
        loadedModels.insert(name)
    }

    func unloadModel(name: String) async {
        unloadModelCallCount += 1
        loadedModels.remove(name)
    }

    func unloadAllModels() async {
        unloadAllModelsCallCount += 1
        loadedModels.removeAll()
    }

    func transcribe(audioURL: URL, mode: TranscriptionMode = .local(model: "small")) async throws -> String {
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
    var language: String = "ru"
    var appLanguage: String = "en"
    var openaiApiKey: String = ""
    var openaiTranscriptionModel: String = "gpt-4o-transcribe"
    var geminiApiKey: String = ""
    var geminiModel: String = GeminiTranscriptionModel.flash2.rawValue

    private var whisperModelSettingsMap: [String: WhisperModelSettings] = [:]
    private var toggleCloudHotkey: Hotkey?
    private var toggleGeminiHotkey: Hotkey?
    private var cancelHotkey: Hotkey?

    func loadWhisperModelSettings() -> [String: WhisperModelSettings] {
        return whisperModelSettingsMap
    }

    func saveWhisperModelSettings(_ settings: [String: WhisperModelSettings]) {
        whisperModelSettingsMap = settings
    }

    func loadToggleCloudHotkey() -> Hotkey? {
        return toggleCloudHotkey
    }

    func saveToggleCloudHotkey(_ hotkey: Hotkey?) {
        toggleCloudHotkey = hotkey
    }

    func loadToggleGeminiHotkey() -> Hotkey? {
        return toggleGeminiHotkey
    }

    func saveToggleGeminiHotkey(_ hotkey: Hotkey?) {
        toggleGeminiHotkey = hotkey
    }

    func loadCancelHotkey() -> Hotkey? {
        return cancelHotkey
    }

    func saveCancelHotkey(_ hotkey: Hotkey?) {
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

// MARK: - Mock WhisperKit Service

final class MockWhisperKitService: WhisperKitServiceProtocol, @unchecked Sendable {
    var loadedModelNames: Set<String> = []
    var loadModelCallCount = 0
    var unloadModelCallCount = 0
    var unloadAllModelsCallCount = 0
    var transcribeCallCount = 0
    var downloadModelCallCount = 0
    var lastModelName: String?
    var transcribeResult: Result<String, Error> = .success("Transcribed text")

    func isModelLoaded(name: String) -> Bool {
        loadedModelNames.contains(name)
    }

    var loadedModels: [String] {
        Array(loadedModelNames)
    }

    func loadModel(name: String) async throws {
        loadModelCallCount += 1
        lastModelName = name
        loadedModelNames.insert(name)
    }

    func unloadModel(name: String) async {
        unloadModelCallCount += 1
        loadedModelNames.remove(name)
    }

    func unloadAllModels() async {
        unloadAllModelsCallCount += 1
        loadedModelNames.removeAll()
    }

    func transcribe(audioURL: URL, language: String, model: String) async throws -> String {
        transcribeCallCount += 1
        switch transcribeResult {
        case .success(let text): return text
        case .failure(let error): throw error
        }
    }

    func downloadModel(_ name: String, progress: @escaping @Sendable (Double) -> Void) async throws {
        downloadModelCallCount += 1
        lastModelName = name
        progress(1.0)
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

// MARK: - Mock Hotkey Manager

final class MockHotkeyManager: HotkeyManagerProtocol {
    var onToggleLocalRecording: ((String) -> Void)?
    var onToggleCloudRecording: (() -> Void)?
    var onToggleGeminiRecording: (() -> Void)?
    var onCancelRecording: (() -> Void)?

    var startCallCount = 0
    var stopCallCount = 0
    var updateLocalModelHotkeysCallCount = 0
    var updateCloudHotkeysCallCount = 0
    var lastLocalModelHotkeys: [String: Hotkey]?
    var lastCloudHotkeys: (cloud: Hotkey?, gemini: Hotkey?, cancel: Hotkey?)?
    var isPaused = false

    func start() {
        startCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }

    func updateLocalModelHotkeys(_ hotkeys: [String: Hotkey]) {
        updateLocalModelHotkeysCallCount += 1
        lastLocalModelHotkeys = hotkeys
    }

    func updateCloudHotkeys(toggleCloud: Hotkey?, toggleGemini: Hotkey?, cancel: Hotkey?) {
        updateCloudHotkeysCallCount += 1
        lastCloudHotkeys = (toggleCloud, toggleGemini, cancel)
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
