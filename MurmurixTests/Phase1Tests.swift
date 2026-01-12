//
//  Phase1Tests.swift
//  MurmurixTests
//
//  Tests for Phase 1 refactoring: AudioTestUtility, MIMETypeResolver, and new mocks
//

import Testing
import Foundation
@testable import Murmurix

// MARK: - AudioTestUtility Tests

struct AudioTestUtilityTests {

    // MARK: - createWavData Tests

    @Test func createWavDataReturnsValidData() {
        let data = AudioTestUtility.createWavData()

        // WAV header is at least 44 bytes
        #expect(data.count >= 44)
    }

    @Test func createWavDataStartsWithRIFFHeader() {
        let data = AudioTestUtility.createWavData()

        let headerString = String(data: data.prefix(4), encoding: .ascii)
        #expect(headerString == "RIFF")
    }

    @Test func createWavDataContainsWAVEFormat() {
        let data = AudioTestUtility.createWavData()

        // WAVE is at offset 8
        let waveString = String(data: data[8..<12], encoding: .ascii)
        #expect(waveString == "WAVE")
    }

    @Test func createWavDataContainsFmtChunk() {
        let data = AudioTestUtility.createWavData()

        // "fmt " is at offset 12
        let fmtString = String(data: data[12..<16], encoding: .ascii)
        #expect(fmtString == "fmt ")
    }

    @Test func createWavDataContainsDataChunk() {
        let data = AudioTestUtility.createWavData()

        // "data" is at offset 36
        let dataString = String(data: data[36..<40], encoding: .ascii)
        #expect(dataString == "data")
    }

    @Test func createWavDataSizeIncreasesWithDuration() {
        let shortData = AudioTestUtility.createWavData(duration: 0.1)
        let longData = AudioTestUtility.createWavData(duration: 1.0)

        #expect(longData.count > shortData.count)
    }

    @Test func createWavDataSizeIncreasesWithSampleRate() {
        let lowSampleRate = AudioTestUtility.createWavData(sampleRate: 8000)
        let highSampleRate = AudioTestUtility.createWavData(sampleRate: 44100)

        #expect(highSampleRate.count > lowSampleRate.count)
    }

    @Test func createWavDataWithDefaultParameters() {
        let data = AudioTestUtility.createWavData()

        // Default: 0.1s @ 16000 Hz, 16-bit mono
        // Expected samples: 0.1 * 16000 = 1600
        // Expected data size: 1600 * 2 = 3200 bytes
        // Total: 44 (header) + 3200 = 3244 bytes
        let expectedSize = 44 + Int(0.1 * 16000) * 2
        #expect(data.count == expectedSize)
    }

    @Test func createWavDataWithCustomDuration() {
        let data = AudioTestUtility.createWavData(duration: 0.5, sampleRate: 16000)

        // 0.5s @ 16000 Hz = 8000 samples * 2 bytes = 16000 + 44 header
        let expectedSize = 44 + Int(0.5 * 16000) * 2
        #expect(data.count == expectedSize)
    }

    // MARK: - createSilentWavFile Tests

    @Test func createSilentWavFileCreatesFile() throws {
        let tempURL = AudioTestUtility.createTemporaryTestAudioURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try AudioTestUtility.createSilentWavFile(at: tempURL)

        #expect(FileManager.default.fileExists(atPath: tempURL.path))
    }

    @Test func createSilentWavFileHasCorrectContent() throws {
        let tempURL = AudioTestUtility.createTemporaryTestAudioURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try AudioTestUtility.createSilentWavFile(at: tempURL, duration: 0.2, sampleRate: 16000)

        let fileData = try Data(contentsOf: tempURL)
        let expectedData = AudioTestUtility.createWavData(duration: 0.2, sampleRate: 16000)

        #expect(fileData == expectedData)
    }

    @Test func createSilentWavFileWithCustomParameters() throws {
        let tempURL = AudioTestUtility.createTemporaryTestAudioURL()
        defer { try? FileManager.default.removeItem(at: tempURL) }

        try AudioTestUtility.createSilentWavFile(at: tempURL, duration: 1.0, sampleRate: 44100)

        let fileData = try Data(contentsOf: tempURL)
        // 1.0s @ 44100 Hz = 44100 * 2 bytes + 44 header
        let expectedSize = 44 + 44100 * 2
        #expect(fileData.count == expectedSize)
    }

    // MARK: - createTemporaryTestAudioURL Tests

    @Test func createTemporaryTestAudioURLReturnsWavURL() {
        let url = AudioTestUtility.createTemporaryTestAudioURL()

        #expect(url.pathExtension == "wav")
    }

    @Test func createTemporaryTestAudioURLIsInTempDirectory() {
        let url = AudioTestUtility.createTemporaryTestAudioURL()
        let tempDir = FileManager.default.temporaryDirectory.path

        #expect(url.path.hasPrefix(tempDir))
    }

    @Test func createTemporaryTestAudioURLReturnsUniqueURLs() {
        let url1 = AudioTestUtility.createTemporaryTestAudioURL()
        let url2 = AudioTestUtility.createTemporaryTestAudioURL()

        #expect(url1 != url2)
    }

    @Test func createTemporaryTestAudioURLContainsTestPrefix() {
        let url = AudioTestUtility.createTemporaryTestAudioURL()

        #expect(url.lastPathComponent.hasPrefix("test_audio_"))
    }
}

// MARK: - MIMETypeResolver Tests

struct MIMETypeResolverTests {

    // MARK: - Audio Format Tests

    @Test func mimeTypeForMP3() {
        let mimeType = MIMETypeResolver.mimeType(for: "mp3")
        #expect(mimeType == "audio/mpeg")
    }

    @Test func mimeTypeForMP4() {
        let mimeType = MIMETypeResolver.mimeType(for: "mp4")
        #expect(mimeType == "audio/mp4")
    }

    @Test func mimeTypeForM4A() {
        let mimeType = MIMETypeResolver.mimeType(for: "m4a")
        #expect(mimeType == "audio/mp4")
    }

    @Test func mimeTypeForWAV() {
        let mimeType = MIMETypeResolver.mimeType(for: "wav")
        #expect(mimeType == "audio/wav")
    }

    @Test func mimeTypeForWEBM() {
        let mimeType = MIMETypeResolver.mimeType(for: "webm")
        #expect(mimeType == "audio/webm")
    }

    @Test func mimeTypeForOGG() {
        let mimeType = MIMETypeResolver.mimeType(for: "ogg")
        #expect(mimeType == "audio/ogg")
    }

    @Test func mimeTypeForFLAC() {
        let mimeType = MIMETypeResolver.mimeType(for: "flac")
        #expect(mimeType == "audio/flac")
    }

    @Test func mimeTypeForMPEG() {
        let mimeType = MIMETypeResolver.mimeType(for: "mpeg")
        #expect(mimeType == "audio/mpeg")
    }

    @Test func mimeTypeForMPGA() {
        let mimeType = MIMETypeResolver.mimeType(for: "mpga")
        #expect(mimeType == "audio/mpeg")
    }

    // MARK: - Case Insensitivity Tests

    @Test func mimeTypeIsCaseInsensitive() {
        #expect(MIMETypeResolver.mimeType(for: "MP3") == "audio/mpeg")
        #expect(MIMETypeResolver.mimeType(for: "Mp3") == "audio/mpeg")
        #expect(MIMETypeResolver.mimeType(for: "WAV") == "audio/wav")
        #expect(MIMETypeResolver.mimeType(for: "Wav") == "audio/wav")
        #expect(MIMETypeResolver.mimeType(for: "FLAC") == "audio/flac")
    }

    // MARK: - Default Value Tests

    @Test func mimeTypeReturnsDefaultForUnknownExtension() {
        let mimeType = MIMETypeResolver.mimeType(for: "xyz")
        #expect(mimeType == "audio/mpeg")
    }

    @Test func mimeTypeReturnsDefaultForEmptyExtension() {
        let mimeType = MIMETypeResolver.mimeType(for: "")
        #expect(mimeType == "audio/mpeg")
    }

    // MARK: - All Known Extensions

    @Test func allKnownExtensionsReturnCorrectMIME() {
        let expectedMappings: [String: String] = [
            "mp3": "audio/mpeg",
            "mp4": "audio/mp4",
            "m4a": "audio/mp4",
            "wav": "audio/wav",
            "webm": "audio/webm",
            "ogg": "audio/ogg",
            "flac": "audio/flac",
            "mpeg": "audio/mpeg",
            "mpga": "audio/mpeg"
        ]

        for (extension_, expectedMime) in expectedMappings {
            let actualMime = MIMETypeResolver.mimeType(for: extension_)
            #expect(actualMime == expectedMime, "Expected \(expectedMime) for .\(extension_), got \(actualMime)")
        }
    }
}

// MARK: - APITestResult Tests

struct APITestResultTests {

    @Test func successIsSuccess() {
        let result = APITestResult.success
        #expect(result.isSuccess == true)
    }

    @Test func failureIsNotSuccess() {
        let result = APITestResult.failure("Error message")
        #expect(result.isSuccess == false)
    }

    @Test func successHasNoErrorMessage() {
        let result = APITestResult.success
        #expect(result.errorMessage == nil)
    }

    @Test func failureHasErrorMessage() {
        let result = APITestResult.failure("Connection failed")
        #expect(result.errorMessage == "Connection failed")
    }

    @Test func successEquality() {
        let result1 = APITestResult.success
        let result2 = APITestResult.success
        #expect(result1 == result2)
    }

    @Test func failureEquality() {
        let result1 = APITestResult.failure("Error")
        let result2 = APITestResult.failure("Error")
        #expect(result1 == result2)
    }

    @Test func failuresWithDifferentMessagesAreNotEqual() {
        let result1 = APITestResult.failure("Error 1")
        let result2 = APITestResult.failure("Error 2")
        #expect(result1 != result2)
    }

    @Test func successAndFailureAreNotEqual() {
        let success = APITestResult.success
        let failure = APITestResult.failure("Error")
        #expect(success != failure)
    }
}

// MARK: - MockDaemonManager Tests

struct MockDaemonManagerTests {

    @Test func initialStateIsNotRunning() {
        let mock = MockDaemonManager()
        #expect(mock.isRunning == false)
    }

    @Test func startSetsIsRunningToTrue() {
        let mock = MockDaemonManager()
        mock.start()
        #expect(mock.isRunning == true)
    }

    @Test func stopSetsIsRunningToFalse() {
        let mock = MockDaemonManager()
        mock.isRunning = true
        mock.stop()
        #expect(mock.isRunning == false)
    }

    @Test func startIncreasesCallCount() {
        let mock = MockDaemonManager()
        #expect(mock.startCallCount == 0)

        mock.start()
        #expect(mock.startCallCount == 1)

        mock.start()
        #expect(mock.startCallCount == 2)
    }

    @Test func stopIncreasesCallCount() {
        let mock = MockDaemonManager()
        #expect(mock.stopCallCount == 0)

        mock.stop()
        #expect(mock.stopCallCount == 1)

        mock.stop()
        #expect(mock.stopCallCount == 2)
    }

    @Test func hasDefaultSocketPath() {
        let mock = MockDaemonManager()
        #expect(!mock.socketPath.isEmpty)
        #expect(mock.socketPath.contains("sock"))
    }

    @Test func socketPathIsConfigurable() {
        let mock = MockDaemonManager()
        mock.socketPath = "/custom/path.sock"
        #expect(mock.socketPath == "/custom/path.sock")
    }

    @Test func isRunningIsConfigurable() {
        let mock = MockDaemonManager()
        mock.isRunning = true
        #expect(mock.isRunning == true)
        mock.isRunning = false
        #expect(mock.isRunning == false)
    }
}

// MARK: - MockHotkeyManager Tests

struct MockHotkeyManagerTests {

    @Test func initialStateHasZeroCallCounts() {
        let mock = MockHotkeyManager()
        #expect(mock.startCallCount == 0)
        #expect(mock.stopCallCount == 0)
        #expect(mock.updateHotkeysCallCount == 0)
    }

    @Test func startIncreasesCallCount() {
        let mock = MockHotkeyManager()
        mock.start()
        #expect(mock.startCallCount == 1)
        mock.start()
        #expect(mock.startCallCount == 2)
    }

    @Test func stopIncreasesCallCount() {
        let mock = MockHotkeyManager()
        mock.stop()
        #expect(mock.stopCallCount == 1)
        mock.stop()
        #expect(mock.stopCallCount == 2)
    }

    @Test func updateHotkeysStoresValues() {
        let mock = MockHotkeyManager()
        let local = Hotkey.toggleLocalDefault
        let cloud = Hotkey.toggleCloudDefault
        let gemini = Hotkey.toggleGeminiDefault
        let cancel = Hotkey.cancelDefault

        mock.updateHotkeys(toggleLocal: local, toggleCloud: cloud, toggleGemini: gemini, cancel: cancel)

        #expect(mock.updateHotkeysCallCount == 1)
        #expect(mock.lastHotkeys?.local == local)
        #expect(mock.lastHotkeys?.cloud == cloud)
        #expect(mock.lastHotkeys?.gemini == gemini)
        #expect(mock.lastHotkeys?.cancel == cancel)
    }

    @Test func callbacksCanBeSet() {
        let mock = MockHotkeyManager()
        var localCalled = false
        var cloudCalled = false
        var geminiCalled = false
        var cancelCalled = false

        mock.onToggleLocalRecording = { localCalled = true }
        mock.onToggleCloudRecording = { cloudCalled = true }
        mock.onToggleGeminiRecording = { geminiCalled = true }
        mock.onCancelRecording = { cancelCalled = true }

        mock.onToggleLocalRecording?()
        mock.onToggleCloudRecording?()
        mock.onToggleGeminiRecording?()
        mock.onCancelRecording?()

        #expect(localCalled)
        #expect(cloudCalled)
        #expect(geminiCalled)
        #expect(cancelCalled)
    }

    @Test func isPausedIsConfigurable() {
        let mock = MockHotkeyManager()
        #expect(mock.isPaused == false)
        mock.isPaused = true
        #expect(mock.isPaused == true)
    }
}

// MARK: - MockTranscriptionRepository Tests

struct MockTranscriptionRepositoryTests {

    @Test func initialStateIsEmpty() {
        let mock = MockTranscriptionRepository()
        #expect(mock.records.isEmpty)
        #expect(mock.saveCallCount == 0)
        #expect(mock.fetchAllCallCount == 0)
        #expect(mock.deleteCallCount == 0)
        #expect(mock.deleteAllCallCount == 0)
    }

    @Test func saveAddsRecord() {
        let mock = MockTranscriptionRepository()
        let record = TranscriptionRecord(text: "Test", language: "en", duration: 5)

        mock.save(record)

        #expect(mock.saveCallCount == 1)
        #expect(mock.records.count == 1)
        #expect(mock.records.first?.text == "Test")
    }

    @Test func saveUpdatesExistingRecord() {
        let mock = MockTranscriptionRepository()
        let id = UUID()
        let original = TranscriptionRecord(id: id, text: "Original", language: "en", duration: 5)
        let updated = TranscriptionRecord(id: id, text: "Updated", language: "ru", duration: 10)

        mock.save(original)
        mock.save(updated)

        #expect(mock.saveCallCount == 2)
        #expect(mock.records.count == 1)
        #expect(mock.records.first?.text == "Updated")
        #expect(mock.records.first?.language == "ru")
    }

    @Test func fetchAllReturnsRecordsInReverseChronologicalOrder() {
        let mock = MockTranscriptionRepository()

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

        mock.save(old)
        mock.save(new)

        let fetched = mock.fetchAll()

        #expect(mock.fetchAllCallCount == 1)
        #expect(fetched.count == 2)
        #expect(fetched[0].text == "New")
        #expect(fetched[1].text == "Old")
    }

    @Test func deleteRemovesRecord() {
        let mock = MockTranscriptionRepository()
        let record = TranscriptionRecord(text: "Delete me", language: "en", duration: 5)

        mock.save(record)
        #expect(mock.records.count == 1)

        mock.delete(id: record.id)

        #expect(mock.deleteCallCount == 1)
        #expect(mock.records.isEmpty)
    }

    @Test func deleteDoesNothingForNonexistentID() {
        let mock = MockTranscriptionRepository()
        let record = TranscriptionRecord(text: "Keep me", language: "en", duration: 5)
        mock.save(record)

        mock.delete(id: UUID())

        #expect(mock.deleteCallCount == 1)
        #expect(mock.records.count == 1)
    }

    @Test func deleteAllRemovesAllRecords() {
        let mock = MockTranscriptionRepository()
        mock.save(TranscriptionRecord(text: "One", language: "en", duration: 5))
        mock.save(TranscriptionRecord(text: "Two", language: "en", duration: 5))
        mock.save(TranscriptionRecord(text: "Three", language: "en", duration: 5))

        #expect(mock.records.count == 3)

        mock.deleteAll()

        #expect(mock.deleteAllCallCount == 1)
        #expect(mock.records.isEmpty)
    }

    @Test func conformsToTranscriptionRepositoryProtocol() {
        let mock: TranscriptionRepositoryProtocol = MockTranscriptionRepository()

        // Just verify it compiles and works
        mock.save(TranscriptionRecord(text: "Test", language: "en", duration: 5))
        let fetched = mock.fetchAll()
        #expect(fetched.count == 1)
    }
}
