# Murmurix

A native macOS menubar app for local voice-to-text transcription using [faster-whisper](https://github.com/guillaumekln/faster-whisper).

## Features

- **Global Hotkeys** — Trigger recording from anywhere with customizable shortcuts
- **Local Processing** — All transcription happens on-device, no cloud services
- **AI Post-Processing** — Optional Claude 4.5 API integration to fix technical terms (with structured outputs)
- **In-App Model Download** — Download Whisper models directly from Settings with progress indicator
- **Daemon Mode** — Keep the model in memory for instant transcription (~500MB RAM)
- **Multiple Models** — Choose from 6 Whisper models (tiny to large-v3)
- **Dynamic Island UI** — Minimal floating window with voice-reactive equalizer
- **Voice Activity Detection** — Automatically skips transcription if no voice detected
- **Smart Text Insertion** — Pastes directly into text fields, shows result window otherwise
- **Transcription History** — SQLite database stores all transcriptions with statistics
- **Cancel Transcription** — Abort long-running transcriptions with cancel button
- **Dark Theme** — Native macOS dark appearance throughout

## Requirements

- macOS 13.0+
- Python 3.11+
- ~75MB to ~3GB disk space depending on model

## Installation

### 1. Install Python dependencies

```bash
pip install faster-whisper huggingface_hub
```

### 2. Copy Python scripts

```bash
mkdir -p ~/Library/Application\ Support/Murmurix
cp Python/transcribe.py ~/Library/Application\ Support/Murmurix/
cp Python/transcribe_daemon.py ~/Library/Application\ Support/Murmurix/
```

### 3. Download a Whisper model

Models are stored in the standard Hugging Face cache (`~/.cache/huggingface/hub/`).

```bash
# List available models and their status
python ~/Library/Application\ Support/Murmurix/transcribe_daemon.py --list-models

# Download a model (choose one)
python ~/Library/Application\ Support/Murmurix/transcribe_daemon.py --download small
```

**Available models:**

| Model | Size | Speed | Quality | RAM Usage |
|-------|------|-------|---------|-----------|
| tiny | ~75MB | Fastest | Basic | ~200MB |
| base | ~140MB | Fast | Good | ~300MB |
| small | ~460MB | Medium | Better | ~500MB |
| medium | ~1.5GB | Slow | High | ~1.5GB |
| large-v2 | ~3GB | Slowest | Very High | ~3GB |
| large-v3 | ~3GB | Slowest | Best | ~3GB |

> **Recommendation:** Start with `small` for a good balance of speed and quality.

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

## Whisper Models

### Switching Models

1. Open **Settings** → **General**
2. Select a model from the **Model** dropdown
3. If model is not installed:
   - You'll see "(not installed)" warning and **Download** button
   - Click Download to install the model (progress indicator shown)
   - After download completes, the daemon automatically starts with the new model
4. For installed models, the daemon automatically restarts on selection

### Managing Models via CLI

```bash
cd ~/Library/Application\ Support/Murmurix

# List all models with installation status
python transcribe_daemon.py --list-models

# Output:
# Available models:
#   tiny: ✓ installed
#   base: ✗ not installed
#   small: ✓ installed
#   medium: ✗ not installed
#   large-v2: ✗ not installed
#   large-v3: ✗ not installed

# Download a specific model
python transcribe_daemon.py --download medium

# Models are cached in ~/.cache/huggingface/hub/
```

### Daemon Commands (via Unix Socket)

The daemon accepts JSON commands:

```bash
# List models
echo '{"command": "list_models"}' | nc -U ~/Library/Application\ Support/Murmurix/daemon.sock

# Download model (blocking, may take a while)
echo '{"command": "download_model", "model": "medium"}' | nc -U ~/Library/Application\ Support/Murmurix/daemon.sock
```

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
│   ├── AIPostProcessingService.swift # Claude 4.5 API with structured outputs
│   └── ModelDownloadService.swift # Whisper model downloader
├── Views/
│   ├── RecordingView.swift        # Dynamic Island-style UI
│   ├── ResultView.swift           # Transcription result
│   ├── HistoryView.swift          # History browser
│   ├── SettingsView.swift         # Settings panel
│   └── HotkeyRecorderView.swift   # Custom hotkey picker
└── Python/
    ├── transcribe.py              # Direct transcription (one-shot)
    └── transcribe_daemon.py       # Socket server with model management
```

## Testing

The project includes 56 unit tests with mocks for all services:

```bash
# Run tests in Xcode
⌘U

# Run from command line (disable parallel testing for stability)
xcodebuild test -scheme Murmurix -destination 'platform=macOS' -only-testing:MurmurixTests -parallel-testing-enabled NO
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
| Toggle Recording | Customizable hotkey (default: `⌃D`) |
| Cancel Recording | Customizable hotkey (default: `Esc`) |
| Keep model in memory | Faster transcription, uses ~500MB RAM |
| Language | Russian, English, or Auto-detect |
| Model | Whisper model (restarts daemon on change) |

### AI Processing
| Setting | Description |
|---------|-------------|
| Enable AI post-processing | Send transcription to Claude for term correction |
| API Key | Your Claude API key (stored in Keychain) |
| Test | Verify API key connection before saving |
| Model | Haiku 4.5 (fast), Sonnet 4.5, or Opus 4.5 (best) |
| Prompt | Customizable instructions for term replacement |

**Claude 4.5 Models:**
- `claude-haiku-4-5` — Fastest, best for simple corrections
- `claude-sonnet-4-5` — Balanced speed and quality
- `claude-opus-4-5` — Highest quality

The AI post-processing uses [structured outputs](https://platform.claude.com/docs/en/build-with-claude/structured-outputs) to guarantee clean JSON responses without extra commentary.

**What it does:**
- Fixes technical terms transcribed as Russian phonetic equivalents (e.g., "кафка" → "Kafka")
- Corrects spelling errors
- Preserves original text structure and meaning

**Example replacements:**
- "кафка" → "Kafka"
- "реакт" → "React"
- "гоуэнг" → "Golang"
- "докер" → "Docker"
- "кубернетис" → "Kubernetes"

## Data Storage

| Data | Location | Retention |
|------|----------|-----------|
| Settings | `~/Library/Preferences/` | Persistent |
| API Key | macOS Keychain | Persistent, encrypted |
| History | `~/Library/Application Support/Murmurix/history.sqlite` | Persistent |
| Audio files | `/tmp/` | Deleted after transcription |
| Whisper models | `~/.cache/huggingface/hub/` | Persistent, shared with other HF apps |
| Python scripts | `~/Library/Application Support/Murmurix/` | Persistent |

### Managing Disk Space

To remove downloaded models:

```bash
# Remove a specific model
rm -rf ~/.cache/huggingface/hub/models--Systran--faster-whisper-medium

# Remove all Whisper models
rm -rf ~/.cache/huggingface/hub/models--Systran--faster-whisper-*

# Check cache size
du -sh ~/.cache/huggingface/hub/models--Systran--faster-whisper-*
```

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

## Troubleshooting

### Model not loading
```bash
# Check if model is installed
python ~/Library/Application\ Support/Murmurix/transcribe_daemon.py --list-models

# Download missing model
python ~/Library/Application\ Support/Murmurix/transcribe_daemon.py --download small
```

### Daemon not starting
```bash
# Check if daemon is running
ps aux | grep transcribe_daemon

# Kill stale daemon
pkill -f transcribe_daemon

# Remove stale socket
rm ~/Library/Application\ Support/Murmurix/daemon.sock
```

### Permission issues
- System Preferences → Security & Privacy → Privacy → Microphone → Enable for Murmurix
- System Preferences → Security & Privacy → Privacy → Accessibility → Enable for Murmurix

## License

MIT
