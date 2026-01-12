//
//  RecordingCoordinatorTests.swift
//  MurmurixTests
//

import Testing
import Foundation
import Carbon
@testable import Murmurix

struct RecordingCoordinatorTests {

    private func createCoordinator() -> (
        coordinator: RecordingCoordinator,
        audioRecorder: MockAudioRecorder,
        transcriptionService: MockTranscriptionService,
        historyService: MockHistoryService,
        settings: MockSettings,
        delegate: MockRecordingCoordinatorDelegate
    ) {
        let audioRecorder = MockAudioRecorder()
        let transcriptionService = MockTranscriptionService()
        let historyService = MockHistoryService()
        let settings = MockSettings()

        let coordinator = RecordingCoordinator(
            audioRecorder: audioRecorder,
            transcriptionService: transcriptionService,
            historyService: historyService,
            settings: settings
        )

        let delegate = MockRecordingCoordinatorDelegate()
        coordinator.delegate = delegate

        return (coordinator, audioRecorder, transcriptionService, historyService, settings, delegate)
    }

    // MARK: - Initial State

    @Test func initialStateIsIdle() {
        let (coordinator, _, _, _, _, _) = createCoordinator()
        #expect(coordinator.state == .idle)
    }

    // MARK: - Toggle Recording

    @Test func toggleRecordingFromIdleStartsRecording() {
        let (coordinator, audioRecorder, _, _, _, delegate) = createCoordinator()

        coordinator.toggleRecording(mode: .local)

        #expect(coordinator.state == .recording)
        #expect(audioRecorder.startRecordingCallCount == 1)
        #expect(delegate.recordingDidStartCallCount == 1)
    }

    @Test func toggleRecordingWhileRecordingStopsRecording() async throws {
        let (coordinator, audioRecorder, transcriptionService, _, _, delegate) = createCoordinator()

        // Start recording
        coordinator.toggleRecording(mode: .local)
        #expect(coordinator.state == .recording)

        // Stop recording
        coordinator.toggleRecording(mode: .local)

        #expect(audioRecorder.stopRecordingCallCount == 1)
        #expect(delegate.recordingDidStopCallCount == 1)
        #expect(delegate.transcriptionDidStartCallCount == 1)

        // Wait for async transcription
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(coordinator.state == .idle)
        #expect(transcriptionService.transcribeCallCount == 1)
        #expect(delegate.transcriptionDidCompleteCallCount == 1)
        #expect(delegate.lastCompletedText == "Test transcription")
    }

    @Test func toggleRecordingWhileTranscribingDoesNothing() async throws {
        let (coordinator, audioRecorder, transcriptionService, _, _, _) = createCoordinator()
        transcriptionService.transcriptionDelay = 0.5

        // Start and stop recording to begin transcription
        coordinator.toggleRecording(mode: .local)
        coordinator.toggleRecording(mode: .local)

        #expect(coordinator.state == .transcribing)

        // Try to toggle again while transcribing
        coordinator.toggleRecording(mode: .local)

        // Should still be transcribing, not start new recording
        #expect(coordinator.state == .transcribing)
        #expect(audioRecorder.startRecordingCallCount == 1)
    }

    // MARK: - Cancel Recording

    @Test func cancelRecordingStopsWithoutTranscription() {
        let (coordinator, audioRecorder, transcriptionService, _, _, _) = createCoordinator()

        coordinator.toggleRecording(mode: .local)
        #expect(coordinator.state == .recording)

        coordinator.cancelRecording()

        #expect(coordinator.state == .idle)
        #expect(audioRecorder.stopRecordingCallCount == 1)
        #expect(transcriptionService.transcribeCallCount == 0)
    }

    @Test func cancelRecordingWhenIdleDoesNothing() {
        let (coordinator, audioRecorder, _, _, _, _) = createCoordinator()

        coordinator.cancelRecording()

        #expect(coordinator.state == .idle)
        #expect(audioRecorder.stopRecordingCallCount == 0)
    }

    // MARK: - Transcription

    @Test func successfulTranscriptionSavesToHistory() async throws {
        let (coordinator, _, transcriptionService, historyService, settings, delegate) = createCoordinator()
        transcriptionService.transcriptionResult = .success("Hello world")
        settings.language = "en"

        coordinator.toggleRecording(mode: .local)
        coordinator.toggleRecording(mode: .local)

        // Wait for async transcription
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(historyService.saveCallCount == 1)
        #expect(historyService.records.count == 1)
        #expect(historyService.records.first?.text == "Hello world")
        #expect(historyService.records.first?.language == "en")
        #expect(delegate.transcriptionDidCompleteCallCount == 1)
    }

    @Test func failedTranscriptionCallsDelegateWithError() async throws {
        let (coordinator, _, transcriptionService, historyService, _, delegate) = createCoordinator()

        struct TestError: Error {}
        transcriptionService.transcriptionResult = .failure(TestError())

        coordinator.toggleRecording(mode: .local)
        coordinator.toggleRecording(mode: .local)

        // Wait for async transcription
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(coordinator.state == .idle)
        #expect(historyService.saveCallCount == 0)
        #expect(delegate.transcriptionDidFailCallCount == 1)
        #expect(delegate.lastError != nil)
    }

    // MARK: - Daemon Control

    @Test func startDaemonIfNeededStartsWhenEnabled() {
        let (coordinator, _, transcriptionService, _, settings, _) = createCoordinator()
        settings.keepDaemonRunning = true

        coordinator.startDaemonIfNeeded()

        #expect(transcriptionService.startDaemonCallCount == 1)
    }

    @Test func startDaemonIfNeededDoesNothingWhenDisabled() {
        let (coordinator, _, transcriptionService, _, settings, _) = createCoordinator()
        settings.keepDaemonRunning = false

        coordinator.startDaemonIfNeeded()

        #expect(transcriptionService.startDaemonCallCount == 0)
    }

    @Test func setDaemonEnabledStartsOrStopsDaemon() {
        let (coordinator, _, transcriptionService, _, _, _) = createCoordinator()

        coordinator.setDaemonEnabled(true)
        #expect(transcriptionService.startDaemonCallCount == 1)

        coordinator.setDaemonEnabled(false)
        #expect(transcriptionService.stopDaemonCallCount == 1)
    }

    // MARK: - Voice Activity Detection

    @Test func noVoiceActivitySkipsTranscription() {
        let (coordinator, audioRecorder, transcriptionService, _, _, delegate) = createCoordinator()
        audioRecorder.hadVoiceActivity = false

        coordinator.toggleRecording(mode: .local)
        coordinator.toggleRecording(mode: .local)

        #expect(coordinator.state == .idle)
        #expect(transcriptionService.transcribeCallCount == 0)
        #expect(delegate.recordingDidStopWithoutVoiceCallCount == 1)
    }

    // MARK: - Cancel Transcription

    @Test func cancelTranscriptionDuringTranscribing() async throws {
        let (coordinator, _, transcriptionService, _, _, delegate) = createCoordinator()
        transcriptionService.transcriptionDelay = 1.0 // Long delay

        coordinator.toggleRecording(mode: .local)
        coordinator.toggleRecording(mode: .local)

        #expect(coordinator.state == .transcribing)

        coordinator.cancelTranscription()

        #expect(coordinator.state == .idle)
        #expect(delegate.transcriptionDidCancelCallCount == 1)
    }

    @Test func cancelTranscriptionWhenIdleDoesNothing() {
        let (coordinator, _, _, _, _, delegate) = createCoordinator()

        coordinator.cancelTranscription()

        #expect(coordinator.state == .idle)
        #expect(delegate.transcriptionDidCancelCallCount == 0)
    }

    // MARK: - Audio File Cleanup Tests

    @Test func successfulTranscriptionDeletesAudioFile() async throws {
        let (coordinator, audioRecorder, _, _, _, _) = createCoordinator()
        let audioURL = audioRecorder.createRealTempFile()

        #expect(FileManager.default.fileExists(atPath: audioURL.path))

        coordinator.toggleRecording(mode: .local)
        coordinator.toggleRecording(mode: .local)

        // Wait for async transcription
        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(!FileManager.default.fileExists(atPath: audioURL.path))
    }

    @Test func failedTranscriptionDeletesAudioFile() async throws {
        let (coordinator, audioRecorder, transcriptionService, _, _, _) = createCoordinator()
        let audioURL = audioRecorder.createRealTempFile()

        struct TestError: Error {}
        transcriptionService.transcriptionResult = .failure(TestError())

        #expect(FileManager.default.fileExists(atPath: audioURL.path))

        coordinator.toggleRecording(mode: .local)
        coordinator.toggleRecording(mode: .local)

        // Wait for async transcription
        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(!FileManager.default.fileExists(atPath: audioURL.path))
    }

    @Test func noVoiceActivityDeletesAudioFile() {
        let (coordinator, audioRecorder, _, _, _, _) = createCoordinator()
        let audioURL = audioRecorder.createRealTempFile()
        audioRecorder.hadVoiceActivity = false

        #expect(FileManager.default.fileExists(atPath: audioURL.path))

        coordinator.toggleRecording(mode: .local)
        coordinator.toggleRecording(mode: .local)

        #expect(!FileManager.default.fileExists(atPath: audioURL.path))
    }

    @Test func cancelRecordingDeletesAudioFile() {
        let (coordinator, audioRecorder, _, _, _, _) = createCoordinator()
        let audioURL = audioRecorder.createRealTempFile()

        #expect(FileManager.default.fileExists(atPath: audioURL.path))

        coordinator.toggleRecording(mode: .local)
        coordinator.cancelRecording()

        #expect(!FileManager.default.fileExists(atPath: audioURL.path))
    }

    @Test func cancelTranscriptionDeletesAudioFile() async throws {
        let (coordinator, audioRecorder, transcriptionService, _, _, _) = createCoordinator()
        let audioURL = audioRecorder.createRealTempFile()
        transcriptionService.transcriptionDelay = 1.0

        #expect(FileManager.default.fileExists(atPath: audioURL.path))

        coordinator.toggleRecording(mode: .local)
        coordinator.toggleRecording(mode: .local)

        #expect(coordinator.state == .transcribing)

        coordinator.cancelTranscription()

        #expect(!FileManager.default.fileExists(atPath: audioURL.path))
    }
}
