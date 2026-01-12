//
//  TranscriptionService.swift
//  Murmurix
//

import Foundation

final class TranscriptionService: @unchecked Sendable, TranscriptionServiceProtocol {
    private let daemonManager: DaemonManagerProtocol
    private let settings: SettingsStorageProtocol
    private let openAIService: OpenAITranscriptionServiceProtocol
    private let geminiService: GeminiTranscriptionServiceProtocol
    private let socketClientFactory: (String) -> SocketClientProtocol
    private let language: String

    init(
        daemonManager: DaemonManagerProtocol? = nil,
        settings: SettingsStorageProtocol = Settings.shared,
        openAIService: OpenAITranscriptionServiceProtocol = OpenAITranscriptionService.shared,
        geminiService: GeminiTranscriptionServiceProtocol = GeminiTranscriptionService.shared,
        socketClientFactory: ((String) -> SocketClientProtocol)? = nil,
        language: String = "ru"
    ) {
        self.settings = settings
        self.openAIService = openAIService
        self.geminiService = geminiService
        self.daemonManager = daemonManager ?? DaemonManager(settings: settings, language: language)
        self.socketClientFactory = socketClientFactory ?? { path in UnixSocketClient(socketPath: path) }
        self.language = language
    }

    // MARK: - TranscriptionServiceProtocol

    var isDaemonRunning: Bool {
        daemonManager.isRunning
    }

    func startDaemon() {
        daemonManager.start()
    }

    func stopDaemon() {
        daemonManager.stop()
    }

    func transcribe(audioURL: URL, useDaemon: Bool = true, mode: TranscriptionMode = .local) async throws -> String {
        switch mode {
        case .openai:
            Logger.Transcription.info("☁️ Cloud mode (OpenAI)")
            return try await transcribeViaOpenAI(audioURL: audioURL)

        case .gemini:
            Logger.Transcription.info("☁️ Cloud mode (Gemini)")
            return try await transcribeViaGemini(audioURL: audioURL)

        case .local:
            if useDaemon && isDaemonRunning {
                Logger.Transcription.info("🏠 Local mode (daemon), model=\(settings.whisperModel)")
                return try await transcribeViaDaemon(audioURL: audioURL)
            } else {
                Logger.Transcription.info("🏠 Local mode (direct), model=\(settings.whisperModel)")
                return try await transcribeDirectly(audioURL: audioURL)
            }
        }
    }

    // MARK: - OpenAI Transcription

    private func transcribeViaOpenAI(audioURL: URL) async throws -> String {
        let apiKey = settings.openaiApiKey
        guard !apiKey.isEmpty else {
            throw MurmurixError.transcription(.failed("OpenAI API key not set. Please add it in Settings."))
        }

        let model = settings.openaiTranscriptionModel
        Logger.Transcription.info("OpenAI mode, model=\(model), audio=\(audioURL.path)")

        return try await openAIService.transcribe(
            audioURL: audioURL,
            language: language,
            model: model,
            apiKey: apiKey
        )
    }

    // MARK: - Gemini Transcription

    private func transcribeViaGemini(audioURL: URL) async throws -> String {
        let apiKey = settings.geminiApiKey
        guard !apiKey.isEmpty else {
            throw MurmurixError.transcription(.failed("Gemini API key not set. Please add it in Settings."))
        }

        let model = settings.geminiModel
        Logger.Transcription.info("Gemini mode, model=\(model), audio=\(audioURL.path)")

        return try await geminiService.transcribe(
            audioURL: audioURL,
            language: language,
            model: model,
            apiKey: apiKey
        )
    }

    // MARK: - Daemon Transcription

    private func transcribeViaDaemon(audioURL: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                do {
                    let text = try sendTranscriptionRequest(audioPath: audioURL.path)
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func sendTranscriptionRequest(audioPath: String) throws -> String {
        let socketClient = socketClientFactory(daemonManager.socketPath)

        let request: [String: Any] = [
            "command": "transcribe",
            "language": language,
            "audio_path": audioPath
        ]

        do {
            let response = try socketClient.send(request: request, timeout: NetworkConfig.daemonSocketTimeout)
            return try parseTranscriptionResponse(response)
        } catch let error as SocketError {
            switch error {
            case .connectionFailed:
                throw MurmurixError.transcription(.daemonNotRunning)
            case .timeout:
                throw MurmurixError.transcription(.timeout)
            case .noResponse:
                throw MurmurixError.transcription(.failed("No response from daemon"))
            case .invalidResponse:
                throw MurmurixError.transcription(.failed("Invalid response from daemon"))
            }
        }
    }

    private func parseTranscriptionResponse(_ json: [String: Any]) throws -> String {
        if let text = json["text"] as? String {
            return text
        } else if let error = json["error"] as? String {
            throw MurmurixError.transcription(.failed(error))
        } else {
            throw MurmurixError.transcription(.failed("Invalid response"))
        }
    }

    // MARK: - Direct Transcription (fallback)

    private func transcribeDirectly(audioURL: URL) async throws -> String {
        guard let python = PythonResolver.findPython() else {
            throw MurmurixError.transcription(.pythonNotFound)
        }

        guard let script = PythonResolver.findTranscribeScript() else {
            throw MurmurixError.transcription(.scriptNotFound)
        }

        let modelName = settings.whisperModel

        Logger.Transcription.info("Direct mode, audio=\(audioURL.path)")

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: python)
                process.arguments = [script, audioURL.path, "--language", self.language, "--model", modelName]

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outputData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    if process.terminationStatus == 0 {
                        continuation.resume(returning: output.isEmpty ? "(empty)" : output)
                    } else {
                        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                        let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: MurmurixError.transcription(.failed(errorOutput)))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
