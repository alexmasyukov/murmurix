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

    @Test func transcriptionErrorModelNotLoaded() {
        let error = MurmurixError.transcription(.modelNotLoaded)

        #expect(error.errorDescription?.contains("not loaded") == true)
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

    // MARK: - ModelError

    @Test func modelErrorDownloadFailed() {
        let error = MurmurixError.model(.downloadFailed("Network error"))

        #expect(error.errorDescription?.contains("Network error") == true)
        #expect(error.recoverySuggestion?.contains("internet") == true)
    }

    @Test func modelErrorLoadFailed() {
        let error = MurmurixError.model(.loadFailed("Out of memory"))

        #expect(error.errorDescription?.contains("Out of memory") == true)
        #expect(error.recoverySuggestion?.contains("restart") == true)
    }

    @Test func modelErrorNotFound() {
        let error = MurmurixError.model(.notFound("tiny"))

        #expect(error.errorDescription?.contains("tiny") == true)
        #expect(error.recoverySuggestion?.contains("Download") == true)
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
            .transcription(.modelNotLoaded),
            .transcription(.failed("test")),
            .transcription(.timeout),
            .model(.downloadFailed("test")),
            .model(.loadFailed("test")),
            .model(.notFound("test")),
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
        #expect(!AppPaths.historyDatabase.isEmpty)
    }

    @Test func appPathsExpandedPathIsAbsolute() {
        let expanded = AppPaths.expandedApplicationSupport
        #expect(expanded.hasPrefix("/"))
        #expect(expanded.contains("Library/Application Support/Murmurix"))
    }

    // MARK: - Defaults

    @Test func defaultLanguageIsRussian() {
        #expect(Defaults.language == "ru")
    }

    // MARK: - ModelPaths

    @Test func modelPathsRepoDirPointsToDocuments() {
        let repoDir = ModelPaths.repoDir
        #expect(repoDir.path.contains("Documents"))
        #expect(repoDir.path.contains("huggingface/models/argmaxinc/whisperkit-coreml"))
    }

    @Test func modelPathsModelDirAppendsModelName() {
        let modelDir = ModelPaths.modelDir(for: "small")
        #expect(modelDir.lastPathComponent == "openai_whisper-small")
        #expect(modelDir.path.contains("whisperkit-coreml"))
    }

    @Test func modelPathsRepoSubpathIsCorrect() {
        #expect(ModelPaths.repoSubpath == "huggingface/models/argmaxinc/whisperkit-coreml")
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

    @Test func modelLoggerDoesNotCrash() {
        Logger.Model.info("Test info message")
        Logger.Model.error("Test error message")
        Logger.Model.warning("Test warning message")
        Logger.Model.debug("Test debug message")

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

// MARK: - OpenAITranscriptionModel Tests

struct OpenAITranscriptionModelTests {

    @Test func allCasesContainsAllModels() {
        let allCases = OpenAITranscriptionModel.allCases

        #expect(allCases.count == 2)
        #expect(allCases.contains(.gpt4oTranscribe))
        #expect(allCases.contains(.gpt4oMiniTranscribe))
    }

    @Test func displayNamesAreNotEmpty() {
        for model in OpenAITranscriptionModel.allCases {
            #expect(!model.displayName.isEmpty)
        }
    }

    @Test func rawValuesContainGpt() {
        for model in OpenAITranscriptionModel.allCases {
            #expect(model.rawValue.contains("gpt"))
        }
    }

    @Test func rawValuesAreUnique() {
        let rawValues = OpenAITranscriptionModel.allCases.map { $0.rawValue }
        let uniqueValues = Set(rawValues)

        #expect(rawValues.count == uniqueValues.count)
    }
}

// MARK: - SQLiteDatabase Tests

struct SQLiteDatabaseTests {

    private func createTempDatabase() -> SQLiteDatabase {
        let tempDir = FileManager.default.temporaryDirectory
        let dbPath = tempDir.appendingPathComponent("test_db_\(UUID().uuidString).sqlite").path
        return SQLiteDatabase(path: dbPath)
    }

    @Test func databaseCreatesAndOpens() {
        let db = createTempDatabase()
        #expect(db.path.contains(".sqlite"))
    }

    @Test func executeCreatesTable() {
        let db = createTempDatabase()

        db.execute("""
            CREATE TABLE IF NOT EXISTS test_table (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL
            )
        """)

        // Verify table exists by inserting a row
        if let statement = db.prepareStatement("INSERT INTO test_table (id, name) VALUES (?, ?)") {
            db.bindText(statement, index: 1, value: "1")
            db.bindText(statement, index: 2, value: "Test")
            let success = db.step(statement)
            db.finalize(statement)
            #expect(success)
        }
    }

    @Test func bindAndRetrieveText() {
        let db = createTempDatabase()
        db.execute("CREATE TABLE test (value TEXT)")

        if let insertStmt = db.prepareStatement("INSERT INTO test (value) VALUES (?)") {
            db.bindText(insertStmt, index: 1, value: "Hello World")
            db.step(insertStmt)
            db.finalize(insertStmt)
        }

        if let selectStmt = db.prepareStatement("SELECT value FROM test") {
            let hasRow = db.stepRow(selectStmt)
            #expect(hasRow)

            let value = db.columnText(selectStmt, index: 0)
            #expect(value == "Hello World")
            db.finalize(selectStmt)
        }
    }

    @Test func bindAndRetrieveDouble() {
        let db = createTempDatabase()
        db.execute("CREATE TABLE test (value REAL)")

        if let insertStmt = db.prepareStatement("INSERT INTO test (value) VALUES (?)") {
            db.bindDouble(insertStmt, index: 1, value: 3.14159)
            db.step(insertStmt)
            db.finalize(insertStmt)
        }

        if let selectStmt = db.prepareStatement("SELECT value FROM test") {
            let hasRow = db.stepRow(selectStmt)
            #expect(hasRow)

            let value = db.columnDouble(selectStmt, index: 0)
            #expect(abs(value - 3.14159) < 0.0001)
            db.finalize(selectStmt)
        }
    }
}

// MARK: - SQLiteTranscriptionRepository Tests

struct SQLiteTranscriptionRepositoryTests {

    private func createTempRepository() -> SQLiteTranscriptionRepository {
        let tempDir = FileManager.default.temporaryDirectory
        let dbPath = tempDir.appendingPathComponent("test_repo_\(UUID().uuidString).sqlite").path
        return SQLiteTranscriptionRepository(dbPath: dbPath)
    }

    @Test func saveAndFetchRecord() {
        let repo = createTempRepository()
        let record = TranscriptionRecord(text: "Hello", language: "en", duration: 5)

        repo.save(record)
        let fetched = repo.fetchAll()

        #expect(fetched.count == 1)
        #expect(fetched.first?.text == "Hello")
        #expect(fetched.first?.id == record.id)
    }

    @Test func fetchAllReturnsInReverseChronologicalOrder() {
        let repo = createTempRepository()

        let old = TranscriptionRecord(
            text: "Old",
            language: "en",
            duration: 5,
            createdAt: Date(timeIntervalSince1970: 1000)
        )
        let new = TranscriptionRecord(
            text: "New",
            language: "en",
            duration: 5,
            createdAt: Date(timeIntervalSince1970: 2000)
        )

        repo.save(old)
        repo.save(new)

        let fetched = repo.fetchAll()

        #expect(fetched.count == 2)
        #expect(fetched[0].text == "New")
        #expect(fetched[1].text == "Old")
    }

    @Test func deleteRemovesRecord() {
        let repo = createTempRepository()
        let record = TranscriptionRecord(text: "Delete me", language: "en", duration: 5)

        repo.save(record)
        #expect(repo.fetchAll().count == 1)

        repo.delete(id: record.id)
        #expect(repo.fetchAll().count == 0)
    }

    @Test func deleteAllClearsAllRecords() {
        let repo = createTempRepository()

        repo.save(TranscriptionRecord(text: "One", language: "en", duration: 5))
        repo.save(TranscriptionRecord(text: "Two", language: "en", duration: 5))
        repo.save(TranscriptionRecord(text: "Three", language: "en", duration: 5))

        #expect(repo.fetchAll().count == 3)

        repo.deleteAll()
        #expect(repo.fetchAll().count == 0)
    }

    @Test func saveUpdatesExistingRecord() {
        let repo = createTempRepository()
        let id = UUID()

        let original = TranscriptionRecord(id: id, text: "Original", language: "en", duration: 5)
        repo.save(original)

        let updated = TranscriptionRecord(id: id, text: "Updated", language: "ru", duration: 10)
        repo.save(updated)

        let fetched = repo.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched.first?.text == "Updated")
        #expect(fetched.first?.language == "ru")
    }
}

// MARK: - Dependency Injection Tests

struct DependencyInjectionTests {

    @Test func transcriptionServiceAcceptsDependencies() {
        let mockSettings = MockSettings()

        let mockWhisperKit = MockWhisperKitService()
        let service = TranscriptionService(whisperKitService: mockWhisperKit, settings: mockSettings)

        #expect(type(of: service) == TranscriptionService.self)
    }

    @Test func globalHotkeyManagerAcceptsSettings() {
        let mockSettings = MockSettings()

        let manager = GlobalHotkeyManager(settings: mockSettings)

        #expect(manager.isRecording == false)
    }

    @Test func historyServiceAcceptsRepository() {
        let tempDir = FileManager.default.temporaryDirectory
        let dbPath = tempDir.appendingPathComponent("test_di_\(UUID().uuidString).sqlite").path
        let repository = SQLiteTranscriptionRepository(dbPath: dbPath)

        let service = HistoryService(repository: repository)

        // Should work with injected repository
        let record = TranscriptionRecord(text: "Test", language: "en", duration: 5)
        service.save(record: record)

        #expect(service.fetchAll().count == 1)
    }
}
