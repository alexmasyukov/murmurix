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

    func transcribe(audioURL: URL, useDaemon: Bool) async throws -> String {
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
    var aiPostProcessingEnabled: Bool = false

    private var toggleHotkey: Hotkey = .toggleDefault
    private var cancelHotkey: Hotkey = .cancelDefault

    func loadToggleHotkey() -> Hotkey {
        return toggleHotkey
    }

    func saveToggleHotkey(_ hotkey: Hotkey) {
        toggleHotkey = hotkey
    }

    func loadCancelHotkey() -> Hotkey {
        return cancelHotkey
    }

    func saveCancelHotkey(_ hotkey: Hotkey) {
        cancelHotkey = hotkey
    }
}

// MARK: - Mock AI Post-Processing Service

final class MockAIPostProcessingService: AIPostProcessingServiceProtocol, @unchecked Sendable {
    var processCallCount = 0
    var processResult: Result<String, Error> = .success("Processed text")

    func process(text: String) async throws -> String {
        processCallCount += 1
        switch processResult {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - Mock Recording Coordinator Delegate

final class MockRecordingCoordinatorDelegate: RecordingCoordinatorDelegate {
    var recordingDidStartCallCount = 0
    var recordingDidStopCallCount = 0
    var recordingDidStopWithoutVoiceCallCount = 0
    var transcriptionDidStartCallCount = 0
    var processingDidStartCallCount = 0
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

    func processingDidStart() {
        processingDidStartCallCount += 1
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
