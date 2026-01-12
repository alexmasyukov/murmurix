# Murmurix Architecture

## Overview

Murmurix is a native macOS menubar application for voice-to-text transcription with local (Whisper) or cloud (OpenAI/Gemini) processing. The app follows a layered architecture with clear separation of concerns.

```
┌─────────────────────────────────────────────────────────────────┐
│                        Presentation Layer                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   Views     │  │  ViewModels │  │   Window Controllers    │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                        Coordination Layer                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ AppDelegate │  │  Managers   │  │  RecordingCoordinator   │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                         Service Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   Audio     │  │Transcription│  │   Audio Compression     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                          Data Layer                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  Settings   │  │   History   │  │       Keychain          │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                        External Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   Python    │  │ OpenAI API  │  │     Hugging Face        │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
│  ┌─────────────┐  ┌─────────────┐                               │
│  │   Lottie    │  │ Gemini API  │                               │
│  └─────────────┘  └─────────────┘                               │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
Murmurix/
├── App/                          # Application lifecycle
│   ├── main.swift               # Entry point
│   ├── AppDelegate.swift        # App lifecycle, coordination
│   ├── AppConstants.swift       # Centralized constants
│   ├── MenuBarManager.swift     # Status bar and menu
│   ├── WindowManager.swift      # Window lifecycle
│   └── WindowPositioner.swift   # Window positioning utility
│
├── Models/                       # Data models
│   ├── Settings.swift           # App settings (UserDefaults)
│   ├── Hotkey.swift             # Hotkey model with key codes
│   ├── TranscriptionRecord.swift # History record
│   ├── WhisperModel.swift       # Whisper model enum
│   ├── OpenAITranscriptionModel.swift # OpenAI transcription models
│   └── GeminiTranscriptionModel.swift # Gemini transcription models
│
├── ViewModels/                   # Presentation logic
│   ├── HistoryViewModel.swift   # History list logic
│   ├── GeneralSettingsViewModel.swift
│   └── RecordingTimer.swift     # Recording duration timer
│
├── Views/                        # SwiftUI views
│   ├── SettingsView.swift       # Settings wrapper
│   ├── GeneralSettingsView.swift # All settings in one view
│   ├── HistoryView.swift
│   ├── HotkeyRecorderView.swift
│   ├── ResultView.swift
│   │
│   ├── Recording/               # Recording UI components
│   │   ├── RecordingView.swift
│   │   ├── EqualizerView.swift
│   │   ├── CatLoadingView.swift  # Lottie cat animation (transcribing state)
│   │   └── RecordingComponents.swift
│   │
│   ├── History/                 # History UI components
│   │   ├── HistoryStatsView.swift
│   │   ├── HistoryRowView.swift
│   │   └── HistoryDetailView.swift
│   │
│   ├── Components/              # Reusable components
│   │   ├── LottieView.swift     # Animated Lottie wrapper (NSViewRepresentable)
│   │   ├── SectionHeader.swift
│   │   └── SettingsStyles.swift
│   │
│   └── *WindowController.swift  # NSWindowController wrappers
│
├── Services/                     # Business logic
│   ├── Protocols.swift          # Service protocols
│   ├── MurmurixError.swift      # Unified error hierarchy
│   ├── Logger.swift             # Centralized logging (os.log)
│   │
│   ├── AudioRecorder.swift      # AVAudioRecorder wrapper
│   ├── TranscriptionService.swift # Transcription orchestration
│   ├── DaemonManager.swift      # Python daemon lifecycle
│   ├── RecordingCoordinator.swift # Recording state machine
│   │
│   ├── OpenAITranscriptionService.swift # OpenAI Audio API client
│   ├── GeminiTranscriptionService.swift # Google Gemini API client
│   ├── AudioCompressor.swift    # WAV to M4A compression
│   │
│   ├── GlobalHotkeyManager.swift # CGEvent tap for shortcuts
│   ├── TextPaster.swift         # Clipboard & paste
│   ├── Repository.swift         # Repository pattern (SQLiteDatabase, SQLiteTranscriptionRepository)
│   ├── HistoryService.swift     # SQLite storage (delegates to Repository)
│   ├── KeychainService.swift    # Secure key storage
│   ├── ModelDownloadService.swift # Whisper model download
│   └── PythonResolver.swift     # Python/script paths
│
└── Python/                       # Python scripts
    ├── transcribe.py            # One-shot transcription
    └── transcribe_daemon.py     # Socket server daemon
```

## Component Responsibilities

### App Layer

#### AppDelegate (227 lines)
**Role**: Application lifecycle and high-level coordination

**Responsibilities**:
- Initialize all services and managers
- Handle app lifecycle events
- Implement `RecordingCoordinatorDelegate`
- Route recording results to appropriate UI

**Dependencies**: MenuBarManager, WindowManager, RecordingCoordinator, GlobalHotkeyManager

```swift
class AppDelegate: NSApplicationDelegate, RecordingCoordinatorDelegate, MenuBarManagerDelegate
```

#### MenuBarManager
**Role**: Status bar icon and dropdown menu

**Responsibilities**:
- Create and manage NSStatusItem
- Display hotkey shortcuts in menu
- Delegate menu actions to AppDelegate
- Three recording options: Local (Whisper), Cloud (OpenAI), and Gemini

**Protocol**: `MenuBarManagerDelegate`

```swift
protocol MenuBarManagerDelegate: AnyObject {
    func menuBarDidRequestToggleLocalRecording()
    func menuBarDidRequestToggleCloudRecording()
    func menuBarDidRequestToggleGeminiRecording()
    func menuBarDidRequestOpenHistory()
    func menuBarDidRequestOpenSettings()
    func menuBarDidRequestQuit()
}
```

#### WindowManager (91 lines)
**Role**: Window lifecycle management

**Responsibilities**:
- Create/show/hide all window controllers
- Manage recording, result, settings, history windows
- Provide unified window API for AppDelegate

#### AppConstants
**Role**: Centralized configuration constants

**Contains**:
- `Layout` — padding, corner radius, spacing
- `Typography` — font definitions
- `AppColors` — opacity values, background colors
- `AudioConfig` — voice threshold, sample rate
- `NetworkConfig` — socket timeouts
- `WindowSize` — window dimensions
- `AppPaths` — file paths

#### WindowPositioner (35 lines)
**Role**: Window positioning utility

**Methods**:
- `positionTopCenter(_:topOffset:)` — Position at top center of screen
- `center(_:)` — Center window on screen
- `centerAndActivate(_:)` — Center and activate app

---

### Models Layer

#### Settings
**Role**: UserDefaults wrapper with type safety

**Manages**:
- Core: `keepDaemonRunning`, `language`, `whisperModel`
- Transcription: `transcriptionMode` (local/openai/gemini), `openaiTranscriptionModel`, `geminiModel`
- Hotkeys: `toggleLocalHotkey`, `toggleCloudHotkey`, `toggleGeminiHotkey`, `cancelHotkey`
- API keys via KeychainService (OpenAI, Gemini)

**Protocol**: `SettingsStorageProtocol`

```swift
protocol SettingsStorageProtocol: AnyObject {
    var keepDaemonRunning: Bool { get set }
    var language: String { get set }
    var transcriptionMode: String { get set }
    var whisperModel: String { get set }
    var openaiApiKey: String { get set }
    var openaiTranscriptionModel: String { get set }
    var geminiApiKey: String { get set }
    var geminiModel: String { get set }

    func loadToggleLocalHotkey() -> Hotkey
    func saveToggleLocalHotkey(_ hotkey: Hotkey)
    func loadToggleCloudHotkey() -> Hotkey
    func saveToggleCloudHotkey(_ hotkey: Hotkey)
    func loadToggleGeminiHotkey() -> Hotkey
    func saveToggleGeminiHotkey(_ hotkey: Hotkey)
    func loadCancelHotkey() -> Hotkey
    func saveCancelHotkey(_ hotkey: Hotkey)
}
```

#### Hotkey
**Role**: Keyboard shortcut representation

**Properties**: `keyCode`, `modifiers`
**Defaults**: `.toggleLocalDefault` (⌃C), `.toggleCloudDefault` (⌃D), `.toggleGeminiDefault` (⌃G), `.cancelDefault` (Esc)
**Features**: Codable, display formatting, key code mapping

#### TranscriptionRecord (43 lines)
**Role**: History entry model

**Properties**: `id`, `text`, `language`, `duration`, `createdAt`
**Features**: Identifiable, Codable, Hashable

#### WhisperModel
**Role**: Whisper model definitions

**Cases**: tiny, base, small, medium, large-v2, large-v3
**Features**: Display names, installation check via HF cache

#### OpenAITranscriptionModel
**Role**: OpenAI transcription model definitions

**Cases**: gpt4oTranscribe, gpt4oMiniTranscribe
**Features**: Model IDs, display names

#### GeminiTranscriptionModel
**Role**: Google Gemini transcription model definitions

**Cases**: flash2 (gemini-2.0-flash), flash (gemini-1.5-flash), pro (gemini-1.5-pro)
**Features**: Model IDs, display names, descriptions

---

### ViewModels Layer

All ViewModels have protocols for testability.

#### HistoryViewModel (75 lines)
**Role**: History list presentation logic

**Published**: `records`, `selectedRecord`
**Actions**: loadRecords, deleteRecord, clearHistory
**Computed**: totalDuration, totalWords
**Protocol**: `HistoryViewModelProtocol`

#### GeneralSettingsViewModel
**Role**: Model download and installation state

**Published**: `installedModels`, `downloadStatus`
**Actions**: loadInstalledModels, startDownload, cancelDownload
**Protocol**: `GeneralSettingsViewModelProtocol`

#### RecordingTimer
**Role**: Recording duration timer

**Published**: `elapsedTime`
**Actions**: start, stop
**Features**: Formats as MM:SS

---

### Services Layer

#### RecordingCoordinator
**Role**: Recording state machine and orchestration

**State Machine**:
```
idle → recording → transcribing → idle
         ↓              ↓
       cancel        cancel
         ↓              ↓
       idle           idle
```

**Responsibilities**:
- Coordinate AudioRecorder and TranscriptionService
- Manage recording lifecycle
- Pass transcription mode (local/cloud) to service
- Save to history, notify delegate
- Delete audio files after transcription

**Key Method**: `toggleRecording(mode: TranscriptionMode)`

**Protocol**: `RecordingCoordinatorDelegate`

```swift
protocol RecordingCoordinatorDelegate: AnyObject {
    func recordingDidStart()
    func recordingDidStop()
    func recordingDidStopWithoutVoice()
    func transcriptionDidStart()
    func transcriptionDidComplete(text: String, duration: TimeInterval, recordId: UUID)
    func transcriptionDidFail(error: Error)
    func transcriptionDidCancel()
}
```

#### AudioRecorder
**Role**: Audio recording with level monitoring

**Responsibilities**:
- Record audio to WAV file (16kHz, mono)
- Monitor audio levels for voice activity detection
- Handle microphone permissions

**Protocol**: `AudioRecorderProtocol`

#### TranscriptionService
**Role**: Transcription orchestration

**Modes** (via `TranscriptionMode` enum):
1. **Local mode (.local)** — via Unix socket to Python daemon or direct Python process
2. **OpenAI mode (.openai)** — via OpenAI Audio API (gpt-4o-transcribe)
3. **Gemini mode (.gemini)** — via Google Gemini API (gemini-2.0-flash)

**Key Method**: `transcribe(audioURL:useDaemon:mode:)`

**Dependencies**: DaemonManager, PythonResolver, OpenAITranscriptionService, GeminiTranscriptionService

**Protocol**: `TranscriptionServiceProtocol`

```swift
protocol TranscriptionServiceProtocol: Sendable {
    var isDaemonRunning: Bool { get }
    func startDaemon()
    func stopDaemon()
    func transcribe(audioURL: URL, useDaemon: Bool, mode: TranscriptionMode) async throws -> String
}
```

#### OpenAITranscriptionService
**Role**: OpenAI Audio API client

**Responsibilities**:
- Transcribe audio via OpenAI gpt-4o-transcribe
- Validate API keys with test transcription
- Handle multipart/form-data uploads

**Features**:
- Uses M4A format for efficient upload (~10x smaller than WAV)
- Includes technical terms prompt for better recognition
- Supports gpt-4o-transcribe and gpt-4o-mini-transcribe models

#### GeminiTranscriptionService
**Role**: Google Gemini API client

**Responsibilities**:
- Transcribe audio via Google Gemini generative AI
- Validate API keys with test request
- Handle audio data as multipart content

**Features**:
- Uses GoogleGenerativeAI SDK
- Supports multiple audio formats (MP3, M4A, WAV, WebM, OGG, FLAC)
- Includes language hints for better recognition
- Supports gemini-2.0-flash, gemini-1.5-flash, gemini-1.5-pro models

#### AudioCompressor
**Role**: Audio compression for cloud upload

**Responsibilities**:
- Compress WAV to M4A (AAC) format
- ~10x size reduction
- Uses AVAssetExportSession

#### DaemonManager
**Role**: Python daemon process lifecycle

**Responsibilities**:
- Start/stop daemon process
- Monitor socket availability
- Send shutdown commands
- Clean up PID files

**Protocol**: `DaemonManagerProtocol`

#### GlobalHotkeyManager
**Role**: System-wide keyboard shortcuts

**Responsibilities**:
- Install CGEvent tap
- Handle local/cloud/gemini/cancel hotkeys
- Support pause/resume (for Settings window)

**Callbacks**:
- `onToggleLocalRecording` — triggers local Whisper transcription
- `onToggleCloudRecording` — triggers cloud OpenAI transcription
- `onToggleGeminiRecording` — triggers cloud Gemini transcription
- `onCancelRecording` — cancels active recording

**Protocol**: `HotkeyManagerProtocol`

```swift
protocol HotkeyManagerProtocol: AnyObject {
    var onToggleLocalRecording: (() -> Void)? { get set }
    var onToggleCloudRecording: (() -> Void)? { get set }
    var onToggleGeminiRecording: (() -> Void)? { get set }
    var onCancelRecording: (() -> Void)? { get set }

    func start()
    func stop()
    func updateHotkeys(toggleLocal: Hotkey, toggleCloud: Hotkey, toggleGemini: Hotkey, cancel: Hotkey)
}
```

#### TextPaster
**Role**: Smart text insertion

**Responsibilities**:
- Detect if text field is focused
- Paste via clipboard + Cmd+V simulation

#### HistoryService
**Role**: SQLite persistence for transcription history

**Operations**: save, fetchAll, delete, deleteAll
**Protocol**: `HistoryServiceProtocol`
**Delegates to**: `SQLiteTranscriptionRepository`

#### Repository.swift
**Role**: Repository pattern for data persistence

**Components**:
- `Repository<T>` protocol — generic CRUD operations
- `SQLiteDatabase` — helper class for common SQLite operations
- `SQLiteTranscriptionRepository` — concrete implementation for TranscriptionRecord

#### KeychainService
**Role**: Secure storage for API keys

**Operations**: save, load, delete

#### ModelDownloadService
**Role**: Whisper model download management

**Operations**: downloadModel, cancelDownload

#### PythonResolver
**Role**: Find Python executable and scripts

**Checks**: Homebrew, system Python, pyenv

#### Logger
**Role**: Centralized logging using os.log

**Categories**:
- `Logger.Audio` — Audio recording events
- `Logger.Transcription` — Transcription events
- `Logger.Daemon` — Daemon lifecycle
- `Logger.Hotkey` — Hotkey manager
- `Logger.History` — Database operations

**Methods**: `.info()`, `.error()`, `.debug()`, `.warning()`

---

### Error Hierarchy

```swift
MurmurixError
├── transcription(TranscriptionError)
│   ├── pythonNotFound
│   ├── scriptNotFound
│   ├── daemonNotRunning
│   ├── failed(String)
│   └── timeout
├── daemon(DaemonError)
│   ├── notRunning
│   ├── startFailed(String)
│   └── communicationFailed
└── system(SystemError)
    ├── microphonePermissionDenied
    ├── accessibilityPermissionDenied
    ├── fileNotFound(String)
    └── unknown(Error)
```

All errors provide `errorDescription` and `recoverySuggestion`.

---

## Data Flow

### Recording Flow

```
User presses hotkey (⌃C for local, ⌃D for OpenAI, ⌃G for Gemini)
        ↓
GlobalHotkeyManager.onToggle[Local|Cloud|Gemini]Recording
        ↓
AppDelegate.toggleRecording(mode:)
        ↓
RecordingCoordinator.toggleRecording(mode:)
        ↓
AudioRecorder.startRecording()
        ↓
[User speaks, audio levels monitored]
        ↓
User presses same hotkey again
        ↓
AudioRecorder.stopRecording() → audioURL
        ↓
TranscriptionService.transcribe(audioURL, mode)
        ↓
HistoryService.save(record)
        ↓
Delete audio file (cleanup)
        ↓
RecordingCoordinatorDelegate.transcriptionDidComplete()
        ↓
AppDelegate → TextPaster.paste() or ResultWindow
```

### Daemon Communication

```
TranscriptionService (mode: .local)
        ↓
    Unix Socket
        ↓
transcribe_daemon.py
        ↓
faster-whisper (GPU/CPU)
        ↓
    JSON Response
        ↓
TranscriptionService
```

---

## Dependency Injection

Services use protocol-based DI for testability:

```swift
// Protocol
protocol TranscriptionServiceProtocol: Sendable {
    var isDaemonRunning: Bool { get }
    func startDaemon()
    func stopDaemon()
    func transcribe(audioURL: URL, useDaemon: Bool, mode: TranscriptionMode) async throws -> String
}

// Production
final class TranscriptionService: TranscriptionServiceProtocol { ... }

// Test Mock
final class MockTranscriptionService: TranscriptionServiceProtocol { ... }

// Usage in RecordingCoordinator
init(
    audioRecorder: AudioRecorderProtocol,
    transcriptionService: TranscriptionServiceProtocol,
    historyService: HistoryServiceProtocol,
    settings: SettingsStorageProtocol
)
```

---

## Thread Model

| Component | Thread |
|-----------|--------|
| AppDelegate | Main |
| All UI code | Main |
| AudioRecorder level updates | Main (via timer) |
| TranscriptionService.transcribe | Background (Task.detached) |
| DaemonManager socket ops | Background |
| HistoryService | Main (SQLite is fast) |

---

## File Sizes Summary

| Category | Files | Total Lines |
|----------|-------|-------------|
| App | 6 | ~700 |
| Models | 6 | ~300 |
| ViewModels | 3 | ~200 |
| Views | 17 | ~2,300 |
| Services | 17 | ~2,000 |
| Tests | 7 | ~2,100 |
| **Total** | **58** | **~7,200** |

---

## Testing

135+ unit tests covering:
- Model serialization (TranscriptionRecord, Hotkey, WhisperModel, OpenAITranscriptionModel, GeminiTranscriptionModel)
- Service logic (HistoryService, RecordingCoordinator)
- Repository pattern (SQLiteDatabase, SQLiteTranscriptionRepository)
- Dependency injection (all services accept protocol-based dependencies)
- ViewModel behavior (HistoryViewModel, GeneralSettingsViewModel)
- Settings persistence (including Gemini settings)
- Window controllers and positioning (WindowPositioner)
- Error hierarchy (MurmurixError with all cases)
- Constants validation (AppConstants)
- Logger categories
- Audio file cleanup (deletion after transcription)
- Transcription modes (local, openai, gemini)
- Hotkey defaults (including toggleGeminiDefault)

All services have mock implementations in `MurmurixTests/Mocks.swift`:
- MockAudioRecorder, MockTranscriptionService, MockHistoryService
- MockSettings, MockModelDownloadService
- MockOpenAITranscriptionService, MockGeminiTranscriptionService, MockRecordingCoordinatorDelegate
