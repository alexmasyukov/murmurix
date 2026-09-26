//
//  GeneralSettingsViewModel.swift
//  Murmurix
//

import Foundation
import Combine

enum DownloadStatus {
    case idle
    case downloading(progress: Double)
    case compiling
    case completed
    case error(String)
}

enum TestService {
    case local(String)
    case openAI
    case gemini
}

/// What the "Test" flow for a local model is doing right now. The heavy step is
/// the CoreML load/compile (tens of seconds to minutes on a cold ANE), and with
/// only a spinner the user has no idea what the app is waiting for.
enum ModelTestPhase: Equatable {
    case loadingModel(since: Date)
    case transcribing(since: Date)
}

/// Where a model actually is with respect to memory — read from the service, not
/// guessed from timers.
enum ModelMemoryState: Equatable {
    case loaded
    case loading
    case notLoaded
}

@MainActor
final class GeneralSettingsViewModel: ObservableObject {
    @Published var installedModels: Set<String> = []
    @Published var downloadStatuses: [String: DownloadStatus] = [:]

    // Test state
    @Published var isTestingOpenAI = false
    @Published var isTestingGemini = false
    @Published var localTestResults: [String: APITestResult] = [:]
    @Published var testingModels: Set<String> = []
    @Published var testPhases: [String: ModelTestPhase] = [:]

    /// Real memory state per model, refreshed by `refreshModelMemoryStates()` and the
    /// polling task while the settings UI is visible. Replaces the old fake indicator
    /// that turned green on a 1s timer regardless of the actual CoreML load.
    @Published var modelMemoryStates: [String: ModelMemoryState] = [:]
    @Published var openaiTestResult: APITestResult?
    @Published var geminiTestResult: APITestResult?

    @Published var modelSettingsMap: [String: WhisperModelSettings] = [:]

    var onLocalHotkeysChanged: (([String: Hotkey]) -> Void)?

    private let whisperKitService: WhisperKitServiceProtocol
    private let openAIService: OpenAITranscriptionServiceProtocol
    private let geminiService: GeminiTranscriptionServiceProtocol
    private let transcriptionServiceFactory: () -> TranscriptionServiceProtocol
    private let modelDirectory: (String) -> URL
    private let modelsRepositoryDirectory: () -> URL
    private let completedStatusResetDelay: TimeInterval = 2
    private let modelLoadTimeout: TimeInterval
    private let modelOperationTimeout: TimeInterval
    private var statusResetTasks: [String: Task<Void, Never>] = [:]
    private var memoryStatePollTask: Task<Void, Never>?
    let settings: SettingsStorageProtocol

    static func live(
        settings: SettingsStorageProtocol,
        whisperKitService: WhisperKitServiceProtocol,
        openAIService: OpenAITranscriptionServiceProtocol,
        geminiService: GeminiTranscriptionServiceProtocol
    ) -> GeneralSettingsViewModel {
        GeneralSettingsViewModel(
            whisperKitService: whisperKitService,
            openAIService: openAIService,
            geminiService: geminiService,
            transcriptionServiceFactory: {
                TranscriptionService.live(
                    settings: settings,
                    whisperKitService: whisperKitService,
                    openAIService: openAIService,
                    geminiService: geminiService
                )
            },
            modelDirectory: { ModelPaths.modelDir(for: $0) },
            modelsRepositoryDirectory: { ModelPaths.repoDir },
            modelLoadTimeout: 600,
            modelOperationTimeout: 30,
            settings: settings
        )
    }

    init(
        whisperKitService: WhisperKitServiceProtocol,
        openAIService: OpenAITranscriptionServiceProtocol,
        geminiService: GeminiTranscriptionServiceProtocol,
        transcriptionServiceFactory: @escaping () -> TranscriptionServiceProtocol,
        modelDirectory: @escaping (String) -> URL,
        modelsRepositoryDirectory: @escaping () -> URL,
        modelLoadTimeout: TimeInterval = 600,
        modelOperationTimeout: TimeInterval = 30,
        settings: SettingsStorageProtocol
    ) {
        self.whisperKitService = whisperKitService
        self.openAIService = openAIService
        self.geminiService = geminiService
        self.transcriptionServiceFactory = transcriptionServiceFactory
        self.modelDirectory = modelDirectory
        self.modelsRepositoryDirectory = modelsRepositoryDirectory
        self.modelLoadTimeout = modelLoadTimeout
        self.modelOperationTimeout = modelOperationTimeout
        self.settings = settings
    }

    func loadInstalledModels() {
        installedModels = Set(WhisperModel.allCases.filter { $0.isInstalled }.map { $0.rawValue })
        modelSettingsMap = settings.loadWhisperModelSettings()
        refreshModelMemoryStates()
    }

    // MARK: - Model Memory State

    func memoryState(for modelName: String) -> ModelMemoryState {
        modelMemoryStates[modelName] ?? .notLoaded
    }

    func refreshModelMemoryStates() {
        var states: [String: ModelMemoryState] = [:]
        for model in WhisperModel.allCases {
            let name = model.rawValue
            if whisperKitService.isModelLoaded(name: name) {
                states[name] = .loaded
            } else if whisperKitService.isModelLoading(name: name) {
                states[name] = .loading
            } else {
                states[name] = .notLoaded
            }
        }
        // Only publish on change — this runs on a 1s poll and would otherwise
        // re-render the settings UI every tick.
        if states != modelMemoryStates {
            modelMemoryStates = states
        }
    }

    /// Polls the service while the settings UI is on screen so "loading…" flips to
    /// "in memory" the moment the CoreML load actually finishes — loads run in
    /// background Tasks (keep-loaded prewarm at launch, toggle, test) and there is
    /// no completion signal wired to this view model.
    func startObservingModelMemoryStates() {
        refreshModelMemoryStates()
        guard memoryStatePollTask == nil else { return }
        memoryStatePollTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self else { return }
                self.refreshModelMemoryStates()
            }
        }
    }

    func stopObservingModelMemoryStates() {
        memoryStatePollTask?.cancel()
        memoryStatePollTask = nil
    }

    deinit {
        memoryStatePollTask?.cancel()
    }

    func isModelInstalled(_ modelName: String) -> Bool {
        installedModels.contains(modelName)
    }

    func modelSettings(for modelName: String) -> WhisperModelSettings {
        modelSettingsMap[modelName] ?? .default
    }

    func updateModelSettings(for modelName: String, _ update: (inout WhisperModelSettings) -> Void) {
        var ms = modelSettingsMap[modelName] ?? .default
        update(&ms)
        modelSettingsMap[modelName] = ms
        settings.saveWhisperModelSettings(modelSettingsMap)
        notifyHotkeysChanged()
    }

    func downloadStatus(for modelName: String) -> DownloadStatus {
        downloadStatuses[modelName] ?? .idle
    }

    func startDownload(for modelName: String) {
        cancelStatusReset(for: modelName)
        downloadStatuses[modelName] = .downloading(progress: 0)
        Logger.Model.info("UI requested model download: \(modelName)")
        Logger.Model.debug("UI model repository path: \(modelsRepositoryDirectory().path)")
        Logger.Model.debug("UI target model path: \(modelDirectory(modelName).path)")

        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.whisperKitService.downloadModel(modelName) { progress in
                    Logger.Model.debug("Download progress for \(modelName): \(Int(progress * 100))%")
                    Task { @MainActor [weak self] in
                        self?.downloadStatuses[modelName] = .downloading(progress: progress)
                    }
                }
                Logger.Model.info("Model download finished, starting compile/load: \(modelName)")
                self.downloadStatuses[modelName] = .compiling
                try await self.runModelOperationWithTimeout("load \(modelName)", timeout: self.modelLoadTimeout) {
                    try await self.whisperKitService.loadModel(name: modelName)
                }
                let ms = self.modelSettings(for: modelName)
                if !ms.keepLoaded {
                    Logger.Model.debug("Unloading model after compile because keepLoaded=false: \(modelName)")
                    await self.whisperKitService.unloadModel(name: modelName)
                }
                self.downloadStatuses[modelName] = .completed
                Logger.Model.info("Model download flow completed successfully: \(modelName)")
                self.loadInstalledModels()
                self.scheduleStatusReset(for: modelName)
            } catch {
                Logger.Model.error("Model download flow failed for \(modelName): \(error.localizedDescription)")
                self.downloadStatuses[modelName] = .error(error.localizedDescription)
            }
        }
    }

    func cancelDownload(for modelName: String) {
        cancelStatusReset(for: modelName)
        downloadStatuses[modelName] = .idle
    }

    private func scheduleStatusReset(for modelName: String) {
        cancelStatusReset(for: modelName)
        let delayNanoseconds = UInt64(completedStatusResetDelay * 1_000_000_000)

        statusResetTasks[modelName] = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
            } catch {
                return
            }

            guard let self = self, !Task.isCancelled else { return }
            defer { self.statusResetTasks[modelName] = nil }

            if case .completed = self.downloadStatuses[modelName] {
                self.downloadStatuses[modelName] = .idle
            }
        }
    }

    private func cancelStatusReset(for modelName: String) {
        statusResetTasks[modelName]?.cancel()
        statusResetTasks[modelName] = nil
    }

    // MARK: - Model Deletion

    func deleteModel(_ modelName: String) async {
        if whisperKitService.isModelLoaded(name: modelName) {
            await whisperKitService.unloadModel(name: modelName)
        }
        let modelDir = modelDirectory(modelName)
        removeItemIfExists(modelDir, context: "delete model \(modelName)")
        loadInstalledModels()
    }

    func deleteAllModels() async {
        await whisperKitService.unloadAllModels()
        let fm = FileManager.default
        let repoDir = modelsRepositoryDirectory()
        do {
            let contents = try fm.contentsOfDirectory(atPath: repoDir.path)
            for item in contents where item.hasPrefix("openai_whisper-") {
                removeItemIfExists(
                    repoDir.appendingPathComponent(item),
                    context: "delete all models (\(item))"
                )
            }
        } catch {
            Logger.Model.error("Failed to list model repository \(repoDir.path): \(error.localizedDescription)")
        }
        loadInstalledModels()
    }

    // MARK: - API Testing

    func testModel(_ modelName: String) async {
        testingModels.insert(modelName)
        localTestResults[modelName] = nil
        defer {
            testingModels.remove(modelName)
            testPhases[modelName] = nil
        }
        Logger.Model.info("Local model test requested: \(modelName)")
        Logger.Model.debug("Local model test path: \(modelDirectory(modelName).path)")

        guard isModelInstalled(modelName) else {
            Logger.Model.warning("Local model test aborted because model is not installed: \(modelName)")
            localTestResults[modelName] = .failure("Model not installed. Download it first.")
            return
        }

        do {
            let service = transcriptionServiceFactory()
            if !service.isModelLoaded(name: modelName) {
                Logger.Model.debug("Local model test needs to load model first: \(modelName)")
                testPhases[modelName] = .loadingModel(since: Date())
                try await runModelOperationWithTimeout("load \(modelName)", timeout: modelLoadTimeout) {
                    try await service.loadModel(name: modelName)
                }
                refreshModelMemoryStates()
            } else {
                Logger.Model.debug("Local model test using already loaded model: \(modelName)")
            }

            testPhases[modelName] = .transcribing(since: Date())
            let tempURL = AudioTestUtility.createTemporaryTestAudioURL()
            try AudioTestUtility.createSilentWavFile(at: tempURL, duration: 0.5)
            Logger.Model.debug("Local model test audio created at: \(tempURL.path)")
            defer { removeTransientAudioIfNeeded(tempURL) }

            _ = try await runModelOperationWithTimeout("test \(modelName)") {
                try await service.transcribe(
                    audioURL: tempURL,
                    language: self.settings.language,
                    mode: .local(model: modelName)
                )
            }

            Logger.Model.info("Local model test succeeded: \(modelName)")
            localTestResults[modelName] = .success
        } catch {
            Logger.Model.error("Local model test failed for \(modelName): \(error.localizedDescription)")
            localTestResults[modelName] = .failure(error.localizedDescription)
        }
    }

    func testOpenAI(apiKey: String) async {
        isTestingOpenAI = true
        openaiTestResult = nil

        do {
            let isValid = try await openAIService.validateAPIKey(apiKey)
            openaiTestResult = isValid ? .success : .failure("Invalid API key")
        } catch {
            openaiTestResult = .failure(error.localizedDescription)
        }
        isTestingOpenAI = false
    }

    func testGemini(apiKey: String) async {
        isTestingGemini = true
        geminiTestResult = nil

        do {
            let isValid = try await geminiService.validateAPIKey(apiKey)
            geminiTestResult = isValid ? .success : .failure("Invalid API key")
        } catch {
            geminiTestResult = .failure(error.localizedDescription)
        }
        isTestingGemini = false
    }

    func clearTestResult(for service: TestService) {
        switch service {
        case .local(let name):
            localTestResults[name] = nil
        case .openAI:
            openaiTestResult = nil
        case .gemini:
            geminiTestResult = nil
        }
    }

    // MARK: - Hotkey Notification

    private func notifyHotkeysChanged() {
        var hotkeys: [String: Hotkey] = [:]
        for (modelName, ms) in modelSettingsMap {
            if let hotkey = ms.hotkey {
                hotkeys[modelName] = hotkey
            }
        }
        onLocalHotkeysChanged?(hotkeys)
    }

    private func removeItemIfExists(_ url: URL, context: String, logError: (String) -> Void = Logger.Model.error) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            logError("Failed to remove item (\(context)): \(url.path), error: \(error.localizedDescription)")
        }
    }

    private func removeTransientAudioIfNeeded(_ url: URL) {
        removeItemIfExists(
            url,
            context: "remove temporary test audio",
            logError: Logger.Transcription.error
        )
    }

    private func runModelOperationWithTimeout<T: Sendable>(
        _ operationName: String,
        timeout overrideTimeout: TimeInterval? = nil,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let timeout = overrideTimeout ?? modelOperationTimeout
        let timeoutNanoseconds = UInt64(timeout * 1_000_000_000)
        Logger.Model.debug("Starting model operation with timeout \(timeout)s: \(operationName)")

        // structured TaskGroup blocks until *all* children finish — but
        // WhisperKit's CoreML init does not honor Task cancellation, so a hung
        // load would wedge the group forever. Race two detached Tasks via a
        // single-resume continuation: whichever finishes first wins, the loser
        // keeps running in the background but the caller is already unblocked.
        let state = TimeoutRaceState<T>()

        Task.detached(priority: .userInitiated) {
            do {
                let value = try await operation()
                state.tryComplete(.success(value))
            } catch {
                state.tryComplete(.failure(error))
            }
        }

        Task.detached {
            try? await Task.sleep(nanoseconds: timeoutNanoseconds)
            Logger.Model.error("Model operation timed out after \(timeout)s: \(operationName)")
            state.tryComplete(.failure(MurmurixError.transcription(.timeout)))
        }

        let result = try await state.waitForResult()
        Logger.Model.debug("Completed model operation: \(operationName)")
        return result
    }
}

private final class TimeoutRaceState<T: Sendable>: @unchecked Sendable {
    private var settled: Result<T, Error>?
    private var continuation: CheckedContinuation<T, Error>?
    private let lock = NSLock()

    func tryComplete(_ result: Result<T, Error>) {
        let continuationToResume: CheckedContinuation<T, Error>? = lock.withLock {
            guard settled == nil else { return nil }
            settled = result
            let pending = continuation
            continuation = nil
            return pending
        }
        continuationToResume?.resume(with: result)
    }

    func waitForResult() async throws -> T {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<T, Error>) in
            let alreadySettled: Result<T, Error>? = lock.withLock {
                if let settled = settled {
                    return settled
                }
                continuation = cont
                return nil
            }
            if let alreadySettled = alreadySettled {
                cont.resume(with: alreadySettled)
            }
        }
    }
}
