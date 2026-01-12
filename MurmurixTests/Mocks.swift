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

    private var toggleLocalHotkey: Hotkey = .toggleLocalDefault
    private var toggleCloudHotkey: Hotkey = .toggleCloudDefault
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
