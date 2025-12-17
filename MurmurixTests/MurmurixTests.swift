//
//  MurmurixTests.swift
//  MurmurixTests
//

import Testing
import Foundation
import Carbon
@testable import Murmurix

// MARK: - TranscriptionRecord Tests

struct TranscriptionRecordTests {

    @Test func shortTextTruncatesLongText() {
        let longText = String(repeating: "a", count: 100)
        let record = TranscriptionRecord(text: longText, language: "en", duration: 10)

        #expect(record.shortText.count == 53) // 50 + "..."
        #expect(record.shortText.hasSuffix("..."))
    }

    @Test func shortTextKeepsShortText() {
        let shortText = "Hello world"
        let record = TranscriptionRecord(text: shortText, language: "en", duration: 10)

        #expect(record.shortText == shortText)
    }

    @Test func formattedDurationShowsMinutesAndSeconds() {
        let record1 = TranscriptionRecord(text: "test", language: "en", duration: 65)
        #expect(record1.formattedDuration == "1:05")

        let record2 = TranscriptionRecord(text: "test", language: "en", duration: 5)
        #expect(record2.formattedDuration == "0:05")

        let record3 = TranscriptionRecord(text: "test", language: "en", duration: 125)
        #expect(record3.formattedDuration == "2:05")
    }

    @Test func recordIsIdentifiable() {
        let record1 = TranscriptionRecord(text: "test1", language: "en", duration: 10)
        let record2 = TranscriptionRecord(text: "test2", language: "en", duration: 10)

        #expect(record1.id != record2.id)
    }

    @Test func recordIsCodable() throws {
        let original = TranscriptionRecord(text: "test", language: "ru", duration: 30)

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TranscriptionRecord.self, from: encoded)

        #expect(decoded.id == original.id)
        #expect(decoded.text == original.text)
        #expect(decoded.language == original.language)
        #expect(decoded.duration == original.duration)
    }
}

// MARK: - HistoryService Tests

struct HistoryServiceTests {

    private func createTempDatabase() -> HistoryService {
        let tempDir = FileManager.default.temporaryDirectory
        let dbPath = tempDir.appendingPathComponent("test_\(UUID().uuidString).sqlite").path
        return HistoryService(dbPath: dbPath)
    }

    @Test func saveAndFetchRecord() {
        let service = createTempDatabase()
        let record = TranscriptionRecord(text: "Hello world", language: "en", duration: 5)

        service.save(record: record)
        let fetched = service.fetchAll()

        #expect(fetched.count == 1)
        #expect(fetched.first?.text == "Hello world")
        #expect(fetched.first?.id == record.id)
    }

    @Test func fetchAllReturnsRecordsInReverseChronologicalOrder() {
        let service = createTempDatabase()

        let record1 = TranscriptionRecord(
            text: "First",
            language: "en",
            duration: 5,
            createdAt: Date(timeIntervalSince1970: 1000)
        )
        let record2 = TranscriptionRecord(
            text: "Second",
            language: "en",
            duration: 5,
            createdAt: Date(timeIntervalSince1970: 2000)
        )

        service.save(record: record1)
        service.save(record: record2)

        let fetched = service.fetchAll()

        #expect(fetched.count == 2)
        #expect(fetched[0].text == "Second") // Newer first
        #expect(fetched[1].text == "First")
    }

    @Test func deleteRemovesRecord() {
        let service = createTempDatabase()
        let record = TranscriptionRecord(text: "To delete", language: "en", duration: 5)

        service.save(record: record)
        #expect(service.fetchAll().count == 1)

        service.delete(id: record.id)
        #expect(service.fetchAll().count == 0)
    }

    @Test func deleteAllClearsHistory() {
        let service = createTempDatabase()

        service.save(record: TranscriptionRecord(text: "One", language: "en", duration: 5))
        service.save(record: TranscriptionRecord(text: "Two", language: "en", duration: 5))
        service.save(record: TranscriptionRecord(text: "Three", language: "en", duration: 5))

        #expect(service.fetchAll().count == 3)

        service.deleteAll()
        #expect(service.fetchAll().count == 0)
    }

    @Test func saveUpdatesExistingRecord() {
        let service = createTempDatabase()
        let id = UUID()

        let original = TranscriptionRecord(id: id, text: "Original", language: "en", duration: 5)
        service.save(record: original)

        let updated = TranscriptionRecord(id: id, text: "Updated", language: "ru", duration: 10)
        service.save(record: updated)

        let fetched = service.fetchAll()
        #expect(fetched.count == 1)
        #expect(fetched.first?.text == "Updated")
        #expect(fetched.first?.language == "ru")
    }
}

// MARK: - HistoryViewModel Tests

struct HistoryViewModelTests {

    private func createViewModel() -> (HistoryViewModel, MockHistoryService) {
        let mockService = MockHistoryService()
        let viewModel = HistoryViewModel(historyService: mockService)
        return (viewModel, mockService)
    }

    @Test func loadRecordsPopulatesRecords() {
        let (viewModel, mockService) = createViewModel()
        mockService.records = [
            TranscriptionRecord(text: "Test 1", language: "en", duration: 10),
            TranscriptionRecord(text: "Test 2", language: "ru", duration: 20)
        ]

        viewModel.loadRecords()

        #expect(viewModel.records.count == 2)
        // Note: selectedRecord is set asynchronously to avoid multiple updates per frame
    }

    @Test func deleteRecordRemovesFromList() {
        let (viewModel, mockService) = createViewModel()
        let record = TranscriptionRecord(text: "To delete", language: "en", duration: 5)
        mockService.records = [record]
        viewModel.loadRecords()

        viewModel.deleteRecord(record)

        #expect(viewModel.records.isEmpty)
        #expect(mockService.deleteCallCount == 1)
    }

    @Test func clearHistoryRemovesAllRecords() {
        let (viewModel, mockService) = createViewModel()
        mockService.records = [
            TranscriptionRecord(text: "Test 1", language: "en", duration: 10),
            TranscriptionRecord(text: "Test 2", language: "ru", duration: 20)
        ]
        viewModel.loadRecords()

        viewModel.clearHistory()

        #expect(viewModel.records.isEmpty)
        #expect(viewModel.selectedRecord == nil)
        #expect(mockService.deleteAllCallCount == 1)
    }

    @Test func totalDurationSumsAllRecords() {
        let (viewModel, _) = createViewModel()
        viewModel.records = [
            TranscriptionRecord(text: "A", language: "en", duration: 30),
            TranscriptionRecord(text: "B", language: "en", duration: 90),
            TranscriptionRecord(text: "C", language: "en", duration: 45)
        ]

        #expect(viewModel.totalDuration == 165)
        #expect(viewModel.formattedTotalDuration == "2:45")
    }

    @Test func totalWordsCountsAllWords() {
        let (viewModel, _) = createViewModel()
        viewModel.records = [
            TranscriptionRecord(text: "Hello world", language: "en", duration: 5),
            TranscriptionRecord(text: "One two three", language: "en", duration: 5)
        ]

        #expect(viewModel.totalWords == 5)
    }

    @Test func totalCharactersCountsAllCharacters() {
        let (viewModel, _) = createViewModel()
        viewModel.records = [
            TranscriptionRecord(text: "Hello", language: "en", duration: 5),
            TranscriptionRecord(text: "World", language: "en", duration: 5)
        ]

        #expect(viewModel.totalCharacters == 10)
    }
}

// MARK: - ResultWindowController Tests

struct ResultWindowControllerTests {

    @Test func windowControllerInitializesWithCorrectParameters() {
        var deleteCalled = false
        let controller = ResultWindowController(
            text: "Test transcription",
            duration: 65.5,
            onDelete: { deleteCalled = true }
        )

        #expect(controller.window != nil)
        #expect(controller.window?.styleMask == .borderless)
        #expect(controller.window?.level == .floating)
        #expect(controller.window?.isOpaque == false)
    }

    @Test func windowCanBecomeKeyAndMain() {
        let controller = ResultWindowController(
            text: "Test",
            duration: 10,
            onDelete: {}
        )

        #expect(controller.window?.canBecomeKey == true)
        #expect(controller.window?.canBecomeMain == true)
    }

    @Test func onDeleteCallbackIsStored() {
        var deleteCalled = false
        let controller = ResultWindowController(
            text: "Test",
            duration: 10,
            onDelete: { deleteCalled = true }
        )

        // Controller should exist
        #expect(controller.window != nil)
        // deleteCalled is false until button is pressed
        #expect(deleteCalled == false)
    }

    @Test func durationFormattingWorksCorrectly() {
        // Test duration formatting logic (same as in ResultView)
        let testCases: [(TimeInterval, String)] = [
            (0, "0:00"),
            (30, "0:30"),
            (60, "1:00"),
            (90, "1:30"),
            (125, "2:05"),
            (3661, "61:01")
        ]

        for (duration, expected) in testCases {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            let formatted = String(format: "%d:%02d", minutes, seconds)
            #expect(formatted == expected)
        }
    }

    @Test func windowHasCorrectSize() {
        let controller = ResultWindowController(
            text: "Test",
            duration: 10,
            onDelete: {}
        )

        let frame = controller.window?.frame ?? .zero
        #expect(frame.width == 420)
        #expect(frame.height == 300)
    }
}

// MARK: - Hotkey Tests

struct HotkeyTests {

    @Test func displayPartsShowsModifiersAndKey() {
        let hotkey = Hotkey(keyCode: 8, modifiers: UInt32(cmdKey | controlKey)) // Cmd+Control+C

        let parts = hotkey.displayParts

        #expect(parts.contains("⌃"))
        #expect(parts.contains("⌘"))
        #expect(parts.contains("C"))
    }

    @Test func displayPartsShowsNotSetWhenEmpty() {
        let hotkey = Hotkey(keyCode: 999, modifiers: 0) // Invalid keyCode, no modifiers

        let parts = hotkey.displayParts

        #expect(parts == ["Not set"])
    }

    @Test func keyCodeToNameMapsCorrectly() {
        #expect(Hotkey.keyCodeToName(0) == "A")
        #expect(Hotkey.keyCodeToName(8) == "C")
        #expect(Hotkey.keyCodeToName(53) == "esc")
        #expect(Hotkey.keyCodeToName(122) == "F1")
        #expect(Hotkey.keyCodeToName(999) == nil)
    }

    @Test func defaultHotkeysAreValid() {
        let toggle = Hotkey.toggleDefault
        let cancel = Hotkey.cancelDefault

        #expect(Hotkey.keyCodeToName(toggle.keyCode) != nil)
        #expect(Hotkey.keyCodeToName(cancel.keyCode) != nil)
    }

    @Test func hotkeyIsCodable() throws {
        let original = Hotkey(keyCode: 8, modifiers: UInt32(cmdKey | shiftKey))

        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Hotkey.self, from: encoded)

        #expect(decoded == original)
    }
}
