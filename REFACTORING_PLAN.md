# Murmurix: Refactoring Plan for Better Testability

**Document Created**: 2026-01-12
**Version**: 1.3
**Focus**: Improving testability and maintainability

---

## Project Overview

**Murmurix** - macOS Menu Bar приложение для голосовой транскрипции.

### Current Stats
| Metric | Value |
|--------|-------|
| Swift files | 58 |
| Lines of code | ~7,200 |
| Unit tests | 135+ |
| Protocols | 14+ |

### Architecture (Layered + MVVM)
```
┌──────────────────────────────────────────────────────────┐
│  Presentation (Views, ViewModels, WindowControllers)     │
├──────────────────────────────────────────────────────────┤
│  Coordination (AppDelegate, Managers, Coordinator)       │
├──────────────────────────────────────────────────────────┤
│  Service (Audio, Transcription, Hotkeys, etc.)           │
├──────────────────────────────────────────────────────────┤
│  Data (Settings, History, Keychain)                      │
├──────────────────────────────────────────────────────────┤
│  External (Python, OpenAI API, Gemini API)               │
└──────────────────────────────────────────────────────────┘
```

---

## Dependencies

### External (SPM)
| Package | Version | Purpose |
|---------|---------|---------|
| Lottie | 4.5.2 | Loading animations |
| GoogleGenerativeAI | 0.5.6 | Gemini transcription |

### System Frameworks
- **Foundation**, **SwiftUI**, **AppKit**, **AVFoundation**
- **Carbon** (CGEvent for hotkeys)
- **Security** (Keychain)
- **SQLite3** (History)
- **os.log** (Logging)

---

## Current Testability Issues

### 1. Hardcoded Singletons
| File | Line | Issue |
|------|------|-------|
| `TranscriptionService.swift` | 18-19 | `Settings.shared`, `OpenAITranscriptionService.shared`, `GeminiTranscriptionService.shared` |
| `DaemonManager.swift` | 22 | `Settings.shared` |
| `GeneralSettingsView.swift` | 50-55, 87, 274, 391, 435, 524 | Direct `Settings.shared` access |
| `AppDelegate.swift` | 21-22 | `HistoryService.shared`, `Settings.shared` |

### 2. Missing Mock Implementations
| Protocol | Mock Exists | Notes |
|----------|-------------|-------|
| `AudioRecorderProtocol` | Yes | MockAudioRecorder |
| `TranscriptionServiceProtocol` | Yes | MockTranscriptionService |
| `HistoryServiceProtocol` | Yes | MockHistoryService |
| `SettingsStorageProtocol` | Yes | MockSettings |
| `OpenAITranscriptionServiceProtocol` | Yes | MockOpenAITranscriptionService |
| `GeminiTranscriptionServiceProtocol` | Yes | MockGeminiTranscriptionService |
| `DaemonManagerProtocol` | **No** | Missing! |
| `HotkeyManagerProtocol` | **No** | Missing! |
| `Repository<T>` | **No** | Missing! |
| `URLSession` | **No** | Not abstracted |
| `FileManager` | **No** | Not abstracted |
| `Process` | **No** | Not abstracted |

### 3. Non-Testable Components
| Component | Issue |
|-----------|-------|
| `OpenAITranscriptionService` | Uses `URLSession.shared` directly (line 84, 149) |
| `GeminiTranscriptionService` | Uses `GenerativeModel` directly, hard to mock |
| `DaemonManager` | Uses `Process`, socket operations directly |
| `TranscriptionService` | Low-level socket code (lines 118-180) |
| `AudioRecorder` | Uses `AVAudioRecorder` directly |
| `GlobalHotkeyManager` | Uses `CGEvent` directly |

### 4. Business Logic in Views
| File | Lines | Issue |
|------|-------|-------|
| `GeneralSettingsView.swift` | 263-325 | `testLocalModel()`, `createSilentWavFile()` |
| `GeneralSettingsView.swift` | 429-447 | `testGeminiConnection()` |
| `GeneralSettingsView.swift` | 518-536 | `testOpenAIConnection()` |

### 5. Code Duplication
| Code | Files | Issue |
|------|-------|-------|
| WAV file generation | `OpenAITranscriptionService.swift:173-210`, `GeneralSettingsView.swift:294-325` | Same logic duplicated |
| Socket communication | `TranscriptionService.swift:118-180`, `DaemonManager.swift:116-164` | Similar C-style code |
| MIME type resolution | `OpenAITranscriptionService.swift:231-246`, `GeminiTranscriptionService.swift:116-133` | Almost identical |

---

## Refactoring Priorities

### Legend
- 🔴 **High** - Critical for testability
- 🟠 **Medium** - Important improvements
- 🟢 **Low** - Nice to have
- ⚪ **Nice** - Polish

---

## 🔴 High Priority (Testability)

### 1. Add Missing Mock: MockDaemonManager
**File**: `MurmurixTests/Mocks.swift`

**Problem**: `DaemonManagerProtocol` exists but no mock implementation.

**Add**:
```swift
// MARK: - Mock Daemon Manager

final class MockDaemonManager: DaemonManagerProtocol, @unchecked Sendable {
    var isRunning: Bool = false
    var socketPath: String = "/tmp/test_murmurix.sock"

    var startCallCount = 0
    var stopCallCount = 0

    func start() {
        startCallCount += 1
        isRunning = true
    }

    func stop() {
        stopCallCount += 1
        isRunning = false
    }
}
```

---

### 2. Add Missing Mock: MockHotkeyManager
**File**: `MurmurixTests/Mocks.swift`

**Problem**: `HotkeyManagerProtocol` exists but no mock.

**Add**:
```swift
// MARK: - Mock Hotkey Manager

final class MockHotkeyManager: HotkeyManagerProtocol {
    var onToggleLocalRecording: (() -> Void)?
    var onToggleCloudRecording: (() -> Void)?
    var onToggleGeminiRecording: (() -> Void)?
    var onCancelRecording: (() -> Void)?

    var startCallCount = 0
    var stopCallCount = 0
    var updateHotkeysCallCount = 0
    var lastHotkeys: (local: Hotkey, cloud: Hotkey, gemini: Hotkey, cancel: Hotkey)?

    func start() {
        startCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }

    func updateHotkeys(toggleLocal: Hotkey, toggleCloud: Hotkey, toggleGemini: Hotkey, cancel: Hotkey) {
        updateHotkeysCallCount += 1
        lastHotkeys = (toggleLocal, toggleCloud, toggleGemini, cancel)
    }
}
```

---

### 3. Abstract URLSession for Testing
**Files**: `Services/OpenAITranscriptionService.swift`, `Services/Protocols.swift`

**Problem**: Direct use of `URLSession.shared` prevents testing without network.

**Solution A - Protocol**:
```swift
// Protocols.swift
protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

// OpenAITranscriptionService.swift
final class OpenAITranscriptionService: OpenAITranscriptionServiceProtocol {
    private let session: URLSessionProtocol

    init(session: URLSessionProtocol = URLSession.shared) {
        self.session = session
    }
}
```

**Solution B - Closure Injection** (simpler):
```swift
final class OpenAITranscriptionService: OpenAITranscriptionServiceProtocol {
    private let performRequest: (URLRequest) async throws -> (Data, URLResponse)

    init(performRequest: @escaping (URLRequest) async throws -> (Data, URLResponse) = {
        try await URLSession.shared.data(for: $0)
    }) {
        self.performRequest = performRequest
    }
}
```

**Mock for tests**:
```swift
final class MockURLSession: URLSessionProtocol {
    var response: (Data, URLResponse)?
    var error: Error?
    var lastRequest: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        if let error = error { throw error }
        return response ?? (Data(), HTTPURLResponse())
    }
}
```

---

### 4. Extract WAV Generation Utility
**Files**: `Services/AudioTestUtility.swift` (new)

**Problem**: WAV file creation duplicated in 2 files.

**Current locations**:
- `OpenAITranscriptionService.swift:173-210` (`createMinimalWavFile`)
- `GeneralSettingsView.swift:294-325` (`createSilentWavFile`)

**Create**:
```swift
// Services/AudioTestUtility.swift
enum AudioTestUtility {
    /// Creates a silent WAV file for testing
    static func createSilentWavFile(at url: URL, duration: Double = 0.1, sampleRate: Int = 16000) throws {
        let numSamples = Int(Double(sampleRate) * duration)
        var header = Data()

        // RIFF header
        header.append(contentsOf: "RIFF".utf8)
        let fileSize = UInt32(36 + numSamples * 2)
        header.append(contentsOf: withUnsafeBytes(of: fileSize.littleEndian) { Array($0) })
        header.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        header.append(contentsOf: "fmt ".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // PCM
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Array($0) })  // mono
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * 2).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(2).littleEndian) { Array($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Array($0) })

        // data chunk
        header.append(contentsOf: "data".utf8)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(numSamples * 2).littleEndian) { Array($0) })
        header.append(Data(count: numSamples * 2))  // silent samples

        try header.write(to: url)
    }

    /// Creates a temporary test audio URL
    static func createTemporaryTestAudioURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("test_audio_\(UUID().uuidString).wav")
    }

    /// Generates minimal WAV data in memory
    static func createMinimalWavData(duration: Double = 0.1) -> Data {
        // ... implementation
    }
}
```

---

### 5. Extract MIME Type Utility
**File**: `Services/MIMETypeResolver.swift` (new)

**Problem**: MIME type logic duplicated.

**Current locations**:
- `OpenAITranscriptionService.swift:231-246`
- `GeminiTranscriptionService.swift:116-133`

**Create**:
```swift
// Services/MIMETypeResolver.swift
enum MIMETypeResolver {
    static func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "mp3": return "audio/mpeg"
        case "mp4", "m4a": return "audio/mp4"
        case "wav": return "audio/wav"
        case "webm": return "audio/webm"
        case "ogg": return "audio/ogg"
        case "flac": return "audio/flac"
        case "mpeg", "mpga": return "audio/mpeg"
        default: return "audio/mpeg"
        }
    }
}
```

---

### 6. Extract Socket Client
**File**: `Services/UnixSocketClient.swift` (new)

**Problem**: Socket code duplicated in TranscriptionService and DaemonManager.

**Create**:
```swift
// Services/UnixSocketClient.swift
protocol SocketClientProtocol {
    func send(request: [String: Any]) throws -> [String: Any]
}

final class UnixSocketClient: SocketClientProtocol {
    private let socketPath: String
    private let timeout: Int

    init(socketPath: String, timeout: Int = 60) {
        self.socketPath = socketPath
        self.timeout = timeout
    }

    func send(request: [String: Any]) throws -> [String: Any] {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw SocketError.connectionFailed }
        defer { close(fd) }

        // ... socket logic
    }
}

// For testing
final class MockSocketClient: SocketClientProtocol {
    var response: [String: Any] = ["text": "Test"]
    var error: Error?
    var lastRequest: [String: Any]?

    func send(request: [String: Any]) throws -> [String: Any] {
        lastRequest = request
        if let error = error { throw error }
        return response
    }
}
```

---

### 7. Remove Settings.shared from Views
**File**: `Views/GeneralSettingsView.swift`

**Problem**: Direct access to `Settings.shared` makes testing impossible.

**Current** (lines 50-55, 87, 274, etc.):
```swift
_toggleLocalHotkey = State(initialValue: Settings.shared.loadToggleLocalHotkey())
Settings.shared.saveToggleLocalHotkey(newValue)
```

**Solution**: Pass settings via init or use ViewModel:
```swift
struct GeneralSettingsView: View {
    private let settings: SettingsStorageProtocol

    init(
        settings: SettingsStorageProtocol = Settings.shared,
        isDaemonRunning: Binding<Bool>,
        // ...
    ) {
        self.settings = settings
        _toggleLocalHotkey = State(initialValue: settings.loadToggleLocalHotkey())
    }

    // Use self.settings instead of Settings.shared
}
```

**Better**: Move all settings access to ViewModel.

---

### 8. Move API Testing Logic to ViewModel
**File**: `Views/GeneralSettingsView.swift` → `ViewModels/GeneralSettingsViewModel.swift`

**Problem**: Business logic in View prevents unit testing.

**Current in View** (lines 263-325, 429-447, 518-536):
```swift
private func testLocalModel() { ... }
private func testOpenAIConnection() { ... }
private func testGeminiConnection() { ... }
```

**Move to ViewModel**:
```swift
// ViewModels/GeneralSettingsViewModel.swift
@MainActor
final class GeneralSettingsViewModel: ObservableObject {
    // Existing properties...

    @Published var isTestingLocal = false
    @Published var isTestingOpenAI = false
    @Published var isTestingGemini = false
    @Published var localTestResult: APITestResult?
    @Published var openaiTestResult: APITestResult?
    @Published var geminiTestResult: APITestResult?

    private let openAIService: OpenAITranscriptionServiceProtocol
    private let geminiService: GeminiTranscriptionServiceProtocol
    private let transcriptionService: TranscriptionServiceProtocol

    init(
        openAIService: OpenAITranscriptionServiceProtocol = OpenAITranscriptionService.shared,
        geminiService: GeminiTranscriptionServiceProtocol = GeminiTranscriptionService.shared,
        transcriptionService: TranscriptionServiceProtocol? = nil,
        modelDownloadService: ModelDownloadServiceProtocol = ModelDownloadService.shared
    ) {
        self.openAIService = openAIService
        self.geminiService = geminiService
        self.transcriptionService = transcriptionService ?? TranscriptionService()
        self.modelDownloadService = modelDownloadService
    }

    func testLocalModel(isDaemonRunning: Bool) async {
        isTestingLocal = true
        localTestResult = nil

        do {
            let tempURL = AudioTestUtility.createTemporaryTestAudioURL()
            try AudioTestUtility.createSilentWavFile(at: tempURL, duration: 0.5)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            _ = try await transcriptionService.transcribe(
                audioURL: tempURL,
                useDaemon: isDaemonRunning,
                mode: .local
            )
            localTestResult = .success
        } catch {
            localTestResult = .failure(error.localizedDescription)
        }
        isTestingLocal = false
    }

    func testOpenAI(apiKey: String) async {
        isTestingOpenAI = true
        openaiTestResult = nil

        do {
            let isValid = try await openAIService.validateAPIKey(apiKey)
            openaiTestResult = isValid ? .success : .failure("Invalid API key")
        } catch {
            openaiTestResult = .failure(error.localizedDescription)
        }
        isTestingOpenAI = false
    }

    func testGemini(apiKey: String) async {
        isTestingGemini = true
        geminiTestResult = nil

        do {
            let isValid = try await geminiService.validateAPIKey(apiKey)
            geminiTestResult = isValid ? .success : .failure("Invalid API key")
        } catch {
            geminiTestResult = .failure(error.localizedDescription)
        }
        isTestingGemini = false
    }
}
```

**Tests**:
```swift
func testLocalModelSuccess() async {
    let mockTranscription = MockTranscriptionService()
    let viewModel = GeneralSettingsViewModel(transcriptionService: mockTranscription)

    await viewModel.testLocalModel(isDaemonRunning: false)

    XCTAssertEqual(mockTranscription.transcribeCallCount, 1)
    XCTAssertEqual(viewModel.localTestResult, .success)
}

func testOpenAIValidationFailure() async {
    let mockOpenAI = MockOpenAITranscriptionService()
    mockOpenAI.validateAPIKeyResult = .failure(TestError.invalid)
    let viewModel = GeneralSettingsViewModel(openAIService: mockOpenAI)

    await viewModel.testOpenAI(apiKey: "invalid")

    XCTAssertNotNil(viewModel.openaiTestResult)
    if case .failure = viewModel.openaiTestResult {} else {
        XCTFail("Expected failure")
    }
}
```

---

### 9. Extract APITestResult to Models
**File**: `Models/APITestResult.swift` (new)

**Problem**: Enum defined inside View file.

**Current**: `Views/GeneralSettingsView.swift:8-11`

**Create**:
```swift
// Models/APITestResult.swift
enum APITestResult: Equatable {
    case success
    case failure(String)

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var errorMessage: String? {
        if case .failure(let message) = self { return message }
        return nil
    }
}
```

---

### 10. Add TranscriptionRepository Protocol
**File**: `Services/Repository.swift`

**Problem**: `SQLiteTranscriptionRepository` doesn't have a protocol for mocking.

**Add**:
```swift
// Services/Repository.swift

// Add specific protocol for TranscriptionRecord repository
protocol TranscriptionRepositoryProtocol {
    func save(_ item: TranscriptionRecord)
    func fetchAll() -> [TranscriptionRecord]
    func delete(id: UUID)
    func deleteAll()
}

// Conform SQLiteTranscriptionRepository
final class SQLiteTranscriptionRepository: TranscriptionRepositoryProtocol { ... }
```

**Mock**:
```swift
// Mocks.swift
final class MockTranscriptionRepository: TranscriptionRepositoryProtocol {
    var records: [TranscriptionRecord] = []
    var saveCallCount = 0
    var fetchAllCallCount = 0
    var deleteCallCount = 0
    var deleteAllCallCount = 0

    func save(_ item: TranscriptionRecord) {
        saveCallCount += 1
        records.append(item)
    }

    func fetchAll() -> [TranscriptionRecord] {
        fetchAllCallCount += 1
        return records
    }

    func delete(id: UUID) {
        deleteCallCount += 1
        records.removeAll { $0.id == id }
    }

    func deleteAll() {
        deleteAllCallCount += 1
        records.removeAll()
    }
}
```

---

## 🟠 Medium Priority

### 11. Split GeneralSettingsView
**File**: `Views/GeneralSettingsView.swift` (656 lines)

**Problem**: Too large, hard to test and maintain.

**Split into**:
```
Views/Settings/
├── GeneralSettingsView.swift (~100 lines, container)
├── KeyboardShortcutsSection.swift (~80 lines)
├── LanguageSection.swift (~40 lines)
├── LocalWhisperSection.swift (~120 lines)
├── OpenAISection.swift (~100 lines)
└── GeminiSection.swift (~100 lines)
```

Each section receives only the bindings/callbacks it needs.

---

### 12. DRY Hotkey Methods in Settings
**File**: `Models/Settings.swift`

**Problem**: 8 nearly identical methods (lines 63-103, 146-158).

**Current**:
```swift
func loadToggleLocalHotkey() -> Hotkey { ... }
func saveToggleLocalHotkey(_ hotkey: Hotkey) { ... }
// ... 6 more similar methods
```

**Solution**:
```swift
final class Settings: SettingsStorageProtocol {
    // Private generic helpers
    private func loadHotkey(key: String, default defaultHotkey: Hotkey) -> Hotkey {
        guard let data = defaults.data(forKey: key),
              let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) else {
            return defaultHotkey
        }
        return hotkey
    }

    private func saveHotkey(key: String, hotkey: Hotkey) {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: key)
        }
    }

    // Public methods use helpers
    func loadToggleLocalHotkey() -> Hotkey {
        loadHotkey(key: Keys.toggleLocalHotkey, default: .toggleLocalDefault)
    }

    func saveToggleLocalHotkey(_ hotkey: Hotkey) {
        saveHotkey(key: Keys.toggleLocalHotkey, hotkey: hotkey)
    }
    // etc.
}
```

---

### 13. Remove @unchecked Sendable
**Files**: Multiple services

**Problem**: `@unchecked Sendable` bypasses compiler safety checks.

**Current**:
```swift
final class TranscriptionService: @unchecked Sendable { ... }
final class DaemonManager: @unchecked Sendable { ... }
final class OpenAITranscriptionService: @unchecked Sendable { ... }
final class GeminiTranscriptionService: @unchecked Sendable { ... }
```

**Solution A - Actor**:
```swift
actor TranscriptionService: TranscriptionServiceProtocol { ... }
```

**Solution B - Make properties Sendable**:
```swift
final class TranscriptionService: Sendable {
    private let daemonManager: any DaemonManagerProtocol & Sendable
    // ... ensure all properties are Sendable
}
```

---

### 14. Add Process Abstraction
**Files**: `Services/DaemonManager.swift`, `Services/TranscriptionService.swift`

**Problem**: Direct `Process` usage prevents testing.

**Create**:
```swift
// Services/ProcessRunner.swift
protocol ProcessRunnerProtocol {
    func run(executable: String, arguments: [String]) throws -> ProcessResult
    func runBackground(executable: String, arguments: [String]) throws -> Int32
}

struct ProcessResult {
    let exitCode: Int32
    let output: String
    let error: String
}

final class ProcessRunner: ProcessRunnerProtocol {
    func run(executable: String, arguments: [String]) throws -> ProcessResult { ... }
    func runBackground(executable: String, arguments: [String]) throws -> Int32 { ... }
}

// Mock
final class MockProcessRunner: ProcessRunnerProtocol {
    var runResult: ProcessResult = ProcessResult(exitCode: 0, output: "", error: "")
    var runCallCount = 0

    func run(executable: String, arguments: [String]) throws -> ProcessResult {
        runCallCount += 1
        return runResult
    }

    func runBackground(executable: String, arguments: [String]) throws -> Int32 {
        runCallCount += 1
        return 12345
    }
}
```

---

### 15. Abstract FileManager Operations
**Problem**: Direct `FileManager.default` usage scattered everywhere.

**Solution**: Create FileManagerProtocol for testability:
```swift
protocol FileManagerProtocol {
    func fileExists(atPath path: String) -> Bool
    func removeItem(at URL: URL) throws
    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey : Any]?) -> Bool
    var temporaryDirectory: URL { get }
}

extension FileManager: FileManagerProtocol {}

final class MockFileManager: FileManagerProtocol {
    var existingPaths: Set<String> = []
    var removedURLs: [URL] = []
    var createdFiles: [(path: String, data: Data?)] = []

    func fileExists(atPath path: String) -> Bool {
        existingPaths.contains(path)
    }

    func removeItem(at URL: URL) throws {
        removedURLs.append(URL)
    }

    // etc.
}
```

---

## 🟢 Low Priority

### 16. Add Keychain Key Enum
**File**: `Services/KeychainService.swift`

**Problem**: Magic strings for Keychain keys.

**Current**:
```swift
KeychainService.load(key: "openaiApiKey")
```

**Solution**:
```swift
extension KeychainService {
    enum Key: String {
        case openaiApiKey
        case geminiApiKey
    }

    static func load(key: Key) -> String? {
        load(key: key.rawValue)
    }
}
```

---

### 17. Add Documentation Comments
**All public APIs**

**Add DocC-style comments**:
```swift
/// Coordinates the recording lifecycle and transcription process.
///
/// ## State Machine
/// ```
/// idle → recording → transcribing → idle
///          ↓              ↓
///        cancel        cancel
/// ```
///
/// ## Usage
/// ```swift
/// let coordinator = RecordingCoordinator(...)
/// coordinator.toggleRecording(mode: .local)
/// ```
final class RecordingCoordinator { ... }
```

---

### 18. Add Result Type for Transcription
**File**: `Services/TranscriptionService.swift`

**Enhancement**:
```swift
struct TranscriptionResult {
    let text: String
    let mode: TranscriptionMode
    let processingTime: TimeInterval
}

func transcribe(...) async -> Result<TranscriptionResult, MurmurixError>
```

---

## ⚪ Nice to Have

### 19. Swift 6 Strict Concurrency
- Add `@MainActor` where needed
- Remove all `@unchecked Sendable`
- Use actors for mutable state

### 20. Accessibility Support
```swift
Button("Test") { ... }
    .accessibilityLabel("Test API connection")
    .accessibilityHint("Double tap to test the API key")
```

### 21. Performance Metrics Service
```swift
actor MetricsService {
    func trackTranscription(mode: TranscriptionMode, duration: TimeInterval)
    func getAverageTime(for mode: TranscriptionMode) -> TimeInterval
}
```

---

## New Files to Create

| File | Purpose |
|------|---------|
| `Services/AudioTestUtility.swift` | WAV generation utility |
| `Services/MIMETypeResolver.swift` | MIME type resolution |
| `Services/UnixSocketClient.swift` | Socket abstraction |
| `Services/ProcessRunner.swift` | Process abstraction |
| `Models/APITestResult.swift` | API test result enum |
| `Views/Settings/KeyboardShortcutsSection.swift` | Extracted view |
| `Views/Settings/LocalWhisperSection.swift` | Extracted view |
| `Views/Settings/OpenAISection.swift` | Extracted view |
| `Views/Settings/GeminiSection.swift` | Extracted view |

---

## Recommended Implementation Order

> **IMPORTANT**: Write/update tests after EACH phase before moving to the next one.
> This ensures issues are caught early and makes debugging easier.

### Phase 1: Enable Testing (Priority) ✅ DONE
1. Add MockDaemonManager ✅
2. Add MockHotkeyManager ✅
3. Extract APITestResult to Models/ ✅
4. Extract AudioTestUtility ✅
5. Add TranscriptionRepositoryProtocol ✅
6. Create MIMETypeResolver ✅
7. DRY hotkey methods ✅

**Tests for Phase 1:** ✅ DONE
- [x] AudioTestUtility tests (WAV generation) - 13 tests
- [x] MIMETypeResolver tests (all file types) - 12 tests
- [x] APITestResult tests - 8 tests
- [x] MockDaemonManager tests - 8 tests
- [x] MockHotkeyManager tests - 6 tests
- [x] MockTranscriptionRepository tests - 8 tests

### Phase 2: Improve Testability (Partial) ✅ DONE
1. Abstract URLSession for network testing ✅
2. Extract UnixSocketClient from TranscriptionService/DaemonManager ✅
3. Remove Settings.shared from Views (use DI) - *deferred to Phase 3*
4. Move test logic from GeneralSettingsView to ViewModel - *deferred to Phase 3*

**Tests for Phase 2:** ✅ DONE
- [x] MockURLSession tests - 6 tests
- [x] MockSocketClient tests - 6 tests
- [x] SocketError tests - 4 tests
- [x] OpenAITranscriptionServiceDI tests - 3 tests
- [x] TranscriptionServiceSocketDI tests - 1 test

### Phase 3: Code Quality + Deferred Tasks ✅ DONE
1. Remove Settings.shared from Views (use DI) - *from Phase 2* ✅
2. Move test logic from GeneralSettingsView to ViewModel - *from Phase 2* ✅
3. Split GeneralSettingsView into sections - *deferred (file already well-structured at 552 lines)*
4. Remove @unchecked Sendable - *deferred to Phase 4 (requires actor conversion)*
5. Add Process/FileManager abstractions - *deferred (not blocking tests)*

**Tests for Phase 3:** ✅ DONE
- [x] GeneralSettingsViewModelAPITests - 15 tests (testLocalModel, testOpenAI, testGemini, clearTestResult)
- [x] GeneralSettingsViewModelSettingsDITests - 2 tests
- [x] TestServiceEnumTests - 1 test

### Phase 4: Polish (Optional)
1. Documentation (DocC comments)
2. Keychain key enum

**Deferred tasks (low priority):**
3. Remove @unchecked Sendable (requires actor conversion)
4. Split GeneralSettingsView into sections (file already well-structured at 552 lines)
5. Add Process/FileManager abstractions
6. Swift 6 strict concurrency preparation (do when upgrading to Swift 6)

**Tests to add after Phase 4:**
- [ ] Verify all tests pass with strict concurrency (when needed)

---

## Testing Checklist

After each refactoring step:
- [ ] All existing tests pass (`⌘U`)
- [ ] New tests added for extracted code
- [ ] Manual testing:
  - [ ] Local recording (⌃C)
  - [ ] OpenAI recording (⌃D)
  - [ ] Gemini recording (⌃G)
  - [ ] Cancel (Esc)
  - [ ] Settings window
  - [ ] History window
  - [ ] API key testing
  - [ ] Model download

---

## Metrics After Refactoring

**Target improvements**:
| Metric | Current | Target |
|--------|---------|--------|
| Mock implementations | 8 | 12+ |
| Testable services | ~60% | 95%+ |
| View business logic | ~300 lines | 0 lines |
| Code duplication | ~200 lines | <50 lines |
| @unchecked Sendable | 4 | 0 |
