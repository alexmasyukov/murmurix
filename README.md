# Murmurix

A native macOS menubar app for voice-to-text transcription using local WhisperKit (CoreML), OpenAI, or Google Gemini.

**Version 2.0** | 54 production files | 305 tests | Pure Swift, no Python

## Features

- **Local Transcription (WhisperKit)** — Native CoreML inference on Apple Silicon, fully offline
- **Cloud Transcription (OpenAI)** — gpt-4o-transcribe / gpt-4o-mini-transcribe
- **Cloud Transcription (Gemini)** — Gemini 2.0 Flash / 1.5 Flash / 1.5 Pro
- **Triple Hotkeys** — Separate shortcuts for each transcription mode
- **In-App Model Management** — Download, test, and delete Whisper models from Settings
- **Keep Model Loaded** — Instant transcription by keeping WhisperKit in memory
- **Voice Activity Detection** — Skips transcription if no voice detected
- **Smart Text Insertion** — Pastes directly into focused text fields
- **Animated UI** — Lottie cat animation during transcription, voice-reactive equalizer
- **Transcription History** — SQLite database with statistics
- **Dark Theme** — Native macOS dark appearance

## Requirements

- macOS 14.5+ (Sonoma)
- Apple Silicon (for WhisperKit CoreML inference)
- ~75MB to ~3GB disk space depending on Whisper model

## Whisper Models

Models are downloaded via WhisperKit from Hugging Face and stored in `~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/`.

| Model | Size | Speed | Quality |
|-------|------|-------|---------|
| tiny | ~75MB | Fastest | Basic |
| base | ~140MB | Fast | Good |
| small | ~460MB | Medium | Better |
| medium | ~1.5GB | Slow | High |
| large-v2 | ~3GB | Slowest | Very High |
| large-v3 | ~3GB | Slowest | Best |

> **Recommendation:** Start with `small` for a good balance of speed and quality.

### Managing Models

Open **Settings** (Cmd+,) to:
- Download models with progress indicator
- Test local model to verify it works
- Delete individual models or all models
- Toggle "Keep model loaded" for instant transcription

## Usage

1. Click the waveform icon in the menubar or press a hotkey:
   - `^C` for local WhisperKit transcription
   - `^D` for cloud OpenAI transcription
   - `^G` for cloud Gemini transcription
2. Speak — the equalizer animates when voice is detected
3. Press the same hotkey again or click Stop to finish
4. Transcription appears:
   - **In text fields** — Text is pasted directly at cursor position
   - **Elsewhere** — Result window appears with Copy button

> If no voice is detected during recording, transcription is skipped automatically.

### Keyboard Shortcuts

| Action | Default | Description |
|--------|---------|-------------|
| Local Recording | `^C` | Record with local WhisperKit model |
| Cloud Recording (OpenAI) | `^D` | Record with OpenAI cloud API |
| Gemini Recording | `^G` | Record with Google Gemini API |
| Cancel Recording | `Esc` | Cancel active recording |

Customize hotkeys in **Settings** (Cmd+,).

## Permissions

The app requires:
- **Microphone** — For audio recording (System Settings > Privacy > Microphone)
- **Accessibility** — For global hotkeys (System Settings > Privacy > Accessibility)

## Settings

### Keyboard Shortcuts
Separate hotkey recorders for Local, OpenAI, Gemini, and Cancel.

### Recognition
| Setting | Description |
|---------|-------------|
| Language | Russian, English, or Auto-detect |

### Local (WhisperKit)
| Setting | Description |
|---------|-------------|
| Model | Whisper model (tiny to large-v3) |
| Keep model loaded | Faster transcription, keeps CoreML model in memory |
| Test | Verify local model works correctly |

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

305 tests using Apple's Swift Testing framework:

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
