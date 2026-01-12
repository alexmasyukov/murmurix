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
    func recordingDidStopWithoutVoice()
    func transcriptionDidStart()
    func transcriptionDidComplete(text: String, duration: TimeInterval, recordId: UUID)
    func transcriptionDidFail(error: Error)
    func transcriptionDidCancel()
}

final class RecordingCoordinator {
    weak var delegate: RecordingCoordinatorDelegate?

    private(set) var state: RecordingState = .idle
    private var recordingStartTime: Date?
    private var transcriptionTask: Task<Void, Never>?
    private var currentAudioURL: URL?

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

    func cancelTranscription() {
        guard state == .transcribing else { return }

        transcriptionTask?.cancel()
        transcriptionTask = nil

        // Clean up audio file
        if let audioURL = currentAudioURL {
            try? FileManager.default.removeItem(at: audioURL)
            currentAudioURL = nil
        }

        state = .idle
        delegate?.transcriptionDidCancel()
    }

    private func startRecording() {
        state = .recording
        recordingStartTime = Date()
        audioRecorder.startRecording()
        delegate?.recordingDidStart()
    }

    private func stopRecording() {
        guard state == .recording else { return }

        let hadVoice = audioRecorder.hadVoiceActivity
        let audioURL = audioRecorder.stopRecording()
        let duration = Date().timeIntervalSince(recordingStartTime ?? Date())

        delegate?.recordingDidStop()

        // Skip transcription if no voice was detected (prevents Whisper hallucinations)
        guard hadVoice else {
            state = .idle
            try? FileManager.default.removeItem(at: audioURL)
            Logger.Transcription.info("No voice activity detected, skipping transcription")
            delegate?.recordingDidStopWithoutVoice()
            return
        }

        state = .transcribing
        delegate?.transcriptionDidStart()

        performTranscription(audioURL: audioURL, duration: duration)
    }

    private func performTranscription(audioURL: URL, duration: TimeInterval) {
        currentAudioURL = audioURL
        let service = transcriptionService
        let useDaemon = settings.keepDaemonRunning
        let language = settings.language

        transcriptionTask = Task.detached { [weak self] in
            guard let self = self else { return }

            do {
                // For cloud mode, compress WAV to M4A for faster upload
                let transcriptionURL: URL
                var compressedURL: URL?

                if self.settings.transcriptionMode == "cloud" {
                    compressedURL = try? await AudioCompressor.compress(wavURL: audioURL, deleteOriginal: false)
                    if let compressed = compressedURL {
                        transcriptionURL = compressed
                        Logger.Transcription.info("Using M4A for cloud transcription")
                    } else {
                        transcriptionURL = audioURL
                    }
                } else {
                    transcriptionURL = audioURL
                }

                let transcribedText = try await service.transcribe(audioURL: transcriptionURL, useDaemon: useDaemon)

                // Check if cancelled
                if Task.isCancelled { return }

                await MainActor.run {
                    self.state = .idle
                    self.currentAudioURL = nil
                    self.transcriptionTask = nil

                    // Save to history
                    let record = TranscriptionRecord(
                        text: transcribedText,
                        language: language,
                        duration: duration
                    )
                    self.historyService.save(record: record)

                    // Delete audio files
                    try? FileManager.default.removeItem(at: audioURL)
                    if let compressed = compressedURL {
                        try? FileManager.default.removeItem(at: compressed)
                    }

                    self.delegate?.transcriptionDidComplete(text: transcribedText, duration: duration, recordId: record.id)
                }
            } catch {
                // Check if cancelled
                if Task.isCancelled { return }

                await MainActor.run {
                    self.state = .idle
                    self.currentAudioURL = nil
                    self.transcriptionTask = nil

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

    func restartDaemon() {
        transcriptionService.stopDaemon()
        // Wait a bit for cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.transcriptionService.startDaemon()
        }
    }
}
