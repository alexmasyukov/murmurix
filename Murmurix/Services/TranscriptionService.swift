//
//  TranscriptionService.swift
//  Murmurix
//

import Foundation

final class TranscriptionService: @unchecked Sendable, TranscriptionServiceProtocol {
    enum TranscriptionError: Error, LocalizedError {
        case pythonNotFound
        case scriptNotFound
        case daemonNotRunning
        case transcriptionFailed(String)
        case timeout

        var errorDescription: String? {
            switch self {
            case .pythonNotFound:
                return "Python not found. Please install Python 3.11+"
            case .scriptNotFound:
                return "Transcription script not found"
            case .daemonNotRunning:
                return "Daemon is not running"
            case .transcriptionFailed(let message):
                return "Transcription failed: \(message)"
            case .timeout:
                return "Daemon timeout (30s)"
            }
        }
    }

    private let daemonManager: DaemonManagerProtocol
    private let language: String

    init(daemonManager: DaemonManagerProtocol? = nil, language: String = "ru") {
        self.daemonManager = daemonManager ?? DaemonManager(language: language)
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

    func transcribe(audioURL: URL, useDaemon: Bool = true) async throws -> String {
        if useDaemon && isDaemonRunning {
            return try await transcribeViaDaemon(audioURL: audioURL)
        } else {
            return try await transcribeDirectly(audioURL: audioURL)
        }
    }

    // MARK: - Daemon Transcription

    private func transcribeViaDaemon(audioURL: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                do {
                    let response = try sendTranscriptionRequest(audioPath: audioURL.path)
                    let text = try parseTranscriptionResponse(response)
                    continuation.resume(returning: text)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func sendTranscriptionRequest(audioPath: String) throws -> String {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw TranscriptionError.daemonNotRunning
        }
        defer { close(fd) }

        var timeout = timeval(tv_sec: NetworkConfig.daemonSocketTimeout, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        try connectToSocket(fd: fd)

        let request: [String: Any] = [
            "command": "transcribe",
            "language": language,
            "audio_path": audioPath
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: request)
        let jsonString = String(data: jsonData, encoding: .utf8)! + "\n"

        jsonString.withCString { ptr in
            _ = send(fd, ptr, strlen(ptr), 0)
        }

        var buffer = [CChar](repeating: 0, count: 65536)
        let bytesRead = recv(fd, &buffer, buffer.count - 1, 0)

        guard bytesRead > 0 else {
            if errno == EAGAIN || errno == EWOULDBLOCK {
                throw TranscriptionError.timeout
            }
            throw TranscriptionError.transcriptionFailed("No response from daemon")
        }

        return String(cString: buffer)
    }

    private func connectToSocket(fd: Int32) throws {
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        let socketPath = daemonManager.socketPath
        let maxPathLen = MemoryLayout.size(ofValue: addr.sun_path) - 1

        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                let pathBuf = UnsafeMutableRawPointer(pathPtr).assumingMemoryBound(to: CChar.self)
                strncpy(pathBuf, ptr, maxPathLen)
                pathBuf[maxPathLen] = 0
            }
        }

        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(fd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard connectResult == 0 else {
            throw TranscriptionError.daemonNotRunning
        }
    }

    private func parseTranscriptionResponse(_ response: String) throws -> String {
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TranscriptionError.transcriptionFailed("Failed to parse response")
        }

        if let text = json["text"] as? String {
            return text
        } else if let error = json["error"] as? String {
            throw TranscriptionError.transcriptionFailed(error)
        } else {
            throw TranscriptionError.transcriptionFailed("Invalid response")
        }
    }

    // MARK: - Direct Transcription (fallback)

    private func transcribeDirectly(audioURL: URL) async throws -> String {
        guard let python = PythonResolver.findPython() else {
            throw TranscriptionError.pythonNotFound
        }

        guard let script = PythonResolver.findTranscribeScript() else {
            throw TranscriptionError.scriptNotFound
        }

        let modelName = Settings.shared.whisperModel

        print("TranscriptionService: direct mode, audio=\(audioURL.path)")

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
                        continuation.resume(throwing: TranscriptionError.transcriptionFailed(errorOutput))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
