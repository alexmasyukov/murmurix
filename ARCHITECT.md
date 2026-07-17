# Murmurix Architecture

## Overview

Murmurix is a native macOS menubar application for voice-to-text transcription with local (WhisperKit/CoreML) or cloud (OpenAI/Gemini) processing. Pure Swift, no external runtimes. Multilingual interface (EN/RU/ES).

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
|   +-- AppLanguage.swift        # App language enum (EN/RU/ES)
|   +-- L10n.swift               # Localization strings
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
|   |   +-- WhisperModelCardView.swift
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
    +-- SilenceTrimmer.swift     # Trims edge silence via EnergyVAD (anti-hallucination)
    +-- HallucinationFilter.swift # Strips memorized subtitle filler from results
    +-- OpenAITranscriptionService.swift
    +-- GeminiTranscriptionService.swift
    +-- RecordingCoordinator.swift # Recording state machine
    +-- GlobalHotkeyManager.swift # CGEvent tap for shortcuts
    +-- APIServer.swift          # Local HTTP API (Swifter) + SerialTranscriber queue
    +-- AudioDecoder.swift       # In-memory WAV/PCM -> 16 kHz mono float
    +-- TextPaster.swift         # Clipboard-safe paste (snapshot + restore)
    +-- Repository.swift         # SQLiteDatabase + Repository
    +-- HistoryService.swift     # Delegates to Repository
    +-- KeychainService.swift    # Secure key storage
    +-- AudioTestUtility.swift   # Test WAV generation
    +-- MIMETypeResolver.swift   # Audio MIME types
```

**66 Swift files, ~6700 lines of production code**

## Localization

Enum-based `L10n.swift` with `tr(en, ru, es)` helper. No .lproj/.strings files.

- SwiftUI views re-render via `@AppStorage("appLanguage")`
- AppKit menus/windows update via `NotificationCenter` → `.appLanguageDidChange`
- Language switch is instant, no restart required

## Key Services

### WhisperKitService
Native CoreML speech recognition via WhisperKit.

- `loadModel(name:)` — Load a CoreML model from `ModelPaths`. Prod and dev keep
  **separate** directories (all under Application Support) so local development
  and tests never touch the shipped production models; the dev repo is meant to
  mirror the prod folder's model set. Selection is controlled by
  `MURMURIX_USE_TEMP_MODEL_REPO` (`#if DEBUG` defaults to the dev repo unless set
  to `0`), or overridden entirely with `MURMURIX_MODEL_REPO_DIR`:
  - `Release`: `~/Library/Application Support/Murmurix/huggingface/...`
  - `Debug` + Tests (shared dev repo): `~/Library/Application Support/murmurix-dev-models/huggingface/...`
- `unloadModel()` — Free memory
- `transcribe(audioURL:language:)` — Loads audio, trims edge silence via
  `SilenceTrimmer`, then runs inference (falls back to file path on error)
- `downloadModel(_:progress:)` — Download from Hugging Face

Thread-safe with NSLock. Singleton with DI override via `WhisperKitServiceProtocol`.

### SilenceTrimmer / HallucinationFilter
Two layers that suppress Whisper's trailing-silence hallucinations (memorized
YouTube-subtitle filler like "Продолжение следует...", "Спасибо за просмотр").
WhisperKit's built-in VAD chunker only runs on audio longer than 30s, so short
dictations reach the decoder whole — silent tail included.

- `SilenceTrimmer.trim(_:)` — loads the recording into a 16kHz buffer and trims
  leading/trailing silence via `EnergyVAD` before decoding, keeping internal
  pauses and 0.2s edge padding. Recordings ≤2.5s (single-word dictations) are
  passed through untouched — on such short clips EnergyVAD can mis-bound the one
  word and trim it away, leaving nothing to decode.
- `HallucinationFilter.clean(_:)` — deterministically strips known filler
  phrases from the tail of the result. Local (WhisperKit) mode only — cloud
  providers steer output with their own prompts and don't exhibit this.

### APIServer / AudioDecoder
Optional local HTTP API (Swifter) so other apps reuse Murmurix's in-memory
models instead of loading their own. Bound to `127.0.0.1` only; toggle + port in
Settings (default 51789). Started/stopped from `AppDelegate` via
`apiServerSettingsDidChange`.

- Routes: `GET /health`, `GET /v1/models`,
  `POST /v1/transcribe?model=&language=` with audio as the request body.
- `AudioDecoder` turns the body (WAV PCM16/Float32 or raw Float32) into a 16 kHz
  mono buffer **in memory** — API requests never touch disk.
- `SerialTranscriber` (actor) serializes requests into a queue so concurrent
  callers don't fight over the ANE.
- Handlers call `TranscriptionService.transcribe(samples:)`, the in-memory path
  shared with the file/mic route (same trim + hallucination filter).

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

### AudioRecorder — start latency
The hotkey path to `record()` is a hard latency budget: anything on it is speech
the user has already spoken and we never captured. Measured end-to-end (keypress
→ microphone actually recording): **median 23ms, p90 28ms**.

Two things keep it there, and both are easy to undo by accident:

- `prepare()` builds the `AVAudioRecorder` and calls `prepareToRecord()` ahead of
  time — at launch and after every stop. A cold `record()` that does its own file
  and audio-queue setup costs ~83ms and loses ~69ms of audio; pre-primed, it
  returns in ~25ms. `prepareToRecord()` does not open the input, so no microphone
  indicator appears and nothing is captured until `record()` runs.
- **No Accessibility calls before `record()`.** `TextPaster.focusedContext()` is a
  synchronous IPC round-trip into the focused app; a busy Chrome/Electron/JetBrains
  target stalls the main thread for hundreds of ms. It used to run ahead of
  `record()` and is now in `AppDelegate.recordingDidStart()` — after the microphone
  is live, still before our own window can steal focus.

### GlobalHotkeyManager
System-wide keyboard shortcuts via CGEvent tap:

- Per-model local hotkeys (configurable per Whisper model)
- Cloud OpenAI hotkey (configurable, no default)
- Cloud Gemini hotkey (configurable, no default)
- Cancel hotkey (default: Esc)

All hotkeys are optional — only Cancel has a default (Escape).

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
User presses assigned hotkey
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

403 tests using Swift Testing framework (`@Test`, `#expect`).

Coverage: services, ViewModels, models, settings, error hierarchy, constants, DI, recording state machine, file cleanup, transcription modes, model management, settings migration.
