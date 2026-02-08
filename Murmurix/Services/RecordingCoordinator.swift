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

enum TranscriptionMode: String, CaseIterable {
    case local   // Whisper (local)
    case openai  // OpenAI Cloud API (renamed from cloud)
    case gemini  // Google Gemini API (new)

    var displayName: String {
        switch self {
        case .local: return "Local (Whisper)"
        case .openai: return "Cloud (OpenAI)"
        case .gemini: return "Cloud (Gemini)"
        }
    }

    /// Is cloud mode (requires audio compression)
    var isCloud: Bool {
        self != .local
    }
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
    private var currentTranscriptionMode: TranscriptionMode = .local

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

    func toggleRecording(mode: TranscriptionMode) {
        switch state {
        case .idle:
            currentTranscriptionMode = mode
            startRecording()
        case .recording:
            stopRecording()
        case .transcribing:
            break // Ignore while transcribing
        }
    }

    func cancelRecording() {
        guard state == .recording else { return }

        let audioURL = audioRecorder.stopRecording()
        try? FileManager.default.removeItem(at: audioURL)
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
        Logger.Transcription.info("Recording started, mode: \(currentTranscriptionMode.rawValue)")
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
        let language = settings.language
        let mode = currentTranscriptionMode

        Logger.Transcription.info("Starting transcription, mode: \(mode.rawValue), language: \(language), duration: \(String(format: "%.1f", duration))s")

        transcriptionTask = Task.detached { [weak self] in
            guard let self = self else { return }

            do {
                // For cloud mode, compress WAV to M4A for faster upload
                let transcriptionURL: URL
                var compressedURL: URL?

                if mode.isCloud {
                    compressedURL = try? await AudioCompressor.compress(wavURL: audioURL, deleteOriginal: false)
                    if let compressed = compressedURL {
                        transcriptionURL = compressed
                        Logger.Transcription.info("Using M4A for cloud transcription (\(mode.rawValue))")
                    } else {
                        transcriptionURL = audioURL
                    }
                } else {
                    transcriptionURL = audioURL
                }

                let transcribedText = try await service.transcribe(audioURL: transcriptionURL, mode: mode)

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

    // MARK: - Model Control

    func loadModelIfNeeded() {
        if settings.keepModelLoaded {
            Task { try? await transcriptionService.loadModel() }
        }
    }

    func unloadModel() {
        Task { await transcriptionService.unloadModel() }
    }

    func setModelLoaded(_ enabled: Bool) {
        if enabled {
            Task { try? await transcriptionService.loadModel() }
        } else {
            Task { await transcriptionService.unloadModel() }
        }
    }

    func reloadModel() {
        Task {
            await transcriptionService.unloadModel()
            if settings.keepModelLoaded {
                try? await transcriptionService.loadModel()
            }
        }
    }
}
