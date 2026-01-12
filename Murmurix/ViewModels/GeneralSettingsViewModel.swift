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
    func testLocalModel(isDaemonRunning: Bool) async
    func testOpenAI(apiKey: String) async
    func testGemini(apiKey: String) async
    func clearTestResult(for service: TestService)
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

    private let downloadService: ModelDownloadServiceProtocol
    private let openAIService: OpenAITranscriptionServiceProtocol
    private let geminiService: GeminiTranscriptionServiceProtocol
    private let transcriptionServiceFactory: () -> TranscriptionServiceProtocol
    let settings: SettingsStorageProtocol

    init(
        downloadService: ModelDownloadServiceProtocol = ModelDownloadService.shared,
        openAIService: OpenAITranscriptionServiceProtocol = OpenAITranscriptionService.shared,
        geminiService: GeminiTranscriptionServiceProtocol = GeminiTranscriptionService.shared,
        transcriptionServiceFactory: @escaping () -> TranscriptionServiceProtocol = { TranscriptionService() },
        settings: SettingsStorageProtocol = Settings.shared
    ) {
        self.downloadService = downloadService
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
        downloadStatus = .downloading

        downloadService.downloadModel(modelName) { [weak self] status in
            guard let self = self else { return }

            self.downloadStatus = status

            if case .completed = status {
                self.loadInstalledModels()
                self.onModelChanged?()
                self.scheduleStatusReset()
            }
        }
    }

    func cancelDownload() {
        downloadService.cancelDownload()
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

    // MARK: - API Testing

    func testLocalModel(isDaemonRunning: Bool) async {
        isTestingLocal = true
        localTestResult = nil

        do {
            let tempURL = AudioTestUtility.createTemporaryTestAudioURL()
            try AudioTestUtility.createSilentWavFile(at: tempURL, duration: 0.5)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            let service = transcriptionServiceFactory()
            _ = try await service.transcribe(audioURL: tempURL, useDaemon: isDaemonRunning, mode: .local)

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
