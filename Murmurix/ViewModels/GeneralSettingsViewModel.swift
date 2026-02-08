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

@MainActor
final class GeneralSettingsViewModel: ObservableObject {
    @Published var installedModels: Set<String> = []
    @Published var downloadStatuses: [String: DownloadStatus] = [:]

    // Test state
    @Published var isTestingOpenAI = false
    @Published var isTestingGemini = false
    @Published var localTestResults: [String: APITestResult] = [:]
    @Published var testingModels: Set<String> = []
    @Published var openaiTestResult: APITestResult?
    @Published var geminiTestResult: APITestResult?

    @Published var modelSettingsMap: [String: WhisperModelSettings] = [:]

    var onLocalHotkeysChanged: (([String: Hotkey]) -> Void)?

    private let whisperKitService: WhisperKitServiceProtocol
    private let openAIService: OpenAITranscriptionServiceProtocol
    private let geminiService: GeminiTranscriptionServiceProtocol
    private let transcriptionServiceFactory: () -> TranscriptionServiceProtocol
    let settings: SettingsStorageProtocol

    init(
        whisperKitService: WhisperKitServiceProtocol = WhisperKitService.shared,
        openAIService: OpenAITranscriptionServiceProtocol = OpenAITranscriptionService.shared,
        geminiService: GeminiTranscriptionServiceProtocol = GeminiTranscriptionService.shared,
        transcriptionServiceFactory: @escaping () -> TranscriptionServiceProtocol = { TranscriptionService() },
        settings: SettingsStorageProtocol = Settings.shared
    ) {
        self.whisperKitService = whisperKitService
        self.openAIService = openAIService
        self.geminiService = geminiService
        self.transcriptionServiceFactory = transcriptionServiceFactory
        self.settings = settings
    }

    func loadInstalledModels() {
        installedModels = Set(WhisperModel.allCases.filter { $0.isInstalled }.map { $0.rawValue })
        modelSettingsMap = settings.loadWhisperModelSettings()
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
        downloadStatuses[modelName] = .downloading(progress: 0)

        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.whisperKitService.downloadModel(modelName) { progress in
                    Task { @MainActor [weak self] in
                        self?.downloadStatuses[modelName] = .downloading(progress: progress)
                    }
                }
                self.downloadStatuses[modelName] = .compiling
                try await self.whisperKitService.loadModel(name: modelName)
                let ms = self.modelSettings(for: modelName)
                if !ms.keepLoaded {
                    await self.whisperKitService.unloadModel(name: modelName)
                }
                self.downloadStatuses[modelName] = .completed
                self.loadInstalledModels()
                self.scheduleStatusReset(for: modelName)
            } catch {
                self.downloadStatuses[modelName] = .error(error.localizedDescription)
            }
        }
    }

    func cancelDownload(for modelName: String) {
        downloadStatuses[modelName] = .idle
    }

    private func scheduleStatusReset(for modelName: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            if case .completed = self.downloadStatuses[modelName] {
                self.downloadStatuses[modelName] = .idle
            }
        }
    }

    // MARK: - Model Deletion

    func deleteModel(_ modelName: String) async {
        if whisperKitService.isModelLoaded(name: modelName) {
            await whisperKitService.unloadModel(name: modelName)
        }
        let fm = FileManager.default
        let modelDir = ModelPaths.modelDir(for: modelName)
        try? fm.removeItem(at: modelDir)
        loadInstalledModels()
    }

    func deleteAllModels() async {
        await whisperKitService.unloadAllModels()
        let fm = FileManager.default
        let repoDir = ModelPaths.repoDir
        if let contents = try? fm.contentsOfDirectory(atPath: repoDir.path) {
            for item in contents where item.hasPrefix("openai_whisper-") {
                try? fm.removeItem(at: repoDir.appendingPathComponent(item))
            }
        }
        loadInstalledModels()
    }

    // MARK: - API Testing

    func testModel(_ modelName: String) async {
        testingModels.insert(modelName)
        localTestResults[modelName] = nil

        guard isModelInstalled(modelName) else {
            localTestResults[modelName] = .failure("Model not installed. Download it first.")
            testingModels.remove(modelName)
            return
        }

        do {
            let service = transcriptionServiceFactory()
            if !service.isModelLoaded(name: modelName) {
                try await service.loadModel(name: modelName)
            }

            let tempURL = AudioTestUtility.createTemporaryTestAudioURL()
            try AudioTestUtility.createSilentWavFile(at: tempURL, duration: 0.5)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            _ = try await service.transcribe(audioURL: tempURL, mode: .local(model: modelName))

            localTestResults[modelName] = .success
        } catch {
            localTestResults[modelName] = .failure(error.localizedDescription)
        }
        testingModels.remove(modelName)
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
}
