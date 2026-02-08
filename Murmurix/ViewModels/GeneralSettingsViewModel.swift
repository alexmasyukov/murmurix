//
//  GeneralSettingsViewModel.swift
//  Murmurix
//

import Foundation
import Combine

protocol GeneralSettingsViewModelProtocol: ObservableObject {
    var installedModels: Set<String> { get }
    var downloadStatus: DownloadStatus { get }
    var onModelChanged: (() -> Void)? { get set }

    // Test state
    var isTestingLocal: Bool { get }
    var isTestingOpenAI: Bool { get }
    var isTestingGemini: Bool { get }
    var localTestResult: APITestResult? { get }
    var openaiTestResult: APITestResult? { get }
    var geminiTestResult: APITestResult? { get }

    func loadInstalledModels()
    func isModelInstalled(_ modelName: String) -> Bool
    func handleModelChange(_ newModel: String)
    func startDownload(for modelName: String)
    func cancelDownload()

    // Test functions
    func testLocalModel() async
    func testOpenAI(apiKey: String) async
    func testGemini(apiKey: String) async
    func clearTestResult(for service: TestService)
}

enum DownloadStatus {
    case idle
    case downloading(progress: Double)
    case compiling
    case completed
    case error(String)
}

enum TestService {
    case local
    case openAI
    case gemini
}

@MainActor
final class GeneralSettingsViewModel: ObservableObject, GeneralSettingsViewModelProtocol {
    @Published var installedModels: Set<String> = []
    @Published var downloadStatus: DownloadStatus = .idle

    // Test state
    @Published var isTestingLocal = false
    @Published var isTestingOpenAI = false
    @Published var isTestingGemini = false
    @Published var localTestResult: APITestResult?
    @Published var openaiTestResult: APITestResult?
    @Published var geminiTestResult: APITestResult?

    var onModelChanged: (() -> Void)?

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
    }

    func isModelInstalled(_ modelName: String) -> Bool {
        installedModels.contains(modelName)
    }

    func handleModelChange(_ newModel: String) {
        downloadStatus = .idle
        if let model = WhisperModel(rawValue: newModel), model.isInstalled {
            onModelChanged?()
        }
    }

    func startDownload(for modelName: String) {
        downloadStatus = .downloading(progress: 0)

        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.whisperKitService.downloadModel(modelName) { progress in
                    Task { @MainActor [weak self] in
                        self?.downloadStatus = .downloading(progress: progress)
                    }
                }
                self.downloadStatus = .compiling
                try await self.whisperKitService.loadModel(name: modelName)
                if !self.settings.keepModelLoaded {
                    await self.whisperKitService.unloadModel()
                }
                self.downloadStatus = .completed
                self.loadInstalledModels()
                self.onModelChanged?()
                self.scheduleStatusReset()
            } catch {
                self.downloadStatus = .error(error.localizedDescription)
            }
        }
    }

    func cancelDownload() {
        downloadStatus = .idle
    }

    private func scheduleStatusReset() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            if case .completed = self.downloadStatus {
                self.downloadStatus = .idle
            }
        }
    }

    // MARK: - Model Deletion

    func deleteModel(_ modelName: String) async {
        if whisperKitService.isModelLoaded {
            await whisperKitService.unloadModel()
        }
        let fm = FileManager.default
        let documentsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelDir = documentsDir.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-\(modelName)")
        try? fm.removeItem(at: modelDir)
        loadInstalledModels()
    }

    func deleteAllModels() async {
        if whisperKitService.isModelLoaded {
            await whisperKitService.unloadModel()
        }
        let fm = FileManager.default
        let documentsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let repoDir = documentsDir.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml")
        if let contents = try? fm.contentsOfDirectory(atPath: repoDir.path) {
            for item in contents where item.hasPrefix("openai_whisper-") {
                try? fm.removeItem(at: repoDir.appendingPathComponent(item))
            }
        }
        loadInstalledModels()
    }

    // MARK: - API Testing

    func testLocalModel() async {
        isTestingLocal = true
        localTestResult = nil

        let modelName = settings.whisperModel
        guard isModelInstalled(modelName) else {
            localTestResult = .failure("Model not installed. Download it first.")
            isTestingLocal = false
            return
        }

        do {
            let service = transcriptionServiceFactory()
            if !service.isModelLoaded {
                try await service.loadModel()
            }

            let tempURL = AudioTestUtility.createTemporaryTestAudioURL()
            try AudioTestUtility.createSilentWavFile(at: tempURL, duration: 0.5)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            _ = try await service.transcribe(audioURL: tempURL, mode: .local)

            localTestResult = .success
        } catch {
            localTestResult = .failure(error.localizedDescription)
        }
        isTestingLocal = false
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
        case .local:
            localTestResult = nil
        case .openAI:
            openaiTestResult = nil
        case .gemini:
            geminiTestResult = nil
        }
    }
}
