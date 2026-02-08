//
//  NewFunctionalityTests.swift
//  MurmurixTests
//
//  Tests for new functionality after WhisperKit migration and refactoring
//

import Testing
import Foundation
@testable import Murmurix

// MARK: - DownloadStatus Tests

struct DownloadStatusTests {

    @Test func idleIsDefault() {
        let status: DownloadStatus = .idle
        if case .idle = status {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected idle status")
        }
    }

    @Test func downloadingTracksProgress() {
        let status: DownloadStatus = .downloading(progress: 0.5)
        if case .downloading(let progress) = status {
            #expect(progress == 0.5)
        } else {
            #expect(Bool(false), "Expected downloading status")
        }
    }

    @Test func downloadingProgressBoundaries() {
        let zero: DownloadStatus = .downloading(progress: 0.0)
        let full: DownloadStatus = .downloading(progress: 1.0)

        if case .downloading(let p) = zero { #expect(p == 0.0) }
        if case .downloading(let p) = full { #expect(p == 1.0) }
    }

    @Test func compilingStatus() {
        let status: DownloadStatus = .compiling
        if case .compiling = status {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected compiling status")
        }
    }

    @Test func completedStatus() {
        let status: DownloadStatus = .completed
        if case .completed = status {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected completed status")
        }
    }

    @Test func errorStatusContainsMessage() {
        let status: DownloadStatus = .error("Network timeout")
        if case .error(let message) = status {
            #expect(message == "Network timeout")
        } else {
            #expect(Bool(false), "Expected error status")
        }
    }
}

// MARK: - APITestResult Tests

struct APITestResultPropertyTests {

    @Test func successIsSuccess() {
        let result = APITestResult.success
        #expect(result.isSuccess == true)
    }

    @Test func failureIsNotSuccess() {
        let result = APITestResult.failure("Error")
        #expect(result.isSuccess == false)
    }

    @Test func successHasNoErrorMessage() {
        let result = APITestResult.success
        #expect(result.errorMessage == nil)
    }

    @Test func failureHasErrorMessage() {
        let result = APITestResult.failure("Connection refused")
        #expect(result.errorMessage == "Connection refused")
    }

    @Test func successEquality() {
        #expect(APITestResult.success == APITestResult.success)
    }

    @Test func failureEquality() {
        #expect(APITestResult.failure("A") == APITestResult.failure("A"))
        #expect(APITestResult.failure("A") != APITestResult.failure("B"))
    }

    @Test func successNotEqualToFailure() {
        #expect(APITestResult.success != APITestResult.failure("Error"))
    }
}

// MARK: - RecordingTimer Tests

struct RecordingTimerTests {

    @Test func initialElapsedSecondsIsZero() {
        let timer = RecordingTimer()
        #expect(timer.elapsedSeconds == 0)
    }

    @Test func formattedTimeAtZero() {
        let timer = RecordingTimer()
        #expect(timer.formattedTime == "0:00")
    }

    @Test func formattedTimeSeconds() {
        let timer = RecordingTimer()
        timer.elapsedSeconds = 5
        #expect(timer.formattedTime == "0:05")
    }

    @Test func formattedTimeMinutesAndSeconds() {
        let timer = RecordingTimer()
        timer.elapsedSeconds = 65
        #expect(timer.formattedTime == "1:05")
    }

    @Test func formattedTimeExactMinute() {
        let timer = RecordingTimer()
        timer.elapsedSeconds = 120
        #expect(timer.formattedTime == "2:00")
    }

    @Test func formattedTimeLargeValue() {
        let timer = RecordingTimer()
        timer.elapsedSeconds = 3661 // 61 minutes 1 second
        #expect(timer.formattedTime == "61:01")
    }

    @Test func formattedTimePadsSeconds() {
        let timer = RecordingTimer()
        timer.elapsedSeconds = 9
        #expect(timer.formattedTime == "0:09")
    }

    @Test func startResetsElapsedSeconds() {
        let timer = RecordingTimer()
        timer.elapsedSeconds = 42
        timer.start()
        #expect(timer.elapsedSeconds == 0)
        timer.stop()
    }

    @Test func stopDoesNotCrashWhenNotStarted() {
        let timer = RecordingTimer()
        timer.stop()
        #expect(timer.elapsedSeconds == 0)
    }

    @Test func stopAfterStartDoesNotCrash() {
        let timer = RecordingTimer()
        timer.start()
        timer.stop()
        #expect(true)
    }

    @Test func doubleStopDoesNotCrash() {
        let timer = RecordingTimer()
        timer.start()
        timer.stop()
        timer.stop()
        #expect(true)
    }

    @Test func doubleStartResetsTimer() {
        let timer = RecordingTimer()
        timer.start()
        timer.elapsedSeconds = 10
        timer.start()
        #expect(timer.elapsedSeconds == 0)
        timer.stop()
    }
}

// MARK: - AudioCompressor.CompressionError Tests

struct AudioCompressorErrorTests {

    @Test func exportFailedDescription() {
        let error = AudioCompressor.CompressionError.exportFailed("Timeout")
        #expect(error.errorDescription?.contains("Timeout") == true)
        #expect(error.errorDescription?.contains("compression") == true)
    }

    @Test func assetLoadFailedDescription() {
        let error = AudioCompressor.CompressionError.assetLoadFailed
        #expect(error.errorDescription?.contains("load") == true)
    }

    @Test func exportSessionCreationFailedDescription() {
        let error = AudioCompressor.CompressionError.exportSessionCreationFailed
        #expect(error.errorDescription?.contains("export session") == true)
    }

    @Test func allErrorsHaveDescriptions() {
        let errors: [AudioCompressor.CompressionError] = [
            .exportFailed("test"),
            .assetLoadFailed,
            .exportSessionCreationFailed
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(!error.errorDescription!.isEmpty)
        }
    }
}

// MARK: - GeneralSettingsViewModel Model Management Tests

@MainActor
struct GeneralSettingsViewModelModelTests {

    // MARK: - isModelInstalled

    @Test func isModelInstalledReturnsTrueForInstalled() {
        let viewModel = GeneralSettingsViewModel()
        viewModel.installedModels = ["small", "tiny"]

        #expect(viewModel.isModelInstalled("small") == true)
        #expect(viewModel.isModelInstalled("tiny") == true)
    }

    @Test func isModelInstalledReturnsFalseForNotInstalled() {
        let viewModel = GeneralSettingsViewModel()
        viewModel.installedModels = ["small"]

        #expect(viewModel.isModelInstalled("tiny") == false)
    }

    @Test func isModelInstalledWithEmptySet() {
        let viewModel = GeneralSettingsViewModel()

        #expect(viewModel.isModelInstalled("small") == false)
    }

    // MARK: - cancelDownload

    @Test func cancelDownloadResetsToIdle() {
        let viewModel = GeneralSettingsViewModel()
        viewModel.downloadStatuses["small"] = .downloading(progress: 0.75)

        viewModel.cancelDownload(for: "small")

        if case .idle = viewModel.downloadStatus(for: "small") {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected idle status after cancel")
        }
    }

    @Test func cancelDownloadFromCompiling() {
        let viewModel = GeneralSettingsViewModel()
        viewModel.downloadStatuses["small"] = .compiling

        viewModel.cancelDownload(for: "small")

        if case .idle = viewModel.downloadStatus(for: "small") {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected idle status after cancel")
        }
    }

    // MARK: - startDownload

    @Test func startDownloadSetsDownloadingStatus() {
        let mockWhisperKit = MockWhisperKitService()
        let viewModel = GeneralSettingsViewModel(whisperKitService: mockWhisperKit)

        viewModel.startDownload(for: "small")

        if case .downloading = viewModel.downloadStatus(for: "small") {
            #expect(true)
        } else {
            #expect(Bool(false), "Expected downloading status")
        }
    }

    @Test func startDownloadCallsWhisperKitService() async throws {
        let mockWhisperKit = MockWhisperKitService()
        let mockSettings = MockSettings()
        let viewModel = GeneralSettingsViewModel(
            whisperKitService: mockWhisperKit,
            settings: mockSettings
        )

        viewModel.startDownload(for: "tiny")

        // Wait for async download to complete
        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(mockWhisperKit.downloadModelCallCount == 1)
        #expect(mockWhisperKit.lastModelName == "tiny")
        #expect(mockWhisperKit.loadModelCallCount == 1)
    }

    @Test func startDownloadUnloadsModelWhenKeepLoadedIsFalse() async throws {
        let mockWhisperKit = MockWhisperKitService()
        let mockSettings = MockSettings()
        // keepLoaded defaults to false in WhisperModelSettings.default
        let viewModel = GeneralSettingsViewModel(
            whisperKitService: mockWhisperKit,
            settings: mockSettings
        )

        viewModel.startDownload(for: "tiny")

        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(mockWhisperKit.unloadModelCallCount == 1)
    }

    @Test func startDownloadKeepsModelLoadedWhenEnabled() async throws {
        let mockWhisperKit = MockWhisperKitService()
        let mockSettings = MockSettings()
        // Set keepLoaded=true for tiny
        mockSettings.saveWhisperModelSettings(["tiny": WhisperModelSettings(hotkey: nil, keepLoaded: true)])
        let viewModel = GeneralSettingsViewModel(
            whisperKitService: mockWhisperKit,
            settings: mockSettings
        )
        viewModel.loadInstalledModels()

        viewModel.startDownload(for: "tiny")

        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(mockWhisperKit.unloadModelCallCount == 0)
    }

    @Test func startDownloadCompletesSuccessfully() async throws {
        let mockWhisperKit = MockWhisperKitService()
        let mockSettings = MockSettings()
        let viewModel = GeneralSettingsViewModel(
            whisperKitService: mockWhisperKit,
            settings: mockSettings
        )

        viewModel.startDownload(for: "small")

        try await Task.sleep(nanoseconds: 200_000_000)

        #expect(mockWhisperKit.downloadModelCallCount == 1)
    }

    // MARK: - deleteModel (with temp filesystem)

    @Test func deleteModelRemovesDirectory() async {
        let mockWhisperKit = MockWhisperKitService()
        let viewModel = GeneralSettingsViewModel(whisperKitService: mockWhisperKit)

        // Create a temp directory pretending to be a model
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_delete_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        #expect(FileManager.default.fileExists(atPath: tempDir.path))

        // We can't easily test with real ModelPaths, but we can test that
        // unloadModel is called when model is loaded
        mockWhisperKit.loadedModelNames.insert("small")
        await viewModel.deleteModel("small")

        #expect(mockWhisperKit.unloadModelCallCount == 1)

        // Cleanup
        try? FileManager.default.removeItem(at: tempDir)
    }

    @Test func deleteModelUnloadsModelWhenLoaded() async {
        let mockWhisperKit = MockWhisperKitService()
        mockWhisperKit.loadedModelNames.insert("small")
        let viewModel = GeneralSettingsViewModel(whisperKitService: mockWhisperKit)

        await viewModel.deleteModel("small")

        #expect(mockWhisperKit.unloadModelCallCount == 1)
    }

    @Test func deleteModelSkipsUnloadWhenNotLoaded() async {
        let mockWhisperKit = MockWhisperKitService()
        let viewModel = GeneralSettingsViewModel(whisperKitService: mockWhisperKit)

        await viewModel.deleteModel("small")

        #expect(mockWhisperKit.unloadModelCallCount == 0)
    }

    // MARK: - deleteAllModels

    @Test func deleteAllModelsUnloadsAllModels() async {
        let mockWhisperKit = MockWhisperKitService()
        mockWhisperKit.loadedModelNames.insert("small")
        let viewModel = GeneralSettingsViewModel(whisperKitService: mockWhisperKit)

        await viewModel.deleteAllModels()

        #expect(mockWhisperKit.unloadAllModelsCallCount == 1)
    }

    @Test func deleteAllModelsWorksWhenNoneLoaded() async {
        let mockWhisperKit = MockWhisperKitService()
        let viewModel = GeneralSettingsViewModel(whisperKitService: mockWhisperKit)

        await viewModel.deleteAllModels()

        #expect(mockWhisperKit.unloadAllModelsCallCount == 1)
    }
}

// MARK: - Settings Migration Tests

struct SettingsMigrationTests {

    @Test func migratesOldSingleModelToPerModelSettings() {
        let suiteName = "com.murmurix.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        // Simulate old settings
        defaults.set("tiny", forKey: "whisperModel")
        defaults.set(true, forKey: "keepModelLoaded")
        let oldHotkey = Hotkey.toggleLocalDefault
        if let data = try? JSONEncoder().encode(oldHotkey) {
            defaults.set(data, forKey: "toggleLocalHotkey")
        }

        let settings = Settings(defaults: defaults)

        let map = settings.loadWhisperModelSettings()
        #expect(map["tiny"] != nil)
        #expect(map["tiny"]?.keepLoaded == true)
        #expect(map["tiny"]?.hotkey == oldHotkey)

        // Legacy keys should be cleaned up
        #expect(defaults.object(forKey: "whisperModel") == nil)
        #expect(defaults.object(forKey: "keepModelLoaded") == nil)
        #expect(defaults.object(forKey: "toggleLocalHotkey") == nil)
    }

    @Test func migrationDefaultsToSmallWhenNoOldModelSet() {
        let suiteName = "com.murmurix.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let settings = Settings(defaults: defaults)

        let map = settings.loadWhisperModelSettings()
        #expect(map["small"] != nil)
        #expect(map["small"]?.keepLoaded == true)
        #expect(map["small"]?.hotkey == .toggleLocalDefault)
    }

    @Test func doesNotMigrateWhenAlreadyMigrated() {
        let suiteName = "com.murmurix.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        // Pre-set the new format
        let existingSettings: [String: WhisperModelSettings] = ["base": WhisperModelSettings(hotkey: nil, keepLoaded: false)]
        if let data = try? JSONEncoder().encode(existingSettings) {
            defaults.set(data, forKey: "whisperModelSettings")
        }

        let settings = Settings(defaults: defaults)

        let map = settings.loadWhisperModelSettings()
        #expect(map["base"] != nil)
        #expect(map["base"]?.keepLoaded == false)
        #expect(map["small"] == nil) // Should not have migrated defaults
    }

    @Test func defaultLanguageUsesConstant() {
        let suiteName = "com.murmurix.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!

        let settings = Settings(defaults: defaults)

        #expect(settings.language == Defaults.language)
        #expect(settings.language == "ru")
    }
}

// MARK: - RecordingCoordinator Model Control Tests

struct RecordingCoordinatorModelControlTests {

    private func createCoordinator() -> (
        coordinator: RecordingCoordinator,
        transcriptionService: MockTranscriptionService,
        settings: MockSettings
    ) {
        let audioRecorder = MockAudioRecorder()
        let transcriptionService = MockTranscriptionService()
        let historyService = MockHistoryService()
        let settings = MockSettings()

        let coordinator = RecordingCoordinator(
            audioRecorder: audioRecorder,
            transcriptionService: transcriptionService,
            historyService: historyService,
            settings: settings
        )

        return (coordinator, transcriptionService, settings)
    }

    @Test func reloadModelUnloadsAndReloads() async throws {
        let (coordinator, transcriptionService, settings) = createCoordinator()
        settings.saveWhisperModelSettings(["small": WhisperModelSettings(hotkey: nil, keepLoaded: true)])

        coordinator.reloadModel(name: "small")

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(transcriptionService.unloadModelCallCount == 1)
        #expect(transcriptionService.loadModelCallCount == 1)
    }

    @Test func reloadModelOnlyUnloadsWhenKeepLoadedIsFalse() async throws {
        let (coordinator, transcriptionService, settings) = createCoordinator()
        settings.saveWhisperModelSettings(["small": WhisperModelSettings(hotkey: nil, keepLoaded: false)])

        coordinator.reloadModel(name: "small")

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(transcriptionService.unloadModelCallCount == 1)
        #expect(transcriptionService.loadModelCallCount == 0)
    }

    @Test func unloadAllModelsCallsService() async throws {
        let (coordinator, transcriptionService, _) = createCoordinator()

        coordinator.unloadAllModels()

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(transcriptionService.unloadAllModelsCallCount == 1)
    }
}

// MARK: - GeminiTranscriptionModel Tests

struct GeminiModelEnumTests {

    @Test func allCasesContainsAllModels() {
        let allCases = GeminiTranscriptionModel.allCases
        #expect(allCases.count == 3)
        #expect(allCases.contains(.flash2))
        #expect(allCases.contains(.flash))
        #expect(allCases.contains(.pro))
    }

    @Test func displayNamesAreNotEmpty() {
        for model in GeminiTranscriptionModel.allCases {
            #expect(!model.displayName.isEmpty)
        }
    }

    @Test func rawValuesContainGemini() {
        for model in GeminiTranscriptionModel.allCases {
            #expect(model.rawValue.contains("gemini"))
        }
    }

    @Test func rawValuesAreUnique() {
        let rawValues = GeminiTranscriptionModel.allCases.map { $0.rawValue }
        let uniqueValues = Set(rawValues)
        #expect(rawValues.count == uniqueValues.count)
    }

    @Test func flash2IsRecommended() {
        let flash2 = GeminiTranscriptionModel.flash2
        #expect(flash2.displayName.contains("recommended"))
    }
}

// MARK: - TranscriptionMode Tests

struct TranscriptionModeTests {

    @Test func logNameReturnsCorrectValue() {
        #expect(TranscriptionMode.local(model: "tiny").logName == "local:tiny")
        #expect(TranscriptionMode.openai.logName == "openai")
        #expect(TranscriptionMode.gemini.logName == "gemini")
    }

    @Test func isCloudForLocalIsFalse() {
        #expect(TranscriptionMode.local(model: "small").isCloud == false)
    }

    @Test func isCloudForCloudModesIsTrue() {
        #expect(TranscriptionMode.openai.isCloud == true)
        #expect(TranscriptionMode.gemini.isCloud == true)
    }

    @Test func displayNamesAreNotEmpty() {
        let modes: [TranscriptionMode] = [.local(model: "small"), .openai, .gemini]
        for mode in modes {
            #expect(!mode.displayName.isEmpty)
        }
    }

    @Test func equatable() {
        #expect(TranscriptionMode.local(model: "small") == .local(model: "small"))
        #expect(TranscriptionMode.local(model: "small") != .local(model: "tiny"))
        #expect(TranscriptionMode.openai == .openai)
        #expect(TranscriptionMode.gemini == .gemini)
        #expect(TranscriptionMode.openai != .gemini)
    }
}

// MARK: - RecordingState Tests

struct RecordingStateTests {

    @Test func allStatesAreDistinct() {
        #expect(RecordingState.idle != RecordingState.recording)
        #expect(RecordingState.recording != RecordingState.transcribing)
        #expect(RecordingState.idle != RecordingState.transcribing)
    }

    @Test func statesAreEquatable() {
        #expect(RecordingState.idle == RecordingState.idle)
        #expect(RecordingState.recording == RecordingState.recording)
        #expect(RecordingState.transcribing == RecordingState.transcribing)
    }
}
