//
//  RecordingCoordinator.swift
//  Murmurix
//

import Foundation

enum RecordingState: Equatable {
    case idle
    case recording
    case transcribing
}

protocol RecordingCoordinatorDelegate: AnyObject {
    func recordingDidStart()
    func recordingDidStop()
    func transcriptionDidStart()
    func transcriptionDidComplete(text: String, duration: TimeInterval, recordId: UUID)
    func transcriptionDidFail(error: Error)
}

final class RecordingCoordinator {
    weak var delegate: RecordingCoordinatorDelegate?

    private(set) var state: RecordingState = .idle
    private var recordingStartTime: Date?

    private let audioRecorder: AudioRecorderProtocol
    private let transcriptionService: TranscriptionServiceProtocol
    private let historyService: HistoryServiceProtocol
    private let settings: SettingsStorageProtocol

    init(
        audioRecorder: AudioRecorderProtocol,
        transcriptionService: TranscriptionServiceProtocol,
        historyService: HistoryServiceProtocol,
        settings: SettingsStorageProtocol
    ) {
        self.audioRecorder = audioRecorder
        self.transcriptionService = transcriptionService
        self.historyService = historyService
        self.settings = settings
    }

    // MARK: - Recording Control

    func toggleRecording() {
        switch state {
        case .idle:
            startRecording()
        case .recording:
            stopRecording()
        case .transcribing:
            break // Ignore while transcribing
        }
    }

    func cancelRecording() {
        guard state == .recording else { return }

        _ = audioRecorder.stopRecording()
        state = .idle
        recordingStartTime = nil
    }

    private func startRecording() {
        state = .recording
        recordingStartTime = Date()
        audioRecorder.startRecording()
        delegate?.recordingDidStart()
    }

    private func stopRecording() {
        guard state == .recording else { return }

        state = .transcribing
        let audioURL = audioRecorder.stopRecording()
        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())

        delegate?.recordingDidStop()
        delegate?.transcriptionDidStart()

        performTranscription(audioURL: audioURL, duration: duration)
    }

    private func performTranscription(audioURL: URL, duration: TimeInterval) {
        let service = transcriptionService
        let useDaemon = settings.keepDaemonRunning
        let language = settings.language

        Task.detached { [weak self] in
            guard let self = self else { return }

            do {
                let text = try await service.transcribe(audioURL: audioURL, useDaemon: useDaemon)

                await MainActor.run {
                    self.state = .idle

                    // Save to history
                    let record = TranscriptionRecord(
                        text: text,
                        language: language,
                        duration: duration
                    )
                    self.historyService.save(record: record)

                    // Delete audio file
                    try? FileManager.default.removeItem(at: audioURL)

                    self.delegate?.transcriptionDidComplete(text: text, duration: duration, recordId: record.id)
                }
            } catch {
                await MainActor.run {
                    self.state = .idle

                    // Delete audio file even on error
                    try? FileManager.default.removeItem(at: audioURL)

                    self.delegate?.transcriptionDidFail(error: error)
                }
            }
        }
    }

    // MARK: - Daemon Control

    func startDaemonIfNeeded() {
        if settings.keepDaemonRunning {
            transcriptionService.startDaemon()
        }
    }

    func stopDaemon() {
        transcriptionService.stopDaemon()
    }

    func setDaemonEnabled(_ enabled: Bool) {
        if enabled {
            transcriptionService.startDaemon()
        } else {
            transcriptionService.stopDaemon()
        }
    }
}
