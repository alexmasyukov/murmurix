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
        executeTransition(
            RecordingFlowReducer.reduce(
                state: state,
                event: .toggle(mode: mode)
            )
        )
    }

    func cancelRecording() {
        executeTransition(
            RecordingFlowReducer.reduce(
                state: state,
                event: .cancelRecording
            )
        )
    }

    func cancelTranscription() {
        executeTransition(
            RecordingFlowReducer.reduce(
                state: state,
                event: .cancelTranscription
            )
        )
    }

    private func executeTransition(_ transition: RecordingFlowTransition) {
        switch transition {
        case .startRecording(let selectedMode):
            currentTranscriptionMode = selectedMode
            startRecording()
        case .stopRecording:
            stopRecording()
        case .cancelRecording:
            cancelActiveRecording()
        case .cancelTranscription:
            cancelActiveTranscription()
        case .ignore:
            break
        }
    }

    private func cancelActiveRecording() {
        let audioURL = audioRecorder.stopRecording()
        removeFileIfExists(audioURL, context: "cancel recording")
        state = .idle
        recordingStartTime = nil
    }

    private func cancelActiveTranscription() {
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
                let transcriptionURL = await self.transcriptionInputURL(audioURL: audioURL, mode: mode)

                let transcribedText = try await service.transcribe(
                    audioURL: transcriptionURL,
                    language: language,
                    mode: mode
                )

                if Task.isCancelled { return }
                self.completeTranscriptionSuccess(
                    text: transcribedText,
                    language: language,
                    duration: duration,
                    sourceAudioURL: audioURL
                )
            } catch {
                if Task.isCancelled { return }
                self.completeTranscriptionFailure(error, sourceAudioURL: audioURL)
            }
        }
    }

    // MARK: - Model Control

    func loadModelsIfNeeded() {
        let modelSettings = settings.loadWhisperModelSettings()
        for (modelName, ms) in modelSettings where ms.keepLoaded {
            Task {
                await self.loadModelWithLogging(name: modelName, action: "load")
            }
        }
    }

    func unloadAllModels() {
        Task { await transcriptionService.unloadAllModels() }
    }

    func setModelLoaded(_ enabled: Bool, model: String) {
        if enabled {
            Task {
                await self.loadModelWithLogging(name: model, action: "load")
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
                await self.loadModelWithLogging(name: name, action: "reload")
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

    private func transcriptionInputURL(audioURL: URL, mode: TranscriptionMode) async -> URL {
        guard mode.isCloud else { return audioURL }

        do {
            let compressedURL = try await AudioCompressor.compress(wavURL: audioURL, deleteOriginal: false)
            currentCompressedAudioURL = compressedURL
            Logger.Transcription.info("Using M4A for cloud transcription (\(mode.logName))")
            return compressedURL
        } catch {
            Logger.Transcription.error("Audio compression failed, fallback to WAV: \(error.localizedDescription)")
            return audioURL
        }
    }

    private func completeTranscriptionSuccess(
        text: String,
        language: String,
        duration: TimeInterval,
        sourceAudioURL: URL
    ) {
        resetTranscriptionState()

        let record = TranscriptionRecord(
            text: text,
            language: language,
            duration: duration
        )
        historyService.save(record: record)

        cleanupTranscriptionFiles(audioURL: sourceAudioURL, phase: "successful transcription")
        delegate?.transcriptionDidComplete(text: text, duration: duration, recordId: record.id)
    }

    private func completeTranscriptionFailure(_ error: Error, sourceAudioURL: URL) {
        resetTranscriptionState()
        cleanupTranscriptionFiles(audioURL: sourceAudioURL, phase: "failed transcription")
        delegate?.transcriptionDidFail(error: error)
    }

    private func loadModelWithLogging(name: String, action: String) async {
        do {
            try await transcriptionService.loadModel(name: name)
        } catch {
            Logger.Model.error("Failed to \(action) model \(name): \(error.localizedDescription)")
        }
    }
}
