//
//  DaemonManager.swift
//  Murmurix
//

import Foundation

protocol DaemonManagerProtocol: Sendable {
    var isRunning: Bool { get }
    var socketPath: String { get }

    func start()
    func stop()
}

final class DaemonManager: @unchecked Sendable, DaemonManagerProtocol {
    let socketPath: String
    private let settings: SettingsStorageProtocol
    private let language: String
    private let socketClientFactory: (String) -> SocketClientProtocol
    private var daemonProcess: Process?

    init(
        settings: SettingsStorageProtocol = Settings.shared,
        language: String = "ru",
        socketClientFactory: ((String) -> SocketClientProtocol)? = nil
    ) {
        self.settings = settings
        self.language = language
        self.socketPath = AppPaths.socketPath
        self.socketClientFactory = socketClientFactory ?? { path in UnixSocketClient(socketPath: path) }
    }

    var isRunning: Bool {
        FileManager.default.fileExists(atPath: socketPath)
    }

    func start() {
        guard !isRunning else {
            Logger.Daemon.info("Daemon already running")
            return
        }

        guard let python = PythonResolver.findPython(),
              let script = PythonResolver.findDaemonScript() else {
            Logger.Daemon.error("Cannot start daemon: python or script not found")
            return
        }

        let modelName = settings.whisperModel

        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = [script, "--socket-path", socketPath, "--language", language, "--model", modelName]
        process.standardOutput = FileHandle.standardError
        process.standardError = FileHandle.standardError

        do {
            try process.run()
            daemonProcess = process
            Logger.Daemon.info("Daemon started with PID: \(process.processIdentifier)")

            waitForSocket()
        } catch {
            Logger.Daemon.error("Failed to start daemon: \(error)")
        }
    }

    func stop() {
        sendShutdownCommand()
        terminateProcess()
        killByPidFile()
        cleanupFiles()
        Logger.Daemon.info("Daemon stopped")
    }

    // MARK: - Private

    private func waitForSocket() {
        for _ in 0..<NetworkConfig.daemonStartupTimeout {
            if FileManager.default.fileExists(atPath: socketPath) {
                Logger.Daemon.info("Daemon socket ready")
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        Logger.Daemon.warning("Daemon socket not found after timeout")
    }

    private func sendShutdownCommand() {
        guard isRunning else { return }

        do {
            _ = try sendCommand("shutdown")
        } catch {
            Logger.Daemon.error("Graceful shutdown failed: \(error)")
        }
    }

    private func terminateProcess() {
        guard let process = daemonProcess, process.isRunning else { return }
        process.terminate()
        process.waitUntilExit()
        daemonProcess = nil
    }

    private func killByPidFile() {
        let pidPath = socketPath + ".pid"
        guard let pidString = try? String(contentsOfFile: pidPath, encoding: .utf8),
              let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }
        kill(pid, SIGTERM)
    }

    private func cleanupFiles() {
        let pidPath = socketPath + ".pid"
        try? FileManager.default.removeItem(atPath: socketPath)
        try? FileManager.default.removeItem(atPath: pidPath)
    }

    private func sendCommand(_ command: String) throws -> [String: Any] {
        let socketClient = socketClientFactory(socketPath)
        let request: [String: Any] = ["command": command]

        do {
            return try socketClient.send(request: request, timeout: NetworkConfig.shutdownTimeout)
        } catch let error as SocketError {
            switch error {
            case .connectionFailed:
                throw MurmurixError.daemon(.notRunning)
            case .timeout, .noResponse:
                throw MurmurixError.daemon(.communicationFailed)
            case .invalidResponse:
                throw MurmurixError.daemon(.communicationFailed)
            }
        }
    }

}
