//
//  RecordingCoordinator.swift
//  Murmurix
//

import Foundation

enum RecordingState: Equatable {
    case idle
    case recording
    case transcribing
    case processing  // AI post-processing
}

protocol RecordingCoordinatorDelegate: AnyObject {
    func recordingDidStart()
    func recordingDidStop()
    func recordingDidStopWithoutVoice()
    func transcriptionDidStart()
    func processingDidStart()  // AI post-processing started
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
    private var skipAIForCurrentRecording: Bool = false

    private let audioRecorder: AudioRecorderProtocol
    private let transcriptionService: TranscriptionServiceProtocol
    private let historyService: HistoryServiceProtocol
    private let settings: SettingsStorageProtocol
    private let aiService: AIPostProcessingServiceProtocol

    init(
        audioRecorder: AudioRecorderProtocol,
        transcriptionService: TranscriptionServiceProtocol,
        historyService: HistoryServiceProtocol,
        settings: SettingsStorageProtocol,
        aiService: AIPostProcessingServiceProtocol = AIPostProcessingService()
    ) {
        self.audioRecorder = audioRecorder
        self.transcriptionService = transcriptionService
        self.historyService = historyService
        self.settings = settings
        self.aiService = aiService
    }

    // MARK: - Recording Control

    func toggleRecording(skipAI: Bool = false) {
        switch state {
        case .idle:
            skipAIForCurrentRecording = skipAI
            startRecording()
        case .recording:
            stopRecording()
        case .transcribing, .processing:
            break // Ignore while transcribing or processing
        }
    }

    func cancelRecording() {
        guard state == .recording else { return }

        _ = audioRecorder.stopRecording()
        state = .idle
        recordingStartTime = nil
    }

    func cancelTranscription() {
        guard state == .transcribing || state == .processing else { return }

        transcriptionTask?.cancel()
        transcriptionTask = nil

        // Clean up audio file
        if let audioURL = currentAudioURL {
            // try? FileManager.default.removeItem(at: audioURL)  // DEBUG: keep audio files
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
            // try? FileManager.default.removeItem(at: audioURL)  // DEBUG: keep audio files
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
        let aiEnabled = settings.aiPostProcessingEnabled && !skipAIForCurrentRecording
        let aiProcessor = aiService

        transcriptionTask = Task.detached { [weak self] in
            guard let self = self else { return }

            do {
                // Compress WAV to M4A for efficient storage/transfer
                let compressedURL = try? await AudioCompressor.compress(wavURL: audioURL, deleteOriginal: false)
                if let compressedURL = compressedURL {
                    Logger.Audio.info("Compressed audio saved: \(compressedURL.lastPathComponent)")
                }

                // For cloud mode use compressed M4A (faster upload), for local use WAV
                let transcriptionURL: URL
                if self.settings.transcriptionMode == "cloud", let compressed = compressedURL {
                    transcriptionURL = compressed
                    Logger.Transcription.info("Using M4A for cloud transcription")
                } else {
                    transcriptionURL = audioURL
                }

                let transcribedText = try await service.transcribe(audioURL: transcriptionURL, useDaemon: useDaemon)

                // Check if cancelled
                if Task.isCancelled { return }

                // AI Post-processing if enabled
                var finalText = transcribedText
                if aiEnabled {
                    await MainActor.run {
                        self.state = .processing
                        self.delegate?.processingDidStart()
                    }

                    if Task.isCancelled { return }

                    do {
                        finalText = try await aiProcessor.process(text: transcribedText)
                    } catch {
                        // Log error but continue with original text
                        Logger.AI.error("Post-processing failed: \(error.localizedDescription)")
                    }

                    if Task.isCancelled { return }
                }

                let resultText = finalText
                await MainActor.run {
                    self.state = .idle
                    self.currentAudioURL = nil
                    self.transcriptionTask = nil

                    // Save to history
                    let record = TranscriptionRecord(
                        text: resultText,
                        language: language,
                        duration: duration
                    )
                    self.historyService.save(record: record)

                    // Delete audio file
                    // try? FileManager.default.removeItem(at: audioURL)  // DEBUG: keep audio files

                    self.delegate?.transcriptionDidComplete(text: resultText, duration: duration, recordId: record.id)
                }
            } catch {
                // Check if cancelled
                if Task.isCancelled { return }

                await MainActor.run {
                    self.state = .idle
                    self.currentAudioURL = nil
                    self.transcriptionTask = nil

                    // Delete audio file even on error
                    // try? FileManager.default.removeItem(at: audioURL)  // DEBUG: keep audio files

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
