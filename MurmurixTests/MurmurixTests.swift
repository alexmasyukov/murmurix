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
