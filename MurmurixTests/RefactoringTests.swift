//
//  RefactoringTests.swift
//  MurmurixTests
//
//  Tests for refactored components: MurmurixError, WindowPositioner, Logger, AppConstants
//

import Testing
import Foundation
import AppKit
@testable import Murmurix

// MARK: - MurmurixError Tests

struct MurmurixErrorTests {

    // MARK: - TranscriptionError

    @Test func transcriptionErrorPythonNotFound() {
        let error = MurmurixError.transcription(.pythonNotFound)

        #expect(error.errorDescription?.contains("Python") == true)
        #expect(error.recoverySuggestion?.contains("install") == true)
    }

    @Test func transcriptionErrorScriptNotFound() {
        let error = MurmurixError.transcription(.scriptNotFound)

        #expect(error.errorDescription?.contains("script") == true)
        #expect(error.recoverySuggestion?.contains("Murmurix") == true)
    }

    @Test func transcriptionErrorDaemonNotRunning() {
        let error = MurmurixError.transcription(.daemonNotRunning)

        #expect(error.errorDescription?.contains("daemon") == true)
        #expect(error.recoverySuggestion?.contains("Settings") == true)
    }

    @Test func transcriptionErrorFailed() {
        let error = MurmurixError.transcription(.failed("Connection refused"))

        #expect(error.errorDescription?.contains("Connection refused") == true)
        #expect(error.recoverySuggestion != nil)
    }

    @Test func transcriptionErrorTimeout() {
        let error = MurmurixError.transcription(.timeout)

        #expect(error.errorDescription?.contains("timed out") == true)
        #expect(error.recoverySuggestion?.contains("shorter") == true)
    }

    // MARK: - AIError

    @Test func aiErrorNoApiKey() {
        let error = MurmurixError.ai(.noApiKey)

        #expect(error.errorDescription?.contains("API key") == true)
        #expect(error.recoverySuggestion?.contains("Settings") == true)
    }

    @Test func aiErrorInvalidApiKey() {
        let error = MurmurixError.ai(.invalidApiKey)

        #expect(error.errorDescription?.contains("Invalid") == true)
        #expect(error.recoverySuggestion?.contains("API key") == true)
    }

    @Test func aiErrorInvalidResponse() {
        let error = MurmurixError.ai(.invalidResponse)

        #expect(error.errorDescription?.contains("Invalid response") == true)
        #expect(error.recoverySuggestion != nil)
    }

    @Test func aiErrorApiError() {
        let error = MurmurixError.ai(.apiError("Rate limit exceeded"))

        #expect(error.errorDescription?.contains("Rate limit exceeded") == true)
        #expect(error.recoverySuggestion != nil)
    }

    @Test func aiErrorNetworkError() {
        let underlyingError = NSError(domain: "test", code: -1, userInfo: [NSLocalizedDescriptionKey: "No connection"])
        let error = MurmurixError.ai(.networkError(underlyingError))

        #expect(error.errorDescription?.contains("Network") == true)
        #expect(error.recoverySuggestion?.contains("internet") == true)
    }

    // MARK: - DaemonError

    @Test func daemonErrorNotRunning() {
        let error = MurmurixError.daemon(.notRunning)

        #expect(error.errorDescription?.contains("not running") == true)
        #expect(error.recoverySuggestion?.contains("Settings") == true)
    }

    @Test func daemonErrorStartFailed() {
        let error = MurmurixError.daemon(.startFailed("Port in use"))

        #expect(error.errorDescription?.contains("Port in use") == true)
        #expect(error.recoverySuggestion?.contains("Python") == true)
    }

    @Test func daemonErrorCommunicationFailed() {
        let error = MurmurixError.daemon(.communicationFailed)

        #expect(error.errorDescription?.contains("communicate") == true)
        #expect(error.recoverySuggestion?.contains("restart") == true)
    }

    // MARK: - SystemError

    @Test func systemErrorMicrophonePermissionDenied() {
        let error = MurmurixError.system(.microphonePermissionDenied)

        #expect(error.errorDescription?.contains("Microphone") == true)
        #expect(error.recoverySuggestion?.contains("System Settings") == true)
    }

    @Test func systemErrorAccessibilityPermissionDenied() {
        let error = MurmurixError.system(.accessibilityPermissionDenied)

        #expect(error.errorDescription?.contains("Accessibility") == true)
        #expect(error.recoverySuggestion?.contains("System Settings") == true)
    }

    @Test func systemErrorFileNotFound() {
        let error = MurmurixError.system(.fileNotFound("/path/to/file"))

        #expect(error.errorDescription?.contains("/path/to/file") == true)
        #expect(error.recoverySuggestion?.contains("Reinstall") == true)
    }

    @Test func systemErrorUnknown() {
        let underlyingError = NSError(domain: "test", code: 42, userInfo: [NSLocalizedDescriptionKey: "Something went wrong"])
        let error = MurmurixError.system(.unknown(underlyingError))

        #expect(error.errorDescription?.contains("Something went wrong") == true)
        #expect(error.recoverySuggestion?.contains("restart") == true)
    }

    // MARK: - LocalizedError Conformance

    @Test func allErrorsHaveDescriptions() {
        let errors: [MurmurixError] = [
            .transcription(.pythonNotFound),
            .transcription(.scriptNotFound),
            .transcription(.daemonNotRunning),
            .transcription(.failed("test")),
            .transcription(.timeout),
            .ai(.noApiKey),
            .ai(.invalidApiKey),
            .ai(.invalidResponse),
            .ai(.apiError("test")),
            .ai(.networkError(NSError(domain: "", code: 0))),
            .daemon(.notRunning),
            .daemon(.startFailed("test")),
            .daemon(.communicationFailed),
            .system(.microphonePermissionDenied),
            .system(.accessibilityPermissionDenied),
            .system(.fileNotFound("test")),
            .system(.unknown(NSError(domain: "", code: 0)))
        ]

        for error in errors {
            #expect(error.errorDescription != nil, "Error \(error) should have a description")
            #expect(error.recoverySuggestion != nil, "Error \(error) should have a recovery suggestion")
        }
    }
}

// MARK: - AppConstants Tests

struct AppConstantsTests {

    // MARK: - Layout

    @Test func layoutPaddingValuesArePositive() {
        #expect(Layout.Padding.standard > 0)
        #expect(Layout.Padding.small > 0)
        #expect(Layout.Padding.vertical > 0)
        #expect(Layout.Padding.section > 0)
    }

    @Test func layoutCornerRadiusValuesArePositive() {
        #expect(Layout.CornerRadius.card > 0)
        #expect(Layout.CornerRadius.button > 0)
        #expect(Layout.CornerRadius.window > 0)
    }

    @Test func layoutSpacingValuesArePositive() {
        #expect(Layout.Spacing.section > 0)
        #expect(Layout.Spacing.item > 0)
        #expect(Layout.Spacing.tiny > 0)
        #expect(Layout.Spacing.indicator > 0)
    }

    // MARK: - Typography

    @Test func typographyFontsExist() {
        // These should not crash when accessed
        _ = Typography.title
        _ = Typography.label
        _ = Typography.description
        _ = Typography.caption
        _ = Typography.monospaced

        #expect(true) // If we get here, fonts were created successfully
    }

    // MARK: - AppColors

    @Test func appColorsOpacityValuesAreValid() {
        #expect(AppColors.backgroundOpacity >= 0 && AppColors.backgroundOpacity <= 1)
        #expect(AppColors.borderOpacity >= 0 && AppColors.borderOpacity <= 1)
        #expect(AppColors.disabledOpacity >= 0 && AppColors.disabledOpacity <= 1)
        #expect(AppColors.mutedOpacity >= 0 && AppColors.mutedOpacity <= 1)
    }

    @Test func appColorsColorsExist() {
        // These should not crash when accessed
        _ = AppColors.cardBackground
        _ = AppColors.divider

        #expect(true) // If we get here, colors were created successfully
    }

    // MARK: - AudioConfig

    @Test func audioConfigThresholdIsValid() {
        #expect(AudioConfig.voiceActivityThreshold >= 0 && AudioConfig.voiceActivityThreshold <= 1)
    }

    @Test func audioConfigTimingValuesArePositive() {
        #expect(AudioConfig.meterUpdateInterval > 0)
        #expect(AudioConfig.sampleRate > 0)
    }

    // MARK: - NetworkConfig

    @Test func networkConfigTimeoutsArePositive() {
        #expect(NetworkConfig.daemonSocketTimeout > 0)
        #expect(NetworkConfig.daemonStartupTimeout > 0)
        #expect(NetworkConfig.shutdownTimeout > 0)
    }

    // MARK: - AIConfig

    @Test func aiConfigDefaultPromptIsNotEmpty() {
        #expect(!AIConfig.defaultPrompt.isEmpty)
        #expect(AIConfig.defaultPrompt.count > 100) // Should be substantial
    }

    @Test func aiConfigVersionsAreNotEmpty() {
        #expect(!AIConfig.apiVersion.isEmpty)
        #expect(!AIConfig.betaVersion.isEmpty)
    }

    // MARK: - WindowSize

    @Test func windowSizesAreReasonable() {
        #expect(WindowSize.recording.width > 0)
        #expect(WindowSize.recording.height > 0)

        #expect(WindowSize.result.width > 0)
        #expect(WindowSize.result.height > 0)

        #expect(WindowSize.settings.width > 0)
        #expect(WindowSize.settings.height > 0)

        #expect(WindowSize.history.width > 0)
        #expect(WindowSize.history.height > 0)
    }

    // MARK: - AppPaths

    @Test func appPathsAreNotEmpty() {
        #expect(!AppPaths.applicationSupport.isEmpty)
        #expect(!AppPaths.daemonSocket.isEmpty)
        #expect(!AppPaths.historyDatabase.isEmpty)
    }

    @Test func appPathsExpandedPathIsAbsolute() {
        let expanded = AppPaths.expandedApplicationSupport
        #expect(expanded.hasPrefix("/"))
        #expect(expanded.contains("Library/Application Support/Murmurix"))
    }

    @Test func appPathsSocketPathIsAbsolute() {
        let socketPath = AppPaths.socketPath
        #expect(socketPath.hasPrefix("/"))
        #expect(socketPath.contains("daemon.sock"))
    }
}

// MARK: - WindowPositioner Tests

@MainActor
struct WindowPositionerTests {

    @Test func positionTopCenterDoesNotCrash() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        WindowPositioner.positionTopCenter(window)

        // If we get here, no crash occurred
        #expect(true)
    }

    @Test func positionTopCenterWithOffsetDoesNotCrash() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        WindowPositioner.positionTopCenter(window, topOffset: 20)

        #expect(true)
    }

    @Test func centerDoesNotCrash() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        WindowPositioner.center(window)

        #expect(true)
    }

    @Test func centerAndActivateDoesNotCrash() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        WindowPositioner.centerAndActivate(window)

        #expect(true)
    }

    @Test func positionTopCenterPositionsWindowAtTop() {
        guard NSScreen.main != nil else {
            // Skip if no screen available (CI environment)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        WindowPositioner.positionTopCenter(window)

        // Window should be positioned near the top of the screen
        if let screen = NSScreen.main {
            let screenTop = screen.visibleFrame.maxY
            let windowTop = window.frame.maxY

            // Window top should be close to screen top (within offset + small margin)
            #expect(abs(screenTop - windowTop) < 50)
        }
    }
}

// MARK: - Logger Tests

struct LoggerTests {

    @Test func audioLoggerDoesNotCrash() {
        Logger.Audio.info("Test info message")
        Logger.Audio.error("Test error message")
        Logger.Audio.debug("Test debug message")

        #expect(true)
    }

    @Test func transcriptionLoggerDoesNotCrash() {
        Logger.Transcription.info("Test info message")
        Logger.Transcription.error("Test error message")
        Logger.Transcription.debug("Test debug message")

        #expect(true)
    }

    @Test func daemonLoggerDoesNotCrash() {
        Logger.Daemon.info("Test info message")
        Logger.Daemon.error("Test error message")
        Logger.Daemon.warning("Test warning message")
        Logger.Daemon.debug("Test debug message")

        #expect(true)
    }

    @Test func hotkeyLoggerDoesNotCrash() {
        Logger.Hotkey.info("Test info message")
        Logger.Hotkey.error("Test error message")

        #expect(true)
    }

    @Test func historyLoggerDoesNotCrash() {
        Logger.History.error("Test error message")
        Logger.History.debug("Test debug message")

        #expect(true)
    }

    @Test func aiLoggerDoesNotCrash() {
        Logger.AI.error("Test error message")
        Logger.AI.debug("Test debug message")

        #expect(true)
    }
}

// MARK: - WhisperModel Tests

struct WhisperModelTests {

    @Test func allCasesContainsAllModels() {
        let allCases = WhisperModel.allCases

        #expect(allCases.count == 6)
        #expect(allCases.contains(.tiny))
        #expect(allCases.contains(.base))
        #expect(allCases.contains(.small))
        #expect(allCases.contains(.medium))
        #expect(allCases.contains(.largeV2))
        #expect(allCases.contains(.largeV3))
    }

    @Test func displayNamesAreNotEmpty() {
        for model in WhisperModel.allCases {
            #expect(!model.displayName.isEmpty)
        }
    }

    @Test func rawValuesAreUnique() {
        let rawValues = WhisperModel.allCases.map { $0.rawValue }
        let uniqueValues = Set(rawValues)

        #expect(rawValues.count == uniqueValues.count)
    }
}

// MARK: - AIModel Tests

struct AIModelTests {

    @Test func allCasesContainsAllModels() {
        let allCases = AIModel.allCases

        #expect(allCases.count == 3)
        #expect(allCases.contains(.haiku))
        #expect(allCases.contains(.sonnet))
        #expect(allCases.contains(.opus))
    }

    @Test func displayNamesAreNotEmpty() {
        for model in AIModel.allCases {
            #expect(!model.displayName.isEmpty)
        }
    }

    @Test func rawValuesContainClaudeIdentifier() {
        for model in AIModel.allCases {
            #expect(model.rawValue.contains("claude"))
        }
    }
}
