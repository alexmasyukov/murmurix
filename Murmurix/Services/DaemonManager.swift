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
    private let language: String
    private var daemonProcess: Process?

    init(language: String = "ru") {
        self.language = language
        self.socketPath = AppPaths.socketPath
    }

    var isRunning: Bool {
        FileManager.default.fileExists(atPath: socketPath)
    }

    func start() {
        guard !isRunning else {
            print("Daemon already running")
            return
        }

        guard let python = PythonResolver.findPython(),
              let script = PythonResolver.findDaemonScript() else {
            print("Cannot start daemon: python or script not found")
            return
        }

        let modelName = Settings.shared.whisperModel

        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)
        process.arguments = [script, "--socket-path", socketPath, "--language", language, "--model", modelName]
        process.standardOutput = FileHandle.standardError
        process.standardError = FileHandle.standardError

        do {
            try process.run()
            daemonProcess = process
            print("Daemon started with PID: \(process.processIdentifier)")

            waitForSocket()
        } catch {
            print("Failed to start daemon: \(error)")
        }
    }

    func stop() {
        sendShutdownCommand()
        terminateProcess()
        killByPidFile()
        cleanupFiles()
        print("Daemon stopped")
    }

    // MARK: - Private

    private func waitForSocket() {
        for _ in 0..<NetworkConfig.daemonStartupTimeout {
            if FileManager.default.fileExists(atPath: socketPath) {
                print("Daemon socket ready")
                return
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        print("Warning: Daemon socket not found after timeout")
    }

    private func sendShutdownCommand() {
        guard isRunning else { return }

        do {
            _ = try sendCommand("shutdown")
        } catch {
            print("Graceful shutdown failed: \(error)")
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

    private func sendCommand(_ command: String) throws -> String {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else {
            throw DaemonError.notRunning
        }
        defer { close(fd) }

        var timeout = timeval(tv_sec: NetworkConfig.shutdownTimeout, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)

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
            throw DaemonError.notRunning
        }

        let request: [String: Any] = ["command": command]
        let jsonData = try JSONSerialization.data(withJSONObject: request)
        let jsonString = String(data: jsonData, encoding: .utf8)! + "\n"

        jsonString.withCString { ptr in
            _ = send(fd, ptr, strlen(ptr), 0)
        }

        var buffer = [CChar](repeating: 0, count: 4096)
        let bytesRead = recv(fd, &buffer, buffer.count - 1, 0)

        guard bytesRead > 0 else {
            throw DaemonError.noResponse
        }

        return String(cString: buffer)
    }

    enum DaemonError: Error {
        case notRunning
        case noResponse
    }
}
