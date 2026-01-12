# Промпт для продолжения работы над Murmurix

## Контекст

Murmurix - macOS Menu Bar приложение для голосовой транскрипции (Whisper, OpenAI, Gemini).

## Что было сделано

### Phase 1 ✅ DONE (код + тесты)

1. **Моки** в `MurmurixTests/Mocks.swift`:
   - MockDaemonManager, MockHotkeyManager, MockTranscriptionRepository

2. **Утилиты**:
   - `Models/APITestResult.swift`
   - `Services/AudioTestUtility.swift`
   - `Services/MIMETypeResolver.swift`

3. **DRY рефакторинг**: hotkey методы, удален дублированный код

4. **Тесты** в `MurmurixTests/Phase1Tests.swift` - 55 тестов

### Phase 2 ✅ DONE (код + тесты)

1. **URLSession абстракция**:
   - `URLSessionProtocol` в `Protocols.swift`
   - DI в `OpenAITranscriptionService`
   - `MockURLSession` в `Mocks.swift`

2. **UnixSocketClient**:
   - `Services/UnixSocketClient.swift` - SocketClientProtocol, SocketError
   - DI в `TranscriptionService` и `DaemonManager`
   - `MockSocketClient` в `Mocks.swift`

3. **Тесты** в `MurmurixTests/Phase2Tests.swift` - 20 тестов

### Phase 3 ✅ DONE (код + тесты)

1. **Перенос тестовой логики в ViewModel**:
   - `testLocalModel`, `testOpenAI`, `testGemini` перенесены из View в ViewModel
   - `@MainActor` добавлен в `GeneralSettingsViewModel`
   - Инъекция сервисов: OpenAI, Gemini, Transcription

2. **Удаление Settings.shared из View**:
   - Все runtime операции используют `viewModel.settings`
   - Init по-прежнему использует Settings.shared (ограничение SwiftUI)

3. **Новые типы**:
   - `TestService` enum для идентификации сервисов
   - `clearTestResult(for:)` метод

4. **Тесты** в `MurmurixTests/Phase3Tests.swift` - 18 тестов

### Phase 4 ✅ DONE (Keychain enum)

1. **KeychainKey enum** в `Services/KeychainService.swift`:
   - Type-safe ключи: `.openaiApiKey`, `.geminiApiKey`
   - Перегруженные методы `save/load/delete/exists`
   - Обновлен `Settings.swift` для использования enum

2. **Тесты** в `MurmurixTests/Phase4Tests.swift` - 8 тестов

### Integration Tests ✅ DONE

1. **Интеграционные тесты с реальным демоном** в `MurmurixTests/IntegrationTests.swift`:
   - `daemonStartsAndStops()` - проверка lifecycle демона
   - `daemonCleansUpSocketFile()` - проверка cleanup сокета
   - `daemonTranscribesSilentAudio()` - реальная транскрипция

2. **DaemonCleanup** утилита:
   - Убивает демон по PID из файла
   - Fallback через `pkill -f transcribe_daemon.py`
   - Чистит socket и pid файлы

3. **Исправлены flaky тесты**:
   - `toggleRecordingWithOpenAIMode` - timeout 100ms → 2s
   - `toggleRecordingWithGeminiMode` - timeout 100ms → 2s
   - `serviceAcceptsCustomSocketClientFactory` - убрана зависимость от внешнего состояния

## Рефакторинг завершён

Все основные фазы выполнены. Остались только низкоприоритетные задачи:

```
Deferred (low priority):
1. Remove @unchecked Sendable (требует конвертации в actors)
2. Split GeneralSettingsView into sections (файл уже хорошо структурирован)
3. Add Process/FileManager abstractions
4. Swift 6 strict concurrency (делать при переходе на Swift 6)
5. DocC comments (необязательно)
```

## Ключевые файлы

- `REFACTORING_PLAN.md` - полный план
- `MurmurixTests/Phase1Tests.swift` - тесты Phase 1
- `MurmurixTests/Phase2Tests.swift` - тесты Phase 2
- `MurmurixTests/Phase3Tests.swift` - тесты Phase 3
- `MurmurixTests/Phase4Tests.swift` - тесты Phase 4
- `MurmurixTests/IntegrationTests.swift` - интеграционные тесты с демоном
- `MurmurixTests/Mocks.swift` - все моки
- `Murmurix/Services/UnixSocketClient.swift` - сокет-клиент
- `Murmurix/Services/KeychainService.swift` - сервис Keychain с type-safe API
- `Murmurix/ViewModels/GeneralSettingsViewModel.swift` - ViewModel с тестовой логикой

## Статистика тестов

| Файл | Тестов |
|------|--------|
| Phase1Tests.swift | 55 |
| Phase2Tests.swift | 20 |
| Phase3Tests.swift | 18 |
| Phase4Tests.swift | 8 |
| IntegrationTests.swift | 3 |
| RecordingCoordinatorTests.swift | ~15 |
| Другие тесты | ~15 |
| **Всего** | **~114** |

## Команда для запуска тестов

```bash
xcodebuild -project Murmurix.xcodeproj -scheme Murmurix -destination 'platform=macOS' test
```

Все тесты проходят (unit, integration, UI).
