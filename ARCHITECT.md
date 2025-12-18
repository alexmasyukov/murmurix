# Murmurix Architecture

## Overview

Murmurix is a native macOS menubar application for local voice-to-text transcription. The app follows a layered architecture with clear separation of concerns.

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
│  │   Audio     │  │Transcription│  │      AI Processing      │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                          Data Layer                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  Settings   │  │   History   │  │       Keychain          │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                        External Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   Python    │  │ Claude API  │  │     Hugging Face        │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
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
│   └── WindowManager.swift      # Window lifecycle
│
├── Models/                       # Data models
│   ├── Settings.swift           # App settings (UserDefaults)
│   ├── Hotkey.swift             # Hotkey model with key codes
│   ├── TranscriptionRecord.swift # History record
│   ├── WhisperModel.swift       # Whisper model enum
│   └── AIModel.swift            # Claude model enum
│
├── ViewModels/                   # Presentation logic
│   ├── HistoryViewModel.swift   # History list logic
│   ├── GeneralSettingsViewModel.swift
│   └── AISettingsViewModel.swift
│
├── Views/                        # SwiftUI views
│   ├── SettingsView.swift       # Settings container (TabView)
│   ├── GeneralSettingsView.swift
│   ├── AISettingsView.swift
│   ├── HistoryView.swift
│   ├── HotkeyRecorderView.swift
│   ├── ResultView.swift
│   │
│   ├── Recording/               # Recording UI components
│   │   ├── RecordingView.swift
│   │   ├── RecordingTimer.swift
│   │   ├── EqualizerView.swift
│   │   ├── TranscribingView.swift
│   │   ├── ProcessingView.swift
│   │   └── RecordingComponents.swift
│   │
│   ├── History/                 # History UI components
│   │   ├── HistoryStatsView.swift
│   │   ├── HistoryRowView.swift
│   │   └── HistoryDetailView.swift
│   │
│   ├── Components/              # Reusable components
│   │   ├── SectionHeader.swift
│   │   └── SettingsStyles.swift
│   │
│   └── *WindowController.swift  # NSWindowController wrappers
│
├── Services/                     # Business logic
│   ├── Protocols.swift          # Service protocols
│   ├── MurmurixError.swift      # Unified error hierarchy
│   │
│   ├── AudioRecorder.swift      # AVAudioRecorder wrapper
│   ├── TranscriptionService.swift # Transcription orchestration
│   ├── DaemonManager.swift      # Python daemon lifecycle
│   ├── RecordingCoordinator.swift # Recording state machine
│   │
│   ├── AIPostProcessingService.swift # Claude post-processing
│   ├── AnthropicAPIClient.swift # Claude API client
│   │
│   ├── GlobalHotkeyManager.swift # CGEvent tap for shortcuts
│   ├── TextPaster.swift         # Clipboard & paste
│   ├── HistoryService.swift     # SQLite storage
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

#### MenuBarManager (122 lines)
**Role**: Status bar icon and dropdown menu

**Responsibilities**:
- Create and manage NSStatusItem
- Display hotkey shortcuts in menu
- Delegate menu actions to AppDelegate

**Protocol**: `MenuBarManagerDelegate`

#### WindowManager (91 lines)
**Role**: Window lifecycle management

**Responsibilities**:
- Create/show/hide all window controllers
- Manage recording, result, settings, history windows
- Provide unified window API for AppDelegate

#### AppConstants (142 lines)
**Role**: Centralized configuration constants

**Contains**:
- `Layout` — padding, corner radius, spacing
- `Typography` — font definitions
- `AppColors` — opacity values, background colors
- `AudioConfig` — voice threshold, sample rate
- `NetworkConfig` — socket timeouts
- `AIConfig` — API tokens, default prompt
- `WindowSize` — window dimensions
- `AppPaths` — file paths

---

### Models Layer

#### Settings (120 lines)
**Role**: UserDefaults wrapper with type safety

**Manages**:
- Core: `keepDaemonRunning`, `language`, `whisperModel`
- Hotkeys: JSON encode/decode for toggle/cancel
- AI: `aiPostProcessingEnabled`, `aiModel`, `aiPrompt`
- API key via KeychainService

**Protocol**: `SettingsStorageProtocol`

#### Hotkey (64 lines)
**Role**: Keyboard shortcut representation

**Properties**: `keyCode`, `modifiers`
**Features**: Codable, display formatting, key code mapping

#### TranscriptionRecord (43 lines)
**Role**: History entry model

**Properties**: `id`, `text`, `language`, `duration`, `createdAt`
**Features**: Identifiable, Codable, Hashable

#### WhisperModel (49 lines)
**Role**: Whisper model definitions

**Cases**: tiny, base, small, medium, large-v2, large-v3
**Features**: Display names, installation check via HF cache

#### AIModel (20 lines)
**Role**: Claude model definitions

**Cases**: haiku, sonnet, opus
**Features**: Model IDs, display names

---

### ViewModels Layer

#### HistoryViewModel (64 lines)
**Role**: History list presentation logic

**Published**: `records`, `selectedRecord`
**Actions**: loadRecords, deleteRecord, clearHistory
**Computed**: totalDuration, totalWords

#### GeneralSettingsViewModel (65 lines)
**Role**: Model download and installation state

**Published**: `installedModels`, `downloadStatus`
**Actions**: loadInstalledModels, startDownload, cancelDownload

#### AISettingsViewModel (66 lines)
**Role**: API key validation and prompt management

**Published**: `apiKey`, `prompt`, `isTesting`, `testResult`
**Actions**: loadSettings, testConnection, resetPromptToDefault

---

### Services Layer

#### RecordingCoordinator (223 lines)
**Role**: Recording state machine and orchestration

**State Machine**:
```
idle → recording → transcribing → processing → idle
         ↓              ↓            ↓
       cancel        cancel       cancel
         ↓              ↓            ↓
       idle           idle         idle
```

**Responsibilities**:
- Coordinate AudioRecorder, TranscriptionService, AIService
- Manage recording lifecycle
- Save to history, notify delegate

**Protocol**: `RecordingCoordinatorDelegate`

```swift
protocol RecordingCoordinatorDelegate: AnyObject {
    func recordingDidStart()
    func recordingDidStop()
    func recordingDidStopWithoutVoice()
    func transcriptionDidStart()
    func processingDidStart()
    func transcriptionDidComplete(text: String, duration: TimeInterval, recordId: UUID)
    func transcriptionDidFail(error: Error)
    func transcriptionDidCancel()
}
```

#### AudioRecorder (151 lines)
**Role**: Audio recording with level monitoring

**Responsibilities**:
- Record audio to WAV file (16kHz, mono)
- Monitor audio levels for voice activity detection
- Handle microphone permissions

**Protocol**: `AudioRecorderProtocol`

#### TranscriptionService (204 lines)
**Role**: Transcription orchestration

**Modes**:
1. **Daemon mode** — via Unix socket to Python daemon
2. **Direct mode** — spawn Python process

**Dependencies**: DaemonManager, PythonResolver

**Protocol**: `TranscriptionServiceProtocol`

#### DaemonManager (168 lines)
**Role**: Python daemon process lifecycle

**Responsibilities**:
- Start/stop daemon process
- Monitor socket availability
- Send shutdown commands
- Clean up PID files

**Protocol**: `DaemonManagerProtocol`

#### AIPostProcessingService (54 lines)
**Role**: Claude API integration for text correction

**Responsibilities**:
- Fix technical terms in transcriptions
- Use structured outputs for clean JSON

**Protocol**: `AIPostProcessingServiceProtocol`

#### AnthropicAPIClient (166 lines)
**Role**: Low-level Claude API communication

**Responsibilities**:
- API key validation
- Text processing with structured outputs
- Error handling and response parsing

**Protocol**: `AnthropicAPIClientProtocol`

#### GlobalHotkeyManager (127 lines)
**Role**: System-wide keyboard shortcuts

**Responsibilities**:
- Install CGEvent tap
- Handle toggle/cancel hotkeys
- Support pause/resume (for Settings window)

**Protocol**: `HotkeyManagerProtocol`

#### TextPaster (110 lines)
**Role**: Smart text insertion

**Responsibilities**:
- Detect if text field is focused
- Paste via clipboard + Cmd+V simulation

#### HistoryService (141 lines)
**Role**: SQLite persistence for transcription history

**Operations**: save, fetchAll, delete, deleteAll
**Protocol**: `HistoryServiceProtocol`

#### KeychainService (86 lines)
**Role**: Secure storage for API keys

**Operations**: save, load, delete

#### ModelDownloadService (74 lines)
**Role**: Whisper model download management

**Operations**: downloadModel, cancelDownload

#### PythonResolver (38 lines)
**Role**: Find Python executable and scripts

**Checks**: Homebrew, system Python, pyenv

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
├── ai(AIError)
│   ├── noApiKey
│   ├── invalidApiKey
│   ├── invalidResponse
│   ├── apiError(String)
│   └── networkError(Error)
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
User presses hotkey
        ↓
GlobalHotkeyManager.onToggleRecording
        ↓
AppDelegate.toggleRecording()
        ↓
RecordingCoordinator.toggleRecording()
        ↓
AudioRecorder.startRecording()
        ↓
[User speaks, audio levels monitored]
        ↓
User presses hotkey again
        ↓
AudioRecorder.stopRecording() → audioURL
        ↓
TranscriptionService.transcribe(audioURL)
        ↓
[If AI enabled] AIPostProcessingService.process(text)
        ↓
HistoryService.save(record)
        ↓
RecordingCoordinatorDelegate.transcriptionDidComplete()
        ↓
AppDelegate → TextPaster.paste() or ResultWindow
```

### Daemon Communication

```
TranscriptionService
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
    func transcribe(audioURL: URL, useDaemon: Bool) async throws -> String
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
    settings: SettingsStorageProtocol,
    aiService: AIPostProcessingServiceProtocol
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
| AIPostProcessingService | Background (async) |
| HistoryService | Main (SQLite is fast) |

---

## File Sizes Summary

| Category | Files | Total Lines |
|----------|-------|-------------|
| App | 5 | 594 |
| Models | 5 | 296 |
| ViewModels | 3 | 195 |
| Views | 18 | 2,118 |
| Services | 14 | 1,482 |
| **Total** | **45** | **4,697** |

---

## Testing

56 unit tests covering:
- Model serialization (TranscriptionRecord, Hotkey)
- Service logic (HistoryService, RecordingCoordinator)
- ViewModel behavior (HistoryViewModel)
- Settings persistence
- Window controllers

All services have mock implementations in `MurmurixTests/Mocks.swift`.
