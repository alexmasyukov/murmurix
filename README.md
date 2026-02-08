# Murmurix

A native macOS menubar app for voice-to-text transcription using local WhisperKit (CoreML), OpenAI, or Google Gemini.

**Version 2.0** | 57 production files | 298 tests | Pure Swift, no Python

## Features

- **Local Transcription (WhisperKit)** — Native CoreML inference on Apple Silicon, fully offline
- **Cloud Transcription (OpenAI)** — gpt-4o-transcribe / gpt-4o-mini-transcribe
- **Cloud Transcription (Gemini)** — Gemini 2.0 Flash / 1.5 Flash / 1.5 Pro
- **Per-Model Hotkeys** — Assign individual hotkeys to each local model and cloud mode
- **In-App Model Management** — Download, test, and delete Whisper models from Settings
- **Keep Model Loaded** — Instant transcription by keeping WhisperKit in memory
- **Voice Activity Detection** — Skips transcription if no voice detected
- **Smart Text Insertion** — Pastes directly into focused text fields
- **Animated UI** — Lottie cat animation during transcription, voice-reactive equalizer
- **Transcription History** — SQLite database with statistics
- **Multilingual Interface** — English, Russian, Spanish (switchable in Settings)
- **Dark Theme** — Native macOS dark appearance

## Requirements

- macOS 14.5+ (Sonoma)
- Apple Silicon (for WhisperKit CoreML inference)
- ~70MB to ~2.5GB disk space depending on Whisper model

## Whisper Models

Models are downloaded via WhisperKit from Hugging Face and stored in `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/`.

| Model | Size | Speed | Quality |
|-------|------|-------|---------|
| tiny | ~70MB | Fastest | Basic |
| base | ~140MB | Fast | Good |
| small | ~290MB | Medium | Better |
| medium | ~800MB | Slow | High |
| large-v2 | ~2.5GB | Slowest | Very High |
| large-v3 | ~2.5GB | Slowest | Best |

> **Recommendation:** Start with `small` for a good balance of speed and quality.

### Managing Models

Open **Settings** (Cmd+,) to:
- Download models with progress indicator
- Test local model to verify it works
- Delete individual models or all models
- Toggle "Keep model loaded" for instant transcription
- Assign a hotkey to each model

## Usage

1. Click the waveform icon in the menubar or press an assigned hotkey
2. Speak — the equalizer animates when voice is detected
3. Press the same hotkey again or click Stop to finish
4. Transcription appears:
   - **In text fields** — Text is pasted directly at cursor position
   - **Elsewhere** — Result window appears with Copy button

> If no voice is detected during recording, transcription is skipped automatically.

### Keyboard Shortcuts

All hotkeys are configurable in **Settings** (Cmd+,). No hotkeys are assigned by default except Cancel (Esc).

| Action | Default | Description |
|--------|---------|-------------|
| Local Recording | Not set | Assign per-model in Settings |
| Cloud Recording (OpenAI) | Not set | Record with OpenAI cloud API |
| Gemini Recording | Not set | Record with Google Gemini API |
| Cancel Recording | `Esc` | Cancel active recording |

## Permissions

The app requires:
- **Microphone** — For audio recording (System Settings > Privacy > Microphone)
- **Accessibility** — For global hotkeys (System Settings > Privacy > Accessibility)

## Settings

### Language
| Setting | Description |
|---------|-------------|
| App Language | English, Russian, or Spanish |
| Recognition Language | Russian, English, or Auto-detect |

### Keyboard Shortcuts
Hotkey recorders for OpenAI, Gemini, and Cancel. Local model hotkeys are configured per-model in the Local Models section.

### Local Models
Per-model cards with download, test, delete, keep loaded toggle, and individual hotkey assignment.

### Model Management
Delete all downloaded models at once.

### Cloud (OpenAI)
| Setting | Description |
|---------|-------------|
| Model | gpt-4o-transcribe or gpt-4o-mini-transcribe |
| API Key | OpenAI API key (stored in Keychain) |
| Test | Verify API connection |

### Cloud (Gemini)
| Setting | Description |
|---------|-------------|
| Model | Gemini 2.0 Flash, 1.5 Flash, or 1.5 Pro |
| API Key | Google Gemini API key (stored in Keychain) |
| Test | Verify API connection |

## Data Storage

| Data | Location | Retention |
|------|----------|-----------|
| Settings | `~/Library/Preferences/` | Persistent |
| API Keys | macOS Keychain | Persistent, encrypted |
| History | `~/Library/Application Support/Murmurix/history.sqlite` | Persistent |
| Audio files | `/tmp/` | Deleted after transcription |
| WhisperKit models | `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/` | Persistent |

### External Database Access

```bash
sqlite3 ~/Library/Application\ Support/Murmurix/history.sqlite "SELECT * FROM transcriptions ORDER BY created_at DESC"
```

**Schema:**
```sql
CREATE TABLE transcriptions (
    id TEXT PRIMARY KEY,
    text TEXT NOT NULL,
    language TEXT NOT NULL,
    duration REAL NOT NULL,
    created_at REAL NOT NULL  -- Unix timestamp
);
```

## Testing

298 tests using Apple's Swift Testing framework:

```bash
xcodebuild -project Murmurix.xcodeproj -scheme Murmurix -destination 'platform=macOS' test
```

| Suite | Tests | Description |
|-------|-------|-------------|
| RecordingCoordinatorTests | 20 | Recording state machine, modes, file cleanup |
| Phase1Tests | 55 | AudioTestUtility, MIMETypeResolver, mocks |
| Phase2Tests | 20 | URLSession abstractions |
| Phase3Tests | 18 | ViewModel API testing, Settings DI |
| Phase4Tests | 8 | KeychainKey enum |
| RefactoringTests | 42 | Error hierarchy, constants, DB, Logger, DI |
| SettingsTests | 13 | Settings persistence and defaults |
| GeminiTests | 13 | Gemini integration |
| MurmurixTests | 25 | HistoryViewModel, ResultWindowController |
| NewFunctionalityTests | 69 | Model management, timer, migration, enums |
| IntegrationTests | 3 | End-to-end tests |

## Architecture

See [ARCHITECT.md](ARCHITECT.md) for detailed architecture documentation.

## Tech Stack

- **Swift** — async/await, Sendable, SwiftUI + AppKit
- **WhisperKit** — Native CoreML speech recognition (Apple Silicon)
- **GoogleGenerativeAI** — Google Gemini API client
- **Lottie** — Animated loading states
- **SQLite** — Transcription history
- **Keychain** — Secure API key storage

## License

MIT
