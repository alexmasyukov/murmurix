# Murmurix

A native macOS menubar app for local voice-to-text transcription using [faster-whisper](https://github.com/guillaumekln/faster-whisper).

## Features

- **Global Hotkeys** — Trigger recording from anywhere with customizable shortcuts
- **Local Processing** — All transcription happens on-device, no cloud services
- **AI Post-Processing** — Optional Claude API integration to fix technical terms
- **Daemon Mode** — Keep the model in memory for instant transcription (~500MB RAM)
- **Dynamic Island UI** — Minimal floating window with voice-reactive equalizer
- **Voice Activity Detection** — Automatically skips transcription if no voice detected
- **Smart Text Insertion** — Pastes directly into text fields, shows result window otherwise
- **Transcription History** — SQLite database stores all transcriptions with statistics
- **Cancel Transcription** — Abort long-running transcriptions with cancel button
- **Dark Theme** — Native macOS dark appearance throughout

## Requirements

- macOS 13.0+
- Python 3.11+
- ~2GB disk space for the model

## Installation

### 1. Install Python dependencies

```bash
pip install faster-whisper
```

### 2. Download the Whisper model

```bash
# Create models directory
mkdir -p ~/Library/Application\ Support/Murmurix/models

# Download faster-whisper-small (recommended)
# Models are auto-downloaded on first use, or you can pre-download from:
# https://huggingface.co/guillaumekln/faster-whisper-small
```

### 3. Copy Python scripts

```bash
cp Python/transcribe.py ~/Library/Application\ Support/Murmurix/
cp Python/transcribe_daemon.py ~/Library/Application\ Support/Murmurix/
```

### 4. Grant permissions

The app requires:
- **Microphone** — For audio recording
- **Accessibility** — For global hotkeys

## Usage

1. Click the waveform icon in the menubar or press the hotkey (default: `⌃D`)
2. Speak — the equalizer animates when voice is detected
3. Press the hotkey again or click Stop to finish
4. Transcription appears:
   - **In text fields** — Text is pasted directly at cursor position
   - **Elsewhere** — Result window appears with Copy button

> **Note:** If no voice is detected during recording, transcription is skipped to prevent Whisper hallucinations.

### Keyboard Shortcuts

| Action | Default | Menu |
|--------|---------|------|
| Toggle Recording | `⌃D` | Shown in menu |
| Cancel Recording | `Esc` | — |
| History | `⌘H` | History... |
| Settings | `⌘,` | Settings... |
| Quit | `⌘Q` | Quit |

Customize hotkeys in **Settings** (⌘,)

## Architecture

```
Murmurix/
├── App/
│   └── AppDelegate.swift          # App lifecycle, menu bar
├── Models/
│   ├── Hotkey.swift               # Hotkey model with key codes
│   ├── TranscriptionRecord.swift  # History record model
│   └── Settings.swift             # Settings storage wrapper
├── Services/
│   ├── Protocols.swift            # Service protocols for DI
│   ├── AudioRecorder.swift        # AVAudioRecorder with metering
│   ├── GlobalHotkeyManager.swift  # CGEvent tap for shortcuts
│   ├── TranscriptionService.swift # Python subprocess & daemon
│   ├── HistoryService.swift       # SQLite history storage
│   ├── RecordingCoordinator.swift # Recording business logic
│   ├── TextPaster.swift           # Clipboard & keyboard paste
│   ├── KeychainService.swift      # Secure API key storage
│   └── AIPostProcessingService.swift # Claude API integration
├── Views/
│   ├── RecordingView.swift        # Dynamic Island-style UI
│   ├── ResultView.swift           # Transcription result
│   ├── HistoryView.swift          # History browser
│   ├── SettingsView.swift         # Settings panel
│   └── HotkeyRecorderView.swift   # Custom hotkey picker
└── Python/
    ├── transcribe.py              # Direct transcription
    └── transcribe_daemon.py       # Socket server for persistent model
```

## Testing

The project includes 36 unit tests with mocks for all services:

```bash
# Run tests in Xcode
⌘U

# Run only unit tests (faster, skips UI tests)
xcodebuild test -scheme Murmurix -destination 'platform=macOS' -only-testing:MurmurixTests
```

**Test coverage:**
- `TranscriptionRecordTests` — Model serialization, formatting
- `HistoryServiceTests` — SQLite CRUD operations
- `HistoryViewModelTests` — ViewModel logic, statistics
- `HotkeyTests` — Hotkey encoding, display
- `AudioRecorderTests` — Recording state, audio levels
- `GlobalHotkeyManagerTests` — Hotkey callbacks, state
- `RecordingCoordinatorTests` — Recording state machine
- `ResultWindowControllerTests` — Window properties
- `SettingsTests` — UserDefaults persistence
- `TextPasterTests` — Text focus detection, paste

## Settings

### General
| Setting | Description |
|---------|-------------|
| Keep model in memory | Faster transcription, uses ~500MB RAM |
| Language | Russian, English, or Auto-detect |
| Toggle Recording | Customizable hotkey |
| Cancel Recording | Customizable hotkey |

### AI Processing
| Setting | Description |
|---------|-------------|
| Enable AI post-processing | Send transcription to Claude for term correction |
| API Key | Your Claude API key (stored in Keychain) |
| Model | Haiku (fast), Sonnet, or Opus (best) |
| Prompt | Customizable instructions for term replacement |

The AI post-processing is designed to fix technical terms that Whisper transcribes as Russian phonetic equivalents. For example:
- "кафка" → "Kafka"
- "реакт" → "React"
- "гоуэнг" → "Go/Golang"

## Data Storage

| Data | Location | Retention |
|------|----------|-----------|
| Settings | `~/Library/Preferences/` | Persistent |
| API Key | macOS Keychain | Persistent, encrypted |
| History | `~/Library/Application Support/Murmurix/history.sqlite` | Persistent |
| Audio files | `/tmp/` | Deleted after transcription |
| Model | `~/Library/Application Support/Murmurix/models/` | Persistent |

### External Database Access

You can connect to the SQLite database externally while the app is running:

```bash
# CLI
sqlite3 ~/Library/Application\ Support/Murmurix/history.sqlite

# Query history
sqlite3 ~/Library/Application\ Support/Murmurix/history.sqlite "SELECT * FROM transcriptions ORDER BY created_at DESC"
```

**JDBC URL** (for IDE database tools):
```
jdbc:sqlite:/Users/<username>/Library/Application Support/Murmurix/history.sqlite
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

## Supported Languages

faster-whisper supports 99 languages. Currently exposed in UI:
- Russian (ru)
- English (en)
- Auto-detect

## License

MIT
