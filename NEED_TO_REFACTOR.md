# Murmurix: Refactoring Backlog

## Overview

This document tracks remaining refactoring tasks and technical debt. Items are prioritized by impact and effort.

**Last updated**: 2025-12-23

---

## Low Priority

### 1. Consolidate Color Constants

**Status**: Pending

**Current**: 12 places use raw `Color.white.opacity(X)` instead of `AppColors.*`

**Files with hardcoded colors**:
- `Views/HotkeyRecorderView.swift` — 3 occurrences
- `Views/History/HistoryStatsView.swift` — 1 occurrence
- `Views/AISettingsView.swift` — 1 occurrence
- `Views/Recording/RecordingComponents.swift` — 2 occurrences
- `Views/Recording/RecordingView.swift` — 1 occurrence
- `Views/ResultView.swift` — 2 occurrences

**Solution**: Add missing colors to `AppColors` and use consistently:
```swift
// Add to AppConstants.swift
static let buttonBackground = Color.white.opacity(0.15)
static let overlayBackground = Color.black.opacity(0.9)
static let subtleBorder = Color.white.opacity(0.2)
```

**Effort**: Low (30 minutes)

---

### 2. Add ViewModel Protocols

**Status**: Pending

**Current**: ViewModels have no protocols, can't mock for testing

**ViewModels without protocols**:
- `AISettingsViewModel`
- `GeneralSettingsViewModel`
- `HistoryViewModel`

**Solution**:
```swift
protocol AISettingsViewModelProtocol: ObservableObject {
    var apiKey: String { get set }
    var prompt: String { get set }
    var isTesting: Bool { get }
    var testResult: APITestResult? { get }

    func loadSettings()
    func testConnection()
    func resetPromptToDefault()
}
```

**Effort**: Low (1 hour)

---

### 3. RecordingWindowController DI

**Status**: Pending
**File**: `Views/RecordingWindowController.swift`

**Current**: Creates `AudioLevelObserver` with concrete `AudioRecorder` type
```swift
init(audioRecorder: AudioRecorder, ...) {  // Concrete type
    audioLevelObserver = AudioLevelObserver(audioRecorder: audioRecorder)
}
```

**Problem**: Tightly coupled to concrete type

**Solution**: Accept `AudioRecorderProtocol` instead

**Effort**: Low (30 minutes)

---

## Nice to Have

### 4. SwiftUI Previews for All Views

**Status**: Pending

**Missing previews**:
- `GeneralSettingsView`
- `AISettingsView`
- `HistoryView`
- `HotkeyRecorderView`
- `ResultView`

**Effort**: Low (1 hour)

---

### 5. Move RecordingTimer to ViewModels

**Status**: Pending
**Current location**: `Views/Recording/RecordingTimer.swift`

**Better location**: `ViewModels/` — it's presentation logic, not a view

**Effort**: Very Low (15 minutes)

---

## Summary Table

| Priority | Task | Effort | Status |
|----------|------|--------|--------|
| 🟢 Low | Consolidate color constants | 30 min | Pending |
| 🟢 Low | Add ViewModel protocols | 1 hour | Pending |
| 🟢 Low | RecordingWindowController DI | 30 min | Pending |
| ⚪ Nice | SwiftUI previews | 1 hour | Pending |
| ⚪ Nice | Move RecordingTimer | 15 min | Pending |

---

## Completed Refactoring

For reference, here's what has been completed:

- ✅ Split `AppDelegate` → `MenuBarManager`, `WindowManager`
- ✅ Split `TranscriptionService` → `DaemonManager`
- ✅ Split `RecordingView.swift` → 6 files in `Views/Recording/`
- ✅ Split `Settings.swift` → `WhisperModel`, `AIModel`, `OpenAITranscriptionModel` extracted
- ✅ Created `AppConstants.swift` for centralized constants
- ✅ Created `SettingsStyles.swift` for view modifiers
- ✅ Created `MurmurixError.swift` unified error hierarchy
- ✅ Created `GeneralSettingsViewModel`, `AISettingsViewModel`, `HistoryViewModel`
- ✅ Eliminated voice activity threshold duplication
- ✅ Moved default AI prompt to `AIConfig`
- ✅ Migrated all services to unified `MurmurixError` (removed 4 duplicate error enums)
- ✅ Applied `Layout`, `Typography`, `AppColors` constants to main settings views
- ✅ Created `Logger.swift` with `os.log` integration (replaced 22 print statements)
- ✅ Created `WindowPositioner.swift` for centralized window positioning
- ✅ Added 114 tests with full mocking
- ✅ Integrated Lottie library for animated cat loading states
- ✅ Created `LottieView.swift` (NSViewRepresentable wrapper with color replacement)
- ✅ Created `CatLoadingView.swift` (unified transcribing/processing states)
- ✅ Created app icon (waveform, white on black with rounded corners)
- ✅ Added OpenAI cloud transcription (gpt-4o-transcribe)
- ✅ Added audio compression (WAV → M4A for cloud uploads)
- ✅ Async/await migration (only `AudioRecorder.requestPermission` uses completion handler)
- ✅ Released Version 1.0
- ✅ **Removed debug print statements** from `RecordingWindowController.swift`
- ✅ **Replaced singletons with Dependency Injection**:
  - Added protocols: `OpenAITranscriptionServiceProtocol`, `ModelDownloadServiceProtocol`
  - Made `SettingsStorageProtocol` class-only (`AnyObject`)
  - Updated services to accept dependencies via init: `TranscriptionService`, `DaemonManager`, `GlobalHotkeyManager`, `AIPostProcessingService`
  - Updated ViewModels to use protocol-based dependencies
- ✅ **HistoryService → Repository pattern**:
  - Created `Repository.swift` with generic `Repository<T>` protocol
  - Created `SQLiteDatabase` helper class for common SQLite operations
  - Created `SQLiteTranscriptionRepository` implementation
  - Simplified `HistoryService` to delegate to repository
