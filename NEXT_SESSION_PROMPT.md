# Промпт для продолжения рефакторинга Murmurix

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

## Что нужно сделать

### Phase 4 (Polish + Deferred)
```
1. Documentation (DocC comments)
2. Keychain key enum
3. Swift 6 strict concurrency preparation
4. Remove @unchecked Sendable (требует конвертации в actors)
5. Split GeneralSettingsView into sections (опционально)
6. Add Process/FileManager abstractions (опционально)
```

## Ключевые файлы

- `REFACTORING_PLAN.md` - полный план
- `MurmurixTests/Phase1Tests.swift` - тесты Phase 1
- `MurmurixTests/Phase2Tests.swift` - тесты Phase 2
- `MurmurixTests/Phase3Tests.swift` - тесты Phase 3
- `MurmurixTests/Mocks.swift` - все моки
- `Murmurix/Services/UnixSocketClient.swift` - сокет-клиент
- `Murmurix/ViewModels/GeneralSettingsViewModel.swift` - ViewModel с тестовой логикой

## Статистика тестов

| Файл | Тестов |
|------|--------|
| Phase1Tests.swift | 55 |
| Phase2Tests.swift | 20 |
| Phase3Tests.swift | 18 |
| **Всего новых** | **93** |

## Команда для запуска тестов

```bash
xcodebuild -project Murmurix.xcodeproj -scheme Murmurix -destination 'platform=macOS' test
```

## Начни с

```
Прочитай REFACTORING_PLAN.md и начни Phase 4 с добавления DocC комментариев к публичным API
```
