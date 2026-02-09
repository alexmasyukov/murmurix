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

enum TranscriptionMode: Equatable {
    case local(model: String)
    case openai
    case gemini

    var displayName: String {
        switch self {
        case .local(let model): return "Local (\(model))"
        case .openai: return "Cloud (OpenAI)"
        case .gemini: return "Cloud (Gemini)"
        }
    }

    var isCloud: Bool {
        switch self {
        case .local: return false
        case .openai, .gemini: return true
        }
    }

    var logName: String {
        switch self {
        case .local(let model): return "local:\(model)"
        case .openai: return "openai"
        case .gemini: return "gemini"
        }
    }
}

@MainActor
protocol RecordingCoordinatorDelegate: AnyObject {
    func recordingDidStart()
    func recordingDidStop()
    func recordingDidStopWithoutVoice()
    func transcriptionDidStart()
    func transcriptionDidComplete(text: String, duration: TimeInterval, recordId: UUID)
    func transcriptionDidFail(error: Error)
    func transcriptionDidCancel()
}

@MainActor
final class RecordingCoordinator {
    weak var delegate: RecordingCoordinatorDelegate?

    private(set) var state: RecordingState = .idle
    private var recordingStartTime: Date?
    private var transcriptionTask: Task<Void, Never>?
    private var currentAudioURL: URL?
    private var currentCompressedAudioURL: URL?
    private var currentTranscriptionMode: TranscriptionMode = .local(model: "small")

    private let audioRecorder: AudioRecorderProtocol
    private let transcriptionService: TranscriptionServiceProtocol
    private let historyService: HistoryServiceProtocol
    private let settings: SettingsStorageProtocol

    private enum ToggleTransition {
        case startRecording(mode: TranscriptionMode)
        case stopRecording
        case ignore
    }

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
        switch Self.reduceToggleTransition(from: state, mode: mode) {
        case .startRecording(let selectedMode):
            currentTranscriptionMode = selectedMode
            startRecording()
        case .stopRecording:
            stopRecording()
        case .ignore:
            break
        }
    }

    func cancelRecording() {
        guard state == .recording else { return }

        let audioURL = audioRecorder.stopRecording()
        removeFileIfExists(audioURL, context: "cancel recording")
        state = .idle
        recordingStartTime = nil
    }

    func cancelTranscription() {
        guard state == .transcribing else { return }

        transcriptionTask?.cancel()
        transcriptionTask = nil

        // Clean up audio file
        if let audioURL = currentAudioURL {
            removeFileIfExists(audioURL, context: "cancel transcription")
            currentAudioURL = nil
        }
        if let compressedURL = currentCompressedAudioURL {
            removeFileIfExists(compressedURL, context: "cancel transcription (compressed)")
            currentCompressedAudioURL = nil
        }

        state = .idle
        delegate?.transcriptionDidCancel()
    }

    private func startRecording() {
        state = .recording
        recordingStartTime = Date()
        audioRecorder.startRecording()
        Logger.Transcription.info("Recording started, mode: \(currentTranscriptionMode.logName)")
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
            removeFileIfExists(audioURL, context: "no voice activity")
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
        currentCompressedAudioURL = nil
        let service = transcriptionService
        let language = settings.language
        let mode = currentTranscriptionMode

        Logger.Transcription.info("Starting transcription, mode: \(mode.logName), language: \(language), duration: \(String(format: "%.1f", duration))s")

        transcriptionTask = Task { [weak self] in
            guard let self = self else { return }

            do {
                // For cloud mode, compress WAV to M4A for faster upload
                let transcriptionURL: URL

                if mode.isCloud {
                    let compressedURL: URL?
                    do {
                        compressedURL = try await AudioCompressor.compress(wavURL: audioURL, deleteOriginal: false)
                    } catch {
                        Logger.Transcription.error("Audio compression failed, fallback to WAV: \(error.localizedDescription)")
                        compressedURL = nil
                    }

                    if let compressed = compressedURL {
                        self.currentCompressedAudioURL = compressed
                        transcriptionURL = compressed
                        Logger.Transcription.info("Using M4A for cloud transcription (\(mode.logName))")
                    } else {
                        transcriptionURL = audioURL
                    }
                } else {
                    transcriptionURL = audioURL
                }

                let transcribedText = try await service.transcribe(
                    audioURL: transcriptionURL,
                    language: language,
                    mode: mode
                )

                // Check if cancelled
                if Task.isCancelled { return }

                self.resetTranscriptionState()

                // Save to history
                let record = TranscriptionRecord(
                    text: transcribedText,
                    language: language,
                    duration: duration
                )
                self.historyService.save(record: record)

                // Delete audio files
                self.cleanupTranscriptionFiles(audioURL: audioURL, phase: "successful transcription")

                self.delegate?.transcriptionDidComplete(text: transcribedText, duration: duration, recordId: record.id)
            } catch {
                // Check if cancelled
                if Task.isCancelled { return }

                self.resetTranscriptionState()

                // Delete audio files even on error
                self.cleanupTranscriptionFiles(audioURL: audioURL, phase: "failed transcription")

                self.delegate?.transcriptionDidFail(error: error)
            }
        }
    }

    // MARK: - Model Control

    func loadModelsIfNeeded() {
        let modelSettings = settings.loadWhisperModelSettings()
        for (modelName, ms) in modelSettings where ms.keepLoaded {
            Task {
                do {
                    try await transcriptionService.loadModel(name: modelName)
                } catch {
                    Logger.Model.error("Failed to load model \(modelName): \(error.localizedDescription)")
                }
            }
        }
    }

    func unloadAllModels() {
        Task { await transcriptionService.unloadAllModels() }
    }

    func setModelLoaded(_ enabled: Bool, model: String) {
        if enabled {
            Task {
                do {
                    try await transcriptionService.loadModel(name: model)
                } catch {
                    Logger.Model.error("Failed to load model \(model): \(error.localizedDescription)")
                }
            }
        } else {
            Task { await transcriptionService.unloadModel(name: model) }
        }
    }

    func reloadModel(name: String) {
        Task {
            await transcriptionService.unloadModel(name: name)
            let modelSettings = settings.loadWhisperModelSettings()
            if modelSettings[name]?.keepLoaded == true {
                do {
                    try await transcriptionService.loadModel(name: name)
                } catch {
                    Logger.Model.error("Failed to reload model \(name): \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - File Cleanup

    private func removeFileIfExists(_ url: URL, context: String) {
        guard !url.path.isEmpty else { return }
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return }

        do {
            try fileManager.removeItem(at: url)
        } catch {
            Logger.Transcription.error("Failed to remove file (\(context)): \(url.path), error: \(error.localizedDescription)")
        }
    }

    private static func reduceToggleTransition(from state: RecordingState, mode: TranscriptionMode) -> ToggleTransition {
        switch state {
        case .idle:
            return .startRecording(mode: mode)
        case .recording:
            return .stopRecording
        case .transcribing:
            return .ignore
        }
    }

    private func resetTranscriptionState() {
        state = .idle
        currentAudioURL = nil
        transcriptionTask = nil
    }

    private func cleanupTranscriptionFiles(audioURL: URL, phase: String) {
        removeFileIfExists(audioURL, context: phase)
        if let compressedURL = currentCompressedAudioURL {
            removeFileIfExists(compressedURL, context: "\(phase) (compressed)")
        }
        currentCompressedAudioURL = nil
    }
}
