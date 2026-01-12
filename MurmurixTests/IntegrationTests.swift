//
//  IntegrationTests.swift
//  MurmurixTests
//
//  Integration tests that use the real daemon for local model transcription.
//  These tests require:
//  - Python 3 installed
//  - Whisper model installed (tiny recommended for tests)
//  - transcribe_daemon.py script available
//

import Testing
import Foundation
@testable import Murmurix

// MARK: - Test Skip Error

struct TestSkipError: Error, CustomStringConvertible {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var description: String { message }
}

// MARK: - Daemon Integration Tests (All in one serialized suite to avoid conflicts)

@Suite(.serialized)
struct DaemonIntegrationTests {

    // MARK: - Lifecycle Tests

    @Test func daemonStartsAndStops() async throws {
        // Cleanup any leftover daemon first
        DaemonCleanup.forceCleanup()
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        guard PythonResolver.findPython() != nil,
              PythonResolver.findDaemonScript() != nil else {
            throw TestSkipError("Python or daemon script not found")
        }

        let testDefaults = UserDefaults(suiteName: "lifecycle-test-\(UUID().uuidString)")!
        let settings = Settings(defaults: testDefaults)
        settings.whisperModel = "tiny"

        let daemon = DaemonManager(settings: settings, language: "en")

        defer {
            daemon.stop()
            DaemonCleanup.forceCleanup()
        }

        // Initially not running (after cleanup)
        #expect(daemon.isRunning == false)

        // Start
        daemon.start()

        // Wait for startup
        for _ in 0..<100 {
            if daemon.isRunning { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        #expect(daemon.isRunning == true)

        // Stop
        daemon.stop()

        // Should be stopped
        #expect(daemon.isRunning == false)
    }

    @Test func daemonCleansUpSocketFile() async throws {
        // Cleanup any leftover daemon first
        DaemonCleanup.forceCleanup()
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        guard PythonResolver.findPython() != nil,
              PythonResolver.findDaemonScript() != nil else {
            throw TestSkipError("Python or daemon script not found")
        }

        let testDefaults = UserDefaults(suiteName: "cleanup-test-\(UUID().uuidString)")!
        let settings = Settings(defaults: testDefaults)
        settings.whisperModel = "tiny"

        let daemon = DaemonManager(settings: settings, language: "en")
        let socketPath = daemon.socketPath

        defer {
            daemon.stop()
            DaemonCleanup.forceCleanup()
        }

        // Start daemon
        daemon.start()

        // Wait for socket to appear
        for _ in 0..<100 {
            if FileManager.default.fileExists(atPath: socketPath) { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        // Stop daemon
        daemon.stop()

        // Socket file should be cleaned up
        #expect(FileManager.default.fileExists(atPath: socketPath) == false)
    }

    // MARK: - Transcription Tests

    @Test func daemonTranscribesSilentAudio() async throws {
        // Cleanup any leftover daemon first
        DaemonCleanup.forceCleanup()
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Skip if prerequisites not met
        guard PythonResolver.findPython() != nil else {
            throw TestSkipError("Python not found")
        }
        guard PythonResolver.findDaemonScript() != nil else {
            throw TestSkipError("Daemon script not found")
        }

        // Setup
        let testDefaults = UserDefaults(suiteName: "transcribe-test-\(UUID().uuidString)")!
        let settings = Settings(defaults: testDefaults)
        settings.whisperModel = "tiny"
        settings.language = "en"

        let daemon = DaemonManager(settings: settings, language: "en")

        // Cleanup on exit
        defer {
            daemon.stop()
            DaemonCleanup.forceCleanup()
        }

        // Start daemon
        daemon.start()

        // Wait for daemon to be ready (longer wait for model loading)
        for _ in 0..<300 { // 30 seconds
            if daemon.isRunning { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        guard daemon.isRunning else {
            throw TestSkipError("Daemon failed to start")
        }

        // Create test audio file
        let tempURL = AudioTestUtility.createTemporaryTestAudioURL()
        try AudioTestUtility.createSilentWavFile(at: tempURL, duration: 1.0)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Create service and transcribe
        let service = TranscriptionService(settings: settings, language: "en")
        let result = try await service.transcribe(
            audioURL: tempURL,
            useDaemon: true,
            mode: .local
        )

        // Silent audio should return empty or minimal text
        #expect(result.count < 100, "Silent audio should produce minimal text")
    }
}

// MARK: - Force Cleanup Utility

enum DaemonCleanup {
    /// Kills any running daemon processes and cleans up socket files
    static func forceCleanup() {
        let socketPath = AppPaths.socketPath
        let pidPath = socketPath + ".pid"

        // Try to read PID and kill
        if let pidString = try? String(contentsOfFile: pidPath, encoding: .utf8),
           let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines)) {
            kill(pid, SIGTERM)
            usleep(100_000) // 100ms
            kill(pid, SIGKILL) // Force kill if still running
        }

        // Kill by process name as fallback
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-f", "transcribe_daemon.py"]
        try? task.run()
        task.waitUntilExit()

        // Clean up files
        try? FileManager.default.removeItem(atPath: socketPath)
        try? FileManager.default.removeItem(atPath: pidPath)
    }
}
