//
//  APIServer.swift
//  Murmurix
//

import Foundation
import Swifter

/// Serializes transcription requests so concurrent API calls never fight over the ANE.
/// Each call waits for the previous one to finish (a simple task chain), giving the
/// "queue" behavior — requests pile up and are processed one at a time.
actor SerialTranscriber {
    private let service: TranscriptionServiceProtocol
    private var tail: Task<Void, Never> = Task {}

    init(service: TranscriptionServiceProtocol) {
        self.service = service
    }

    func transcribe(samples: [Float], language: String, model: String) async throws -> String {
        let previous = tail
        let work = Task { () -> Result<String, Error> in
            _ = await previous.value
            do {
                return .success(try await self.service.transcribe(samples: samples, language: language, model: model))
            } catch {
                return .failure(error)
            }
        }
        tail = Task { _ = await work.value }
        return try await work.value.get()
    }
}

/// Local HTTP API that lets other apps hand Murmurix audio and get back a
/// transcription, reusing the exact same WhisperKit pipeline (trim + decode +
/// hallucination filter). Binds to 127.0.0.1 only. Audio is decoded to samples in
/// memory — nothing is written to disk.
final class APIServer {
    private let serial: SerialTranscriber
    private let modelsProvider: @Sendable () -> (installed: [String], loaded: [String])
    private var server: HttpServer?
    private(set) var isRunning = false

    init(
        transcriptionService: TranscriptionServiceProtocol,
        modelsProvider: @escaping @Sendable () -> (installed: [String], loaded: [String])
    ) {
        self.serial = SerialTranscriber(service: transcriptionService)
        self.modelsProvider = modelsProvider
    }

    func start(port: UInt16) {
        stop()

        let server = HttpServer()
        server.listenAddressIPv4 = "127.0.0.1" // loopback only

        server.GET["/health"] = { _ in
            Self.json(["status": "ok", "app": "Murmurix"])
        }

        server.GET["/v1/models"] = { [weak self] _ in
            guard let self else { return .internalServerError }
            let models = self.modelsProvider()
            return Self.json(["installed": models.installed, "loaded": models.loaded])
        }

        server.POST["/v1/transcribe"] = { [weak self] request in
            guard let self else { return .internalServerError }
            return self.handleTranscribe(request)
        }

        do {
            try server.start(port, forceIPv4: true, priority: .userInitiated)
            self.server = server
            isRunning = true
            Logger.Transcription.info("API server listening on 127.0.0.1:\(port)")
        } catch {
            self.server = nil
            isRunning = false
            Logger.Transcription.error("API server failed to start on port \(port): \(error.localizedDescription)")
        }
    }

    func stop() {
        server?.stop()
        server = nil
        isRunning = false
    }

    // MARK: - Handlers

    private func handleTranscribe(_ request: HttpRequest) -> HttpResponse {
        let params = Dictionary(request.queryParams, uniquingKeysWith: { first, _ in first })
        guard let model = params["model"], !model.isEmpty else {
            return Self.jsonError(status: 400, message: "Missing required query parameter: model")
        }
        let language = params["language"] ?? "auto"

        let data = Data(request.body)
        let samples: [Float]
        do {
            samples = try AudioDecoder.decodeToMonoFloat16k(data)
        } catch {
            return Self.jsonError(status: 400, message: error.localizedDescription)
        }

        let outcome = Self.runBlocking {
            try await self.serial.transcribe(samples: samples, language: language, model: model)
        }
        switch outcome {
        case .success(let text):
            return Self.json(["text": text])
        case .failure(let error):
            Logger.Transcription.error("API transcribe failed: \(error.localizedDescription)")
            return Self.jsonError(status: 500, message: error.localizedDescription)
        }
    }

    // MARK: - Helpers

    /// Bridges Swifter's synchronous handler thread to our async pipeline. Safe here:
    /// Swifter dispatches each request on its own thread, so blocking that one thread
    /// while the transcription runs (and the serial queue drains) is fine.
    private static func runBlocking<T>(_ operation: @escaping @Sendable () async throws -> T) -> Result<T, Error> {
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox<T>()
        Task {
            do { box.value = .success(try await operation()) }
            catch { box.value = .failure(error) }
            semaphore.signal()
        }
        semaphore.wait()
        return box.value ?? .failure(APIServerError.internalError)
    }

    private static func json(_ object: [String: Any]) -> HttpResponse {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else {
            return .internalServerError
        }
        return .raw(200, "OK", ["Content-Type": "application/json"]) { writer in
            try writer.write(data)
        }
    }

    private static func jsonError(status: Int, message: String) -> HttpResponse {
        let data = (try? JSONSerialization.data(withJSONObject: ["error": message])) ?? Data()
        return .raw(status, "Error", ["Content-Type": "application/json"]) { writer in
            try writer.write(data)
        }
    }
}

private enum APIServerError: Error { case internalError }

private final class ResultBox<T>: @unchecked Sendable {
    var value: Result<T, Error>?
}
