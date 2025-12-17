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
            }
        }
    }

    private let language: String
    private let socketPath: String
    private var daemonProcess: Process?

    init(language: String = "ru") {
        self.language = language
        self.socketPath = NSHomeDirectory() + "/Library/Application Support/Murmurix/daemon.sock"
    }

    // MARK: - Daemon Management

    var isDaemonRunning: Bool {
        FileManager.default.fileExists(atPath: socketPath)
    }

    func startDaemon() {
        guard !isDaemonRunning else {
            print("Daemon already running")
            return
        }

        guard let python = findPython(), let script = findDaemonScript() else {
            print("Cannot start daemon: python or script not found")
            return
        }

        let modelPath = findModelPath()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)

        var arguments = [script, "--socket-path", socketPath, "--language", language]
        if let model = modelPath {
            arguments.append(contentsOf: ["--model-path", model])
        }
        process.arguments = arguments

        // Redirect output to console
        process.standardOutput = FileHandle.standardError
        process.standardError = FileHandle.standardError

        do {
            try process.run()
            daemonProcess = process
            print("Daemon started with PID: \(process.processIdentifier)")

            // Wait for socket to appear
            for _ in 0..<50 { // 5 seconds timeout
                if FileManager.default.fileExists(atPath: socketPath) {
                    print("Daemon socket ready")
                    return
                }
                Thread.sleep(forTimeInterval: 0.1)
            }
            print("Warning: Daemon socket not found after timeout")
        } catch {
            print("Failed to start daemon: \(error)")
        }
    }

    func stopDaemon() {
        // Try graceful shutdown first
        if isDaemonRunning {
            do {
                _ = try sendToDaemon(command: "shutdown", audioPath: nil)
            } catch {
                print("Graceful shutdown failed: \(error)")
            }
        }

        // Force kill if process is tracked
        if let process = daemonProcess, process.isRunning {
            process.terminate()
            process.waitUntilExit()
        }
        daemonProcess = nil

        // Kill by PID file
        let pidPath = socketPath + ".pid"
        if let pidString = try? String(contentsOfFile: pidPath, encoding: .utf8),
           let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) {
            kill(pid, SIGTERM)
        }

        // Cleanup files
        try? FileManager.default.removeItem(atPath: socketPath)
        try? FileManager.default.removeItem(atPath: pidPath)

        print("Daemon stopped")
    }

    // MARK: - Transcription

    func transcribe(audioURL: URL, useDaemon: Bool = true) async throws -> String {
        if useDaemon && isDaemonRunning {
            return try await transcribeViaDaemon(audioURL: audioURL)
        } else {
            return try await transcribeDirectly(audioURL: audioURL)
        }
    }

    private func transcribeViaDaemon(audioURL: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let response = try self.sendToDaemon(command: "transcribe", audioPath: audioURL.path)

                    if let data = response.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let text = json["text"] as? String {
                            continuation.resume(returning: text)
                        } else if let error = json["error"] as? String {
                            continuation.resume(throwing: TranscriptionError.transcriptionFailed(error))
                        } else {
                            continuation.resume(throwing: TranscriptionError.transcriptionFailed("Invalid response"))
                        }
                    } else {
                        continuation.resume(throwing: TranscriptionError.transcriptionFailed("Failed to parse response"))
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func sendToDaemon(command: String, audioPath: String?) throws -> String {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw TranscriptionError.daemonNotRunning
        }
        defer { close(fd) }

        // Set socket timeout (30 seconds for transcription)
        var timeout = timeval(tv_sec: 30, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

        // Safe copy with bounds checking (sun_path is 104 bytes on macOS)
        let maxPathLen = MemoryLayout.size(ofValue: addr.sun_path) - 1
        socketPath.withCString { ptr in
            withUnsafeMutablePointer(to: &addr.sun_path) { pathPtr in
                let pathBuf = UnsafeMutableRawPointer(pathPtr).assumingMemoryBound(to: CChar.self)
                strncpy(pathBuf, ptr, maxPathLen)
                pathBuf[maxPathLen] = 0 // Ensure null termination
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

        var request: [String: Any] = ["command": command, "language": language]
        if let path = audioPath {
            request["audio_path"] = path
        }

        let jsonData = try JSONSerialization.data(withJSONObject: request)
        let jsonString = String(data: jsonData, encoding: .utf8)! + "\n"

        jsonString.withCString { ptr in
            _ = send(fd, ptr, strlen(ptr), 0)
        }

        var buffer = [CChar](repeating: 0, count: 65536)
        let bytesRead = recv(fd, &buffer, buffer.count - 1, 0)

        guard bytesRead > 0 else {
            if errno == EAGAIN || errno == EWOULDBLOCK {
                throw TranscriptionError.transcriptionFailed("Daemon timeout (30s)")
            }
            throw TranscriptionError.transcriptionFailed("No response from daemon")
        }

        return String(cString: buffer)
    }

    // MARK: - Direct Transcription (fallback)

    private func transcribeDirectly(audioURL: URL) async throws -> String {
        guard let python = findPython() else {
            throw TranscriptionError.pythonNotFound
        }

        guard let script = findTranscribeScript() else {
            throw TranscriptionError.scriptNotFound
        }

        let modelPath = findModelPath()

        print("TranscriptionService: direct mode, audio=\(audioURL.path)")

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: python)

                var arguments = [script, audioURL.path, "--language", self.language]
                if let model = modelPath {
                    arguments.append(contentsOf: ["--model-path", model])
                }
                process.arguments = arguments

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

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

    // MARK: - Path Helpers

    private func findPython() -> String? {
        let pythonPaths = [
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/bin/python3"
        ]

        for path in pythonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    private func findTranscribeScript() -> String? {
        let paths = [
            NSHomeDirectory() + "/Library/Application Support/Murmurix/transcribe.py",
            Bundle.main.path(forResource: "transcribe", ofType: "py"),
            NSHomeDirectory() + "/Swift/Murmurix/Python/transcribe.py"
        ].compactMap { $0 }

        return paths.first { FileManager.default.fileExists(atPath: $0) }
    }

    private func findDaemonScript() -> String? {
        let paths = [
            NSHomeDirectory() + "/Library/Application Support/Murmurix/transcribe_daemon.py",
            Bundle.main.path(forResource: "transcribe_daemon", ofType: "py"),
            NSHomeDirectory() + "/Swift/Murmurix/Python/transcribe_daemon.py"
        ].compactMap { $0 }

        return paths.first { FileManager.default.fileExists(atPath: $0) }
    }

    private func findModelPath() -> String? {
        let modelPath = NSHomeDirectory() + "/Library/Application Support/Murmurix/models/faster-whisper-small"
        return FileManager.default.fileExists(atPath: modelPath) ? modelPath : nil
    }
}
