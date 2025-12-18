# Murmurix: Refactoring Backlog

## Overview

This document tracks remaining refactoring tasks and technical debt. Items are prioritized by impact and effort.

---

## High Priority

### ~~1. Migrate to Unified Error Hierarchy~~ COMPLETED

**Status**: Completed
**File**: `Services/MurmurixError.swift`

All error types migrated to unified `MurmurixError` hierarchy:
- `TranscriptionService` now uses `MurmurixError.transcription()`
- `AIPostProcessingService` now uses `MurmurixError.ai()`
- `AnthropicAPIClient` now uses `MurmurixError.ai()`
- `DaemonManager` now uses `MurmurixError.daemon()`

---

### 2. Replace Singletons with Dependency Injection

**Current singletons**:
```swift
Settings.shared           // Used in 8+ places
HistoryService.shared     // Used in AppDelegate, HistoryViewModel
AnthropicAPIClient.shared // Used in AIPostProcessingService, AISettingsViewModel
ModelDownloadService.shared // Used in GeneralSettingsViewModel
```

**Problem**: Hard to test, tight coupling

**Solution**: Inject dependencies through initializers

**Files to update**:
- `App/AppDelegate.swift` — create services and pass down
- `ViewModels/AISettingsViewModel.swift` — accept `AnthropicAPIClientProtocol`
- `Views/GeneralSettingsView.swift` — pass ViewModel with injected services
- `Services/TranscriptionService.swift` — uses `Settings.shared.whisperModel`
- `Services/DaemonManager.swift` — uses `Settings.shared.whisperModel`

**Effort**: High (4-6 hours)

---

## Medium Priority

### ~~3. Apply SettingsStyles to Views~~ COMPLETED

**Status**: Completed
**File**: `Views/Components/SettingsStyles.swift`

All main settings views now use centralized Layout, Typography, and AppColors constants:
- `GeneralSettingsView` — migrated
- `AISettingsView` — migrated
- `HotkeyRecorderView` — migrated
- `ResultView` — migrated

---

### ~~4. Extract Window Positioning Logic~~ COMPLETED

**Status**: Completed
**File**: `App/WindowPositioner.swift`

Created `WindowPositioner` utility with:
- `positionTopCenter(_:topOffset:)` — Position at top center of screen
- `center(_:)` — Center window
- `centerAndActivate(_:)` — Center and activate app

Window controllers updated:
- `RecordingWindowController` — uses `WindowPositioner.positionTopCenter()`
- `ResultWindowController` — uses `WindowPositioner.centerAndActivate()`

---

### 5. HistoryService Repository Pattern

**Current**: Direct SQLite3 C API calls mixed with domain logic

**Problem**:
- Low-level code in service layer
- Hard to swap storage implementation
- Repetitive prepare/bind/step/finalize pattern

**Solution**: Create `DatabaseRepository` protocol:
```swift
protocol Repository<T> {
    func save(_ item: T) throws
    func fetchAll() throws -> [T]
    func delete(id: UUID) throws
    func deleteAll() throws
}

class SQLiteTranscriptionRepository: Repository<TranscriptionRecord> {
    // Implementation
}
```

**Effort**: Medium (2-3 hours)

---

### ~~6. Replace print() with Proper Logging~~ COMPLETED

**Status**: Completed
**File**: `Services/Logger.swift`

Created `Logger` utility using `os.log` for system integration:
- `Logger.Audio` — Audio recording logs
- `Logger.Transcription` — Transcription logs
- `Logger.Daemon` — Daemon lifecycle logs
- `Logger.Hotkey` — Hotkey manager logs
- `Logger.History` — Database logs
- `Logger.AI` — AI processing logs

Each category has `.info()`, `.error()`, `.debug()`, and `.warning()` methods.

---

## Low Priority

### 7. RecordingWindowController DI

**Current**: Creates `AudioLevelObserver` internally with concrete `AudioRecorder`

```swift
// Current
audioLevelObserver = AudioLevelObserver(audioRecorder: audioRecorder)
```

**Problem**: Tightly coupled to concrete type

**Solution**: Accept observer through initializer or use protocol

**Effort**: Low (30 minutes)

---

### 8. Extract RecordingTimer to ViewModel

**Current**: `RecordingTimer` is a class in `Views/Recording/`

**Better location**: Could be in `ViewModels/` as it's presentation logic

**Effort**: Very Low (15 minutes)

---

### 9. Consolidate Color Constants

**Current**: Colors defined in multiple places
```swift
Color.white.opacity(0.05)  // AppColors.cardBackground exists but not used everywhere
Color.white.opacity(0.1)   // AppColors.borderOpacity exists but not used
Color.black.opacity(0.9)   // Used in Recording views, not in AppColors
```

**Solution**: Add missing colors to `AppColors` and use consistently

**Effort**: Low (30 minutes)

---

### 10. Add AISettingsView ViewModel Protocol

**Current**: `AISettingsViewModel` has no protocol

**Problem**: Can't mock for testing

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

**Effort**: Low (30 minutes)

---

### 11. GeneralSettingsViewModel Protocol

**Same as above** — add protocol for testability

**Effort**: Low (30 minutes)

---

## Nice to Have

### 12. SwiftUI Previews for All Views

**Current**: Some views have previews, some don't

**Missing previews**:
- `GeneralSettingsView`
- `AISettingsView`
- `HistoryView`
- `HotkeyRecorderView`
- `ResultView`

**Effort**: Low (1 hour)

---

### 13. Async/Await Migration

**Current**: Mix of completion handlers and async/await

**Files with completion handlers**:
- `ModelDownloadService.downloadModel(_:completion:)`
- Some internal callbacks

**Solution**: Migrate to async/await for consistency

**Effort**: Low (1 hour)

---

### 14. Documentation Comments

**Current**: Minimal documentation

**Files needing docs**:
- All protocol files
- Public API methods
- Complex algorithms (e.g., voice activity detection)

**Effort**: Medium (2-3 hours)

---

## Summary Table

| Priority | Task | Effort | Status |
|----------|------|--------|--------|
| ✅ | Migrate to MurmurixError | Medium | DONE |
| 🔴 High | Replace singletons with DI | High | Pending |
| ✅ | Apply SettingsStyles | Low-Medium | DONE |
| ✅ | Extract window positioning | Low | DONE |
| 🟠 Medium | HistoryService repository | Medium | Pending |
| ✅ | Replace print() with Logger | Low | DONE |
| 🟢 Low | RecordingWindowController DI | Low | Pending |
| 🟢 Low | Move RecordingTimer | Very Low | Pending |
| 🟢 Low | Consolidate colors | Low | Pending |
| 🟢 Low | ViewModel protocols | Low | Pending |
| ⚪ Nice | SwiftUI previews | Low | Pending |
| ⚪ Nice | Async/await migration | Low | Pending |
| ⚪ Nice | Documentation | Medium | Pending |

---

## Completed Refactoring

For reference, here's what has been refactored:

- ✅ Split `AppDelegate` → `MenuBarManager`, `WindowManager`
- ✅ Split `TranscriptionService` → `DaemonManager`
- ✅ Split `RecordingView.swift` → 6 files in `Views/Recording/`
- ✅ Split `Settings.swift` → `WhisperModel`, `AIModel` extracted
- ✅ Created `AppConstants.swift` for centralized constants
- ✅ Created `SettingsStyles.swift` for view modifiers
- ✅ Created `MurmurixError.swift` unified error hierarchy
- ✅ Created `GeneralSettingsViewModel`
- ✅ Created `AISettingsViewModel`
- ✅ Created `HistoryViewModel`
- ✅ Eliminated voice activity threshold duplication
- ✅ Moved default AI prompt to `AIConfig`
- ✅ Migrated all services to unified `MurmurixError` (removed 4 duplicate error enums)
- ✅ Applied `Layout`, `Typography`, `AppColors` constants to all settings views
- ✅ Created `Logger.swift` with `os.log` integration (replaced 22 print statements)
- ✅ Created `WindowPositioner.swift` for centralized window positioning
- ✅ Added 58 new tests (114 total): MurmurixError, AppConstants, WindowPositioner, Logger, WhisperModel, AIModel, voice activity, AI post-processing, skip AI feature
