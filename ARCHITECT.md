# Murmurix Architecture

## Overview

Murmurix is a native macOS menubar application for voice-to-text transcription with local (WhisperKit/CoreML) or cloud (OpenAI/Gemini) processing. Pure Swift, no external runtimes.

```
+---------------------------------------------------------------+
|                      Presentation Layer                       |
|  +----------+  +-----------+  +---------------------------+   |
|  |  Views   |  | ViewModels|  |   Window Controllers      |   |
|  +----------+  +-----------+  +---------------------------+   |
+---------------------------------------------------------------+
|                      Coordination Layer                       |
|  +----------+  +-----------+  +---------------------------+   |
|  |AppDelegate|  | Managers |  |  RecordingCoordinator     |   |
|  +----------+  +-----------+  +---------------------------+   |
+---------------------------------------------------------------+
|                       Service Layer                           |
|  +----------+  +-----------+  +---------------------------+   |
|  |  Audio   |  |Transcriptn|  |  Audio Compression        |   |
|  +----------+  +-----------+  +---------------------------+   |
+---------------------------------------------------------------+
|                        Data Layer                             |
|  +----------+  +-----------+  +---------------------------+   |
|  | Settings |  |  History  |  |      Keychain             |   |
|  +----------+  +-----------+  +---------------------------+   |
+---------------------------------------------------------------+
|                       External Layer                          |
|  +----------+  +-----------+  +---------------------------+   |
|  |WhisperKit|  | OpenAI API|  |    Hugging Face           |   |
|  +----------+  +-----------+  +---------------------------+   |
|  +----------+  +-----------+                                  |
|  |  Lottie  |  | Gemini API|                                  |
|  +----------+  +-----------+                                  |
+---------------------------------------------------------------+
```

## Directory Structure

```
Murmurix/
+-- App/                          # Application lifecycle
|   +-- main.swift               # Entry point
|   +-- AppDelegate.swift        # App lifecycle, coordination
|   +-- AppConstants.swift       # Constants, ModelPaths, Defaults
|   +-- MenuBarManager.swift     # Status bar and menu
|   +-- WindowManager.swift      # Window lifecycle
|   +-- WindowPositioner.swift   # Window positioning utility
|
+-- Models/                       # Data models
|   +-- Settings.swift           # UserDefaults wrapper (SettingsStorageProtocol)
|   +-- Hotkey.swift             # Hotkey model with key codes
|   +-- TranscriptionRecord.swift# History record
|   +-- WhisperModel.swift       # Whisper model enum (6 cases)
|   +-- OpenAITranscriptionModel.swift
|   +-- GeminiTranscriptionModel.swift
|   +-- APITestResult.swift      # API test result enum
|
+-- ViewModels/                   # Presentation logic
|   +-- HistoryViewModel.swift   # History list logic
|   +-- GeneralSettingsViewModel.swift # Settings + model download
|   +-- RecordingTimer.swift     # Recording duration timer
|
+-- Views/                        # SwiftUI views
|   +-- SettingsView.swift       # Settings wrapper
|   +-- GeneralSettingsView.swift# All settings
|   +-- HistoryView.swift
|   +-- HotkeyRecorderView.swift
|   +-- ResultView.swift
|   +-- Recording/               # Recording UI
|   |   +-- RecordingView.swift
|   |   +-- EqualizerView.swift
|   |   +-- CatLoadingView.swift # Lottie animation
|   |   +-- RecordingComponents.swift
|   +-- History/                 # History UI
|   |   +-- HistoryStatsView.swift
|   |   +-- HistoryRowView.swift
|   |   +-- HistoryDetailView.swift
|   +-- Components/              # Reusable components
|   |   +-- LottieView.swift
|   |   +-- ApiKeyField.swift
|   |   +-- TestResultBadge.swift
|   |   +-- SectionHeader.swift
|   |   +-- SettingsStyles.swift
|   +-- *WindowController.swift  # NSWindowController wrappers
|
+-- Services/                     # Business logic
    +-- Protocols.swift          # All service protocols
    +-- MurmurixError.swift      # Unified error hierarchy
    +-- Logger.swift             # os.log with categories
    +-- AudioRecorder.swift      # AVAudioRecorder wrapper
    +-- AudioCompressor.swift    # WAV to M4A (AAC)
    +-- TranscriptionService.swift # Routes to WhisperKit/OpenAI/Gemini
    +-- WhisperKitService.swift  # Native CoreML inference
    +-- OpenAITranscriptionService.swift
    +-- GeminiTranscriptionService.swift
    +-- RecordingCoordinator.swift # Recording state machine
    +-- GlobalHotkeyManager.swift # CGEvent tap for shortcuts
    +-- TextPaster.swift         # Clipboard + paste
    +-- Repository.swift         # SQLiteDatabase + Repository
    +-- HistoryService.swift     # Delegates to Repository
    +-- KeychainService.swift    # Secure key storage
    +-- AudioTestUtility.swift   # Test WAV generation
    +-- MIMETypeResolver.swift   # Audio MIME types
```

**54 Swift files, ~5500 lines of production code**

## Key Services

### WhisperKitService
Native CoreML speech recognition via WhisperKit.

- `loadModel(name:)` — Load a CoreML model from `~/Documents/huggingface/`
- `unloadModel()` — Free memory
- `transcribe(audioURL:language:)` — Run inference
- `downloadModel(_:progress:)` — Download from Hugging Face

Thread-safe with NSLock. Singleton with DI override via `WhisperKitServiceProtocol`.

### TranscriptionService
Routes transcription requests based on mode:

```swift
func transcribe(audioURL: URL, mode: TranscriptionMode) async throws -> String {
    switch mode {
    case .local:  return try await transcribeViaWhisperKit(audioURL: audioURL)
    case .openai: return try await transcribeViaOpenAI(audioURL: audioURL)
    case .gemini: return try await transcribeViaGemini(audioURL: audioURL)
    }
}
```

### RecordingCoordinator
State machine managing the full recording lifecycle:

```
idle --> recording --> transcribing --> idle
           |              |
         cancel          cancel
           |              |
          idle            idle
```

- Coordinates AudioRecorder, TranscriptionService, HistoryService
- Compresses audio to M4A for cloud modes (~10x smaller)
- Cleans up audio files after transcription
- Voice activity detection (skips if no speech)

### GlobalHotkeyManager
System-wide keyboard shortcuts via CGEvent tap:

- `onToggleLocalRecording` — ^C
- `onToggleCloudRecording` — ^D
- `onToggleGeminiRecording` — ^G
- `onCancelRecording` — Esc

## Error Hierarchy

```
MurmurixError
+-- transcription(TranscriptionError)
|   +-- modelNotLoaded
|   +-- failed(String)
|   +-- timeout
+-- model(ModelError)
|   +-- downloadFailed(String)
|   +-- loadFailed(String)
|   +-- notFound(String)
+-- system(SystemError)
    +-- microphonePermissionDenied
    +-- accessibilityPermissionDenied
    +-- fileNotFound(String)
    +-- unknown(Error)
```

All errors provide `errorDescription` and `recoverySuggestion`.

## Data Flow

```
User presses hotkey (^C / ^D / ^G)
        |
GlobalHotkeyManager.onToggle[Local|Cloud|Gemini]Recording
        |
AppDelegate.toggleRecording(mode:)
        |
RecordingCoordinator.toggleRecording(mode:)
        |
AudioRecorder.startRecording()
        |
[User speaks, audio levels monitored]
        |
User presses same hotkey again
        |
AudioRecorder.stopRecording() --> audioURL
        |
[Cloud mode: AudioCompressor.compress() --> M4A]
        |
TranscriptionService.transcribe(audioURL, mode)
        |
HistoryService.save(record)
        |
Delete audio file
        |
AppDelegate --> TextPaster.paste() or ResultWindow
```

## Dependency Injection

All services use protocol-based DI for testability:

```swift
init(
    audioRecorder: AudioRecorderProtocol,
    transcriptionService: TranscriptionServiceProtocol,
    historyService: HistoryServiceProtocol,
    settings: SettingsStorageProtocol
)
```

11 mock implementations in `MurmurixTests/Mocks.swift`.

## Thread Model

| Component | Thread |
|-----------|--------|
| AppDelegate, all UI | Main |
| AudioRecorder level updates | Main (via timer) |
| TranscriptionService.transcribe | Background (Task.detached) |
| HistoryService | Main (SQLite is fast) |
| WhisperKitService | Background (async) |

## Logging

Centralized via `os.log` with categories:

- `Logger.Audio` — Recording events
- `Logger.Transcription` — Transcription events
- `Logger.Model` — WhisperKit model lifecycle
- `Logger.Hotkey` — Hotkey manager
- `Logger.History` — Database operations

## Testing

305 tests (12 test files) using Swift Testing framework (`@Test`, `#expect`).

Coverage: services, ViewModels, models, settings, error hierarchy, constants, DI, recording state machine, file cleanup, transcription modes, model management, settings migration.
