# Murmurix

A native macOS menubar app for voice-to-text transcription using local WhisperKit (CoreML), OpenAI, or Google Gemini.

**Version 4.5.0** | 66 production files | 422 tests | Pure Swift, no Python

## Features

- **Local Transcription (WhisperKit)** — Native CoreML inference on Apple Silicon, fully offline
- **Cloud Transcription (OpenAI)** — gpt-4o-transcribe / gpt-4o-mini-transcribe
- **Cloud Transcription (Gemini)** — Gemini 2.0 Flash / 1.5 Flash / 1.5 Pro
- **Per-Model Hotkeys** — Assign individual hotkeys to each local model and cloud mode
- **In-App Model Management** — Download, test, and delete Whisper models from Settings; the Test button reports its phase step by step with an elapsed counter (CoreML load can take a while on a cold cache)
- **Keep Model Loaded** — Instant transcription by keeping WhisperKit in memory, with a live status indicator (in memory / loading / not loaded) polled from the real service state
- **Voice Activity Detection** — Skips transcription if no voice detected
- **Anti-Hallucination** — Trims leading/trailing silence before inference (edges are only cut when ≥1s of silence is actually removed, so speech right before the hotkey press survives) and filters memorized subtitle filler ("Продолжение следует...") that Whisper invents over silent tails and long mid-dictation pauses
- **Smart Text Insertion** — Pastes directly into focused text fields
- **Clipboard-Safe Paste** — Snapshots and restores your original clipboard (text, images, files — any type) after inserting the result
- **Local HTTP API** — Other apps can POST audio to `127.0.0.1` and get a transcription back, reusing the in-memory models and full pipeline (see below)
- **Animated UI** — Lottie cat animation during transcription, voice-reactive equalizer
- **Transcription History** — SQLite database with statistics
- **Multilingual Interface** — English, Russian, Spanish (switchable in Settings)
- **Dark Theme** — Native macOS dark appearance

## Requirements

- macOS 14.5+ (Sonoma)
- Apple Silicon (for WhisperKit CoreML inference)
- ~70MB to ~2.5GB disk space depending on Whisper model

## Whisper Models

Models are downloaded via WhisperKit from Hugging Face and stored by build type:
- `Debug` and `Tests` (shared dev repo): `~/Library/Application Support/murmurix-dev-models/huggingface/models/argmaxinc/whisperkit-coreml/`
- `Release` (including DMG builds): `~/Library/Application Support/Murmurix/huggingface/models/argmaxinc/whisperkit-coreml/`

> All paths live under `Application Support`, never under `~/Documents`. macOS iCloud Drive's "Desktop & Documents" sync virtualizes `~/Documents`, which blocks WhisperKit reads on cold start after reboot. `Application Support` is excluded from iCloud by Apple's own design.

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
| Audio files | user temp dir (`$TMPDIR`) | Deleted after transcription; crash leftovers older than 1h swept at launch |
| WhisperKit models (Debug + Tests) | `~/Library/Application Support/murmurix-dev-models/huggingface/models/argmaxinc/whisperkit-coreml/` | Shared dev repo, isolated from production |
| WhisperKit models (Release/DMG) | `~/Library/Application Support/Murmurix/huggingface/models/argmaxinc/whisperkit-coreml/` | Persistent, iCloud-safe |

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

422 tests using Apple's Swift Testing framework:

```bash
xcodebuild -project Murmurix.xcodeproj -scheme Murmurix -destination 'platform=macOS' test
```

| Area | Tests | Covers |
|------|-------|--------|
| Settings & model management | 95 | Settings persistence/migration, GeneralSettingsViewModel, download/test flows |
| Recording flow & hotkeys | 75 | RecordingCoordinator, flow reducer, timer, hotkey managers |
| Audio & anti-hallucination | 63 | AudioRecorder, decoder/compressor, SilenceTrimmer, HallucinationFilter |
| Transcription services | 56 | WhisperKit/OpenAI/Gemini clients, prompt policy, serial transcriber |
| Infrastructure | 48 | Error hierarchy, constants, Logger, DI, URLSession mocks |
| History & storage | 38 | SQLite repository, HistoryService/ViewModel, Keychain |
| UI & windows | 30 | Menu bar, result window, positioning, TextPaster, clipboard restore |
| Local HTTP API | 17 | APIServer endpoints, MIME resolution |

## Local HTTP API

Enable **Settings → API → Local API server** to let other apps transcribe audio through Murmurix, reusing the models it already keeps in memory instead of each app loading its own copy. The server binds to `127.0.0.1` only (loopback). Default port `51789` (configurable in Settings).

Audio is decoded to a 16 kHz mono buffer **in memory** — nothing is written to disk. Requests are queued and processed one at a time (the Apple Neural Engine is a shared resource). The same pipeline as recording applies: edge-silence trimming and the hallucination filter.

### Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET`  | `/health` | Liveness check → `{"status":"ok","app":"Murmurix"}` |
| `GET`  | `/v1/models` | Installed and loaded models → `{"installed":[...],"loaded":[...]}` |
| `POST` | `/v1/transcribe?model=<name>&language=<ru\|en\|auto>` | Transcribe the request body → `{"text":"..."}` |

`POST /v1/transcribe` takes the audio as the **raw request body**: a WAV (PCM 16-bit or Float32, any sample rate / channel count — down-mixed and resampled to 16 kHz mono), or raw Float32 mono @ 16 kHz. `model` is required (a model name as shown in `/v1/models`); `language` defaults to `auto`.

### Example

```bash
# List available models
curl http://127.0.0.1:51789/v1/models

# Transcribe a WAV file
curl -X POST "http://127.0.0.1:51789/v1/transcribe?model=large-v3-v20240930_turbo_632MB&language=ru" \
  --data-binary @recording.wav -H "Content-Type: audio/wav"
# → {"text":"..."}
```

Errors return JSON `{"error":"..."}` with status `400` (bad request — e.g. missing `model` or undecodable audio) or `500` (transcription failure).

## Release Build (DMG)

Production artifacts should be published as `.dmg` (not `.zip`):

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project Murmurix.xcodeproj -scheme Murmurix \
-configuration Release -destination 'platform=macOS' \
-derivedDataPath /tmp/murmurix-dd-prod build

hdiutil create -volname "Murmurix" -srcfolder /tmp/murmurix-dd-prod/Build/Products/Release/Murmurix.app \
-ov -format UDZO /tmp/Murmurix-vX.Y-macOS.dmg
```

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
