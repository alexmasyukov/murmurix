# Murmurix: Refactoring Backlog

## Overview

This document tracks remaining refactoring tasks and technical debt. Items are prioritized by impact and effort.

---

## High Priority

### 1. Migrate to Unified Error Hierarchy

**Status**: Infrastructure created, migration pending
**File**: `Services/MurmurixError.swift`

The unified `MurmurixError` hierarchy is defined but not yet used. Old error types remain:

| Old Error | Location | Migrate To |
|-----------|----------|------------|
| `TranscriptionService.TranscriptionError` | TranscriptionService.swift | `MurmurixError.transcription()` |
| `AIPostProcessingError` | AIPostProcessingService.swift | `MurmurixError.ai()` |
| `AnthropicError` | AnthropicAPIClient.swift | `AIError` cases |
| `DaemonManager.DaemonError` | DaemonManager.swift | `MurmurixError.daemon()` |

**Benefits**:
- Consistent error handling across app
- Recovery suggestions for all errors
- Single place to update error messages

**Effort**: Medium (2-3 hours)

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

### 3. Apply SettingsStyles to Views

**Status**: Styles created, application pending
**File**: `Views/Components/SettingsStyles.swift`

Created modifiers not yet applied:
- `settingsCard()` — card background style
- `settingsLabel()` — label typography
- `settingsDescription()` — description typography

**Files with hardcoded values**:
```
Views/GeneralSettingsView.swift   — 15+ instances
Views/AISettingsView.swift        — 12+ instances
Views/HotkeyRecorderView.swift    — 8+ instances
Views/ResultView.swift            — 10+ instances
Views/History/HistoryDetailView.swift
Views/History/HistoryStatsView.swift
```

**Pattern to replace**:
```swift
// Before
.padding(.horizontal, 16)
.padding(.vertical, 10)
.background(Color.white.opacity(0.05))
.cornerRadius(10)

// After
.settingsCard()
```

**Effort**: Low-Medium (1-2 hours)

---

### 4. Extract Window Positioning Logic

**Problem**: Duplicate positioning code in window controllers

**Files**:
- `Views/RecordingWindowController.swift` (lines 93-101, 104-112)
- `Views/ResultWindowController.swift` (similar pattern)

**Solution**: Create `WindowPositioner` utility:
```swift
enum WindowPositioner {
    static func centerTop(_ window: NSWindow, offset: CGFloat = 10)
    static func center(_ window: NSWindow)
}
```

**Effort**: Low (30 minutes)

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

### 6. Replace print() with Proper Logging

**Current**: 30+ `print()` statements scattered across services

**Files with print statements**:
```
Services/TranscriptionService.swift  — 5 prints
Services/DaemonManager.swift         — 8 prints
Services/AudioRecorder.swift         — 4 prints
Services/HistoryService.swift        — 3 prints
App/AppDelegate.swift                — 2 prints
```

**Solution**: Create `Logger` utility:
```swift
enum Logger {
    static func debug(_ message: String, file: String = #file)
    static func info(_ message: String)
    static func error(_ message: String, error: Error?)
}
```

Or use `os.log` / `OSLog` for system integration.

**Effort**: Low (1 hour)

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

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| 🔴 High | Migrate to MurmurixError | Medium | High |
| 🔴 High | Replace singletons with DI | High | High |
| 🟠 Medium | Apply SettingsStyles | Low-Medium | Medium |
| 🟠 Medium | Extract window positioning | Low | Low |
| 🟠 Medium | HistoryService repository | Medium | Medium |
| 🟠 Medium | Replace print() with Logger | Low | Medium |
| 🟢 Low | RecordingWindowController DI | Low | Low |
| 🟢 Low | Move RecordingTimer | Very Low | Low |
| 🟢 Low | Consolidate colors | Low | Low |
| 🟢 Low | ViewModel protocols | Low | Medium |
| ⚪ Nice | SwiftUI previews | Low | Low |
| ⚪ Nice | Async/await migration | Low | Low |
| ⚪ Nice | Documentation | Medium | Medium |

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
